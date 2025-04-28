//
//  ImportExport.swift
//  I Got Gas
//
//  Created by snow on 12/23/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import Foundation

func generateCSV(for services: [SDService], scheduledServices: [SDScheduledService]) -> String {
    var csvContent = "ID,Name,Type,Cost,Date,Odometer,Is Fuel,Gallons,Vendor,Description,Pending,Past Due,Repeating,Frequency Miles,Frequency Time,Frequency Interval\n"
    
    // Export SDService
    for service in services {
        csvContent += """
        \(service.id),\(service.name),Service,\(service.cost),\(service.date),\(service.odometer),\(service.isFuel),\(service.gallons),\(service.vendorName),\(service.fullDescription),\(service.pending),,,,,\n
        """
    }
    
    // Export SDScheduledService
    for scheduledService in scheduledServices {
        csvContent += """
        \(scheduledService.id),\(scheduledService.name),Scheduled Service,,,,,,,\(scheduledService.fullDescription),,\(scheduledService.pastDue),\(scheduledService.repeating),\(scheduledService.frequencyMiles),\(scheduledService.frequencyTime),\(scheduledService.frequencyTimeInterval.rawValue)\n
        """
    }
    
    return csvContent
}

func saveCSVFile(content: String, fileName: String = "ServicesExport.csv") -> URL? {
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
    let fileURL = documentsURL.appendingPathComponent(fileName)
    
    do {
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    } catch {
        print("Error writing CSV file: \(error)")
        return nil
    }
}

enum CSVColumn: Int {
    case id = 0
    case name = 1
    case type = 2
    case cost = 3
    case date = 4
    case odometer = 5
    case isFuel = 6
    case gallons = 7
    case vendorName = 8
    case fullDescription = 9
    case pending = 10
    case repeating = 12
    case frequencyMiles = 13
    case frequencyTime = 14
    case frequencyTimeInterval = 15
}
