//
//  Car+CoreDataClass.swift
//
//
//  Created by Isaac Lyons on 10/21/20.
//
//

import Foundation
import CoreData
import SwiftUI

@objc(Car)
public class Car: NSManagedObject {
    @State private var priceFormat = UserDefaults.standard.string(forKey: "priceFormat") ?? ""
    
    var dpg: String {
        let fuelCosts = services?.compactMap { ($0 as AnyObject).fuel?.dpg as? Double } ?? []
        let totalFuelCost = fuelCosts.reduce(0, +)
        let fuelExpenseCount = Double(fuelCosts.count)
        
        guard fuelExpenseCount > 0 else {
            return "$0.000/gal"
        }
        
        return String(format: "$%.3f/gal", totalFuelCost / fuelExpenseCount)
    }
}
