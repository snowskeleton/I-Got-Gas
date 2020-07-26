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

    @State var carName: String = ""
    @State var carYear: String = ""
    @State var carMake: String = ""
    @State var carModel: String = ""
    @State var carPlate: String = ""
    @State var carVIN: String = ""
    
    var body: some View {
        VStack {
            NavigationView {
                VStack {
                    Form {
                        Section(header: Text("Vehicle Info")) {
                            TextField("Name", text: self.$carName)
                            TextField("Year", text: self.$carYear)
                            TextField("Make", text: self.$carMake)
                            TextField("Model", text: self.$carModel)
                            TextField("License Plate", text: self.$carPlate)
                            TextField("VIN", text: self.$carVIN)
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                self.save()
            }) {
                Text("Add Vehicle")
            }
        }
    }
    func save() {
        let car = Car(context: self.managedObjectContext)
        car.name = self.carName
        car.year = self.carYear
        car.make = self.carMake
        car.model = self.carModel
        car.plate = self.carPlate
        car.vin = self.carVIN
        try? self.managedObjectContext.save()
        
        self.show = false
    }
}

struct AddCarView_Previews: PreviewProvider {
    static var previews: some View {
        AddCarView(show: Binding.constant(true))

    }
}
