//
//  Volume.swift
//  I Got Gas
//
//  Fuel volumes are stored as whole millilitres and displayed in the unit
//  the account is configured for.
//

import Foundation

enum VolumeUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case gallonsUS
    case gallonsImperial
    case liters

    var id: String { rawValue }

    /// Millilitres in one of this unit.
    var millilitersPerUnit: Double {
        switch self {
        case .gallonsUS: return 3785.411784
        case .gallonsImperial: return 4546.09
        case .liters: return 1000.0
        }
    }

    var abbreviation: String {
        switch self {
        case .gallonsUS, .gallonsImperial: return "gal"
        case .liters: return "L"
        }
    }

    var displayName: String {
        switch self {
        case .gallonsUS: return "Gallons (US)"
        case .gallonsImperial: return "Gallons (Imperial)"
        case .liters: return "Liters"
        }
    }

    /// How many decimal places make sense when entering this unit.
    var entryFractionDigits: Int {
        switch self {
        case .gallonsUS, .gallonsImperial: return 3
        case .liters: return 2
        }
    }
}

struct Volume: Equatable, Hashable, Codable, Sendable, Comparable {

    /// Canonical storage. Whole millilitres.
    var milliliters: Int

    init(milliliters: Int) {
        self.milliliters = milliliters
    }

    /// Builds from a value the user typed in their display unit.
    init(value: Double, unit: VolumeUnit) {
        self.milliliters = Int((value * unit.millilitersPerUnit).rounded())
    }

    static var zero: Volume { Volume(milliliters: 0) }

    var isZero: Bool { milliliters == 0 }

    // MARK: - Conversion

    func converted(to unit: VolumeUnit) -> Double {
        Double(milliliters) / unit.millilitersPerUnit
    }

    // MARK: - Formatting

    func formatted(as unit: VolumeUnit, fractionDigits: Int? = nil) -> String {
        let digits = fractionDigits ?? 2
        let value = converted(to: unit)
        return value.formatted(.number.precision(.fractionLength(digits)))
            + " " + unit.abbreviation
    }

    // MARK: - Arithmetic

    static func + (lhs: Volume, rhs: Volume) -> Volume {
        Volume(milliliters: lhs.milliliters + rhs.milliliters)
    }

    static func < (lhs: Volume, rhs: Volume) -> Bool {
        lhs.milliliters < rhs.milliliters
    }
}

extension Sequence where Element == Volume {
    func total() -> Volume {
        reduce(into: Volume.zero) { $0 = $0 + $1 }
    }
}
