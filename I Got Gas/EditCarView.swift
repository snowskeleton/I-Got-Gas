//
//  EditCarView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/15/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct EditCarView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var moc
    
    @State private var showFirstConfirmDeleteRequest = false
    @State private var showSecondConfirmDeleteRequest = false
    
    @Binding var car: Car
    
    @State private var showsYearPicker = false
    @Binding var carYear: String
    @Binding var carMake: String
    @Binding var carModel: String
    @Binding var carPlate: String
    @Binding var carVIN: String
//    @Binding var carOdometer: String
    
    var years = yearsPlusTwo()
    @State var selectionIndex = 0
    
    init(car: Binding<Car>) {
        self._car = car
        self._carYear = Binding<String>(car.year)!
        self._carMake = Binding<String>(car.make)!
        self._carModel = Binding<String>(car.model)!
        self._carPlate = Binding<String>(car.plate)!
        self._carVIN = Binding<String>(car.vin)!
//        self._carOdometer = Binding<String>(car.odometer)!
    }
    
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
                            TextField("Make",
                                      text: $carMake)
                            TextField("Model",
                                      text: $carModel)
                            //                            TextField("\(car.odometer)",
                            //                                      text: $carOdometer)
                            //                                .keyboardType(.numberPad)
                            TextField("Plate",
                                      text: $carPlate)
                            TextField("VIN",
                                      text: $carVIN)

                        }
                    }
                    .dismissKeyboardOnSwipe()
                    .dismissKeyboardOnTap()

                    Button(action: {
                        self.showFirstConfirmDeleteRequest = true
                        }) {
                        Text("Delete Car")
                            .foregroundColor(Color.red)
                           
                    }.alert(isPresented: self.$showFirstConfirmDeleteRequest) {
                    Alert(title: Text("Delete this Vehicle"),
                          message: Text("Deleting this vehicle will permanently remove all data."),
                          primaryButton: .destructive(Text("Delete")) {
                            self.showSecondConfirmDeleteRequest = true                      },
                          secondaryButton: .cancel()
                    )
                }
                }
                .navigationBarTitle("Repaint the Car!")
                .navigationBarItems(leading:
                                        Button("Cancel") {
                                            self.presentationMode.wrappedValue.dismiss()
                                        },
                                    trailing: Button("Save") {
                                        self.save()
                                        self.presentationMode.wrappedValue.dismiss()
                                        
                                    })
            }.alert(isPresented: self.$showSecondConfirmDeleteRequest) {
                Alert(title: Text("Are you really sure?"),
                      message: Text("This action cannot be undone"),
                      primaryButton: .cancel(),
                      secondaryButton: .destructive(Text("I'm sure")) {
                        self.moc.delete(car)
                        self.presentationMode.wrappedValue.dismiss()
                      })
            }
            
            
            
            Spacer()
            
        }
       
    }
    
    func save() {
        if self.carYear != "" {
            car.year = self.carYear
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
