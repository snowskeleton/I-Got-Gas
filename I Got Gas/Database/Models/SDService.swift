//
//  SDService.swift
//  I Got Gas
//
//  Created by snow on 10/4/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftData

@Model
class SDService: Identifiable {
    @Attribute(.unique)
    var localId: String = UUID().uuidString
    var icloudId: String = UUID().uuidString
    var cost: Double = 0.0
    @Attribute(originalName: "datePurchased")
    var date = Date()
    @Attribute(originalName: "note")
    var name: String = ""
    var fullDescription: String = ""
    var odometer: Int = 0
    
    var isFuel: Bool = false
    var isFullTank: Bool = true
    var gallons: Double = 0.0
    
    var vendorName = ""
    
    @Relationship
    var car: SDCar?
    
    init() { }
    init(
        cost: Double,
        date: Date,
        name: String,
        odometer: Int
    ) {
        self.cost = cost
        self.date = date
        self.name = name
        self.odometer = odometer
    }
    
    var costPerGallon: Double {
        cost / gallons
    }
}
