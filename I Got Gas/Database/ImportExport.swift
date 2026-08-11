//
//  ImportExport.swift
//  I Got Gas
//
//  Created by snow on 12/23/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//
//  CSV export/import.
//
//  Two things changed in 3.0. Values are written in the car's display units
//  with the unit named in the header, rather than bare numbers that silently
//  meant miles and US gallons. And fields are properly quoted — part names and
//  descriptions contain commas, which used to corrupt the file.
//
//  The importer still reads 2.x exports; it detects them from the header.
//

import Foundation

// MARK: - Export

func generateCSV(
    for services: [SDService],
    scheduledServices: [SDScheduledService],
    car: SDCar
) -> String {
    let distanceUnit = car.distanceUnit
    let volumeUnit = UnitPreferences.volumeUnit
    let currency = UnitPreferences.currencyCode
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime]

    var rows: [[String]] = []

    rows.append([
        "ID", "Name", "Type",
        "Cost (\(currency))",
        "Date",
        "Odometer (\(distanceUnit.abbreviation))",
        "Kind",
        "Volume (\(volumeUnit.abbreviation))",
        "Full Tank",
        "Vendor", "Description", "Parts", "Schedule",
        "Repeating",
        "Frequency Distance (\(distanceUnit.abbreviation))",
        "Frequency Time", "Frequency Interval",
    ])

    for service in services {
        rows.append([
            service.id,
            service.displayName,
            "Service",
            service.cost.amount.formatted(.number.precision(.fractionLength(0...4)).grouping(.never)),
            dateFormatter.string(from: service.date),
            String(service.odometer.rounded(to: distanceUnit)),
            service.kind.rawValue,
            service.volume.converted(to: volumeUnit)
                .formatted(.number.precision(.fractionLength(0...4)).grouping(.never)),
            String(service.isFullTank),
            service.vendorName,
            service.fullDescription,
            service.liveParts.map(\.name).joined(separator: "; "),
            service.scheduledService?.name ?? "",
            "", "", "", "",
        ])
    }

    for scheduled in scheduledServices {
        rows.append([
            scheduled.id,
            scheduled.name,
            "Scheduled Service",
            "", "", "", "", "", "", "",
            scheduled.fullDescription,
            "", "",
            String(scheduled.repeating),
            String(scheduled.frequencyDistance.rounded(to: distanceUnit)),
            String(scheduled.frequencyTime),
            scheduled.frequencyTimeInterval.rawValue,
        ])
    }

    return rows.map { $0.map(csvEscaped).joined(separator: ",") }.joined(separator: "\n") + "\n"
}

/// Quotes a field if it contains anything that would break the row.
private func csvEscaped(_ field: String) -> String {
    guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
        return field
    }
    return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}

func saveCSVFile(content: String, fileName: String = "ServicesExport.csv") -> URL? {
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
    let fileURL = documentsURL.appendingPathComponent(fileName)

    do {
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    } catch {
        print("Error writing CSV file: \(error)")
        return nil
    }
}

// MARK: - Import

struct CSVImportResult {
    var services: [SDService] = []
    var scheduledServices: [SDScheduledService] = []
    /// Rows that couldn't be understood. Surfaced to the user rather than
    /// crashing the import, which is what 2.x did on an unparseable date.
    var skippedRows: [String] = []
}

enum CSVImporter {

    /// Parses CSV text into unattached models. The caller assigns `car` and
    /// inserts them, so a failed parse can't leave a half-imported car behind.
    static func parse(_ content: String, distanceUnit: DistanceUnit) -> CSVImportResult {
        var result = CSVImportResult()

        let lines = splitRows(content)
        guard let header = lines.first else { return result }
        let legacy = isLegacyHeader(header)
        let columns = indexMap(for: header)

        for line in lines.dropFirst() {
            let fields = parseRow(line)
            guard fields.count > 2 else { continue }

            func field(_ name: String) -> String {
                guard let index = columns[name], index < fields.count else { return "" }
                return fields[index].trimmingCharacters(in: .whitespaces)
            }

            switch field("type") {
            case "Service":
                guard let service = parseService(
                    field: field, legacy: legacy, distanceUnit: distanceUnit
                ) else {
                    result.skippedRows.append(line)
                    continue
                }
                result.services.append(service)

            case "Scheduled Service":
                let scheduled = parseScheduled(
                    field: field, legacy: legacy, distanceUnit: distanceUnit
                )
                result.scheduledServices.append(scheduled)

            default:
                result.skippedRows.append(line)
            }
        }

        return result
    }

