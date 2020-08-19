//
//  AddExpenseView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/27/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct AddFutureServiceView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var moc
        
    @State private var today = Date()
    @State private var odometer = ""
    @State private var name = ""
    @State private var repeating = true
    @State private var months = ""
    @State private var miles = ""
    @Binding var car: Car
    init(car: Binding<Car>) {
        self._car = car
    }
    
    var body: some View {
            VStack {
                NavigationView {
                    VStack {
                        
                        HStack {
                            Button(action: {
                                self.repeating.toggle()
                            }) {
                                self.repeating ? Text("Repeating") : Text("One Time")
                            }
                            .font(.system(size: 30))
                            .padding()
                        }
                        
                        Form {
                            
                            TextField("Service Description", text: self.$name)
                                .font(.system(size: 30))
                            
                            Section(header: Text("Every...")) {
                                HStack {
                                    TextField("", text: self.$months)
                                        .font(.system(size: 30))
                                        .keyboardType(.numberPad)
                                        .dismissKeyboardOnSwipe()
                                        .dismissKeyboardOnTap()
                                    Spacer()
                                    Text("months")
                                }
                            }
                            
                            Section(header: Text("Or...")) {
                                HStack {
                                    TextField("", text: self.$miles)
                                        .font(.system(size: 30))
                                        .keyboardType(.numberPad)
                                        .dismissKeyboardOnSwipe()
                                        .dismissKeyboardOnTap()
                                    Spacer()
                                    Text("miles")
                                }
                            }
                            
                        }
                        
                        Spacer()
                        
                        Button("Save") {
                            self.save()
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }.navigationBarTitle("")
                    .navigationBarHidden(true)
                }
            }
        }
    
    func save() -> Void {
            let futureService = FutureService(context: self.moc)
            futureService.vehicle = car
            
            futureService.name = self.name
            futureService.everyXMiles = Int64(self.miles) ?? 0
            futureService.months = Int64(self.months) ?? 0
            futureService.targetOdometer = (car.odometer + (Int64(self.miles) ?? 0))
            futureService.date = Calendar.current.date(byAdding: .month, value: Int(self.months) ?? 0, to: today)!
            
            try? self.moc.save()
    }
    
}
