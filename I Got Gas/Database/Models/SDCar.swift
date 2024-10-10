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
        let odometerValues = services.map { $0.odometer }
        return max(odometerValues.max() ?? 0, startingOdometer)
    }
    
    var costPerGallon: Double {
        let fuelCosts = services.compactMap { ($0 as AnyObject).costPerGallon }
        let totalFuelCost = fuelCosts.reduce(0, +)
        let fuelExpenseCount = Double(fuelCosts.count)
        
        guard fuelExpenseCount > 0 else {
            return 0.0
        }
        
        return (totalFuelCost / fuelExpenseCount)
    }
    
    var costPerMile: Double {
        let validServices = services.filter { $0.odometer > startingOdometer && ($0.dateCompleted == nil || ($0.dateCompleted != nil && !$0.pendingCompletion)) }
        
        let totalCost = validServices.reduce(0.0) { $0 + $1.cost }
        let highestOdometer = validServices.map { $0.odometer }.max() ?? startingOdometer
        let milesDriven = highestOdometer - startingOdometer
        
        // Prevent division by zero
        guard milesDriven > 0 else {
            return 0.0
        }
        
        return totalCost / Double(milesDriven)
    }
    
    var lastFillup: Date? {
        return services.filter { $0.isFuel }
            .max(by: { $0.odometer < $1.odometer } )?
            .datePurchased
    }
    @available(*, deprecated, message: "use `lastFillup` instead")
    var lastFuelDate: Date? {
        return Date()
    }
}