    // MARK: Row parsing

    private static func parseService(
        field: (String) -> String,
        legacy: Bool,
        distanceUnit: DistanceUnit
    ) -> SDService? {
        guard let date = parseDate(field("date")) else { return nil }

        let service = SDService()
        let id = field("id")
        if !id.isEmpty { service.id = id }
        service.name = field("name")
        service.date = date
        service.vendorName = field("vendor")
        service.fullDescription = field("description")

        // 2.x wrote bare dollars, miles and US gallons.
        let costUnit = legacy ? "USD" : UnitPreferences.currencyCode
        let odometerUnit: DistanceUnit = legacy ? .miles : distanceUnit
        let volumeUnit: VolumeUnit = legacy ? .gallonsUS : UnitPreferences.volumeUnit

        let costValue = Decimal(string: field("cost")) ?? 0
        service.cost = Money(majorUnits: costValue, currencyCode: costUnit)
        service.odometer = Distance(
            value: Double(field("odometer")) ?? 0, unit: odometerUnit
        )
        service.volume = Volume(
            value: Double(field("volume")) ?? 0, unit: volumeUnit
        )

        if legacy {
            service.kind = (Bool(field("kind")) ?? false) ? .fuel : .maintenance
        } else {
            service.kind = ServiceKind(rawValue: field("kind")) ?? .maintenance
        }
        if let fullTank = Bool(field("full tank")) {
            service.isFullTank = fullTank
        }

        return service
    }

    private static func parseScheduled(
        field: (String) -> String,
        legacy: Bool,
        distanceUnit: DistanceUnit
    ) -> SDScheduledService {
        let scheduled = SDScheduledService()
        let id = field("id")
        if !id.isEmpty { scheduled.id = id }
        scheduled.name = field("name")
        scheduled.fullDescription = field("description")
        scheduled.repeating = Bool(field("repeating")) ?? false

        let unit: DistanceUnit = legacy ? .miles : distanceUnit
        scheduled.frequencyDistance = Distance(
            value: Double(field("frequency distance")) ?? 0, unit: unit
        )
        scheduled.frequencyTime = Int(field("frequency time")) ?? 0
        scheduled.frequencyTimeInterval = FrequencyTimeInterval(
            rawValue: field("frequency interval")
        )
        return scheduled
    }

    // MARK: Header handling

    private static func isLegacyHeader(_ header: String) -> Bool {
        let lowered = header.lowercased()
        return lowered.contains("is fuel") || lowered.contains("gallons")
    }

    /// Maps a canonical field name to its column index, so a header that
    /// carries units ("Odometer (mi)") still resolves to "odometer".
    private static func indexMap(for header: String) -> [String: Int] {
        var map: [String: Int] = [:]
        for (index, raw) in parseRow(header).enumerated() {
            var name = raw.lowercased().trimmingCharacters(in: .whitespaces)
            if let paren = name.firstIndex(of: "(") {
                name = String(name[name.startIndex..<paren])
                    .trimmingCharacters(in: .whitespaces)
            }
            // Legacy synonyms.
            switch name {
            case "is fuel": name = "kind"
            case "gallons": name = "volume"
            case "frequency miles": name = "frequency distance"
            default: break
            }
            if map[name] == nil { map[name] = index }
        }
        return map
    }

    private static func parseDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }

        // The 2.x exporter interpolated Date directly, giving this shape.
        let legacy = DateFormatter()
        legacy.locale = Locale(identifier: "en_US_POSIX")
        legacy.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return legacy.date(from: value)
    }

    // MARK: CSV tokenizing

    /// Splits into rows, honouring newlines inside quoted fields.
    private static func splitRows(_ content: String) -> [String] {
        var rows: [String] = []
        var current = ""
        var inQuotes = false

        for character in content {
            if character == "\"" {
                inQuotes.toggle()
                current.append(character)
            } else if (character == "\n" || character == "\r"), !inQuotes {
                if !current.trimmingCharacters(in: .whitespaces).isEmpty {
                    rows.append(current)
                }
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            rows.append(current)
        }
        return rows
    }

    /// Splits one row into fields, unescaping doubled quotes.
    private static func parseRow(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var index = row.startIndex

        while index < row.endIndex {
            let character = row[index]
            if character == "\"" {
                let next = row.index(after: index)
                if inQuotes, next < row.endIndex, row[next] == "\"" {
                    current.append("\"")
                    index = next
                } else {
                    inQuotes.toggle()
                }
            } else if character == ",", !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
            index = row.index(after: index)
        }
        fields.append(current)
        return fields
    }
}
