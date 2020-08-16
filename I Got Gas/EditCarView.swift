//
//  EditCarView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/15/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import CoreData

struct EditCarView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var moc
    @State var car: Car

    @State private var showsYearPicker = false
    @State private var carYear: Int64 = 0
    @State private var carMake: String = ""
    @State private var carModel: String = ""
    @State private var carPlate: String = ""
    @State private var carVIN: String = ""
//    @State private var carOdometer: String = ""


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
                                Text(carYear == 0 ? "\(car.year!)" : "\(carYear.formattedWithoutSeparator)")
                                    .onTapGesture {
                                        self.showsYearPicker.toggle()
                                }
                            }
                    TextField("\(car.make!)",
                              text: $carMake)
                            TextField("\(car.model!)",
                                      text: $carModel)
//                            TextField("\(car.odometer)",
//                                      text: $carOdometer)
//                                .keyboardType(.numberPad)
                            TextField("\(car.plate!)",
                                      text: $carPlate)
                            TextField("\(car.vin!)",
                                      text: $carVIN)
                        }
                    }
                }
                .navigationBarTitle("Repaint the Car!")
            }

            Spacer()

            Button(action: {
                self.save()
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Finalize Rebuild")
            }
        }
    }

    func save() {
        if carYear != 0 {
            car.year = String(self.carYear)
        }
        if carMake != "" {
            car.make = self.carMake
        }
        if carModel != "" {
            car.model = self.carModel
        }
        if carPlate != "" {
            car.plate = self.carPlate
        }
        if carVIN != "" {
            car.vin = self.carVIN
        }
//        if carOdometer != "" {
//            car.odometer = Int64(self.carOdometer)!
//        }
        try? self.moc.save()
    }
}
