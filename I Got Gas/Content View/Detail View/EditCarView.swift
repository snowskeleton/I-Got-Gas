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
    @State var carYear: String
    @State var carMake: String
    @State var carModel: String
    @State var carPlate: String
    @State var carVIN: String
    
    let yearRange: [String]

    init(car: Binding<Car>) {
        self._car = car
        let workingCar = car.wrappedValue
        
        let currentYear = Int(car.year.wrappedValue!)!
        self.yearRange = (1990...currentYear+2).map { String($0) }.reversed()
        
        _carYear = .init(initialValue: workingCar.year ?? currentYear.description)
        _carMake = .init(initialValue: workingCar.make ?? "")
        _carModel = .init(initialValue: workingCar.model ?? "")
        _carPlate = .init(initialValue: workingCar.plate ?? "")
        _carVIN = .init(initialValue: workingCar.vin ?? "")
        
    }
    
    var body: some View {
        VStack {
            NavigationView {
                VStack {
                    Form {
                        
                        Section(header: Text("Vehicle Info")) {
                            Picker("Year", selection: $carYear) {
                                ForEach(yearRange, id: \.self) { year in
                                    Text(year).tag(year)
                                }
                            }

                            TextField("Make",
                                      text: $carMake)
                            TextField("Model",
                                      text: $carModel)
                            TextField("Plate",
                                      text: $carPlate)
                            TextField("VIN",
                                      text: $carVIN)
                            
                        }
                        
                        Section {
                            Button(action: {
                                self.save()
                                self.presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Save")
                                        .foregroundColor(Color.blue)
                                    Spacer()
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Section {
                            Button(action: {
                                self.showFirstConfirmDeleteRequest = true
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Delete Car")
                                        .foregroundColor(Color.red)
                                    Spacer()
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
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
                        for service in car.futureSerevice! {
                            AddFutureServiceView(car: Binding<Car>.constant(car)).removeFutureServiceNotification(service as! FetchedResults<FutureService>.Element)
                        }
                        self.moc.delete(car)
                        self.presentationMode.wrappedValue.dismiss()
                        try? self.moc.save()
                      })
            }
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
        try? self.moc.save()
    }
}
