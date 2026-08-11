//
//  SDCarSettings.swift
//  I Got Gas
//
//  Created by snow on 11/7/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//
//  Per-car filter overrides.
//
//  The stored values are only consulted when `custom` is on. Otherwise the
//  car follows the account defaults in SDUserPreferences — which, unlike the
//  UserDefaults this used to read, actually sync.
//

import Foundation
import SwiftData

@Model
class SDCarSettings: Identifiable {
    // Overrides. Meaningful only while `custom` is true.
    private var _selectedTab: String = "MPG"
    private var _range: Int = 90
    private var _includeFuel: Bool = true
    private var _includeMaintenance: Bool = true
    private var _custom: Bool = false
    private var _notifyOnChange: Bool = true
    var updatedAt: Date = Date()

    var car: SDCar?

    init() { }

    /// Account defaults. Injected by the view layer so the model doesn't have
    /// to reach for a container.
    @MainActor
    private var defaults: SDUserPreferences? {
        guard let context = modelContext else { return nil }
        return try? context.fetch(FetchDescriptor<SDUserPreferences>()).first
    }

    // MARK: - Settings

    /// When switched on, the car keeps whatever it was showing rather than
    /// jumping to unrelated values.
    @MainActor
    var custom: Bool {
        get { _custom }
        set {
            if newValue, let defaults {
                _selectedTab = defaults.defaultSelectedTab
                _range = defaults.defaultRange
                _includeFuel = defaults.defaultIncludeFuel
                _includeMaintenance = defaults.defaultIncludeMaintenance
            }
            _custom = newValue
        }
    }

    var notifyOnChange: Bool {
        get { _notifyOnChange }
        set { _notifyOnChange = newValue }
    }

    @MainActor
    var selectedTab: String {
        get { _custom ? _selectedTab : (defaults?.defaultSelectedTab ?? "MPG") }
        set {
            if _custom {
                _selectedTab = newValue
            } else {
                defaults?.defaultSelectedTab = newValue
                defaults?.touch()
            }
        }
    }

    @MainActor
    var range: Int {
        get { _custom ? _range : (defaults?.defaultRange ?? 90) }
        set {
            if _custom {
                _range = newValue
            } else {
                defaults?.defaultRange = newValue
                defaults?.touch()
            }
        }
    }

    @MainActor
    var includeFuel: Bool {
        get { _custom ? _includeFuel : (defaults?.defaultIncludeFuel ?? true) }
        set {
            if _custom {
                _includeFuel = newValue
            } else {
                defaults?.defaultIncludeFuel = newValue
                defaults?.touch()
            }
        }
    }

    @MainActor
    var includeMaintenance: Bool {
        get { _custom ? _includeMaintenance : (defaults?.defaultIncludeMaintenance ?? true) }
        set {
            if _custom {
                _includeMaintenance = newValue
            } else {
                defaults?.defaultIncludeMaintenance = newValue
                defaults?.touch()
            }
        }
    }

    func touch() {
        updatedAt = Date()
    }
}
