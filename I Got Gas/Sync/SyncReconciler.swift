//
//  SyncReconciler.swift
//  I Got Gas
//
//  "Do you actually have my data?"
//
//  Cursors answer "what changed since seq N" exactly, and that is the whole
//  sync in the normal case. What they cannot answer is whether a record ever
//  arrived at all: a record with no ops has no seq, so being up to date on
//  every cursor is perfectly consistent with the server having never heard of
//  a car. That is not hypothetical — it is what happens to anything created
//  while signed out, restored from a device backup, or migrated to 3.0 by a
//  build that predated the op log.
//
//  So the server now reports what it holds, and this compares:
//
//    * cars — by id, sent outright. A handful of UUIDs, and knowing *which*
//      car is missing is what makes the repair possible.
//    * within a car — by digest, because sending every service id every sync
//      is not free and a 32-byte fingerprint answers the same question.
//
//  Repair is always the same move: re-enqueue that car's ops. They carry each
//  record's own `updatedAt`, so re-pushing something the server already has is
//  a no-op that loses its (ts, deviceID) comparison — safe by construction.
//

import Foundation
import SwiftData

@MainActor
enum SyncReconciler {

    /// The local side of the digest: which records this car actually holds.
    /// Deleted rows are excluded to match the server — see `SyncDigest`.
    static func digest(for car: SDCar) -> String {
        var lines: [String] = []
        for service in car.services ?? [] where !service.deleted {
            lines.append("service:\(service.id)")
        }
        for schedule in car.scheduledServices ?? [] where !schedule.deleted {
            lines.append("scheduled_service:\(schedule.id)")
        }
        return SyncDigest.digest(ofLines: lines)
    }

    /// Cars already repaired this launch. A digest can disagree for reasons a
    /// push won't fix (a car whose services the server is still sending us in
    /// a later batch, say), and without this that becomes a full re-push on
    /// every sync, forever. One attempt per car per session is enough to heal
    /// the real cases and cheap enough to be wrong about.
    private static var attempted: Set<String> = []

    static func resetSession() {
        attempted = []
    }

    /// Compares what the server says it holds against the local store and
    /// enqueues repairs. Returns the ids of cars it pushed, for logging.
    ///
    /// Only safe to call from the settled state — see `shouldRun`.
    @discardableResult
    static func reconcile(
        knownCarIDs: [String]?,
        digests: [String: String]?,
        context: ModelContext
    ) -> [String] {
        guard let knownCarIDs else { return [] }
        let known = Set(knownCarIDs)

        let cars = (try? context.fetch(FetchDescriptor<SDCar>())) ?? []
        var repaired: [String] = []
        var ops: [Op] = []

        for car in cars where !car.deleted {
            guard !attempted.contains(car.id) else { continue }

            let reason: String
            if !known.contains(car.id) {
                reason = "server has never seen it"
            } else if let expected = digests?[car.id],
                      expected != digest(for: car) {
                reason = "membership digest differs"
            } else {
                continue
            }

            attempted.insert(car.id)
            repaired.append(car.id)
            ops += OutboxBackfill.ops(forCar: car)
            NSLog("reconcile: re-pushing car %@ — %@", car.id, reason)
        }

        guard !ops.isEmpty else { return [] }

        Outbox.enqueue(ops, in: context)
        do {
            try context.save()
        } catch {
            NSLog("reconcile: could not enqueue %d ops: %@",
                  ops.count, error.localizedDescription)
            return []
        }
        return repaired
    }

    /// Whether the comparison is meaningful yet.
    ///
    /// Both sides have to be quiet for a difference to mean anything. A
    /// non-empty outbox means we hold writes the server hasn't seen, and a
    /// non-empty pull means it holds writes we haven't applied — in either
    /// case the two *should* differ, and reconciling would push a car's whole
    /// history to fix something that was about to fix itself. Waiting also
    /// handles a truncated batch: the check simply runs once it has drained.
    static func shouldRun(pendingOps: Int, receivedOps: Int) -> Bool {
        pendingOps == 0 && receivedOps == 0
    }
}
