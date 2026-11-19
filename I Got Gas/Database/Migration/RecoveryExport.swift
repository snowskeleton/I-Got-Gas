//
//  RecoveryExport.swift
//  I Got Gas
//
//  The export behind the "couldn't be opened" screen. At that point the app
//  is running on an in-memory store and the real one failed to open, so this
//  cannot go through the normal container. Instead it works on copies:
//
//    database/   an untouched copy of the store files, so support can always
//                recover everything, whatever went wrong.
//    *.csv       one per vehicle, in the same format as the in-app export, so
//                the user can see with their own eyes that the records exist.
//
//  The CSVs come from a second, scratch copy opened with whichever schema the
//  store's columns say it was written with. Opening a store with a schema it
//  matches exactly runs no migration, and because it is a scratch copy even a
//  surprise migration could not touch the real store or the database/ copy.
//
//  CSV is best-effort. If the store can't be read at all, the archive still
//  carries the database copy and a README saying what happened.
//

import Foundation
import SwiftData
import SQLite3

enum RecoveryExport {

    enum Shape: String {
        case v1 = "2.0.x"
        case v1_1 = "2.1"
        case v2 = "2.x (unreleased)"
        case v3 = "3.0"
        case unknown = "unknown"
    }

    /// Builds the archive and returns the zip's location in the temporary
    /// directory. Throws only if not even the raw copy could be made.
    @MainActor
    static func makeArchive(storeURL: URL, error loadError: Error?) throws -> URL {
        let manager = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let work = manager.temporaryDirectory.appendingPathComponent("RecoveryExport", isDirectory: true)
        try? manager.removeItem(at: work)

        let folder = work.appendingPathComponent("I Got Gas data \(stamp)", isDirectory: true)
        let database = folder.appendingPathComponent("database", isDirectory: true)
        let scratch = work.appendingPathComponent("scratch", isDirectory: true)
        try manager.createDirectory(at: database, withIntermediateDirectories: true)
        try manager.createDirectory(at: scratch, withIntermediateDirectories: true)

        try copyStore(from: storeURL, to: database)
        try copyStore(from: storeURL, to: scratch)
        let scratchStore = scratch.appendingPathComponent(storeURL.lastPathComponent)

        let shape = detectShape(of: scratchStore)
        var notes: [String] = []
        do {
            let files = try writeCSVs(from: scratchStore, shape: shape, into: folder)
            notes.append("Exported \(files) vehicle file(s).")
        } catch {
            notes.append("The records could not be read into CSV: \(error)")
        }
        try? manager.removeItem(at: scratch)

        let readme = """
        I Got Gas data export
        Created \(stamp)

        One CSV per vehicle, in the same format as the app's own export.
        The database folder is an untouched copy of the app's data files.
        If anything looks wrong, send this whole file to support@igotgas.app.

        Data format: \(shape.rawValue)
        \(notes.joined(separator: "\n"))
        Open error: \(loadError.map { String(describing: $0) } ?? "none")
        """
        try readme.write(to: folder.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)

        return try zip(folder, to: work.appendingPathComponent("I Got Gas data \(stamp).zip"))
    }

    // MARK: - Copying

