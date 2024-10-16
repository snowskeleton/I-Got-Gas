//
//  SwiftDataManager.swift
//  I Got Gas
//
//  Created by snow on 8/24/24.
//

import Foundation
import SwiftData

public class SwiftDataManager {
    
    public static let shared = SwiftDataManager()
    
    public let container: ModelContainer = {
        
        let schema = Schema([
            SDCar.self,
            SDService.self,
            SDScheduledService.self,
//            SDVendor.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
//            try ModelContainer().deleteAllData()
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            do {
                NSLog("Failed to load current schema and config. Cleraing and trying again")
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()
}
