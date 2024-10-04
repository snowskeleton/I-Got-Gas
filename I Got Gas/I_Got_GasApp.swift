//
//  I_Got_GasApp.swift
//  I Got Gas
//
//  Created by snow on 10/4/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData
import CoreData

@main
struct I_Got_GasApp: App {
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    @Environment(\.scenePhase) var scenePhase
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .modelContainer(SwiftDataManager.shared.container)
        .onChange(of: scenePhase) { _, newScenePhase in
            switch newScenePhase {
            case .background:
                persistenceController.saveContext()
            default:
                break
            }
        }
    }
}
