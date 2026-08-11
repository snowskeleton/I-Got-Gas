//
//  Distance.swift
//  I Got Gas
//
//  Distances are stored as whole metres and displayed in the unit the car
//  is configured for. Storing a canonical unit means a car can switch
//  between miles and kilometres without rewriting its history.
//

import Foundation

enum DistanceUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case miles
    case kilometers

    var id: String { rawValue }

    /// Metres in one of this unit.
    var metersPerUnit: Double {
        switch self {
        case .miles: return 1609.344
        case .kilometers: return 1000.0
        }
    }

    var abbreviation: String {
        switch self {
        case .miles: return "mi"
        case .kilometers: return "km"
        }
    }

    var perUnitAbbreviation: String {
        switch self {
        case .miles: return "mile"
        case .kilometers: return "km"
        }
    }

    var displayName: String {
        switch self {
        case .miles: return "Miles"
        case .kilometers: return "Kilometers"
        }
    }
}

struct Distance: Equatable, Hashable, Codable, Sendable, Comparable {

    /// Canonical storage. Whole metres — sub-metre precision is meaningless
    /// for an odometer reading.
    var meters: Int

    init(meters: Int) {
        self.meters = meters
    }

    /// Builds from a value the user typed in their display unit.
    init(value: Double, unit: DistanceUnit) {
        self.meters = Int((value * unit.metersPerUnit).rounded())
    }

    static var zero: Distance { Distance(meters: 0) }

    // MARK: - Conversion

    func converted(to unit: DistanceUnit) -> Double {
        Double(meters) / unit.metersPerUnit
    }

    /// Whole units, for odometer fields where a fraction would be noise.
    func rounded(to unit: DistanceUnit) -> Int {
        Int(converted(to: unit).rounded())
    }

    // MARK: - Formatting

    func formatted(as unit: DistanceUnit, fractionDigits: Int = 0) -> String {
        let value = converted(to: unit)
        return value.formatted(.number.precision(.fractionLength(fractionDigits)))
            + " " + unit.abbreviation
    }

    // MARK: - Arithmetic

    static func + (lhs: Distance, rhs: Distance) -> Distance {
        Distance(meters: lhs.meters + rhs.meters)
    }

    static func - (lhs: Distance, rhs: Distance) -> Distance {
        Distance(meters: lhs.meters - rhs.meters)
    }

    static func < (lhs: Distance, rhs: Distance) -> Bool {
        lhs.meters < rhs.meters
    }
}
