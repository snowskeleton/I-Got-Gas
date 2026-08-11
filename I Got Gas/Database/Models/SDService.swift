//
//  SDService.swift
//  I Got Gas
//
//  Created by snow on 10/4/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftData

enum ServiceKind: String, Codable, CaseIterable, Sendable {
    case fuel
    case maintenance
}

@Model
class SDService: Identifiable {
    var id: String = UUID().uuidString

    /// Total paid, in currency minor units. Authoritative — parts are a
    /// breakdown for convenience and never write back to this.
    var costMinor: Int = 0

    var date = Date()
    var name: String = ""
    var fullDescription: String = ""

    /// Odometer reading in whole metres.
    var odometerMeters: Int = 0

    var kind: ServiceKind = ServiceKind.maintenance

    // MARK: Fuel-only
    var isFullTank: Bool = true
    /// Volume dispensed, in whole millilitres. Zero for maintenance entries.
    var volumeML: Int = 0

    var vendorName = ""
    var deleted: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship
    var car: SDCar?

    /// The schedule this entry fulfilled, if any. Must belong to the same car.
    var scheduledService: SDScheduledService?

    /// Distinguishes a link the user made deliberately from one the V2→V3
    /// name matcher guessed, so re-running the matcher can't stomp intent.
    var linkedManually: Bool = false

    /// What went into this repair. Fuel entries get no UI for these, but the
    /// model doesn't forbid them.
    @Relationship(deleteRule: .cascade, inverse: \SDPart.service)
    var parts: [SDPart]? = []

    /// Receipt photos.
    @Relationship(deleteRule: .cascade, inverse: \SDAttachment.service)
    var attachments: [SDAttachment]? = []

    init() { }
    init(
        cost: Money,
        date: Date,
        name: String,
        odometer: Distance,
        kind: ServiceKind = .maintenance
    ) {
        self.costMinor = cost.minorUnits
        self.date = date
        self.name = name
        self.odometerMeters = odometer.meters
        self.kind = kind
    }

    // MARK: - Typed accessors

    var cost: Money {
        get { Money(minorUnits: costMinor) }
        set { costMinor = newValue.minorUnits }
    }

    var odometer: Distance {
        get { Distance(meters: odometerMeters) }
        set { odometerMeters = newValue.meters }
    }

    var volume: Volume {
        get { Volume(milliliters: volumeML) }
        set { volumeML = newValue.milliliters }
    }

    var isFuel: Bool { kind == .fuel }

    var liveParts: [SDPart] {
        (parts ?? []).filter { !$0.deleted }.sorted { $0.position < $1.position }
    }

    /// Falls back to the parts list when the entry hasn't been named.
    /// Never persisted, so renaming a part updates every label that shows it.
    var displayName: String {
        if !name.isEmpty { return name }
        let names = liveParts.map(\.name).filter { !$0.isEmpty }
        return names.isEmpty ? "" : names.joined(separator: ", ")
    }

    /// Sum of the parts that carry a unit cost. Informational only —
    /// `cost` is what the user actually paid and is never overwritten.
    var partsTotal: Money {
        liveParts.compactMap(\.lineTotal).total()
    }

    /// Case- and whitespace-insensitive key for grouping vendors. Display
    /// always uses `vendorName` as the user typed it.
    var vendorKey: String {
        vendorName.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Cost per unit of fuel. Nil rather than infinity when no fuel was
    /// dispensed — the old `cost / gallons` returned `inf` for every
    /// maintenance entry and rendered it verbatim.
    var costPerVolume: Money? {
        guard volumeML > 0 else { return nil }
        let perML = Double(costMinor) / Double(volumeML)
        let perUnit = perML * UnitPreferences.volumeUnit.millilitersPerUnit
        return Money(minorUnits: Int(perUnit.rounded()))
    }

    func touch() {
        updatedAt = Date()
    }
}

// MARK: - Filtering

extension Array where Element == SDService {
    // These filters only remove their own results when passed `false`,
    // otherwise they let everything through. For example:
    //   services.fuel(false)
    // returns all non-fuel (i.e. maintenance) transactions.

    func fuel(_ include: Bool = true) -> [SDService] {
        return include ? self : self.filter { $0.kind != .fuel }
    }

    func maintenance(_ include: Bool = true) -> [SDService] {
        return include ? self : self.filter { $0.kind != .maintenance }
    }

    enum TimePeriod {
        case days(Int)
        case weeks(Int)
        case months(Int)
        case years(Int)

        var value: Int {
            switch self {
            case .days(let count), .weeks(let count), .months(let count), .years(let count):
                return count
            }
        }
    }

    func time(_ period: TimePeriod) -> [SDService] {
        let today = Date()
        var targetDate: Date?

        switch period {
        case .days(let count):
            targetDate = Calendar.current.date(byAdding: .day, value: -count, to: today)
        case .weeks(let count):
            targetDate = Calendar.current.date(byAdding: .weekOfYear, value: -count, to: today)
        case .months(let count):
            targetDate = Calendar.current.date(byAdding: .month, value: -count, to: today)
        case .years(let count):
            targetDate = Calendar.current.date(byAdding: .year, value: -count, to: today)
        }

        guard let validDate = targetDate else {
            return []
        }

        if period.value == 0 {
            return self
        } else {
            return self.filter { $0.date >= validDate && $0.date <= today }
        }
    }
}

// MARK: - Aggregates

extension Array where Element == SDService {

    var totalCost: Money {
        map(\.cost).total()
    }

    /// Cost per mile / per km, in the caller's display unit.
    /// Nil when the entries don't span any distance, rather than zero —
    /// "no data" and "free" are different answers.
    func costPerDistance(in unit: DistanceUnit) -> Money? {
        let odometers = self.map(\.odometerMeters)
        guard let lowest = odometers.min(), let highest = odometers.max() else { return nil }
        let metersDriven = highest - lowest
        guard metersDriven > 0 else { return nil }
        let perUnit = Double(totalCost.minorUnits) / Double(metersDriven) * unit.metersPerUnit
        return Money(minorUnits: Int(perUnit.rounded()))
    }

    var lastFillup: Date? {
        self.filter { $0.kind == .fuel }
            .max(by: { $0.odometerMeters < $1.odometerMeters })?
            .date
    }
}
