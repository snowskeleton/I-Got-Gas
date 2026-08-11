//
//  SyncMetadata.swift
//  I Got Gas
//
//  Device identity and per-car sync cursors.
//
//  The cursor is now a server-assigned sequence number rather than a
//  timestamp. That removes the device clock from cursor arithmetic entirely,
//  which is what made the old design lose writes: it advanced the cursor to
//  the *server's* clock while selecting changes by the *device's*, so anything
//  edited during a request fell into the gap and was never sent again.
//
//  Cursors are also namespaced by account. Previously, signing into a second
//  account inherited the first one's cursor, and the new account's entire
//  history sat behind it, invisible.
//

import Foundation

enum SyncMetadata {

    private static let deviceIDKey = "igg_device_id"
    private static let cursorPrefix = "igg_cursor_"
    private static let accountKey = "igg_cursor_account"

    /// Stable per-install identifier. Also the conflict tiebreaker, so it must
    /// not change across launches.
    static var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIDKey) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: deviceIDKey)
        return generated
    }

    /// The account cursors currently belong to. Changing it discards them.
    static var accountID: String {
        get { UserDefaults.standard.string(forKey: accountKey) ?? "" }
        set {
            guard newValue != accountID else { return }
            clearCursors()
            UserDefaults.standard.set(newValue, forKey: accountKey)
        }
    }

    private static var storageKey: String {
        cursorPrefix + (accountID.isEmpty ? "anonymous" : accountID)
    }

    /// car id → last consumed seq. The empty key holds account-scoped ops.
    static var cursors: [String: Int64] {
        get {
            guard let raw = UserDefaults.standard.dictionary(forKey: storageKey) else {
                return [:]
            }
            return raw.compactMapValues { value in
                (value as? NSNumber)?.int64Value
            }
        }
        set {
            let encoded = newValue.mapValues { NSNumber(value: $0) }
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    /// Merges the server's cursors in, never moving one backwards.
    static func advance(_ updates: [String: Int64]) {
        var current = cursors
        for (carID, seq) in updates {
            current[carID] = max(current[carID] ?? 0, seq)
        }
        cursors = current
    }

    /// Forgets a car entirely, so it is pulled from the beginning next time.
    static func resetCursor(forCar carID: String) {
        var current = cursors
        current.removeValue(forKey: carID)
        cursors = current
    }

    static func clearCursors() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// Full reset, on sign-out.
    static func reset() {
        clearCursors()
        UserDefaults.standard.removeObject(forKey: accountKey)
    }

    // MARK: - Display

    static var lastSyncDateKey: String { "igg_last_sync_display" }

    static var lastSyncedAt: Date? {
        get { UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncDateKey) }
    }
}
