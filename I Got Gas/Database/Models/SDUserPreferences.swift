//
//  SDUserPreferences.swift
//  I Got Gas
//
//  Account-level preferences, as a single synced row.
//
//  These used to live in UserDefaults and be read through SDCarSettings'
//  getters whenever a car wasn't marked "custom". That meant the defaults
//  themselves never synced: a new device silently got different filters, and
//  changing a default on one phone had no effect on another.
//

import Foundation
import SwiftData

@Model
final class SDUserPreferences {
    /// There is only ever one of these per account.
    var id: String = "user-preferences"

    // Filter defaults, used by any car not marked custom.
    var defaultSelectedTab: String = "MPG"
    var defaultRange: Int = 90
    var defaultIncludeFuel: Bool = true
    var defaultIncludeMaintenance: Bool = true

    // Display units.
    var volumeUnitRaw: String = VolumeUnit.gallonsUS.rawValue
    var currencyCode: String = "USD"

    var updatedAt: Date = Date()

    init() { }

    var volumeUnit: VolumeUnit {
        get { VolumeUnit(rawValue: volumeUnitRaw) ?? .gallonsUS }
        set { volumeUnitRaw = newValue.rawValue }
    }

    func touch() {
        updatedAt = Date()
    }

    /// Fetches the singleton, creating it on first use. Seeded from whatever
    /// UserDefaults held, so an upgrading user keeps their settings.
    @MainActor
    static func current(in context: ModelContext) -> SDUserPreferences {
        let descriptor = FetchDescriptor<SDUserPreferences>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let preferences = SDUserPreferences()
        let defaults = UserDefaults.standard
        if let tab = defaults.string(forKey: "defaultFilterSelectedTab") {
            preferences.defaultSelectedTab = tab
        }
        if defaults.object(forKey: "defaultFilterRange") != nil {
            preferences.defaultRange = defaults.integer(forKey: "defaultFilterRange")
        }
        if defaults.object(forKey: "defaultFilterIncludeFuel") != nil {
            preferences.defaultIncludeFuel = defaults.bool(forKey: "defaultFilterIncludeFuel")
        }
        if defaults.object(forKey: "defaultFilterIncludeMaintenance") != nil {
            preferences.defaultIncludeMaintenance = defaults.bool(forKey: "defaultFilterIncludeMaintenance")
        }
        preferences.volumeUnit = UnitPreferences.volumeUnit
        preferences.currencyCode = UnitPreferences.currencyCode

        context.insert(preferences)
        return preferences
    }
}
