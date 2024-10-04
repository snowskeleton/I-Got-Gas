//
//  SDCar.swift
//  I Got Gas
//
//  Created by snow on 10/4/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftData

@Model
class SDCar: Identifiable {
    @Attribute(.unique)
    var localId: String = UUID().uuidString
    var icloudId: String = UUID().uuidString
    var make: String = ""
    var model: String = ""
    var name: String = ""
    var plate: String = ""
    var vin: String = ""
    var year: String = ""
    var startingOdometer: Int = 0
    
    @Relationship
    var services: [SDService] = []
    
    init(
        make: String,
        model: String,
        name: String,
        plate: String,
        vin: String,
        year: String,
        startingOdometer: Int
    ) {
        self.make = make
        self.model = model
        self.name = name
        self.plate = plate
        self.vin = vin
        self.year = year
        self.startingOdometer = startingOdometer
    }
    
    var odometer: Int {
        return startingOdometer
    }
    var costPerGallon: Double {
        let fuelCosts = services.compactMap { ($0 as AnyObject).fuel?.dpg as? Double }
        let totalFuelCost = fuelCosts.reduce(0, +)
        let fuelExpenseCount = Double(fuelCosts.count)
        
        guard fuelExpenseCount > 0 else {
            return 0.0
        }
        
        return (totalFuelCost / fuelExpenseCount)
    }
    var costPerMile: Double {
        return 0.0
    }
    var lastFillup: Date? {
        return Date()
    }
    var lastFuelDate: Date? {
        return Date()
    }
}
