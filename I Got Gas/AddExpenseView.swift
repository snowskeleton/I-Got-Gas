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
    @State private var odometer = ""
    
    init(filter: String) {
        
        fetchRequest = FetchRequest<Car>(entity: Car.entity(),
                                         sortDescriptors: [],
                                         predicate: NSPredicate(
                                            format: "id BEGINSWITH %@", filter))
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
                            DatePicker("Date",
                                       selection: self.$expenseDate,
                                       displayedComponents: .date)
                                .padding(.top)
                                .labelsHidden()
                            
                            Section(header: Text("Details")) {
                                
                                HStack {
                                    Text("$")
                                    TextField("Price", text: self.$totalPrice)
                                        .keyboardType(.decimalPad)
                                }.font(.system(size: 30))
                                if self.isGas {
                                    HStack {
                                        Text("   ")
                                        TextField("Gallons", text: self.$gallonsOfGas)
                                            .keyboardType(.decimalPad)
                                    }.font(.system(size: 30))
                                }
                                HStack {
                                    Text("   ")
                                    TextField("Odometer", text: self.$odometer)
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
                            self.save()
                        }) {
                            Text("Save me!")
                        }
                    }.navigationBarTitle("")
                    .navigationBarHidden(true)
                }
            }
        }
    }
    
    func save() -> Void {
        
        for car in car {
            let service = Service(context: self.managedObjectContext)
            service.vendor = Vendor(context: self.managedObjectContext)
            
            service.vehicle = car
            if isGas {
                service.fuel = Fuel(context: self.managedObjectContext)
                service.vehicle?.lastFillup = self.expenseDate
                service.fuel?.numberOfGallons = Double(self.gallonsOfGas) ?? 0.00
                service.fuel?.dpg = ((Double(self.totalPrice) ?? 0.00) / (Double(self.gallonsOfGas) ?? 0.00))
            }
            
            service.vendor?.name = self.vendorName
            
            
            service.cost = Double(self.totalPrice) ?? 0.00
            service.date = self.expenseDate
            service.odometer = Int64(self.odometer) ?? 0
            service.vehicle!.odometer = Int64(self.odometer) ?? 0
            
            try? self.managedObjectContext.save()
        }
        
    }
    
}

//struct AddExpenseView_Previews: PreviewProvider {
//    static var previews: some View {
//        AddExpenseView(filter: "Hello, darkness").environmentObject(\.presentationMode)
//    }
//}
