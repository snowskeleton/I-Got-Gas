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

        carFetchRequest = FetchRequest<Car>(entity: Car.entity(),
                                         sortDescriptors: [],
                                         predicate: NSPredicate(
                                            format: "id = %@", carID))
        serviceFetchRequest = FetchServices(howMany: 0, carID: carID, filters: [["vehicle.id = ", "\(carID)"], ["note = ", "Fuel"]])
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
                    }
                    
                }
                    Spacer()
                    Button("Add Expense") {
                        self.showAddExpenseView = true
                    }.sheet(isPresented: self.$showAddExpenseView) {
                        AddExpenseView(filter: car.id ?? "")
                            .environment(\.managedObjectContext, self.moc)
                    }
            }
        }
    }
}

struct ServiceView_Previews: PreviewProvider {
    static var previews: some View {
        FuelExpenseView(carID: "")
    }
}
