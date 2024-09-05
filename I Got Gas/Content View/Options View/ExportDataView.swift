//
//  ExportDataView.swift
//  I Got Gas
//
//  Created by snow on 9/5/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import CoreData
import UIKit

struct ExportDataView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var csvURL: URL?
    @State private var showShareSheet = false
    
    var body: some View {
        VStack {
            Text("Export Data")
                .font(.largeTitle)
                .padding()
            
            Button(action: exportData) {
                Text("Export to CSV")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = csvURL {
                DocumentInteractionController(url: url)
            }
        }
    }
    
    // Step 2: Export Data Function
    private func exportData() {
        // Define the entities you want to export
        let entities = ["Car", "Fuel", "FutureService", "Service", "Vendor"]
        
        var csvString = ""
        
        // Iterate over each entity
        for entityName in entities {
            // Fetch all objects for the entity
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            do {
                let objects = try viewContext.fetch(fetchRequest)
                if let firstObject = objects.first {
                    let keys = Array(firstObject.entity.attributesByName.keys)
                    csvString.append(contentsOf: keys.joined(separator: ","))
                    csvString.append("\n")
                    
                    for object in objects {
                        var values: [String] = []
                        for key in keys {
                            if let value = object.value(forKey: key) {
                                values.append("\(value)")
                            } else {
                                values.append("")
                            }
                        }
                        csvString.append(contentsOf: values.joined(separator: ","))
                        csvString.append("\n")
                    }
                }
            } catch {
                print("Failed to fetch \(entityName): \(error)")
            }
            csvString.append("\n\n")
        }
        
        // Step 3: Write to a CSV file
        writeCSV(csvString: csvString)
    }
    
    // Function to write CSV string to a file
    private func writeCSV(csvString: String) {
        let fileName = "CoreDataExport.csv"
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: path, atomically: true, encoding: .utf8)
            print("CSV file saved at \(path)")
            csvURL = path
            showShareSheet = true
        } catch {
            print("Failed to save CSV: \(error)")
        }
    }
}

// Document Interaction Controller to handle sharing
struct DocumentInteractionController: UIViewControllerRepresentable {
    var url: URL
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let interactionController = UIDocumentInteractionController(url: url)
        interactionController.presentOptionsMenu(from: uiViewController.view.frame, in: uiViewController.view, animated: true)
    }
}
