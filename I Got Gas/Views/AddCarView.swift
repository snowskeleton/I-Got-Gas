//
//  AddCarView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct AddCarView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) var context
    
    @State private var carMake = ""
    @State private var carModel = ""
    @State private var carPlate = ""
    @State private var carVIN = ""
    @State private var carOdometer: Int?
    @State private var carYear: Int?
    
    var buttonDisabled: Bool {
        carMake.isEmpty ||
        carModel.isEmpty ||
        carPlate.isEmpty ||
        carVIN.isEmpty ||
        carYear == nil ||
        carOdometer == nil
    }

    var body: some View {
        VStack {
            Form {
                Section(
                    header: Text("Vehicle Info"),
                    footer: Text("\nTo increase accuracy of results, it's recommended to only add a new car when it has a full tank of gas.")
                ) {
                    TextField("Year", value: $carYear, formatter: NumberFormatter())
                    
                    TextField("Make", text: $carMake)
                    
                    TextField("Model", text: $carModel)
                    
                    TextField("Current Odometer", value: self.$carOdometer, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                    
                    TextField("License Plate (Optional)", text: self.$carPlate)
                        .disableAutocorrection(true)
                    
                    TextField("VIN (Optional)", text: self.$carVIN)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button("Add Vehicle") {
                        save()
                    }
                    .disabled(buttonDisabled)
                }
            }
        }
        .navigationBarTitle("Add Car")
    }
    
    func save() {
        let car = SDCar()
        
        car.year = carYear
        car.make = carMake
        car.model = carModel
        car.plate = carPlate
        car.vin = carVIN
        car.startingOdometer = carOdometer!
        
        context.insert(car)
        
        presentationMode.wrappedValue.dismiss()
    }
}
