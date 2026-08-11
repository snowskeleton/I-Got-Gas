//
//  UnitPreferences.swift
//  I Got Gas
//
//  Account-level display preferences: which volume unit and currency to show.
//  Distance is per-car (a household can own a car in miles and one in km),
//  so it lives on SDCar rather than here.
//
//  These accessors are the fast path used from formatting code, which runs
//  everywhere and can't take a ModelContext. The values are mirrored here from
//  the synced SDUserPreferences row whenever it changes, so this stays a cache
//  rather than a second source of truth.
//

import Foundation

enum UnitPreferences {

    private enum Key {
        static let volumeUnit = "unitPreferenceVolume"
        static let currencyCode = "unitPreferenceCurrency"
    }

    static var volumeUnit: VolumeUnit {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Key.volumeUnit),
                  let unit = VolumeUnit(rawValue: raw) else {
                return defaultVolumeUnit
            }
            return unit
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.volumeUnit) }
    }

    static var currencyCode: String {
        get {
            UserDefaults.standard.string(forKey: Key.currencyCode) ?? defaultCurrencyCode
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.currencyCode) }
    }

    // MARK: - Locale-derived defaults

    /// Existing installs are all US customary — see the V2→V3 migration, which
    /// converts stored gallons/miles on that assumption. Only a fresh install
    /// picks up the locale's preference.
    private static var defaultVolumeUnit: VolumeUnit {
        Locale.current.measurementSystem == .us ? .gallonsUS : .liters
    }

    private static var defaultCurrencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    private static var defaultDistanceUnit: DistanceUnit {
        Locale.current.measurementSystem == .metric ? .kilometers : .miles
    }

    /// Used when creating a new car.
    static var newCarDistanceUnit: DistanceUnit { defaultDistanceUnit }

    /// Mirrors the synced row into the cache. Called after a sync and when the
    /// user changes units.
    static func mirror(from preferences: SDUserPreferences) {
        volumeUnit = preferences.volumeUnit
        currencyCode = preferences.currencyCode
    }
}
