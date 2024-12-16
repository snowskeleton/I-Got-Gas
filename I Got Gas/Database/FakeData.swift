//
//  FakeData.swift
//  I Got Gas
//
//  Created by snow on 12/9/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import Foundation

func generateFakeCarData() -> SDCar {
    let car = SDCar(
        make: "Toyota",
        model: "Camry",
        name: "Daily Driver",
        plate: "XYZ123",
        vin: "1HGBH41JXMN109186",
        year: 2015,
        startingOdometer: 20000
    )
    
    let currentDate = Date()
    let calendar = Calendar.current
    var date = calendar.date(byAdding: .year, value: -5, to: currentDate)!
    var odometer = car.startingOdometer
    
    // Generate Fuel Services
    while date < currentDate {
        let gallons = randomDouble(min: 10.0, max: 15.0)
        let pricePerGallon = randomDouble(min: 2.5, max: 4.0)
        let cost = gallons * pricePerGallon
        
        odometer += randomInt(min: 450, max: 800)
        
        let fuelService = SDService(
            cost: cost,
            date: date,
            name: "Fuel",
            odometer: odometer
        )
        fuelService.isFuel = true
        fuelService.gallons = gallons
        
        car.services?.append(fuelService)
        
        date = calendar.date(byAdding: .day, value: 14, to: date)!
    }
    
    // Generate Maintenance Services
    generateMaintenanceServices(for: car)
    return car
}

func generateMaintenanceServices(for car: SDCar) {
    let maintenanceNames = [
        "Oil Change", "Tire Replacement", "Brake Pads Replacement",
        "Air Filter Replacement", "Battery Replacement",
        "Spark Plugs Replacement", "Transmission Fluid Change",
        "Timing Belt Replacement", "Wheel Alignment", "Coolant Flush"
    ]
    
    var date = car.services?.first?.date ?? Date()
    var odometer = car.startingOdometer
    let calendar = Calendar.current
    
    for _ in 0..<20 {
        let milesBetween = randomInt(min: 2000, max: 5000)
        odometer += milesBetween
        let maintenanceName = maintenanceNames.randomElement() ?? "General Repair"
        let cost = randomDouble(min: 100.0, max: 800.0)
        
        date = calendar.date(byAdding: .day, value: randomInt(min: 30, max: 90), to: date)!
        
        let maintenanceService = SDService(
            cost: cost,
            date: date,
            name: maintenanceName,
            odometer: odometer
        )
        car.services?.append(maintenanceService)
    }
}

func randomDouble(min: Double, max: Double, skewLow: Bool = false) -> Double {
    let random = Double.random(in: 0...1)
    let weighted = skewLow ? pow(random, 2) : random  // Squaring biases towards lower end
    return min + (max - min) * weighted
}

func randomInt(min: Int, max: Int) -> Int {
    return Int.random(in: min...max)
}
