//
//  CarInfoView.swift
//  I Got Gas
//
//  Created by snow on 10/16/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct CarInfoView: View {
    @Environment(\.modelContext) private var context
    @Environment(AuthManager.self) private var authManager
    @Binding var car: SDCar
    
    @State private var showCopied = false
    @State private var alertTitle = "Copied!"
    @State private var alertMessage = ""
    
    @State private var csvFile: URL?
    
    @State private var importText = ""
    @State private var error: Error?
    @State private var isImporting = false
    @State private var importWarning: String?
    
    var body: some View {
        List {
            if !car.name.isEmpty {
                Section {
                    Text(car.name)
                } header: {
                    Button {
                        UIPasteboard.general.string = car.name
                        alertMessage = "Copied: \(car.name)"
                        showCopied = true
                    } label: {
                        HStack {
                            Text("Name")
                            Spacer()
                            Image(systemName: "clipboard")
                        }
                    }
                }
            }
            Section {
                if car.year != nil {
                    Text(car.year!.description)
                } else {
                    Text("Year")
                        .italic()
                }
                if !car.make.isEmpty {
                    Text(car.make)
                } else {
                    Text("Make")
                        .italic()
                }
                if !car.model.isEmpty {
                    Text(car.model)
                } else {
                    Text("model")
                        .italic()
                }
            } header: {
                Button {
                    UIPasteboard.general.string = car.joinedModel
                    alertMessage = "Copied: \(car.joinedModel)"
                    showCopied = true
                } label: {
                    HStack {
                        Text("Model")
                        Spacer()
                        Image(systemName: "clipboard")
                    }
                }
            }
            Section {
                if !car.plate.isEmpty {
                    Text(car.plate)
                } else {
                    Text("Plate")
                        .italic()
                }
            } header: {
                Button {
                    UIPasteboard.general.string = car.plate
                    alertMessage = "Copied: \(car.plate)"
                    showCopied = true
                } label: {
                    HStack {
                        Text("License Plate")
                        Spacer()
                        Image(systemName: "clipboard")
                    }
                }
            }
            
            Section {
                if !car.vin.isEmpty {
                    Text(car.vin)
                } else {
                    Text("VIN")
                        .italic()
                }
            } header: {
                Button {
                    UIPasteboard.general.string = car.vin
                    alertMessage = "Copied: \(car.vin)"
                    showCopied = true
                } label: {
                    HStack {
                        Text("VIN")
                        Spacer()
                        Image(systemName: "clipboard")
                    }
                }
            }
            
            Section("Notifications") {
                Toggle("Notify on updates", isOn: notifyOnChangeBinding)
            }

            // Sharing section — only for owned cars
            if car.ownerID.isEmpty || car.ownerID == authManager.userID {
                Section("Sharing") {
                    NavigationLink {
                        ShareVehicleView(carID: car.id, carName: car.visualName)
                    } label: {
                        HStack {
                            Image(systemName: "person.2")
                            Text("Share this Vehicle")
                        }
                    }
                }
            }

            Section {
                Button("Export") {
                    let data = generateCSV(for: car.services ?? [], scheduledServices: car.scheduledServices ?? [], car: car)
                    csvFile = saveCSVFile(content: data)
                }
                if let fileURL = csvFile {
                    ShareLink(item: fileURL) {
                        Text("Share CSV File")
                    }
                }
                Button("Import") {
                    isImporting = true
                }
                
                Button(action: {
                    isImporting = true
                }) {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
                }
                .padding()
                
                if let importWarning {
                    Text(importWarning)
                        .foregroundStyle(.orange)
                }
                if let error {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .alert(isPresented: $showCopied) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage)
            )
        }
        .navigationTitle("Info")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    EditCarView(car: Binding<SDCar>.constant(car))
                } label: {
                    Text("Edit")
                }
            }
        }
        .onAppear {
            Analytics.track(
                .openedCarInfo
            )
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText]) { result in
            handleImportResult(result)
        }

    }
    
    
    private var notifyOnChangeBinding: Binding<Bool> {
        Binding(
            get: { car.settings?.notifyOnChange ?? true },
            set: { newValue in
                if car.settings == nil {
                    car.settings = SDCarSettings()
                }
                car.settings?.notifyOnChange = newValue
            }
        )
    }

    /// Handle the import result from file picker
    private func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            processCSVFile(from: url)
        case .failure(let importError):
            error = importError
        }
    }
    
    /// Process the CSV file from the selected URL
    private func processCSVFile(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            importCSVData(from: csvContent)
        } catch {
            self.error = error
        }
    }
    
    /// Parse and import CSV content into the car's data
    private func importCSVData(from content: String) {
        let result = CSVImporter.parse(content, distanceUnit: car.distanceUnit)

        for service in result.services {
            service.car = car
            car.services?.append(service)
        }
        for scheduled in result.scheduledServices {
            scheduled.car = car
            // Anchor a freshly imported schedule where the car is now, so it
            // doesn't read as wildly overdue before any history is linked.
            scheduled.anchorDate = Date()
            scheduled.anchorOdometer = car.odometer
            car.scheduledServices?.append(scheduled)
        }

        // Backfill schedule links from the imported names.
        try? ScheduleLinkMatcher.linkExistingHistory(in: context)

        if !result.skippedRows.isEmpty {
            importWarning = "\(result.skippedRows.count) row(s) could not be read and were skipped."
        }
    }

    
}
