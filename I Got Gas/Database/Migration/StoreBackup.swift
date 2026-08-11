//
//  StoreBackup.swift
//  I Got Gas
//
//  A copy of the SQLite store taken immediately before a major-version
//  migration, so a migration that goes wrong is recoverable rather than
//  merely survivable.
//
//  Two rules drive the whole design:
//
//  1. The copy has to happen before `ModelContainer` is constructed, because
//     that is what runs the migration. That also means the store is closed and
//     has no live writer, so a plain file copy is consistent.
//  2. A store is not one file. The `-wal` sidecar holds committed transactions
//     that have not been checkpointed into the main file yet, so copying only
//     the `.store` silently loses the user's most recent writes.
//
//  Restore cannot happen in place — you can't swap the file out from under an
//  open store — so it is staged to a flag and applied on the next launch,
//  before the container opens.
//

import Foundation
import SwiftData

enum StoreBackup {

    // MARK: - Keys

    private static let lastOpenedVersionKey = "igg_last_opened_schema_version"
    private static let pendingRestoreKey = "igg_pending_restore"

    // MARK: - Locations

    /// Authoritative store location, taken from the same configuration the
    /// container is built with rather than assumed.
    static func storeURL(for configuration: ModelConfiguration) -> URL {
        configuration.url
    }

