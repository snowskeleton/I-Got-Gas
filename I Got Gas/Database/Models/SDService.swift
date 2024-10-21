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

