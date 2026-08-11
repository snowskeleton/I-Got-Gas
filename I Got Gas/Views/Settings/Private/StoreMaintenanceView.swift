//
//  StoreMaintenanceView.swift
//  I Got Gas
//
//  Developer-menu store surgery. Both actions replace the database on disk,
//  which can only happen while it is closed, so each one quits the app and
//  takes effect on the next launch.
//

import SwiftUI

struct StoreMaintenanceView: View {
    @State private var confirming: StoreMaintenance.Action?
    @State private var showRestartNotice = false

    var body: some View {
        List {
            Section {
                Button("Erase and start empty", role: .destructive) {
                    confirming = .reset
                }
            } footer: {
                Text("Deletes the database on disk. Use this to get back to a "
                     + "working app when the store can't be opened, without "
                     + "reinstalling.")
            }

            Section {
                Button("Seed a 2.x store") {
                    confirming = .seedV2
                }
            } footer: {
                Text("Replaces the database with one written in the 2.x shape, "
                     + "so the next launch runs the real V2→V3 migration. "
                     + "Unlike \"Generate test data\", which builds current-schema "
                     + "objects directly and never exercises the migration.")
            }
        }
        .navigationTitle("Reset / Seed Store")
        .confirmationDialog(
            confirming == .seedV2 ? "Replace the database with 2.x test data?"
                                  : "Erase the database?",
            isPresented: .init(
                get: { confirming != nil },
                set: { if !$0 { confirming = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Continue and Quit", role: .destructive) {
                guard let action = confirming else { return }
                StoreMaintenance.stage(action)
                confirming = nil
                showRestartNotice = true
            }
            Button("Cancel", role: .cancel) { confirming = nil }
        } message: {
            Text("Everything currently stored on this device will be replaced.")
        }
        .alert("Reopen the app", isPresented: $showRestartNotice) {
            Button("Quit Now") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { exit(0) }
            }
        } message: {
            Text("This takes effect on the next launch. I Got Gas will now "
                 + "close — open it again to finish.")
        }
    }
}
