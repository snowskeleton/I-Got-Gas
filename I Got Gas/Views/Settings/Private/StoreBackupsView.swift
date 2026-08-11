//
//  StoreBackupsView.swift
//  I Got Gas
//
//  Developer-menu access to the pre-migration store copies.
//
//  This lives behind the developer menu on purpose. Restoring replaces the
//  whole database, so it is a support-assisted operation rather than something
//  a user should stumble into from Settings.
//

import SwiftUI

struct StoreBackupsView: View {
    @State private var entries: [StoreBackup.Entry] = []
    @State private var pendingRestore: StoreBackup.Entry?
    @State private var showRestartNotice = false

    var body: some View {
        List {
            if entries.isEmpty {
                Section {
                    Text("No backups yet.")
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("A copy is taken automatically before a major schema migration.")
                }
            }

            ForEach(entries) { entry in
                Section {
                    LabeledContent("Taken", value: entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Size", value: ByteCountFormatter.string(
                        fromByteCount: Int64(entry.byteSize), countStyle: .file
                    ))
                    Button("Restore this backup") { pendingRestore = entry }
                    Button("Delete", role: .destructive) {
                        StoreBackup.delete(entry)
                        reload()
                    }
                } header: {
                    Text(entry.name)
                }
            }
        }
        .navigationTitle("Store Backups")
        .onAppear(perform: reload)
        .confirmationDialog(
            "Replace the current database with this backup?",
            isPresented: .init(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Restore and Quit", role: .destructive) {
                guard let entry = pendingRestore else { return }
                StoreBackup.stageRestore(entry)
                pendingRestore = nil
                showRestartNotice = true
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            Text("Everything currently in the app will be replaced. This cannot be undone from here.")
        }
        .alert("Reopen the app", isPresented: $showRestartNotice) {
            Button("Quit Now") { quit() }
        } message: {
            Text("The backup will be restored the next time the app launches. "
                 + "I Got Gas will now close — open it again to finish.")
        }
    }

    private func reload() {
        entries = StoreBackup.available()
    }

    /// The store can't be swapped while it's open, so the restore is applied
    /// during the next launch. Closing here is what makes that happen
    /// promptly, instead of whenever iOS happens to reap the process.
    private func quit() {
        // Give the alert a beat to dismiss so the exit doesn't read as a crash.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            exit(0)
        }
    }
}
