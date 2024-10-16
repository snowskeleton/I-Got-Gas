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
    }
}
