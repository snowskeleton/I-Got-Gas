//
//  EditCarView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/15/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct EditCarView: View {
    @Environment(\.managedObjectContext) var managedObjectContext

    var carFetchRequest: FetchRequest<Car>
    var car: Car { carFetchRequest.wrappedValue[0] }
    
    @State private var showsYearPicker = false
    @State private var carYear: Int64 = 0
    
    @State private var carMake: String = ""
    @State private var carModel: String = ""
    @State private var carPlate: String = ""
    @State private var carVIN: String = ""
    @State private var carOdometer: String = ""
    
    init(carID: String) {
        carFetchRequest = Fetch.car(carID: carID)
        carMake = car.make!
        carYear = Int64(car.year!)!
        carModel = car.model!
        carPlate = car.plate!
        carVIN = car.vin!
        carOdometer = String(car.odometer)
    }

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
                                      text: self.$carMake)
                            TextField("* Model",
                                      text: self.$carModel)
                            TextField("* Current Odometer",
                                      text: self.$carOdometer)
                                .keyboardType(.numberPad)
                            TextField("* License Plate",
                                      text: self.$carPlate)
                            TextField("* VIN",
                                      text: self.$carVIN)
                        }
                    }
                }
                .navigationBarTitle("Repaint the Car!")
            }
            
            Spacer()
            
            Button(action: {
                self.save()
            }) {
                Text("Finalize Rebuild")
            }
        }
    }
    
    func save() {
        car.year = String(self.carYear)
        car.make = self.carMake
        car.model = self.carModel
        car.plate = self.carPlate
        car.vin = self.carVIN
        car.odometer = Int64(self.carOdometer)!
        try? self.managedObjectContext.save()
    }
}

struct EditCarView_Previews: PreviewProvider {
    static var previews: some View {
        EditCarView(carID: "Hello, darkness")
    }
}
