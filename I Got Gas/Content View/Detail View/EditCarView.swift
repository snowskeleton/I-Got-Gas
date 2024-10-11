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
    @Environment(\.modelContext) var context
    
    @State private var showFirstConfirmDeleteRequest = false
    @State private var showSecondConfirmDeleteRequest = false
    
    @Binding var car: SDCar
    
    @State var carYear: Int?
    @State var carMake: String
    @State var carModel: String
    @State var carPlate: String
    @State var carVIN: String
    
    init(car: Binding<SDCar>) {
        self._car = car
        let workingCar = car.wrappedValue
        
        _carYear = .init(initialValue: workingCar.year)
        _carMake = .init(initialValue: workingCar.make)
        _carModel = .init(initialValue: workingCar.model)
        _carPlate = .init(initialValue: workingCar.plate)
        _carVIN = .init(initialValue: workingCar.vin)
    }
    
    var body: some View {
        VStack {
            NavigationView {
                VStack {
                    Form {
                        Section {
                            TextField("Year", value: $carYear, formatter: NumberFormatter())
                            TextField("Make", text: $carMake)
                            TextField("Model", text: $carModel)
                            TextField("Plate", text: $carPlate)
                            TextField("VIN", text: $carVIN)
                        }
                        
                        Section {
                            Button("Save") {
                                self.presentationMode.wrappedValue.dismiss()
                            }
                        }
                        
                        Section {
                            Button("Delete", role: .destructive) {
                                self.showFirstConfirmDeleteRequest = true
                            }
                            .alert(isPresented: self.$showFirstConfirmDeleteRequest) {
                                Alert(title: Text("Delete this Vehicle"),
                                      message: Text("Deleting this vehicle will permanently remove all data."),
                                      primaryButton: .destructive(Text("Delete")) {
                                        self.showSecondConfirmDeleteRequest = true
                                      },
                                      secondaryButton: .cancel())
                            }
                        }
                        
                    }
                }
                .navigationBarTitle("Update Details")
                .navigationBarItems(leading:
                                        Button("Cancel") {
                                            self.presentationMode.wrappedValue.dismiss()
                                        })
            }.alert(isPresented: self.$showSecondConfirmDeleteRequest) {
                Alert(title: Text("Are you really sure?"),
                      message: Text("This action cannot be undone"),
                      primaryButton: .cancel(),
                      secondaryButton: .destructive(Text("I'm sure")) {
//                        for service in car.futureSerevice! {
                            // cancel notifications
//                        }
                    
                    car.deleted = true
                      }
                )
            }
        }
    }
    
    func save() {
        if self.carYear != nil {
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
    }
}
