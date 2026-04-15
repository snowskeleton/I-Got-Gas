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
    @Attribute(originalName: "localId")
    var id: String = UUID().uuidString
    var make: String = ""
    var model: String = ""
    var name: String = ""
    var plate: String = ""
    var vin: String = ""
    var year: Int?
    var startingOdometer: Int = 0
    var pinned: Bool = false
    var deleted: Bool = false
    var archived: Bool = false
    var ownerID: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    @Relationship
    var services: [SDService]? = []
    
    @Relationship
    var scheduledServices: [SDScheduledService]? = []
    
    @Relationship
    var settings: SDCarSettings?

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
        let odometerValues = services?.map { $0.odometer } ?? []
        return max(odometerValues.max() ?? 0, startingOdometer)
    }
    
    var costPerGallon: Double {
        let fuelCosts = services?.compactMap { $0.costPerGallon } ?? []
        let totalFuelCost = fuelCosts.reduce(0, +)
        let fuelExpenseCount = Double(fuelCosts.count)
        
        guard fuelExpenseCount > 0 else {
            return 0.0
        }
        
        return (totalFuelCost / fuelExpenseCount)
    }
    
//    var costPerMile: Double {
//        let totalCost = services?.reduce(0.0) { $0 + $1.cost } ?? 0.0
//        let highestOdometer = services?.map { $0.odometer }.max() ?? startingOdometer
//        let milesDriven = highestOdometer - startingOdometer
//        
//        // Prevent division by zero
//        guard milesDriven > 0 else {
//            return 0.0
//        }
//        
//        return totalCost / Double(milesDriven)
//    }
    
    @available(*, deprecated, message: "use `lastFillup` instead")
    var lastFuelDate: Date? {
        return Date()
    }

    func touch() {
        updatedAt = Date()
    }

    func toAPIModel() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "owner_id": ownerID,
            "make": make,
            "model": model,
            "name": name,
            "plate": plate,
            "vin": vin,
            "starting_odometer": startingOdometer,
            "pinned": pinned,
            "deleted": deleted,
            "archived": archived,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
        if let year = year {
            dict["year"] = year
        }
        return dict
    }

    func applyRemote(_ remote: [String: Any]) {
        if let v = remote["make"] as? String { make = v }
        if let v = remote["model"] as? String { model = v }
        if let v = remote["name"] as? String { name = v }
        if let v = remote["plate"] as? String { plate = v }
        if let v = remote["vin"] as? String { vin = v }
        if let v = remote["year"] as? Int { year = v }
        if let v = remote["starting_odometer"] as? Int { startingOdometer = v }
        if let v = remote["pinned"] as? Bool { pinned = v }
        if let v = remote["deleted"] as? Bool { deleted = v }
        if let v = remote["archived"] as? Bool { archived = v }
        if let v = remote["owner_id"] as? String { ownerID = v }
        if let s = remote["updated_at"] as? String,
           let d = ISO8601DateFormatter().date(from: s) {
            updatedAt = d
        }
        if let s = remote["created_at"] as? String,
           let d = ISO8601DateFormatter().date(from: s) {
            createdAt = d
        }
    }
}
