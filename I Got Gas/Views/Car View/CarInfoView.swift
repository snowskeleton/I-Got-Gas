//
//  CarInfoView.swift
//  I Got Gas
//
//  Created by snow on 10/16/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct CarInfoView: View {
    @Environment(\.presentationMode) var mode
    @Binding var car: SDCar
    
    @State private var showCopied = false
    @State private var alertTitle = "Copied!"
    @State private var alertMessage = ""
    
    @State private var csvFile: URL?
    
    @State private var importText = ""
    @State private var error: Error?
    @State private var isImporting = false
    
    var body: some View {
        NavigationStack {
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
                
                Section {
                    Button("Export") {
                        let data = generateCSV(for: car.services ?? [], scheduledServices: car.scheduledServices ?? [])
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        mode.wrappedValue.dismiss()
                    }
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
        let rows = content.split(separator: "\n").dropFirst() // Skip header row
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        

        for row in rows {
            let columns = row.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            guard columns.count > 2 else { continue }
            
            let type = columns[CSVColumn.type.rawValue]
            
            if type == "Service" {
                // Create and append SDService
                let service = SDService()
                service.id = columns[CSVColumn.id.rawValue]
                service.name = columns[CSVColumn.name.rawValue]
                service.cost = Double(columns[CSVColumn.cost.rawValue]) ?? 0.0
                
                guard let parsedDate = dateFormatter.date(from: columns[CSVColumn.date.rawValue]) else {
                    fatalError("Failed to parse date: \(columns[CSVColumn.date.rawValue])")
                }
                service.date = parsedDate
                
//                service.date = ISO8601DateFormatter().date(from: columns[CSVColumn.date.rawValue])!
                service.odometer = Int(columns[CSVColumn.odometer.rawValue]) ?? 0
                service.isFuel = Bool(columns[CSVColumn.isFuel.rawValue]) ?? false
                service.gallons = Double(columns[CSVColumn.gallons.rawValue]) ?? 0.0
                service.vendorName = columns[CSVColumn.vendorName.rawValue]
                service.fullDescription = columns[CSVColumn.fullDescription.rawValue]
                service.pending = Bool(columns[CSVColumn.pending.rawValue]) ?? false
                service.car = car
                car.services?.append(service)
            } else if type == "Scheduled Service" {
                // Create and append SDScheduledService
                let scheduledService = SDScheduledService()
                scheduledService.id = columns[CSVColumn.id.rawValue]
                scheduledService.name = columns[CSVColumn.name.rawValue]
                scheduledService.fullDescription = columns[CSVColumn.fullDescription.rawValue]
                scheduledService.repeating = Bool(columns[CSVColumn.repeating.rawValue]) ?? false
                scheduledService.frequencyMiles = Int(columns[CSVColumn.frequencyMiles.rawValue]) ?? 0
                scheduledService.frequencyTime = Int(columns[CSVColumn.frequencyTime.rawValue]) ?? 0
                scheduledService.frequencyTimeInterval = FrequencyTimeInterval(rawValue: columns[CSVColumn.frequencyTimeInterval.rawValue])
                scheduledService.car = car
                car.scheduledServices?.append(scheduledService)
            }
        }
    }

    
}
