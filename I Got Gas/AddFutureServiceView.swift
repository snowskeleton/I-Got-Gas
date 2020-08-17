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
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    
    var carFetchRequest: FetchRequest<Car>
    var car: Car { carFetchRequest.wrappedValue[0] }
    
    @State private var today = Date()
    @State private var odometer = ""
    @State private var name = ""
    @State private var repeating = true
    @State private var months = ""
    @State private var miles = ""
    
    init(carID: String) {
        carFetchRequest = Fetch.car(carID: carID)
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
                                Spacer()
                                Text("months")
                            }
                        }
                        
                        Section(header: Text("Or...")) {
                            HStack {
                                TextField("", text: self.$miles)
                                    .font(.system(size: 30))
                                    .keyboardType(.numberPad)
                                Spacer()
                                Text("miles")
                            }
                        }
                        
                    }
                    .dismissKeyboardOnSwipe()
                    .dismissKeyboardOnTap()

                    
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
            let futureService = FutureService(context: self.managedObjectContext)
            futureService.vehicle = car
            
            futureService.name = self.name
            futureService.everyXMiles = Int64(self.miles) ?? 0
            futureService.months = Int64(self.months) ?? 0
            futureService.targetOdometer = (car.odometer + (Int64(self.miles) ?? 0))
            futureService.date = Calendar.current.date(byAdding: .month, value: Int(self.months) ?? 0, to: today)!
            
            try? self.managedObjectContext.save()
    }
    
}
