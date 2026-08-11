//
//  OutboxBackfill.swift
//  I Got Gas
//
//  Pushes everything once, after the V2→V3 store migration.
//
//  Ops are normally emitted by `SyncManager.record*` when a view saves, so
//  records that existed before the upgrade have never produced any. The server
//  projects 2.x rows into ops on its own (see ProjectCar), which covers the
//  usual case — but only for data the server actually has. A single-device
//  user whose 2.x sync had fallen behind, or who was never signed in, holds
//  entries the server has never seen. This is what carries those across.
//
//  Deliberately belt-and-braces: it duplicates work the projector already did.
//  That's harmless — the ops carry each record's own `updatedAt`, so they tie
//  with the projection and resolve by device id, converging either way.
//

import Foundation
import SwiftData

@MainActor
enum OutboxBackfill {

    private static let pendingKey = "igg_needs_op_backfill"

    /// Marked during the V2→V3 migration, drained on the next sync setup.
    /// A flag rather than immediate work because the migration runs before
    /// there is a usable context or a signed-in user.
    static func markNeeded() {
        UserDefaults.standard.set(true, forKey: pendingKey)
    }

    static var isNeeded: Bool {
        UserDefaults.standard.bool(forKey: pendingKey)
    }

    /// Enqueues a full op set for every live record. Clears the flag only on
    /// success, so an interrupted run is retried rather than half-applied.
    @discardableResult
    static func runIfNeeded(context: ModelContext) -> Int {
        guard isNeeded else { return 0 }

        var ops: [Op] = []

        let cars = (try? context.fetch(FetchDescriptor<SDCar>())) ?? []
        for car in cars {
            ops += OpBuilder.ops(for: car)
            for service in car.services ?? [] {
                ops += OpBuilder.ops(for: service)
            }
            for schedule in car.scheduledServices ?? [] {
                ops += OpBuilder.ops(for: schedule)
            }
            if let settings = car.settings {
                ops += OpBuilder.ops(for: settings)
            }
        }

        guard !ops.isEmpty else {
            UserDefaults.standard.set(false, forKey: pendingKey)
            return 0
        }

        Outbox.enqueue(ops, in: context)
        do {
            try context.save()
        } catch {
            NSLog("backfill: could not enqueue %d ops: %@", ops.count, error.localizedDescription)
            return 0
        }

        UserDefaults.standard.set(false, forKey: pendingKey)
        NSLog("backfill: enqueued %d ops for %d cars", ops.count, cars.count)
        return ops.count
    }
}
