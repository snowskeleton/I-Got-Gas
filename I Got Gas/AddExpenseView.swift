//
//  AddExpenseView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/27/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

extension NumberFormatter {
    static var decimal: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }
    static var currency: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }
}

struct AddExpenseView: View {
    @Environment(\.presentationMode) var presentationMode
    var fetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { fetchRequest.wrappedValue }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }
    @State private var expenseDate = Date()
    
    @State private var isGas = true
    @State private var totalPrice: Float = 0.00
    @State private var gallonsOfGas: Float = 0.00
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
                            DatePicker("Please enter a date",
                                       selection: self.$expenseDate,
                                       displayedComponents: .date)
                            
                            Section(header: self.isGas ? Text("Fuel stats") : Text("Price")) {
                                
                                VStack {
                                    if self.isGas {
                                        HStack {
                                            Text("Gallons: ")
                                            TextField("", value: self.$gallonsOfGas,
                                                      formatter: NumberFormatter.decimal)
                                                .keyboardType(.decimalPad)
                                        }
                                    }
                                    HStack {
                                        Text("Price:   $")
                                        TextField("", value: self.$totalPrice,
                                                  formatter: NumberFormatter.decimal)
                                            .keyboardType(.decimalPad)
                                    }
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
}

//struct AddExpenseView_Previews: PreviewProvider {
//    static var previews: some View {
//        AddExpenseView(filter: "Hello, darkness").environmentObject(\.presentationMode)
//    }
//}
