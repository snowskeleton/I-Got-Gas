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
    var selectedTab = "MPG"
    var range: Int = 90
    var includeFuel: Bool = true
    var includeMaintenance: Bool = true
    var includeCompleted: Bool = true
    var includePending: Bool = false
    var modified: Bool = false
    
    var car: SDCar?
    
    init() {}
    
    func reset() {
        let defaults = UserDefaults.standard
        
        // Check if each key exists before assigning, with fallback values if missing.
        if let savedTab = defaults.string(forKey: "defaultFilterSelectedTab") {
            self.selectedTab = savedTab
        } else {
            self.selectedTab = "MPG"
        }
        
        let savedRange = defaults.object(forKey: "defaultFilterRange") as? Int
        self.range = savedRange ?? 90
        
        // Optional: check if `savedRange` is zero to fall back to 90 if needed
        if savedRange == 0 {
            self.range = 90
        }
        
        if defaults.object(forKey: "defaultFilterIncludeFuel") != nil {
            self.includeFuel = defaults.bool(forKey: "defaultFilterIncludeFuel")
        } else {
            self.includeFuel = true
        }
        
        if defaults.object(forKey: "defaultFilterIncludeMaintenance") != nil {
            self.includeMaintenance = defaults.bool(forKey: "defaultFilterIncludeMaintenance")
        } else {
            self.includeMaintenance = true
        }
        
        if defaults.object(forKey: "defaultFilterIncludeCompleted") != nil {
            self.includeCompleted = defaults.bool(forKey: "defaultFilterIncludeCompleted")
        } else {
            self.includeCompleted = true
        }
        
        if defaults.object(forKey: "defaultFilterIncludePending") != nil {
            self.includePending = defaults.bool(forKey: "defaultFilterIncludePending")
        } else {
            self.includePending = false
        }
        
        self.modified = false
    }
}
