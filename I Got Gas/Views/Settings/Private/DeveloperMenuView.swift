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
    @AppStorage("verboseLogging") var verboseLogging = false
    @AppStorage("itemCountOnCarView") var itemCountOnCarView: Int = 3
    @State private var isGeneratingData = false


    var body: some View {
        List {
            Section {
                TextField("Service Count", value: $itemCountOnCarView, formatter: NumberFormatter())
            } footer: {
                Text("Requires app restart")
            }

            Section("Troubleshooting") {
                Toggle("Show debug values in various locations throughout the app", isOn: $showDebugValues)
                Toggle("Verbose logging", isOn: $verboseLogging)
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
            
            Button(action: {
                Task {
                    isGeneratingData = true
                    await generateTestData()
                    isGeneratingData = false
                }
            }) {
                HStack {
                    if isGeneratingData {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    Text(isGeneratingData ? "Generating Data..." : "Generate Fake Vehicle Data")
                }
            }
        }
        .navigationTitle("Developer")
    }
    
    private func generateTestData() async {
        // Step 1: Generate the Fake Data
        let fakeCar = generateFakeCarData()
        
        // Step 2: Insert the Car with Fake Data into the SwiftData ModelContext
        context.insert(fakeCar)
        
        do {
            try context.save()
            print("Successfully added fake vehicle data!")
        } catch {
            print("Error saving fake vehicle data: \(error)")
        }
    }
}
