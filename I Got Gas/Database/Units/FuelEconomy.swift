//
//  FuelEconomy.swift
//  I Got Gas
//
//  Fuel economy is unit-dependent in a way the other quantities are not:
//  US drivers read distance-per-volume (higher is better) and metric drivers
//  read volume-per-distance (lower is better). Storing the ratio canonically
//  and choosing the presentation at the edge keeps the chart honest.
//

import Foundation

enum FuelEconomyStyle: Sendable {
    /// Miles per gallon, km per litre — higher is better.
    case distancePerVolume
    /// Litres per 100 km — lower is better.
    case volumePer100km

    /// The convention that goes with a given pair of display units.
    static func preferred(distance: DistanceUnit, volume: VolumeUnit) -> FuelEconomyStyle {
        (distance == .kilometers && volume == .liters) ? .volumePer100km : .distancePerVolume
    }
}

struct FuelEconomy: Equatable, Hashable, Sendable {

    /// Canonical ratio: metres travelled per millilitre burned.
    var metersPerMilliliter: Double

    init?(distance: Distance, volume: Volume) {
        guard volume.milliliters > 0, distance.meters > 0 else { return nil }
        self.metersPerMilliliter = Double(distance.meters) / Double(volume.milliliters)
    }

    init(metersPerMilliliter: Double) {
        self.metersPerMilliliter = metersPerMilliliter
    }

    /// The number to plot or print, in the caller's units and convention.
    func value(distance: DistanceUnit, volume: VolumeUnit, style: FuelEconomyStyle) -> Double {
        switch style {
        case .distancePerVolume:
            return metersPerMilliliter * volume.millilitersPerUnit / distance.metersPerUnit
        case .volumePer100km:
            guard metersPerMilliliter > 0 else { return 0 }
            // millilitres per 100 km → litres per 100 km
            return (100_000.0 / metersPerMilliliter) / 1000.0
        }
    }

    func label(distance: DistanceUnit, volume: VolumeUnit, style: FuelEconomyStyle) -> String {
        switch style {
        case .distancePerVolume:
            return "\(distance.abbreviation.uppercased())P\(volume.abbreviation.uppercased())"
        case .volumePer100km:
            return "L/100km"
        }
    }

    func formatted(distance: DistanceUnit, volume: VolumeUnit, style: FuelEconomyStyle) -> String {
        let number = value(distance: distance, volume: volume, style: style)
        return number.formatted(.number.precision(.fractionLength(1)))
            + " " + label(distance: distance, volume: volume, style: style)
    }
}
