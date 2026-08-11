//
//  I_Got_GasApp.swift
//  I Got Gas
//
//  Created by snow on 10/4/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData
import Aptabase

@main
struct I_Got_GasApp: App {
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    @Environment(\.scenePhase) var scenePhase

    @State private var authManager = AuthManager()
    @State private var syncManager = SyncManager()
    @State private var shareManager = ShareManager()

    init() {
        Aptabase.shared.initialize(
            appKey: AptabaseSecrets.appKey,
            with: InitOptions(host: AptabaseSecrets.host)
        )
        Analytics.track(.appLaunch)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let failure = SwiftDataManager.shared.loadFailure {
                    // In-memory fallback: the app would otherwise present an
                    // empty account with no explanation.
                    StoreRecoveryView(error: failure)
                } else if authManager.isAuthenticated || authManager.skippedLogin {
                    MainView()
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
                // Nothing below should run against the throwaway store.
                guard SwiftDataManager.shared.loadFailure == nil else { return }
                syncManager.configure(
                    context: SwiftDataManager.shared.container.mainContext
                )
                Task {
                    await NotificationReconciler.reconcile(
                        context: SwiftDataManager.shared.container.mainContext
                    )
                }
                TombstonePurge.run(context: SwiftDataManager.shared.container.mainContext)
                // Mirror the synced preferences into the formatting cache.
                let preferences = SDUserPreferences.current(
                    in: SwiftDataManager.shared.container.mainContext
                )
                UnitPreferences.mirror(from: preferences)
                if authManager.isAuthenticated {
                    PushTokenManager.shared.requestPermissionAndRegister()
                }
            }
        }
        .modelContainer(SwiftDataManager.shared.container)
        .onChange(of: scenePhase) { _, newScenePhase in
            guard SwiftDataManager.shared.loadFailure == nil else { return }
            switch newScenePhase {
            case .active:
                // Reminders are derived state, so they get recomputed rather
                // than being written when an expense happens to be saved.
                Task {
                    await NotificationReconciler.reconcile(
                        context: SwiftDataManager.shared.container.mainContext
                    )
                }
                if authManager.isAuthenticated {
                    syncManager.syncNow()
                    syncManager.startPeriodicSync()
                    PushTokenManager.shared.requestPermissionAndRegister()
                    Task { await authManager.verifyAuth() }
                    Task { await shareManager.fetchReceivedShares() }
                }
            case .background:
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
