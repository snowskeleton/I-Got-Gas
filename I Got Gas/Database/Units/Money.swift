//
//  Money.swift
//  I Got Gas
//
//  Exact currency amounts stored as integer minor units.
//
//  Money is never a Double. Doubles were the old representation and they
//  accumulated rounding error across sums and produced `inf` on unguarded
//  division. Minor units are exact, and the entry form already thought in
//  cents, so this is closer to how the app actually behaves.
//

import Foundation

struct Money: Equatable, Hashable, Codable, Sendable {

    /// The amount in the currency's smallest unit (cents for USD, yen for JPY).
    var minorUnits: Int

    /// ISO 4217 code. Determines how many minor units make a major unit.
    var currencyCode: String

    init(minorUnits: Int, currencyCode: String = UnitPreferences.currencyCode) {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    static var zero: Money { Money(minorUnits: 0) }

    // MARK: - Conversion

    /// Number of decimal places this currency uses. USD → 2, JPY → 0.
    var fractionDigits: Int {
        Money.fractionDigits(for: currencyCode)
    }

    /// The amount as an exact decimal. Use for formatting, never for storage.
    var amount: Decimal {
        Decimal(minorUnits) * Decimal(sign: .plus, exponent: -fractionDigits, significand: 1)
    }

    /// Lossy bridge for Swift Charts, which requires a `Plottable` type and
    /// does not accept `Decimal`. Exact for any amount the app will ever hold.
    var plottableDouble: Double {
        Double(minorUnits) / pow(10.0, Double(fractionDigits))
    }

    /// Builds an amount from a major-unit value (e.g. 12.34 dollars).
    /// Rounds to the nearest minor unit rather than truncating.
    init(majorUnits: Decimal, currencyCode: String = UnitPreferences.currencyCode) {
        let digits = Money.fractionDigits(for: currencyCode)
        let scaled = majorUnits * Decimal(sign: .plus, exponent: digits, significand: 1)
        var rounded = Decimal()
        var source = scaled
        NSDecimalRound(&rounded, &source, 0, .plain)
        self.minorUnits = NSDecimalNumber(decimal: rounded).intValue
        self.currencyCode = currencyCode
    }

    // MARK: - Formatting

    func formatted() -> String {
        amount.formatted(.currency(code: currencyCode))
    }

    /// Formatted with extra precision, for per-unit prices like $3.499/gal
    /// where the sub-cent digit is meaningful.
    func formattedPerUnit(fractionDigits digits: Int = 3) -> String {
        amount.formatted(
            .currency(code: currencyCode)
                .precision(.fractionLength(digits))
        )
    }

    // MARK: - Arithmetic

    static func + (lhs: Money, rhs: Money) -> Money {
        Money(minorUnits: lhs.minorUnits + rhs.minorUnits, currencyCode: lhs.currencyCode)
    }

    static func - (lhs: Money, rhs: Money) -> Money {
        Money(minorUnits: lhs.minorUnits - rhs.minorUnits, currencyCode: lhs.currencyCode)
    }

    static func * (lhs: Money, rhs: Int) -> Money {
        Money(minorUnits: lhs.minorUnits * rhs, currencyCode: lhs.currencyCode)
    }

    /// Multiplies by a fractional quantity, rounding to the nearest minor unit.
    static func * (lhs: Money, rhs: Decimal) -> Money {
        let product = Decimal(lhs.minorUnits) * rhs
        var rounded = Decimal()
        var source = product
        NSDecimalRound(&rounded, &source, 0, .plain)
        return Money(
            minorUnits: NSDecimalNumber(decimal: rounded).intValue,
            currencyCode: lhs.currencyCode
        )
    }

    // MARK: - Currency metadata

    private static let fractionDigitCache = NSCache<NSString, NSNumber>()

    static func fractionDigits(for code: String) -> Int {
        if let cached = fractionDigitCache.object(forKey: code as NSString) {
            return cached.intValue
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        let digits = formatter.maximumFractionDigits
        fractionDigitCache.setObject(NSNumber(value: digits), forKey: code as NSString)
        return digits
    }
}

extension Sequence where Element == Money {
    /// Sums exactly. Returns zero in the account currency when empty.
    func total() -> Money {
        reduce(into: Money.zero) { $0 = $0 + $1 }
    }
}
