//
//  UnitsTests.swift
//  I Got GasTests
//
//  The value types replaced floating-point dollars, miles and gallons. These
//  cover the properties that motivated the change: exactness, correct
//  rounding, and no infinities.
//

import Testing
import Foundation
@testable import I_Got_Gas

struct MoneyTests {

    @Test func minorUnitsRoundTripThroughMajor() {
        let money = Money(minorUnits: 4599, currencyCode: "USD")
        #expect(money.amount == Decimal(string: "45.99"))
        #expect(Money(majorUnits: money.amount, currencyCode: "USD").minorUnits == 4599)
    }

    @Test func majorUnitsRoundRatherThanTruncate() {
        // The old entry form did String(format: "%.0f", cost * 100), which
        // floored — so 0.615 became 61 cents, not 62.
        #expect(Money(majorUnits: Decimal(string: "0.615")!, currencyCode: "USD").minorUnits == 62)
        #expect(Money(majorUnits: Decimal(string: "0.614")!, currencyCode: "USD").minorUnits == 61)
    }

    @Test func summingIsExact() {
        // 0.1 + 0.2 in binary floating point is famously not 0.3.
        let amounts = [Money(minorUnits: 10), Money(minorUnits: 20)]
        #expect(amounts.total().minorUnits == 30)

        // A hundred ten-cent charges is exactly ten dollars, every time.
        let many = Array(repeating: Money(minorUnits: 10), count: 100)
        #expect(many.total().minorUnits == 1000)
    }

    @Test func multiplyingByAFractionalQuantityRounds() {
        let unitCost = Money(minorUnits: 499, currencyCode: "USD")
        #expect((unitCost * Decimal(3)).minorUnits == 1497)
        #expect((unitCost * Decimal(string: "2.5")!).minorUnits == 1248) // 1247.5 → 1248
    }

    @Test func zeroDecimalCurrenciesHaveNoMinorUnits() {
        #expect(Money.fractionDigits(for: "JPY") == 0)
        #expect(Money.fractionDigits(for: "USD") == 2)
    }
}

struct DistanceTests {

    @Test func milesRoundTrip() {
        let distance = Distance(value: 100_000, unit: .miles)
        #expect(distance.rounded(to: .miles) == 100_000)
    }

    @Test func kilometersRoundTrip() {
        let distance = Distance(value: 250_000, unit: .kilometers)
        #expect(distance.rounded(to: .kilometers) == 250_000)
    }

    @Test func conversionBetweenUnitsIsSane() {
        let hundredMiles = Distance(value: 100, unit: .miles)
        #expect(abs(hundredMiles.converted(to: .kilometers) - 160.9344) < 0.001)
    }

    @Test func arithmeticStaysInMeters() {
        let a = Distance(value: 10, unit: .miles)
        let b = Distance(value: 5, unit: .miles)
        #expect((a - b).rounded(to: .miles) == 5)
        #expect((a + b).rounded(to: .miles) == 15)
    }
}

struct VolumeTests {

    @Test func gallonsRoundTrip() {
        let volume = Volume(value: 12.345, unit: .gallonsUS)
        #expect(abs(volume.converted(to: .gallonsUS) - 12.345) < 0.001)
    }

    @Test func litersRoundTrip() {
        let volume = Volume(value: 45.5, unit: .liters)
        #expect(abs(volume.converted(to: .liters) - 45.5) < 0.001)
    }

    @Test func imperialAndUSGallonsDiffer() {
        let us = Volume(value: 1, unit: .gallonsUS)
        let imperial = Volume(value: 1, unit: .gallonsImperial)
        #expect(us.milliliters != imperial.milliliters)
    }
}

struct FuelEconomyTests {

    @Test func zeroVolumeProducesNoEconomy() {
        // The old costPerGallon divided without a guard and returned `inf`
        // for every maintenance entry, then rendered it as "$inf/gal".
        let economy = FuelEconomy(distance: Distance(value: 300, unit: .miles), volume: .zero)
        #expect(economy == nil)
    }

    @Test func zeroDistanceProducesNoEconomy() {
        let economy = FuelEconomy(
            distance: .zero, volume: Volume(value: 10, unit: .gallonsUS)
        )
        #expect(economy == nil)
    }

    @Test func milesPerGallonIsCorrect() throws {
        let economy = try #require(FuelEconomy(
            distance: Distance(value: 300, unit: .miles),
            volume: Volume(value: 10, unit: .gallonsUS)
        ))
        let mpg = economy.value(distance: .miles, volume: .gallonsUS, style: .distancePerVolume)
        #expect(abs(mpg - 30) < 0.01)
    }

    @Test func metricDriversGetLitersPerHundredKilometers() throws {
        let economy = try #require(FuelEconomy(
            distance: Distance(value: 100, unit: .kilometers),
            volume: Volume(value: 8, unit: .liters)
        ))
        let value = economy.value(distance: .kilometers, volume: .liters, style: .volumePer100km)
        #expect(abs(value - 8) < 0.01)
    }

    @Test func styleFollowsTheUnits() {
        #expect(FuelEconomyStyle.preferred(distance: .miles, volume: .gallonsUS) == .distancePerVolume)
        #expect(FuelEconomyStyle.preferred(distance: .kilometers, volume: .liters) == .volumePer100km)
    }

    @Test func labelsUseConventionalSpelling() {
        func label(_ d: DistanceUnit, _ v: VolumeUnit) -> String {
            FuelEconomy.label(
                distance: d, volume: v,
                style: FuelEconomyStyle.preferred(distance: d, volume: v)
            )
        }
        #expect(label(.miles, .gallonsUS) == "MPG")
        #expect(label(.miles, .gallonsImperial) == "MPG (imp)")
        #expect(label(.miles, .liters) == "mi/L")
        #expect(label(.kilometers, .gallonsUS) == "km/gal")
        #expect(label(.kilometers, .liters) == "L/100km")
    }

    @Test func formattedEconomyReadsNaturally() throws {
        let economy = try #require(FuelEconomy(
            distance: Distance(value: 300, unit: .miles),
            volume: Volume(value: 10, unit: .gallonsUS)
        ))
        #expect(economy.formatted(
            distance: .miles, volume: .gallonsUS, style: .distancePerVolume
        ) == "30.0 MPG")
    }
}

struct TimestampTests {

    @Test func fractionalSecondsParse() throws {
        // Exactly what Go's time.Time emits. The default ISO8601DateFormatter
        // rejects this, which silently broke every remote update in 2.x.
        let parsed = try #require(ISO8601.parse("2026-08-10T12:00:00.123456Z"))
        let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(identifier: "UTC")!, from: parsed
        )
        #expect(components.year == 2026)
        #expect(components.hour == 12)
    }

    @Test func wholeSecondsStillParse() {
        #expect(ISO8601.parse("2026-08-10T12:00:00Z") != nil)
    }

    @Test func offsetTimestampsParse() {
        #expect(ISO8601.parse("2026-08-10T21:16:03.561283-06:00") != nil)
    }

    @Test func roundTripsThroughOurOwnFormatter() throws {
        let now = Date()
        let parsed = try #require(ISO8601.parse(ISO8601.string(from: now)))
        #expect(abs(parsed.timeIntervalSince(now)) < 0.001)
    }
}
