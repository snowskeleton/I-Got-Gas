//
//  SyncManager.swift
//  I Got Gas
//
//  Created by Claude on 2025.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
class SyncManager {
    var isSyncing = false
    var lastError: String?
    var lastSyncDate: Date?
    var shares: SyncShares?

    private var debounceTask: Task<Void, Never>?
    private var periodicTask: Task<Void, Never>?
    private var context: ModelContext?

    func configure(context: ModelContext) {
        self.context = context
        lastSyncDate = SyncMetadata.lastSyncedAt
    }

    // Called after local writes — debounced by 2 seconds
    func triggerSync() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await performSync()
        }
    }

    // Called on foreground / pull-to-refresh — immediate
    func syncNow() {
        Task { await performSync() }
    }

    // Start 5-minute periodic sync
    func startPeriodicSync() {
        periodicTask?.cancel()
        periodicTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { break }
                await performSync()
            }
        }
    }

    func stopPeriodicSync() {
        periodicTask?.cancel()
    }

    private func performSync() async {
        guard !isSyncing else { return }
        guard KeychainHelper.read(.accessToken) != nil else { return }
        guard let context else { return }

        isSyncing = true
        lastError = nil

        do {
            // Gather local changes since last sync
            let changes = try gatherLocalChanges(context: context)

            let request = SyncRequest(
                deviceID: SyncMetadata.deviceID,
                lastSyncedAt: SyncMetadata.lastSyncedAtString,
                changes: changes
            )

            let response: SyncResponse = try await APIClient.shared.request(
                APIEndpoints.sync,
                method: "POST",
                body: request
            )

            // Apply remote changes
            let merger = SyncMerger(context: context)
            try merger.apply(response)

            // Update cursor
            SyncMetadata.updateCursor(from: response.syncedAt)
            lastSyncDate = SyncMetadata.lastSyncedAt
            shares = response.shares
        } catch {
            lastError = error.localizedDescription
        }

        isSyncing = false
    }

    private func gatherLocalChanges(context: ModelContext) throws -> SyncChanges {
        let isoFormatter = ISO8601DateFormatter()
        let since = SyncMetadata.lastSyncedAt ?? Date.distantPast

        // Cars changed since last sync
        let carPredicate = #Predicate<SDCar> { $0.updatedAt > since }
        let carDescriptor = FetchDescriptor<SDCar>(predicate: carPredicate)
        let localCars = try context.fetch(carDescriptor)
        let apiCars: [APICar] = localCars.map { car in
            APICar(
                id: car.id,
                ownerID: car.ownerID,
                make: car.make,
                model: car.model,
                name: car.name,
                plate: car.plate,
                vin: car.vin,
                year: car.year,
                startingOdometer: car.startingOdometer,
                pinned: car.pinned,
                deleted: car.deleted,
                archived: car.archived,
                createdAt: isoFormatter.string(from: car.createdAt),
                updatedAt: isoFormatter.string(from: car.updatedAt)
            )
        }

        // Services changed since last sync
        let svcPredicate = #Predicate<SDService> { $0.updatedAt > since }
        let svcDescriptor = FetchDescriptor<SDService>(predicate: svcPredicate)
        let localServices = try context.fetch(svcDescriptor)
        let apiServices: [APIService] = localServices.map { svc in
            APIService(
                id: svc.id,
                carID: svc.car?.id ?? "",
                cost: svc.cost,
                date: isoFormatter.string(from: svc.date),
                pending: svc.pending,
                name: svc.name,
                fullDescription: svc.fullDescription,
                odometer: svc.odometer,
                isFuel: svc.isFuel,
                isFullTank: svc.isFullTank,
                gallons: svc.gallons,
                vendorName: svc.vendorName,
                deleted: svc.deleted,
                createdAt: isoFormatter.string(from: svc.createdAt),
                updatedAt: isoFormatter.string(from: svc.updatedAt)
            )
        }

        // Scheduled services changed since last sync
        let ssPredicate = #Predicate<SDScheduledService> { $0.updatedAt > since }
        let ssDescriptor = FetchDescriptor<SDScheduledService>(predicate: ssPredicate)
        let localScheduled = try context.fetch(ssDescriptor)
        let apiScheduled: [APIScheduledService] = localScheduled.map { ss in
            let intervalString: String
            switch ss.frequencyTimeInterval {
            case .day: intervalString = "day"
            case .month: intervalString = "month"
            case .year: intervalString = "year"
            }
            return APIScheduledService(
                id: ss.id,
                carID: ss.car?.id ?? "",
                name: ss.name,
                fullDescription: ss.fullDescription,
                notificationUUID: ss.notificationUUID,
                repeating: ss.repeating,
                odometerFirstOccurance: ss.odometerFirstOccurance,
                frequencyMiles: ss.frequencyMiles,
                frequencyTime: ss.frequencyTime,
                frequencyTimeInterval: intervalString,
                frequencyTimeStart: isoFormatter.string(from: ss.frequencyTimeStart),
                deleted: ss.deleted,
                createdAt: isoFormatter.string(from: ss.createdAt),
                updatedAt: isoFormatter.string(from: ss.updatedAt)
            )
        }

        // Car settings — always send all (they're small)
        let settingsDescriptor = FetchDescriptor<SDCarSettings>()
        let localSettings = try context.fetch(settingsDescriptor)
        let apiSettings: [APICarSettings] = localSettings.compactMap { cs in
            guard let carID = cs.car?.id else { return nil }
            return APICarSettings(
                carID: carID,
                selectedTab: cs.selectedTab,
                rangeDays: cs.range,
                includeFuel: cs.includeFuel,
                includeMaintenance: cs.includeMaintenance,
                includeCompleted: cs.includeCompleted,
                includePending: cs.includePending,
                custom: cs.custom,
                updatedAt: isoFormatter.string(from: cs.updatedAt)
            )
        }

        return SyncChanges(
            cars: apiCars,
            services: apiServices,
            scheduledServices: apiScheduled,
            carSettings: apiSettings
        )
    }
}
