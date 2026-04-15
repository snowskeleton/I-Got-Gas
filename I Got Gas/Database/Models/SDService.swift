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
    @Attribute(originalName: "localId")
    var id: String = UUID().uuidString
    
    var cost: Double = 0.0
    @Attribute(originalName: "datePurchased")
    var date = Date()
    @Attribute(originalName: "isCompleted")
    var pending: Bool = false
    @Attribute(originalName: "note")
    var name: String = ""
    var fullDescription: String = ""
    var odometer: Int = 0
    
    var isFuel: Bool = false
    var isFullTank: Bool = true
    var gallons: Double = 0.0
    
    var vendorName = ""
    var deleted: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

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

    func touch() {
        updatedAt = Date()
    }

    func toAPIModel() -> [String: Any] {
        return [
            "id": id,
            "car_id": car?.id ?? "",
            "cost": cost,
            "date": ISO8601DateFormatter().string(from: date),
            "pending": pending,
            "name": name,
            "full_description": fullDescription,
            "odometer": odometer,
            "is_fuel": isFuel,
            "is_full_tank": isFullTank,
            "gallons": gallons,
            "vendor_name": vendorName,
            "deleted": deleted,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
    }

    func applyRemote(_ remote: [String: Any]) {
        if let v = remote["cost"] as? Double { cost = v }
        if let v = remote["pending"] as? Bool { pending = v }
        if let v = remote["name"] as? String { name = v }
        if let v = remote["full_description"] as? String { fullDescription = v }
        if let v = remote["odometer"] as? Int { odometer = v }
        if let v = remote["is_fuel"] as? Bool { isFuel = v }
        if let v = remote["is_full_tank"] as? Bool { isFullTank = v }
        if let v = remote["gallons"] as? Double { gallons = v }
        if let v = remote["vendor_name"] as? String { vendorName = v }
        if let v = remote["deleted"] as? Bool { deleted = v }
        if let s = remote["date"] as? String,
           let d = ISO8601DateFormatter().date(from: s) {
            date = d
        }
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

extension Array where Element == SDService {
    // these filters only filter our their own results when passed `false`,
    // otherwise they let through everything.
    // For example, call with
    //services.fuel(false).pending(false)
    // to get all non-fuel (i.e., maintenance) and completed transactions
    
    func fuel(_ include: Bool = true) -> [SDService] {
        return include ? self : self.filter { !$0.isFuel }
    }
    
    func maintenance(_ include: Bool = true) -> [SDService] {
        return include ? self : self.filter { $0.isFuel }
    }
    
    func pending(_ include: Bool = true) -> [SDService] {
        return include ? self : self.filter { !$0.pending }
    }
    
    func completed(_ include: Bool = true) -> [SDService] {
        return include ? self : self.filter { $0.pending }
    }
   
    enum TimePeriod {
        case days(Int)
        case weeks(Int)
        case months(Int)
        case years(Int)
        
        var value: Int {
            switch self {
            case .days(let count), .weeks(let count), .months(let count), .years(let count):
                return count
            }
        }
    }
    
    func time(_ period: TimePeriod) -> [SDService] {
        let today = Date()
        var targetDate: Date?
        
        switch period {
        case .days(let count):
            targetDate = Calendar.current.date(byAdding: .day, value: -count, to: today)
        case .weeks(let count):
            targetDate = Calendar.current.date(byAdding: .weekOfYear, value: -count, to: today)
        case .months(let count):
            targetDate = Calendar.current.date(byAdding: .month, value: -count, to: today)
        case .years(let count):
            targetDate = Calendar.current.date(byAdding: .year, value: -count, to: today)
        }
        
        guard let validDate = targetDate else {
            return []
        }
        
        if period.value == 0 {
            return self
        } else {
            return self.filter { $0.date >= validDate && $0.date <= today }
        }
    }
}

extension Array where Element == SDService {
    var costPerMile: Double {
        let totalCost = self.reduce(0.0) { $0 + $1.cost }
        let lowestOdometer = self.map { $0.odometer }.min() ?? 0
        let highestOdometer = self.map { $0.odometer }.max() ?? lowestOdometer
        let milesDriven = highestOdometer - lowestOdometer
        
        // Prevent division by zero
        guard milesDriven > 0 else {
            return 0.0
        }
        
        return totalCost / Double(milesDriven)
    }
    
    var lastFillup: Date? {
        self.filter { $0.isFuel }
            .max(by: { $0.odometer < $1.odometer } )?
            .date
    }
}

