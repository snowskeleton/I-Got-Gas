//
//  PushTokenManager.swift
//  I Got Gas
//
//  Created by Claude on 2025.
//

import Foundation
import UIKit
import UserNotifications

final class PushTokenManager: @unchecked Sendable {
    static let shared = PushTokenManager()

    private let notifyModeKey = "igg_push_notify_mode"
    private(set) var currentToken: String?

    private init() {}

    var notifyMode: String {
        get { UserDefaults.standard.string(forKey: notifyModeKey) ?? "silent" }
        set { UserDefaults.standard.set(newValue, forKey: notifyModeKey) }
    }

    func requestPermissionAndRegister() {
        print("[Push] requestPermissionAndRegister called")
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            print("[Push] authorization result: granted=\(granted), error=\(String(describing: error))")
            // Silent pushes work even if the user denies permission.
            DispatchQueue.main.async {
                print("[Push] calling registerForRemoteNotifications")
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func didRegister(tokenData: Data) {
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()
        print("[Push] got APNs token: \(hex.prefix(16))...")
        currentToken = hex
        Task { await registerTokenWithServer() }
    }

    func updateNotifyMode(_ mode: String) {
        notifyMode = mode
        Task { await registerTokenWithServer() }
    }

    private func registerTokenWithServer() async {
        guard let token = currentToken else { return }
        guard KeychainHelper.read(.accessToken) != nil else { return }

        let body = RegisterDeviceRequest(
            deviceID: SyncMetadata.deviceID,
            token: token,
            platform: "ios",
            notifyMode: notifyMode
        )

        do {
            try await APIClient.shared.requestNoContent(
                APIEndpoints.devices,
                method: "PUT",
                body: body
            )
        } catch {
            // Non-critical; will retry next foreground
        }
    }

    func unregisterDevice() async {
        let body = UnregisterDeviceRequest(deviceID: SyncMetadata.deviceID)
        do {
            try await APIClient.shared.requestNoContent(
                APIEndpoints.devices,
                method: "DELETE",
                body: body
            )
        } catch {
            // Best-effort
        }
        currentToken = nil
    }
}
