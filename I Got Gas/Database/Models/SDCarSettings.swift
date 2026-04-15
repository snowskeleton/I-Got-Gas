//
//  SDCarSettings.swift
//  I Got Gas
//
//  Created by snow on 11/7/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftData

@Model
class SDCarSettings: Identifiable {
    // Internal storage for custom settings
    private var _selectedTab: String = "MPG"
    private var _range: Int = 90
    private var _includeFuel: Bool = true
    private var _includeMaintenance: Bool = true
    private var _includeCompleted: Bool = true
    private var _includePending: Bool = false
    private var _custom: Bool = false
    var updatedAt: Date = Date()

    var car: SDCar?
    
    init() {
        loadFromDefaults()
    }
    
    // MARK: - Computed Properties for Each Setting
    
    var custom: Bool {
        get {
            _custom
        }
        set {
            if newValue {
                loadFromDefaults()
            } else {
                saveToDefaults()
            }
            _custom = newValue
        }
    }
    
    var selectedTab: String {
        get {
            custom ? _selectedTab : UserDefaults.standard.string(forKey: "defaultFilterSelectedTab") ?? "MPG"
        }
        set {
            if custom {
                _selectedTab = newValue
            } else {
                UserDefaults.standard.set(newValue, forKey: "defaultFilterSelectedTab")
            }
        }
    }
    
    var range: Int {
        get {
            custom ? _range : UserDefaults.standard.integer(forKey: "defaultFilterRange")
        }
        set {
            if custom {
                _range = newValue
            } else {
                UserDefaults.standard.set(newValue, forKey: "defaultFilterRange")
            }
        }
    }
    
    var includeFuel: Bool {
        get {
            custom ? _includeFuel : UserDefaults.standard.bool(forKey: "defaultFilterIncludeFuel")
        }
        set {
            if custom {
                _includeFuel = newValue
            } else {
                UserDefaults.standard.set(newValue, forKey: "defaultFilterIncludeFuel")
            }
        }
    }
    
    var includeMaintenance: Bool {
        get {
            custom ? _includeMaintenance : UserDefaults.standard.bool(forKey: "defaultFilterIncludeMaintenance")
        }
        set {
            if custom {
                _includeMaintenance = newValue
            } else {
                UserDefaults.standard.set(newValue, forKey: "defaultFilterIncludeMaintenance")
            }
        }
    }
    
    var includeCompleted: Bool {
        get {
            custom ? _includeCompleted : UserDefaults.standard.bool(forKey: "defaultFilterIncludeCompleted")
        }
        set {
            if custom {
                _includeCompleted = newValue
            } else {
                UserDefaults.standard.set(newValue, forKey: "defaultFilterIncludeCompleted")
            }
        }
    }
    
    var includePending: Bool {
        get {
            custom ? _includePending : UserDefaults.standard.bool(forKey: "defaultFilterIncludePending")
        }
        set {
            if custom {
                _includePending = newValue
            } else {
                UserDefaults.standard.set(newValue, forKey: "defaultFilterIncludePending")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Load settings from UserDefaults as the shared defaults
    private func loadFromDefaults() {
        _selectedTab = UserDefaults.standard.string(forKey: "defaultFilterSelectedTab") ?? "MPG"
        _range = UserDefaults.standard.integer(forKey: "defaultFilterRange")
        _includeFuel = UserDefaults.standard.bool(forKey: "defaultFilterIncludeFuel")
        _includeMaintenance = UserDefaults.standard.bool(forKey: "defaultFilterIncludeMaintenance")
        _includeCompleted = UserDefaults.standard.bool(forKey: "defaultFilterIncludeCompleted")
        _includePending = UserDefaults.standard.bool(forKey: "defaultFilterIncludePending")
    }
    
    // Save current custom state to UserDefaults
    private func saveToDefaults() {
        UserDefaults.standard.set(_selectedTab, forKey: "defaultFilterSelectedTab")
        UserDefaults.standard.set(_range, forKey: "defaultFilterRange")
        UserDefaults.standard.set(_includeFuel, forKey: "defaultFilterIncludeFuel")
        UserDefaults.standard.set(_includeMaintenance, forKey: "defaultFilterIncludeMaintenance")
        UserDefaults.standard.set(_includeCompleted, forKey: "defaultFilterIncludeCompleted")
        UserDefaults.standard.set(_includePending, forKey: "defaultFilterIncludePending")
    }
    
    func touch() {
        updatedAt = Date()
    }

    func toAPIModel() -> [String: Any] {
        return [
            "car_id": car?.id ?? "",
            "selected_tab": _selectedTab,
            "range_days": _range,
            "include_fuel": _includeFuel,
            "include_maintenance": _includeMaintenance,
            "include_completed": _includeCompleted,
            "include_pending": _includePending,
            "custom": _custom,
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
    }

    func applyRemote(_ remote: [String: Any]) {
        if let v = remote["selected_tab"] as? String { _selectedTab = v }
        if let v = remote["range_days"] as? Int { _range = v }
        if let v = remote["include_fuel"] as? Bool { _includeFuel = v }
        if let v = remote["include_maintenance"] as? Bool { _includeMaintenance = v }
        if let v = remote["include_completed"] as? Bool { _includeCompleted = v }
        if let v = remote["include_pending"] as? Bool { _includePending = v }
        if let v = remote["custom"] as? Bool { _custom = v }
        if let s = remote["updated_at"] as? String,
           let d = ISO8601DateFormatter().date(from: s) {
            updatedAt = d
        }
    }

    static public func setDefaults() {
        if !UserDefaults.standard.bool(forKey: "defaultFilterCompletedFirstRun") {
            UserDefaults.standard.set(true, forKey: "defaultFilterFirstRun")
            
            UserDefaults.standard.set("MPG", forKey: "defaultFilterSelectedTab")
            UserDefaults.standard.set("MPG", forKey: "defaultFilterSelectedTab")
            UserDefaults.standard.set(90, forKey: "defaultFilterRange")
            UserDefaults.standard.set(true, forKey: "defaultFilterIncludeFuel")
            UserDefaults.standard.set(true, forKey: "defaultFilterIncludeMaintenance")
            UserDefaults.standard.set(true, forKey: "defaultFilterIncludeCompleted")
            UserDefaults.standard.set(false, forKey: "defaultFilterIncludePending")
        }
    }
}
