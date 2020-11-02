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

    func dpg() -> Text {
        var fuelCost = 0.00
        var fuelExpenseCount = 0.0

        for service in services! {
            if ((service as AnyObject).fuel as AnyObject).dpg != nil {
                fuelCost += ((service as AnyObject).fuel as AnyObject).dpg
                fuelExpenseCount += 1
            }
        }
        return Text("\((fuelCost / fuelExpenseCount), specifier: (priceFormat == "" ? "%.3f" : "\(String(describing: priceFormat))"))/gal")
    }

}
