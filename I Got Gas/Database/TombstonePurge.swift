//
//  TombstonePurge.swift
//  I Got Gas
//
//  Local half of the retention policy.
//
//  Tombstones used to accumulate forever on both sides — the app never removed
//  anything, so a store only ever grew. They now expire on the same 30-day
//  window the server uses.
//
//  The one safety rule: nothing is purged while the outbox still holds ops for
//  it. Deleting the row out from under an unsent op would strand that deletion
//  and leave the record alive everywhere else.
//

import Foundation
import SwiftData

@MainActor
enum TombstonePurge {

    static func run(context: ModelContext) {
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -TombstoneRetention.days, to: Date()
        ) ?? Date.distantPast

        // Entity ids that still have unsent ops.
        let pendingIDs = Set(Outbox.pending(in: context).map(\.entityID))

        var removed = 0

        // Children first, so a parent's cascade never surprises us.
        removed += purge(
            FetchDescriptor<SDPart>(
                predicate: #Predicate { $0.deleted == true && $0.updatedAt < cutoff }
            ),
            context: context, skipping: pendingIDs, id: \.id
        )

        // Attachments take their cached bytes with them.
        let staleAttachments = (try? context.fetch(
            FetchDescriptor<SDAttachment>(
                predicate: #Predicate { $0.deleted == true && $0.updatedAt < cutoff }
            )
        )) ?? []
        for attachment in staleAttachments where !pendingIDs.contains(attachment.id) {
            if let filename = attachment.localFilename {
                AttachmentStore.remove(filename)
            }
            context.delete(attachment)
            removed += 1
        }

        removed += purge(
            FetchDescriptor<SDService>(
                predicate: #Predicate { $0.deleted == true && $0.updatedAt < cutoff }
            ),
            context: context, skipping: pendingIDs, id: \.id
        )
        removed += purge(
            FetchDescriptor<SDScheduledService>(
                predicate: #Predicate { $0.deleted == true && $0.updatedAt < cutoff }
            ),
            context: context, skipping: pendingIDs, id: \.id
        )
        removed += purge(
            FetchDescriptor<SDCatalogPart>(
                predicate: #Predicate { $0.deleted == true && $0.updatedAt < cutoff }
            ),
            context: context, skipping: pendingIDs, id: \.id
        )
        removed += purge(
            FetchDescriptor<SDCar>(
                predicate: #Predicate { $0.deleted == true && $0.updatedAt < cutoff }
            ),
            context: context, skipping: pendingIDs, id: \.id
        )

        if removed > 0 {
            try? context.save()
            NSLog("purge: removed %d expired tombstone(s)", removed)
        }

        AttachmentStore.trimCache()
    }

    private static func purge<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        skipping pendingIDs: Set<String>,
        id: KeyPath<T, String>
    ) -> Int {
        let doomed = (try? context.fetch(descriptor)) ?? []
        var count = 0
        for model in doomed where !pendingIDs.contains(model[keyPath: id]) {
            context.delete(model)
            count += 1
        }
        return count
    }
}
