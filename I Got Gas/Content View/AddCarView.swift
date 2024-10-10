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
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    
    @State private var carMake = ""
    @State private var carModel = ""
    @State private var carPlate = ""
    @State private var carVIN = ""
    @State private var carOdometer = ""
        
    @State var carYear: String
    let yearRange: [String]
    
    var buttonDisabled: Bool {
        carMake.isEmpty ||
        carModel.isEmpty ||
        carPlate.isEmpty ||
        carVIN.isEmpty ||
        carOdometer.isEmpty
    }

    init() {
        let currentYear = Calendar.current.component(.year, from: Date())
        _carYear = .init(initialValue: currentYear.description)
        self.yearRange = (1990...currentYear+2).map { String($0) }.reversed()
    }
    
    var body: some View {
        VStack {
            NavigationView {
                VStack {
                    Form {
                        Section(
                            header: Text("Vehicle Info"),
                            footer: Text("\nTo increase accuracy of results, it's recommended to only add a new car when it has a full tank of gas.")
                        ) {
                            Picker("Year", selection: $carYear) {
                                ForEach(yearRange, id: \.self) { year in
                                    Text(year).tag(year)
                                }
                            }

                            TextField("Make", text: $carMake)

                            TextField("Model", text: $carModel)

                            TextField("Current Odometer", text: self.$carOdometer)
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
        }
    }
    
    func save() {
        let car = Car(context: moc)
        car.year = carYear
        car.make = carMake
        car.model = carModel
        car.plate = carPlate
        car.vin = carVIN
        car.odometer = Int64(carOdometer)!
        car.startingOdometer = Int64(carOdometer)!
        car.id = UUID().uuidString
        try? moc.save()
        presentationMode.wrappedValue.dismiss()
    }
}
