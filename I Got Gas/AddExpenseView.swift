//
//  AddExpenseView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/27/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct AddExpenseView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>

    var fetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { fetchRequest.wrappedValue }
    
    @Environment(\.presentationMode) var presentationMode
    
//    @Binding var filter: String

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }
    
    @State private var expenseDate = Date()
    
    @State private var isGas = true
    @State private var totalPrice = ""
    @State private var gallonsOfGas = ""
    @State private var vendorName = ""
    @State private var serviceNotes = ""
    
    
    
    
    
    init(filter: String) {
        
        fetchRequest = FetchRequest<Car>(entity: Car.entity(),
                                         sortDescriptors: [],
                                         predicate: NSPredicate(
                                            format: "idea BEGINSWITH %@", filter))
    }
    
    var body: some View {
        ForEach(car, id: \.self) { car in
            VStack {
                
                HStack {
                    Button(action: {
                        self.isGas.toggle()
                    }) {
                        self.isGas ? Text("Gas") : Text("Service")
                    }
                    .font(.system(size: 30))
                    .padding()
                    
                }
                
                NavigationView {
                    VStack {
                        Form {
                            DatePicker(self.isGas ? "Fuel-up Date:" : "Service Date:",
                                       selection: self.$expenseDate,
                                       displayedComponents: .date)
                                .padding(.top)
                            
                            Section(header: self.isGas ? Text("Fuel stats") : Text("Price")) {
                                
                                if self.isGas {
                                    TextField("    Gallons", text: self.$gallonsOfGas)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 30))
                                }
                                HStack {
                                    Text("$")
                                    TextField("Price", text: self.$totalPrice)
                                        .keyboardType(.decimalPad)
                                }.font(.system(size: 30))
                                
                                
                            }
                            
                            Section(header: Text("Vendor")) {
                                TextField("Vendor name", text: self.$vendorName)
                                
                                if !self.isGas {
                                    TextField("Service Notes", text: self.$serviceNotes)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Save me!")
                        }
                    }.navigationBarTitle("")
                        .navigationBarHidden(true)
                }
            }
        }
    }
    
//    func save() -> Void {
//
//            car.name = self.carName
//            car.year = self.carYear
//            car.make = self.carMake
//            car.model = self.carModel
//            car.plate = self.carPlate
//            car.vin = self.carVIN
//            car.odometer = Int64(self.carOdometer) ?? 0
//            car.idea = UUID().uuidString
//            
//            try? self.managedObjectContext.save()
////            let car = Car(context: self.managedObjectContext)
//
//    }
    
}

//struct AddExpenseView_Previews: PreviewProvider {
//    static var previews: some View {
//        AddExpenseView(filter: "Hello, darkness").environmentObject(\.presentationMode)
//    }
//}
