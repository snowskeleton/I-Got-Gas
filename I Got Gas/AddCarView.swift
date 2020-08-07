//
//  AddCarView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct AddCarView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>

    @Binding var show: Bool
    @State private var buttonEnabled = false

    @State private var carName = ""
    
    @State var carYear = 0
    @State private var showsYearPicker = false

    @State private var carMake = ""
    @State private var carModel = ""
    @State private var carPlate = ""
    @State private var carVIN = ""
    @State private var carOdometer = ""
    
    var body: some View {
        VStack {
            NavigationView {
                VStack {
                    Form {
                        Section(header: Text("Vehicle Info")) {
                            CollapsableWheelPicker(
                                    "",
                                    showsPicker: $showsYearPicker,
                                    selection: $carYear
                                ) {
                                    ForEach((1885..<2020).reversed(), id: \.self) { year in
                                        Text("\(year.formattedWithoutSeparator)").tag(year)
                                    }
                                }
                            .animation(.easeInOut)
                            if !self.showsYearPicker {
                                Text(carYear == 0 ? "Year: " : "\(carYear.formattedWithoutSeparator)")
                                    .onTapGesture {
                                        self.showsYearPicker.toggle()
                                    }
                            }
                            TextField("* Make",
                                      text: self.$carMake,
                                      onCommit: { self.maybeEnableButton() })
                            TextField("* Model",
                                      text: self.$carModel,
                                      onCommit: { self.maybeEnableButton() })
                            TextField("* Current Odometer",
                                      text: self.$carOdometer,
                                      onCommit: { self.maybeEnableButton() })
                                .keyboardType(.numberPad)
                            TextField("* License Plate",
                                      text: self.$carPlate,
                                      onCommit: { self.maybeEnableButton() })
                            TextField("* VIN",
                                      text: self.$carVIN,
                                      onCommit: { self.maybeEnableButton() })
                        }
                    }
                }
            .navigationBarTitle("You get a car!")
            }
            
            Spacer()
            
            Button(action: {
                self.save()
            }) {
                Text("Add Vehicle")
            }
        .disabled(!buttonEnabled)
        }
    }

    func maybeEnableButton() {
        if self.carYear == 0 {
            return
        }
        if self.carMake == "" {
            return
        }
        if self.carModel == "" {
            return
        }
        if self.carPlate == "" {
            return
        }
        if self.carVIN == "" {
            return
        }
        if self.carOdometer == "" {
            return
        }
        self.buttonEnabled = true
    }
    
    func save() {
        let car = Car(context: self.managedObjectContext)
        car.name = self.carName
        car.year = String(self.carYear)
        car.make = self.carMake
        car.model = self.carModel
        car.plate = self.carPlate
        car.vin = self.carVIN
        car.odometer = Int64(self.carOdometer) ?? 0
        car.id = UUID().uuidString
        try? self.managedObjectContext.save()
        
        self.show = false
    }
}

struct AddCarView_Previews: PreviewProvider {
    static var previews: some View {
        AddCarView(show: Binding.constant(true))

    }
}
