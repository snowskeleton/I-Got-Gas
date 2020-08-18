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
    @State private var carYear: String? = ""
    @State private var carMake: String = ""
    @State private var carModel: String = ""
    @State private var carPlate: String = ""
    @State private var carVIN: String = ""
    //    @State private var carOdometer: String = ""
    
    private var years: [String] {
        var list: [Int] = []
        for i in 1885...2022 {
            list.insert(i, at: 0)
        }
        let returnlist = list.map { String($0) }
        return returnlist
    }
    @State var selectionIndex = 0
    
    
    
    var body: some View {
        VStack {
            NavigationView {
                VStack {
                    Form {
                        Section(header: Text("Vehicle Info")) {
                            TextFieldWithPickerAsInputView(data: self.years,
                                                           placeholder: "* Year",
                                                           selectionIndex: self.$selectionIndex,
                                                           text: self.$carYear)
                            TextField("\(car.make!)",
                                      text: $carMake)
                                .dismissKeyboardOnSwipe()
                                .dismissKeyboardOnTap()

                            TextField("\(car.model!)",
                                      text: $carModel)
                                .dismissKeyboardOnSwipe()
                                .dismissKeyboardOnTap()

                            //                            TextField("\(car.odometer)",
                            //                                      text: $carOdometer)
                            //                                .keyboardType(.numberPad)
                            TextField("\(car.plate!)",
                                      text: $carPlate)
                                .dismissKeyboardOnSwipe()
                                .dismissKeyboardOnTap()

                            TextField("\(car.vin!)",
                                      text: $carVIN)
                                .dismissKeyboardOnSwipe()
                                .dismissKeyboardOnTap()

                        }
                    }
                    Button("Delete Car") {
                        self.moc.delete(car)
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
        if self.carYear != "" {
            car.year = self.carYear!
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
