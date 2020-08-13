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
    
    var fetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { fetchRequest.wrappedValue }
    
    @State private var today = Date()
    @State private var odometer = ""
    @State private var name = ""
    @State private var repeating = true
    @State private var months = ""
    @State private var miles = ""
    
    init(filter: String) {
        
        fetchRequest = FetchRequest<Car>(entity: Car.entity(),
                                         sortDescriptors: [],
                                         predicate: NSPredicate(
                                            format: "id = %@", filter))
    }
    
    var body: some View {
        ForEach(car, id: \.self) { car in
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
    }
    
    func save() -> Void {
        for car in car {
            let futureService = FutureService(context: self.managedObjectContext)
            futureService.vehicle = car
            
            futureService.name = self.name
            futureService.miles = Int64(self.miles) ?? 0
            futureService.months = Int64(self.months) ?? 0
            print((car.odometer + (Int64(self.miles) ?? 0)))
            futureService.odometer = (car.odometer + (Int64(self.miles) ?? 0))
            futureService.date = Calendar.current.date(byAdding: .month, value: Int(self.months) ?? 0, to: today)!
            
            try? self.managedObjectContext.save()
        }
    }
    
}

//struct AddFutureExpenseView_Previews: PreviewProvider {
//    static var previews: some View {
//        AddExpenseView(filter: "Hello, darkness").environmentObject(\.presentationMode)
//    }
//}
