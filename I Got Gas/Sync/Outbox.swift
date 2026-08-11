//
//  Outbox.swift
//  I Got Gas
//
//  Local ops waiting to be acknowledged by the server.
//
//  The old sync selected what to push by comparing each record's `updatedAt`
//  against a cursor that was then overwritten with the *server's* clock. Any
//  edit made while a request was in flight ended up behind the new cursor and
//  was never pushed again — a silent, permanent loss.
//
//  An explicit outbox removes the question entirely: an op leaves only when
//  the server confirms its id.
//

import Foundation
import SwiftData

@Model
final class SDPendingOp {
    /// The op's id, which is also the server's idempotency key.
    @Attribute(.unique) var opID: String = UUID().uuidString

    var carID: String = ""
    var entityRaw: String = ""
    var entityID: String = ""
    var field: String = ""
    /// The op's JSON, stored whole so this model never has to know field types.
    var payload: Data = Data()
    var ts: Date = Date()
    var deviceID: String = ""

    /// Attempts so far, for backoff and for giving up on poison ops.
    var attempts: Int = 0
    var lastError: String?
    var createdAt: Date = Date()

    init() { }

    init(op: Op) {
        self.opID = op.opID
        self.carID = op.carID
        self.entityRaw = op.entity.rawValue
        self.entityID = op.entityID
        self.field = op.field
        self.ts = op.ts
        self.deviceID = op.deviceID
        self.payload = (try? JSONEncoder().encode(op)) ?? Data()
    }

    var op: Op? {
        try? JSONDecoder().decode(Op.self, from: payload)
    }
}

@MainActor
enum Outbox {

    /// Records ops locally. They are pushed on the next sync and removed only
    /// once the server has acknowledged them.
    static func enqueue(_ ops: [Op], in context: ModelContext) {
        for op in ops {
            context.insert(SDPendingOp(op: op))
        }
    }

    static func enqueue(_ op: Op, in context: ModelContext) {
        enqueue([op], in: context)
    }

    /// Oldest first, so a create is pushed before the edits that follow it.
    static func pending(in context: ModelContext, limit: Int = 2000) -> [SDPendingOp] {
        var descriptor = FetchDescriptor<SDPendingOp>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    static func count(in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<SDPendingOp>())) ?? 0
    }

    /// Drops acknowledged ops. Anything the server didn't mention stays put
    /// and is retried — which is the whole point.
    static func acknowledge(_ opIDs: [String], in context: ModelContext) {
        guard !opIDs.isEmpty else { return }
        let ids = Set(opIDs)
        for pending in pending(in: context) where ids.contains(pending.opID) {
            context.delete(pending)
        }
    }

    /// Handles rejections. Permanent ones are dropped — retrying a forbidden
    /// or malformed op forever would wedge the queue behind it. Transient ones
    /// are counted and retried.
    static func reject(_ rejections: [OpRejection], in context: ModelContext) {
        guard !rejections.isEmpty else { return }
        let byID = Dictionary(rejections.map { ($0.opID, $0) }, uniquingKeysWith: { first, _ in first })

        for pending in pending(in: context) {
            guard let rejection = byID[pending.opID] else { continue }
            if rejection.isPermanent {
                NSLog("sync: dropping op %@ (%@): %@",
                      pending.opID, rejection.reason, rejection.detail ?? "")
                context.delete(pending)
            } else if rejection.isWaitingOnUpgrade {
                // Held, not failed: no attempt counted, so it survives until
                // the blocking side updates and the push finally lands. The
                // banner has already told the user their changes are pending.
                pending.lastError = rejection.reason
            } else {
                pending.attempts += 1
                pending.lastError = rejection.reason
                // A transient failure that never clears is still a stuck queue.
                if pending.attempts >= 10 {
                    NSLog("sync: giving up on op %@ after %d attempts",
                          pending.opID, pending.attempts)
                    context.delete(pending)
                }
            }
        }
    }

    /// Clears everything. Used on sign-out, alongside the cursor reset.
    static func clear(in context: ModelContext) {
        try? context.delete(model: SDPendingOp.self)
    }
}
