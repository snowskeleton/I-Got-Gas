//
//  MigrationTests.swift
//  I Got GasTests
//
//  Opens stores written in each shipped 2.x shape with the real migration
//  plan. 3.0 build 4 went to the App Store unable to open any 2.0.1 store,
//  because the plan only knew the unreleased cloud-saves 2.x shape.
//

import Testing
import Foundation
import SwiftData
@testable import I_Got_Gas

@MainActor
struct MigrationTests {

    private func temporaryStoreURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("igg-migration-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("default.store")
    }

    private func openCurrent(at url: URL) throws -> ModelContainer {
        let schema = Schema(IGGSchemaV3.models)
        return try ModelContainer(
            for: schema,
            migrationPlan: IGGMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
    }

    @Test func appStore201StoreMigrates() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        do {
            let schema = Schema(versionedSchema: IGGSchemaV1.self)
            let container = try ModelContainer(
                for: schema, configurations: [ModelConfiguration(schema: schema, url: url)]
            )
            let context = ModelContext(container)
            let car = IGGSchemaV1.SDCar()
            car.id = "car-1"
            car.name = "Civic"
            car.startingOdometer = 40_000
            context.insert(car)

            let fill = IGGSchemaV1.SDService()
            fill.id = "svc-1"
            fill.cost = 41.37
            fill.gallons = 10.5
            fill.odometer = 41_000
            fill.isFuel = true
            fill.car = car
            context.insert(fill)

            let schedule = IGGSchemaV1.SDScheduledService()
            schedule.id = "sched-1"
            schedule.name = "Oil change"
            schedule.frequencyMiles = 5_000
            schedule.odometerFirstOccurance = 45_000
            schedule.frequencyTime = 6
            schedule.car = car
            context.insert(schedule)
            try context.save()
        }

        let container = try openCurrent(at: url)
        let context = ModelContext(container)

        let cars = try context.fetch(FetchDescriptor<SDCar>())
        #expect(cars.map(\.id) == ["car-1"])
        #expect(cars.first?.name == "Civic")

        let services = try context.fetch(FetchDescriptor<SDService>())
        #expect(services.count == 1)
        let service = try #require(services.first)
        #expect(service.costMinor == 4137)
        #expect(service.kind == .fuel)
        #expect(service.car?.id == "car-1")
        #expect(abs(Double(service.volumeML) - 10.5 * 3785.411784) < 1)

        let schedules = try context.fetch(FetchDescriptor<SDScheduledService>())
        #expect(schedules.first?.name == "Oil change")
        #expect(schedules.first?.frequencyTime == 6)
    }

    @Test func cloudSaves2xStoreStillMigrates() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        do {
            let schema = Schema(versionedSchema: IGGSchemaV2.self)
            let container = try ModelContainer(
                for: schema, configurations: [ModelConfiguration(schema: schema, url: url)]
            )
            let context = ModelContext(container)
            let car = IGGSchemaV2.SDCar()
            car.id = "car-2"
            context.insert(car)
            let service = IGGSchemaV2.SDService()
            service.id = "svc-2"
            service.cost = 12.5
            service.car = car
            context.insert(service)
            try context.save()
        }

        let context = ModelContext(try openCurrent(at: url))
        let services = try context.fetch(FetchDescriptor<SDService>())
        #expect(services.first?.costMinor == 1250)
    }

    // MARK: - Recovery export

    private func makeV1Store() throws -> URL {
        let url = temporaryStoreURL()
        let schema = Schema(versionedSchema: IGGSchemaV1.self)
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let context = ModelContext(container)
        let car = IGGSchemaV1.SDCar()
        car.name = "Civic, the good one"
        context.insert(car)
        let fill = IGGSchemaV1.SDService()
        fill.id = "svc-r"
        fill.name = "Shell, Main St"
        fill.cost = 41.37
        fill.gallons = 10.5
        fill.odometer = 41_000
        fill.isFuel = true
        fill.car = car
        context.insert(fill)
        try context.save()
        return url
    }

    @Test func detectsEachStoreShape() throws {
        let v1 = try makeV1Store()
        defer { try? FileManager.default.removeItem(at: v1.deletingLastPathComponent()) }
        #expect(RecoveryExport.detectShape(of: v1) == .v1)

        let v3 = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: v3.deletingLastPathComponent()) }
        let schema = Schema(IGGSchemaV3.models)
        _ = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: v3)])
        #expect(RecoveryExport.detectShape(of: v3) == .v3)
    }

    @Test func recoveryArchiveLeavesTheStoreAlone() throws {
        let url = try makeV1Store()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let before = try Data(contentsOf: url)

        let archive = try RecoveryExport.makeArchive(storeURL: url, error: nil)
        #expect(FileManager.default.fileExists(atPath: archive.path))
        #expect(archive.pathExtension == "zip")
        #expect(try Data(contentsOf: url) == before)
        // Still a V1 store, so the real migration will still recognise it.
        #expect(RecoveryExport.detectShape(of: url) == .v1)
    }

    @Test func legacyRecoveryCSVReimports() throws {
        let service = try {
            let url = try makeV1Store()
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let schema = Schema(versionedSchema: IGGSchemaV1.self)
            let context = ModelContext(try ModelContainer(
                for: schema, configurations: [ModelConfiguration(schema: schema, url: url)]
            ))
            return try #require(context.fetch(FetchDescriptor<IGGSchemaV1.SDService>()).first)
        }()
        let csv = RecoveryExport.legacyCSV(services: [.init(service)], schedules: [])

        let result = CSVImporter.parse(csv, distanceUnit: .kilometers)
        #expect(result.skippedRows.isEmpty)
        let parsed = try #require(result.services.first)
        #expect(parsed.id == "svc-r")
        #expect(parsed.name == "Shell, Main St")
        #expect(parsed.costMinor == 4137)
        #expect(parsed.kind == .fuel)
        // Legacy rows are miles regardless of the car's unit.
        #expect(abs(Double(parsed.odometerMeters) - 41_000 * 1609.344) < 1)
    }
}
