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
    @State private var isPackagingScans = false
    @State private var scanPackage: ScanPackage?

    /// A zip waiting for the share sheet. Wrapped because `URL` can't identify
    /// a sheet on its own.
    private struct ScanPackage: Identifiable {
        let id = UUID()
        let url: URL
    }


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
            
            Section("Data") {
                NavigationLink(destination: StoreBackupsView()) { Text("Store Backups") }
                NavigationLink(destination: StoreMaintenanceView()) { Text("Reset / Seed Store") }
            }

            Section {
                #if DEBUG
                NavigationLink(destination: PumpScanSimulatorView()) {
                    Text("Pump Scan Simulator")
                }
                #endif

                LabeledContent("Recorded scans", value: PumpScanDebugRecorder.summary)

                Button {
                    isPackagingScans = true
                    Task {
                        let packaged = await Task.detached(priority: .userInitiated) {
                            PumpScanDebug.packagedScans()
                        }.value
                        isPackagingScans = false
                        if let packaged { scanPackage = ScanPackage(url: packaged) }
                    }
                } label: {
                    HStack {
                        if isPackagingScans {
                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                        }
                        Text(isPackagingScans ? "Packaging…" : "Share Recorded Scans")
                    }
                }
                .disabled(isPackagingScans)

                Button("Delete Recorded Scans", role: .destructive) {
                    PumpScanDebugRecorder.deleteAll()
                }
            } header: {
                Text("Scanning")
            } footer: {
                Text(
                    "Every pump scan saves the photo it read, plus what Vision made of it "
                    + "on this device, keeping the 12 most recent. Share them to get a real "
                    + "capture off the phone — the exported photos a camera roll gives you "
                    + "have already been resized, which is exactly the detail these displays "
                    + "turn on."
                    + (Config.appConfiguration == .Debug
                       ? " Debug builds also expose them in Files, under On My iPhone."
                       : "")
                )
            }
            .sheet(item: $scanPackage) { PumpScanShareSheet(url: $0.url) }

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
