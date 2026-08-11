//
//  AppDelegate.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import UIKit
import CoreData
import SwiftData
import Aptabase
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // we have to keep this around for legacy versions that need to migrate data
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "I_Got_Gas")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushTokenManager.shared.didRegister(tokenData: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if targetEnvironment(simulator)
        DebugLog.push("not supported in Simulator")
        #else
        DebugLog.push("registration FAILED: \(error)")
        #endif
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            let changedCarIDs = await SyncManager.current?.performSync() ?? []
            if !changedCarIDs.isEmpty {
                postLocalNotifications(for: changedCarIDs)
            }
            completionHandler(changedCarIDs.isEmpty ? .noData : .newData)
        }
    }

    private func postLocalNotifications(for carIDs: Set<String>) {
        let context = SwiftDataManager.shared.container.mainContext
        let center = UNUserNotificationCenter.current()

        for carID in carIDs {
            let predicate = #Predicate<SDCar> { $0.id == carID }
            let descriptor = FetchDescriptor<SDCar>(predicate: predicate)
            guard let car = try? context.fetch(descriptor).first else { continue }

            let shouldNotify = car.settings?.notifyOnChange ?? true
            guard shouldNotify else { continue }

            let content = UNMutableNotificationContent()
            content.title = car.visualName
            content.body = "Vehicle data was updated"
            content.sound = .default

            let identifier = "sync_\(carID)_\(Date().timeIntervalSince1970)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            center.add(request)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await SyncManager.current?.performSync()
            completionHandler()
        }
    }
}