    static var backupsRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PreMigrationBackups", isDirectory: true)
    }

    /// Every file that makes up the store. The support directory holds
    /// `.externalStorage` blobs; there are none before 3.0, but a future major
    /// will have them and a partial backup is worse than none.
    /// The sidecars are `default.store-wal` / `-shm` — SQLite appends them
    /// with a hyphen, so they are *not* path extensions. Building them with
    /// `appendingPathExtension` yields `default.store.wal`, which matches
    /// nothing: the backup silently omits the write-ahead log, and a restore
    /// leaves the previous store's log in place next to the restored database.
    static func components(of storeURL: URL) -> [URL] {
        let directory = storeURL.deletingLastPathComponent()
        let name = storeURL.lastPathComponent
        let stem = storeURL.deletingPathExtension().lastPathComponent
        return [
            storeURL,
            directory.appendingPathComponent("\(name)-wal"),
            directory.appendingPathComponent("\(name)-shm"),
            directory.appendingPathComponent(".\(stem)_SUPPORT", isDirectory: true),
        ]
    }

    /// Removes every component of the store. Callers must only do this while
    /// the store is closed — a half-removed set is a corrupt store.
    static func removeStore(at storeURL: URL) {
        let manager = FileManager.default
        for component in components(of: storeURL) where manager.fileExists(atPath: component.path) {
            try? manager.removeItem(at: component)
        }
    }

    // MARK: - Version tracking

    /// Only major transitions get a backup. Lightweight in-place migrations
    /// are reversible enough not to be worth the disk.
    static func shouldBackUp(currentVersion: Schema.Version) -> Bool {
        guard let last = UserDefaults.standard.string(forKey: lastOpenedVersionKey) else {
            // First launch with this code. Only worth a copy if a store
            // already exists — a brand new install has nothing to lose.
            return true
        }
        let lastMajor = Int(last.split(separator: ".").first ?? "0") ?? 0
        return currentVersion.major > lastMajor
    }

    /// Makes the next open look like a fresh version transition. Used after
    /// the store on disk has been replaced with something older.
    static func forgetVersionMarker() {
        UserDefaults.standard.removeObject(forKey: lastOpenedVersionKey)
    }

    /// Called only after the container opens cleanly. A failed migration
    /// deliberately leaves the marker alone, so the next launch still sees the
    /// transition as pending and does not overwrite the good backup.
    static func markOpened(version: Schema.Version) {
        let text = "\(version.major).\(version.minor).\(version.patch)"
        UserDefaults.standard.set(text, forKey: lastOpenedVersionKey)
    }

    // MARK: - Backing up

    @discardableResult
    static func backUpIfNeeded(configuration: ModelConfiguration, version: Schema.Version) -> URL? {
        guard shouldBackUp(currentVersion: version) else { return nil }

        let storeURL = storeURL(for: configuration)
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            NSLog("StoreBackup: no existing store, nothing to back up")
            return nil
        }

        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let previous = UserDefaults.standard.string(forKey: lastOpenedVersionKey) ?? "unknown"
        let destination = backupsRoot.appendingPathComponent("v\(previous)-\(stamp)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: destination, withIntermediateDirectories: true
            )
            for component in components(of: storeURL) {
                guard FileManager.default.fileExists(atPath: component.path) else { continue }
                try FileManager.default.copyItem(
                    at: component,
                    to: destination.appendingPathComponent(component.lastPathComponent)
                )
            }
            excludeFromDeviceBackup(destination)
            let copied = (try? FileManager.default.contentsOfDirectory(
                at: destination, includingPropertiesForKeys: nil
            ).map(\.lastPathComponent)) ?? []
            NSLog("StoreBackup: copied store to %@ (%@)",
                  destination.lastPathComponent, copied.joined(separator: ", "))
            return destination
        } catch {
            // A backup we couldn't take must not stop the app from opening.
            NSLog("StoreBackup: backup failed: %@", error.localizedDescription)
            return nil
        }
    }

    /// Recovery artifact, not user content — keep it off the user's iCloud
    /// quota, matching what `AttachmentStore` does with cached receipts.
    private static func excludeFromDeviceBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    // MARK: - Listing

    struct Entry: Identifiable, Hashable {
        var id: String { name }
        let name: String
        let url: URL
        let createdAt: Date
        let byteSize: Int
    }

    static func available() -> [Entry] {
        let manager = FileManager.default
        guard let contents = try? manager.contentsOfDirectory(
            at: backupsRoot,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.compactMap { url -> Entry? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            else { return nil }
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            return Entry(
                name: url.lastPathComponent,
                url: url,
                createdAt: created ?? Date(timeIntervalSince1970: 0),
                byteSize: size(of: url)
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    private static func size(of directory: URL) -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return files.reduce(0) { total, file in
            total + ((try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
    }

    // MARK: - Restoring

    /// Stages a restore. Applied on the next launch — see `applyPendingRestore`.
    static func stageRestore(_ entry: Entry) {
        UserDefaults.standard.set(entry.name, forKey: pendingRestoreKey)

        // The cursors live in UserDefaults and survive the store swap. Left
        // alone, the server would correctly send nothing back to a client that
        // still claims to be caught up, stranding the restored store behind.
        SyncMetadata.clearCursors()

        // The staging UI quits with `exit(0)`, which skips the normal
        // termination flush. Without this the flag can be gone on next launch
        // and the restore silently never happens.
        UserDefaults.standard.synchronize()
    }

    static var hasPendingRestore: Bool {
        UserDefaults.standard.string(forKey: pendingRestoreKey) != nil
    }

    /// Must run before the container is constructed.
    static func applyPendingRestore(configuration: ModelConfiguration) {
        guard let name = UserDefaults.standard.string(forKey: pendingRestoreKey) else { return }
        UserDefaults.standard.removeObject(forKey: pendingRestoreKey)

        let source = backupsRoot.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.path) else {
            NSLog("StoreBackup: staged restore %@ is missing", name)
            return
        }

        let storeURL = storeURL(for: configuration)
        let manager = FileManager.default

        do {
            // Clear the live store first, including the sidecars: a database
            // restored next to the previous store's write-ahead log is corrupt.
            removeStore(at: storeURL)
            let files = try manager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
            for file in files {
                try manager.copyItem(
                    at: file,
                    to: storeURL.deletingLastPathComponent()
                        .appendingPathComponent(file.lastPathComponent)
                )
            }
            NSLog("StoreBackup: restored %d files: %@",
                  files.count, files.map(\.lastPathComponent).joined(separator: ", "))
            // The restored store predates the current schema, so the next open
            // has to be treated as a fresh transition.
            UserDefaults.standard.removeObject(forKey: lastOpenedVersionKey)
            NSLog("StoreBackup: restored %@", name)
        } catch {
            NSLog("StoreBackup: restore failed: %@", error.localizedDescription)
        }
    }

    static func delete(_ entry: Entry) {
        try? FileManager.default.removeItem(at: entry.url)
    }
}