    private static func copyStore(from storeURL: URL, to directory: URL) throws {
        let manager = FileManager.default
        var copied = 0
        for component in StoreBackup.components(of: storeURL)
        where manager.fileExists(atPath: component.path) {
            try manager.copyItem(
                at: component, to: directory.appendingPathComponent(component.lastPathComponent)
            )
            copied += 1
        }
        guard copied > 0 else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: storeURL.path])
        }
    }

    // MARK: - Shape

    /// Reads the service table's columns straight out of SQLite. Each version
    /// has a column the earlier ones don't.
    static func detectShape(of storeURL: URL) -> Shape {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return .unknown
        }
        let services = columns(of: "ZSDSERVICE", in: db)
        if services.contains("ZCOSTMINOR") { return .v3 }
        if services.contains("ZUPDATEDAT") {
            return columns(of: "ZSDCARSETTINGS", in: db).contains("Z_NOTIFYONCHANGE") ? .v2 : .v1_1
        }
        if services.contains("ZCOST") { return .v1 }
        return .unknown
    }

    private static func columns(of table: String, in db: OpaquePointer?) -> Set<String> {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        var columns = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 1) {
                columns.insert(String(cString: name).uppercased())
            }
        }
        return columns
    }

    // MARK: - CSV

    @MainActor
    private static func writeCSVs(from storeURL: URL, shape: Shape, into folder: URL) throws -> Int {
        var written = 0
        func write(_ csv: String, name: String) throws {
            written += 1
            let safe = name.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|"))
                .joined(separator: "-")
                .trimmingCharacters(in: .whitespaces)
            let file = "\(String(format: "%02d", written)) \(safe.isEmpty ? "Vehicle" : safe).csv"
            try csv.write(to: folder.appendingPathComponent(file), atomically: true, encoding: .utf8)
        }

        switch shape {
        case .v3:
            let context = try open(storeURL, schema: Schema(IGGSchemaV3.models))
            for car in try context.fetch(FetchDescriptor<SDCar>()) where !car.deleted {
                let csv = generateCSV(
                    for: (car.services ?? []).filter { !$0.deleted },
                    scheduledServices: (car.scheduledServices ?? []).filter { !$0.deleted },
                    car: car
                )
                try write(csv, name: car.visualName)
            }

        case .v1_1:
            let context = try open(storeURL, schema: Schema(versionedSchema: IGGSchemaV1_1.self))
            for car in try context.fetch(FetchDescriptor<IGGSchemaV1_1.SDCar>()) where !car.deleted {
                let csv = legacyCSV(
                    services: (car.services ?? []).filter { !$0.deleted }.map(LegacyService.init),
                    schedules: (car.scheduledServices ?? []).filter { !$0.deleted }.map(LegacySchedule.init)
                )
                try write(csv, name: displayName(car.name, car.year, car.make, car.model))
            }

        case .v2:
            let context = try open(storeURL, schema: Schema(versionedSchema: IGGSchemaV2.self))
            for car in try context.fetch(FetchDescriptor<IGGSchemaV2.SDCar>()) where !car.deleted {
                let csv = legacyCSV(
                    services: (car.services ?? []).filter { !$0.deleted }.map(LegacyService.init),
                    schedules: (car.scheduledServices ?? []).filter { !$0.deleted }.map(LegacySchedule.init)
                )
                try write(csv, name: displayName(car.name, car.year, car.make, car.model))
            }

        case .v1, .unknown:
            // Unknown gets the oldest shape: it is the one real users have.
            let context = try open(storeURL, schema: Schema(versionedSchema: IGGSchemaV1.self))
            for car in try context.fetch(FetchDescriptor<IGGSchemaV1.SDCar>()) where !car.deleted {
                let csv = legacyCSV(
                    services: (car.services ?? []).map(LegacyService.init),
                    schedules: (car.scheduledServices ?? []).map(LegacySchedule.init)
                )
                try write(csv, name: displayName(car.name, car.year, car.make, car.model))
            }
        }
        return written
    }

    @MainActor
    private static func open(_ url: URL, schema: Schema) throws -> ModelContext {
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let context = ModelContext(container)
        // The context does not keep its container alive on its own.
        retained = container
        return context
    }

    nonisolated(unsafe) private static var retained: ModelContainer?

    private static func displayName(_ name: String, _ year: Int?, _ make: String, _ model: String) -> String {
        if !name.isEmpty { return name }
        let joined = [year.map(String.init) ?? "", make, model].filter { !$0.isEmpty }.joined(separator: " ")
        return joined.isEmpty ? "Vehicle" : joined
    }

    // MARK: Legacy rows

    /// Both 2.x shapes, flattened. The values are what 2.x stored: dollars,
    /// miles and US gallons.
    struct LegacyService {
        var id, name, vendor, description: String
        var cost, gallons: Double
        var date: Date
        var odometer: Int
        var isFuel, isFullTank: Bool

        init(_ s: IGGSchemaV1.SDService) {
            (id, name, vendor, description) = (s.id, s.name, s.vendorName, s.fullDescription)
            (cost, gallons, date, odometer) = (s.cost, s.gallons, s.date, s.odometer)
            (isFuel, isFullTank) = (s.isFuel, s.isFullTank)
        }
        init(_ s: IGGSchemaV1_1.SDService) {
            (id, name, vendor, description) = (s.id, s.name, s.vendorName, s.fullDescription)
            (cost, gallons, date, odometer) = (s.cost, s.gallons, s.date, s.odometer)
            (isFuel, isFullTank) = (s.isFuel, s.isFullTank)
        }
        init(_ s: IGGSchemaV2.SDService) {
            (id, name, vendor, description) = (s.id, s.name, s.vendorName, s.fullDescription)
            (cost, gallons, date, odometer) = (s.cost, s.gallons, s.date, s.odometer)
            (isFuel, isFullTank) = (s.isFuel, s.isFullTank)
        }
    }

    struct LegacySchedule {
        var id, name, description, interval: String
        var repeating: Bool
        var frequencyMiles, frequencyTime: Int

        init(_ s: IGGSchemaV1.SDScheduledService) {
            (id, name, description, interval) = (s.id, s.name, s.fullDescription, s.frequencyTimeInterval.rawValue)
            (repeating, frequencyMiles, frequencyTime) = (s.repeating, s.frequencyMiles, s.frequencyTime)
        }
        init(_ s: IGGSchemaV1_1.SDScheduledService) {
            (id, name, description, interval) = (s.id, s.name, s.fullDescription, s.frequencyTimeInterval.rawValue)
            (repeating, frequencyMiles, frequencyTime) = (s.repeating, s.frequencyMiles, s.frequencyTime)
        }
        init(_ s: IGGSchemaV2.SDScheduledService) {
            (id, name, description, interval) = (s.id, s.name, s.fullDescription, s.frequencyTimeInterval.rawValue)
            (repeating, frequencyMiles, frequencyTime) = (s.repeating, s.frequencyMiles, s.frequencyTime)
        }
    }

    /// The 2.x export layout, which `CSVImporter` recognises from the
    /// "Is Fuel" / "Gallons" headers and reads as dollars, miles and gallons.
    static func legacyCSV(services: [LegacyService], schedules: [LegacySchedule]) -> String {
        let dates = ISO8601DateFormatter()
        dates.formatOptions = [.withInternetDateTime]
        var rows: [[String]] = [[
            "ID", "Name", "Type", "Cost", "Date", "Odometer", "Is Fuel", "Gallons",
            "Full Tank", "Vendor", "Description", "Repeating",
            "Frequency Miles", "Frequency Time", "Frequency Interval",
        ]]
        for s in services {
            rows.append([
                s.id, s.name, "Service", String(s.cost), dates.string(from: s.date),
                String(s.odometer), String(s.isFuel), String(s.gallons), String(s.isFullTank),
                s.vendor, s.description, "", "", "", "",
            ])
        }
        for s in schedules {
            rows.append([
                s.id, s.name, "Scheduled Service", "", "", "", "", "", "", "",
                s.description, String(s.repeating), String(s.frequencyMiles),
                String(s.frequencyTime), s.interval,
            ])
        }
        return rows.map { $0.map(csvEscaped).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    // MARK: - Zip

    /// `NSFileCoordinator`'s upload option is Foundation's only archiver; its
    /// temporary zip vanishes when the block returns, so it is copied out.
    private static func zip(_ folder: URL, to destination: URL) throws -> URL {
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: folder, options: [.forUploading], error: &coordinationError
        ) { temporary in
            do {
                try FileManager.default.copyItem(at: temporary, to: destination)
            } catch {
                copyError = error
            }
        }
        if let error = coordinationError ?? copyError { throw error }
        return destination
    }
}
