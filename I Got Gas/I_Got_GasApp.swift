//
//  I_Got_GasApp.swift
//  I Got Gas
//
//  Created by snow on 10/4/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import CoreData

@main
struct I_Got_GasApp: App {
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    @Environment(\.scenePhase) var scenePhase
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            // Provide the managed object context to the SwiftUI view hierarchy
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .onChange(of: scenePhase) { _, newScenePhase in
            switch newScenePhase {
            case .background:
                persistenceController.saveContext() // Save context when entering background
            default:
                break
            }
        }
    }
}
