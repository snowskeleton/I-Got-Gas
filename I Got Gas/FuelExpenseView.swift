//
//  TestView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import CoreData

struct FuelExpenseView: View {
    @Environment(\.managedObjectContext) var moc
    var carFetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { carFetchRequest.wrappedValue }
    
    var serviceFetchRequest: FetchRequest<Service>
    var services: FetchedResults<Service> { serviceFetchRequest.wrappedValue }
    
    
    @State var showAddExpenseView = false
    
    init(carID: String) {
        carFetchRequest = Fetch.car(carID: carID)

        serviceFetchRequest = Fetch.services(howMany: 0,
                                            carID: carID,
                                            filters: [
                                                "vehicle.id = '\(carID)'",
                                                "note = 'Fuel'"
                                            ])
    }
    
    
    var body: some View {
        VStack {
            ForEach(car, id: \.self) { car in
                List {
                    
                    ForEach(services, id: \.self) { service in
                        VStack {
                            HStack {
                                Text("$\(service.cost, specifier: "%.2f")($\(service.fuel?.dpg ?? 0.00, specifier: "%.2f")/g)")
                                Spacer()
                            }
                            HStack {
                                Text("\(service.odometer)")
                                Spacer()
                                Text("\(service.date!, formatter: DateFormatter.taskDateFormat)")
                            }
                        }
                    }.onDelete(perform: loseMemory)
                    
                }
                Spacer()
                Button("Add Expense") {
                    self.showAddExpenseView = true
                }.sheet(isPresented: self.$showAddExpenseView) {
                    AddExpenseView(carID: car.id ?? "")
                        .environment(\.managedObjectContext, self.moc)
                }
            }
        }
    }
    func loseMemory(at offsets: IndexSet) {
        for index in offsets {
            let service = services[index]
            moc.delete(service)
            try? self.moc.save()
            AddExpenseView(carID: car[0].id ?? "").updateCarStats(car[0])
        }
    }
}

struct FuelExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        FuelExpenseView(carID: "")
    }
}
