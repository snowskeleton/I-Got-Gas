//
//  SyncMetadata.swift
//  I Got Gas
//
//  Created by Claude on 2025.
//

import Foundation

enum SyncMetadata {
    private static let deviceIDKey = "igg_sync_device_id"
    private static let lastSyncKey = "igg_last_synced_at"

    static var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIDKey) {
            return existing
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: deviceIDKey)
        return newID
    }

    static var lastSyncedAt: Date? {
        get {
            UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastSyncKey)
        }
    }

    static var lastSyncedAtString: String? {
        guard let date = lastSyncedAt else { return nil }
        return ISO8601DateFormatter().string(from: date)
    }

    static func updateCursor(from syncedAt: String) {
        if let date = ISO8601DateFormatter().date(from: syncedAt) {
            lastSyncedAt = date
        }
    }
}
