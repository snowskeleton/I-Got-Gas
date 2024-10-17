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
    var year: Int?
    var startingOdometer: Int = 0
    var pinned: Bool = false
    var deleted: Bool = false
    
    @Relationship
    var services: [SDService] = []
    
    init() { }
    init(
        make: String,
        model: String,
        name: String,
        plate: String,
        vin: String,
        year: Int?,
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
    
    var joinedModel: String {
        return [year?.description ?? "", make, model].joined(separator: " ")
    }
    
    var visualName: String {
        if name.isEmpty {
            return joinedModel
        } else {
            return name
        }
    }
    
    var odometer: Int {
        let odometerValues = services.map { $0.odometer }
        return max(odometerValues.max() ?? 0, startingOdometer)
    }
    
    var costPerGallon: Double {
        let fuelCosts = services.compactMap { $0.costPerGallon }
        let totalFuelCost = fuelCosts.reduce(0, +)
        let fuelExpenseCount = Double(fuelCosts.count)
        
        guard fuelExpenseCount > 0 else {
            return 0.0
        }
        
        return (totalFuelCost / fuelExpenseCount)
    }
    
    var costPerMile: Double {
        let totalCost = services.reduce(0.0) { $0 + $1.cost }
        let highestOdometer = services.map { $0.odometer }.max() ?? startingOdometer
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
            .date
    }
    @available(*, deprecated, message: "use `lastFillup` instead")
    var lastFuelDate: Date? {
        return Date()
    }
}
