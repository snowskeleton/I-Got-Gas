//
//  SyncManager.swift
//  I Got Gas
//

import Foundation
import SwiftData
import SwiftUI

/// Drives the op exchange.
///
/// What changed from the previous version, and why:
///
///  * Local changes come from an explicit outbox rather than a timestamp
///    window, so an edit made mid-request can't fall into a gap.
///  * Syncs queue instead of being dropped. The old code returned early if a
///    sync was already running, so a debounced save that collided with the
///    periodic timer was simply discarded.
///  * Failures back off and retry instead of being written to a label.
@Observable
@MainActor
class SyncManager {
    /// Shared reference so AppDelegate can trigger syncs for background pushes.
    static var current: SyncManager?

    var isSyncing = false
    var lastError: String?
    var lastSyncDate: Date?
    var shares: SyncShares?

    /// Cars this build is too old to write to. Drives the upgrade banner.
    var blockedCarIDs: Set<String> = []
    var needsAppUpdate = false

    var pendingOpCount: Int = 0

    private var debounceTask: Task<Void, Never>?
    private var periodicTask: Task<Void, Never>?
    private var context: ModelContext?

    /// Serializes syncs. A request arriving while one is in flight sets this
    /// flag and is run immediately afterwards rather than being dropped.
    private var syncQueued = false
    private var consecutiveFailures = 0

    init() {
        SyncManager.current = self
    }

    func configure(context: ModelContext) {
        self.context = context
        lastSyncDate = SyncMetadata.lastSyncedAt
        pendingOpCount = Outbox.count(in: context)
    }

    // MARK: - Recording changes

    /// Records ops for a changed object and schedules a push.
    func record(_ ops: [Op]) {
        guard !ops.isEmpty, let context else { return }
        Outbox.enqueue(ops, in: context)
        pendingOpCount = Outbox.count(in: context)
        triggerSync()
    }

    func recordCar(_ car: SDCar) { record(OpBuilder.ops(for: car)) }
    func recordService(_ service: SDService) { record(OpBuilder.ops(for: service)) }
    func recordSchedule(_ schedule: SDScheduledService) { record(OpBuilder.ops(for: schedule)) }
    func recordPart(_ part: SDPart) { record(OpBuilder.ops(for: part)) }
    func recordCatalogPart(_ entry: SDCatalogPart) { record(OpBuilder.ops(for: entry)) }
    func recordAttachment(_ attachment: SDAttachment) { record(OpBuilder.ops(for: attachment)) }
    func recordSettings(_ settings: SDCarSettings) { record(OpBuilder.ops(for: settings)) }

    // MARK: - Triggers

    /// Called after local writes — debounced.
    func triggerSync() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await performSync()
        }
    }

    /// Called on foreground / pull-to-refresh — immediate.
    func syncNow() {
        Task { await performSync() }
    }

    func startPeriodicSync() {
        periodicTask?.cancel()
        periodicTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(120))
                guard !Task.isCancelled else { break }
                await performSync()
            }
        }
    }

    func stopPeriodicSync() {
        periodicTask?.cancel()
    }

    /// Forgets everything about the previous account.
    func signOut() {
        stopPeriodicSync()
        debounceTask?.cancel()
        if let context {
            Outbox.clear(in: context)
        }
        SyncMetadata.reset()
        blockedCarIDs = []
        needsAppUpdate = false
        pendingOpCount = 0
        Task { await NotificationReconciler.cancelAll() }
    }

    // MARK: - The exchange

    @discardableResult
    func performSync() async -> Set<String> {
        // Queue rather than drop.
        if isSyncing {
            syncQueued = true
            return []
        }
        guard KeychainHelper.read(.accessToken) != nil else { return [] }

        if context == nil {
            context = SwiftDataManager.shared.container.mainContext
        }
        guard let context else { return [] }

        isSyncing = true
        defer { isSyncing = false }

        var changedCarIDs = Set<String>()

        do {
            let pending = Outbox.pending(in: context)
            let ops = pending.compactMap(\.op)

            let request = OpSyncRequest(
                deviceID: SyncMetadata.deviceID,
                schemaVersion: SchemaVersion.current,
                cursors: SyncMetadata.cursors,
                ops: ops
            )

            let response: OpSyncResponse = try await APIClient.shared.request(
                APIEndpoints.sync, method: "POST", body: request
            )

            // Acknowledged ops leave the outbox. Anything unmentioned stays
            // and is retried — that's the guarantee the old design lacked.
            Outbox.acknowledge(response.appliedOpIDs ?? [], in: context)
            Outbox.reject(response.rejected ?? [], in: context)

            if let remote = response.ops, !remote.isEmpty {
                let applier = OpApplier(context: context)
                changedCarIDs = try applier.apply(remote)
            }

            // Cars the server says we can no longer see.
            for carID in response.revokedCarIDs ?? [] {
                dropLocalCar(carID, in: context)
            }

            SyncMetadata.advance(response.cursors ?? [:])
            SyncMetadata.lastSyncedAt = Date()
            lastSyncDate = SyncMetadata.lastSyncedAt
            shares = response.shares
            blockedCarIDs = Set(response.blockedCarIDs ?? [])
            needsAppUpdate = !blockedCarIDs.isEmpty

            try? context.save()
            pendingOpCount = Outbox.count(in: context)
            lastError = nil
            consecutiveFailures = 0

            await NotificationReconciler.reconcile(context: context)
            await AttachmentTransfer.shared.uploadPending(context: context)

        } catch let error as APIClientError {
            if case .httpError(426) = error {
                // Below the server's floor — no amount of retrying helps.
                needsAppUpdate = true
                lastError = "This version of the app is too old to sync."
            } else {
                lastError = error.localizedDescription
                await backoff()
            }
        } catch {
            lastError = error.localizedDescription
            await backoff()
        }

        if syncQueued {
            syncQueued = false
            return await performSync()
        }
        return changedCarIDs
    }

    /// Exponential backoff, capped. Scheduled rather than slept inline so the
    /// caller isn't held open.
    private func backoff() async {
        consecutiveFailures += 1
        let delay = min(pow(2.0, Double(consecutiveFailures)), 300)
        debounceTask?.cancel()
        debounceTask = Task { [delay] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await performSync()
        }
    }

    /// Removes a car whose share was revoked. Local-only: the data still
    /// exists on the owner's account, we just no longer have access.
    private func dropLocalCar(_ carID: String, in context: ModelContext) {
        let descriptor = FetchDescriptor<SDCar>(predicate: #Predicate { $0.id == carID })
        guard let car = try? context.fetch(descriptor).first else {
            SyncMetadata.resetCursor(forCar: carID)
            return
        }
        for service in car.services ?? [] { context.delete(service) }
        for schedule in car.scheduledServices ?? [] { context.delete(schedule) }
        context.delete(car)
        SyncMetadata.resetCursor(forCar: carID)
    }
}
