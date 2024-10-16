//
//  DeveloperMenuView.swift
//  I Got Gas
//
//  Created by snow on 8/28/24.
//

import SwiftUI
import SwiftData

struct DeveloperMenuView: View {
    @Environment(\.modelContext) private var context
    @State private var showCrashConfirmation = false
    @AppStorage("showDebugValues") var showDebugValues = false
    @AppStorage("migratedFrom1.0To2.0") var migrated: Bool = false
    @AppStorage("priceFormat") var priceFormat = "%.3f"

    var body: some View {
        List {
            Section(
                header: Text("Decimal Length for fuel prices"),
                footer: Text("(e.g., \(3.456, specifier: priceFormat))")
            ) {
                Picker(selection: $priceFormat, label: Text("Fuel Price Decimal Length")) {
                    Text("2").tag("%.2f")
                    Text("3").tag("%.3f")
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section("Troubleshooting") {
                Toggle("2.0 Migration Complete", isOn: $migrated)
                Toggle("Show debug values in various locations throughout the app", isOn: $showDebugValues)
            }
            
            Section("Notifications") {
                NavigationLink(destination: NotificationPermissionsView()) { Text("Notification Permissions") }
                NavigationLink(destination: PendingNotificationsView()) { Text("Pending Notifications") }
            }
            
            Section("Actions") {
                Button("Crash!") { showCrashConfirmation = true }
                    .confirmationDialog(
                        "Crash car into a bridge",
                        isPresented: $showCrashConfirmation) {
                            Button(
                                "Watch and let it burn",
                                role: .destructive ) {
                                    fatalError()
                                }
                        }
                Button("Drop all tables", role: .destructive) { try? ModelContainer().deleteAllData() }
            }
            
        }
        .navigationTitle("Developer")
    }
    
}
