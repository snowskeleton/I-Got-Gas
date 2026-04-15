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
import Aptabase

@main
struct I_Got_GasApp: App {
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    @Environment(\.scenePhase) var scenePhase
    let persistenceController = PersistenceController.shared

    @State private var authManager = AuthManager()
    @State private var syncManager = SyncManager()
    @State private var shareManager = ShareManager()

    init() {
        Aptabase.shared.initialize(
            appKey: AptabaseSecrets.appKey,
            with: InitOptions(host: AptabaseSecrets.host)
        )
        Analytics.track(.appLaunch)
        SDCarSettings.setDefaults()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated || authManager.skippedLogin {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                } else {
                    LoginView()
                }
            }
            .environment(authManager)
            .environment(syncManager)
            .environment(shareManager)
            .onOpenURL { url in
                handleIncomingURL(url)
            }
            .onAppear {
                syncManager.configure(
                    context: SwiftDataManager.shared.container.mainContext
                )
            }
        }
        .modelContainer(SwiftDataManager.shared.container)
        .onChange(of: scenePhase) { _, newScenePhase in
            switch newScenePhase {
            case .active:
                if authManager.isAuthenticated {
                    syncManager.syncNow()
                    syncManager.startPeriodicSync()
                    Task { await authManager.fetchEmailIfNeeded() }
                    Task { await shareManager.fetchReceivedShares() }
                }
            case .background:
                persistenceController.saveContext()
                syncManager.stopPeriodicSync()
            default:
                break
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        // Deep link callback: igg://auth/callback?access_token=...&refresh_token=...&expires_in=...
        if components.path.contains("auth/callback"),
           let accessToken = components.queryItems?.first(where: { $0.name == "access_token" })?.value,
           let refreshToken = components.queryItems?.first(where: { $0.name == "refresh_token" })?.value {
            authManager.handleDeepLinkTokens(accessToken: accessToken, refreshToken: refreshToken)
            return
        }

        // Share acceptance: igg://shares/accept?token=...
        if components.path.contains("shares/accept"),
           let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
            Task {
                _ = token
            }
            return
        }
    }
}
