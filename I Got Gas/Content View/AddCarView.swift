//
//  AddCarView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import UIKit

struct AddCarView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    
    @State private var buttonEnabled = false
    
    @State private var carYear: String = ""
    
    @State private var carMake = ""
    @State private var carModel = ""
    @State private var carPlate = ""
    @State private var carVIN = ""
    @State private var carOdometer = ""
        
    var years = yearsPlusTwo()
    @State var selectionIndex = 0
    
    var body: some View {
        VStack {
            NavigationView {
                VStack {
                    Form {
                        Section(header: Text("Vehicle Info"), footer: Text("\nTo increase accuracy of results, it's recommended to only add a new car when it has a full tank of gas.")) {
                            
                            TextFieldWithPickerAsInputView(data: self.years,
                                                           placeholder: "* Year",
                                                           selectionIndex: self.$selectionIndex,
                                                           text: self.$carYear)
                                .onChange(of: self.carYear) { _ in
                                    self.maybeEnableButton()
                                }
                            
                            TextField("* Make",
                                      text: self.$carMake,
                                      onCommit: {
                                        self.maybeEnableButton()
                                    })
                                .onChange(of: self.carMake) { _ in
                                    self.maybeEnableButton()
                                }

                            TextField("* Model",
                                      text: self.$carModel,
                                      onCommit: {
                                        self.maybeEnableButton()
                                    })
                                .onChange(of: self.carModel) { _ in
                                    self.maybeEnableButton()
                                }

                            TextField("* Current Odometer",
                                      text: self.$carOdometer,
                                      onCommit: {
                                        self.maybeEnableButton()
                                    })
                                .keyboardType(.numberPad)
                                .onChange(of: self.carOdometer) { _ in
                                    self.maybeEnableButton()
                                }

                            TextField("License Plate",
                                      text: self.$carPlate,
                                      onCommit: {
                                        self.maybeEnableButton()
                                    })
                                .disableAutocorrection(true)
                                .onChange(of: self.carPlate) { _ in
                                    self.maybeEnableButton()
                                }

                            TextField("VIN",
                                      text: self.$carVIN,
                                      onCommit: {
                                        self.maybeEnableButton()
                                    })
                                .disableAutocorrection(true)
                                .onChange(of: self.carVIN) { _ in
                                    self.maybeEnableButton()
                                }
                        }
                        
                        Section {
                            Button(action: {
                                self.save()
                                self.presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("Add Vehicle")
                            }
                            .disabled(!buttonEnabled)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .navigationBarTitle("Add Car")
            }
        }
    }
    
    func maybeEnableButton() {
        if self.carYear == "" {
            self.buttonEnabled = false
            return
        }
        if self.carMake == "" {
            self.buttonEnabled = false
            return
        }
        if self.carModel == "" {
            self.buttonEnabled = false
            return
        }
        if self.carOdometer == "" {
            self.buttonEnabled = false
            return
        }
        self.buttonEnabled = true
    }
    
    func save() {
        let car = Car(context: self.moc)
        car.year = self.carYear
        car.make = self.carMake
        car.model = self.carModel
        car.plate = self.carPlate
        car.vin = self.carVIN
        car.odometer = Int64(self.carOdometer)!
        car.startingOdometer = Int64(self.carOdometer)!
        car.id = UUID().uuidString
        try? self.moc.save()        
    }
}
