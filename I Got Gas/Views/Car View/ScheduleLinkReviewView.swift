//
//  ScheduleLinkReviewView.swift
//  I Got Gas
//
//  Shown once after the 3.0 upgrade. The migration guesses which past
//  maintenance entries fulfilled which schedules by matching names, and this
//  is where the user confirms or undoes those guesses in bulk.
//
//  Guessing silently across a long history would be hard to undo by hand,
//  which is the whole reason this screen exists.
//

import SwiftUI
import SwiftData

struct ScheduleLinkReviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncManager.self) private var syncManager

    @AppStorage(ScheduleLinkReview.reviewedKey) private var reviewed = false

    @State private var entries: [SDService] = []
    @State private var rejected: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("We matched these past entries to your schedules by name, so your service history carries over. Uncheck anything that looks wrong.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(entries) { entry in
                    Button {
                        toggle(entry)
                    } label: {
                        HStack {
                            Image(systemName: rejected.contains(entry.id)
                                  ? "circle"
                                  : "checkmark.circle.fill")
                            .foregroundStyle(rejected.contains(entry.id)
                                             ? AnyShapeStyle(.secondary)
                                             : AnyShapeStyle(Color.accentColor))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayName)
                                    .foregroundStyle(.primary)
                                HStack(spacing: 4) {
                                    Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
                                    if let schedule = entry.scheduledService {
                                        Text("→ \(schedule.name)")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Review Matches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Unlink All") {
                        rejected = Set(entries.map(\.id))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { commit() }
                }
            }
            .onAppear {
                entries = (try? ScheduleLinkMatcher.autoLinkedEntries(in: context)) ?? []
                if entries.isEmpty { finish() }
            }
        }
    }

    private func toggle(_ entry: SDService) {
        if rejected.contains(entry.id) {
            rejected.remove(entry.id)
        } else {
            rejected.insert(entry.id)
        }
    }

    private func commit() {
        for entry in entries where rejected.contains(entry.id) {
            entry.scheduledService?.touch()
            entry.scheduledService = nil
            entry.touch()
        }
        // Anything kept was confirmed by a person, so it's no longer a guess.
        for entry in entries where !rejected.contains(entry.id) {
            entry.linkedManually = true
            entry.touch()
        }
        try? context.save()
        for entry in entries {
            syncManager.recordService(entry)
        }
        Task { await NotificationReconciler.reconcile(context: context) }
        finish()
    }

    private func finish() {
        reviewed = true
        dismiss()
    }
}

enum ScheduleLinkReview {
    static let reviewedKey = "scheduleLinkReviewCompleted"

    /// True when the migration guessed at least one link and the user hasn't
    /// looked at them yet.
    @MainActor
    static func isPending(context: ModelContext) -> Bool {
        guard !UserDefaults.standard.bool(forKey: reviewedKey) else { return false }
        let entries = (try? ScheduleLinkMatcher.autoLinkedEntries(in: context)) ?? []
        return !entries.isEmpty
    }
}
