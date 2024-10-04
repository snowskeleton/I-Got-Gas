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
    var startingOdometer: String = "0"
    
    @Relationship
    var services: [SDService] = []
    
    init(
        make: String,
        model: String,
        name: String,
        plate: String,
        vin: String,
        year: String,
        startingOdometer: String
    ) {
        self.make = make
        self.model = model
        self.name = name
        self.plate = plate
        self.vin = vin
        self.year = year
        self.startingOdometer = startingOdometer
    }
    
    var odometer: String {
        return startingOdometer
    }
    var costPerGallon: Double {
        return 0.0
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
