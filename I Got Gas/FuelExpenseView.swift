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
    @State private var priceFormat = UserDefaults.standard.string(forKey: "priceFormat") ?? ""
    
    var carFetchRequest: FetchRequest<Car>
    var cars: FetchedResults<Car> { carFetchRequest.wrappedValue }
    
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
        ForEach(cars, id: \.self) { car in
            
            VStack {
                List {
                    
                    ForEach(services, id: \.self) { service in
                        VStack {
                            HStack {
                                Text("$\(service.cost, specifier: "%.2f")($\((service.fuel?.dpg)!, specifier: (priceFormat == "" ? "%.3f" : "\(String(describing: priceFormat))")))/g)")
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
                }
                .padding(.bottom)
                .sheet(isPresented: self.$showAddExpenseView) {
                    AddExpenseView(carID: car.id!,
                                   car: Binding<Car>.constant(cars[0]),
                                   isGas: Binding<Bool>.constant(true), inputSelectedFutureService: -1)
                }
            }
        }
    }
    func loseMemory(at offsets: IndexSet) {
        for index in offsets {
            let service = services[index]
            let savedCar = service.vehicle
            moc.delete(service)
            try? self.moc.save()
            if services.count > 0 {
                services[0].vehicle?.odometer = services[0].odometer
            } else {
                savedCar!.odometer = savedCar!.startingOdometer
            }
            try? self.moc.save()
            AddExpenseView(carID: cars[0].id!,
                           car: Binding<Car>.constant(cars[0]),
                           isGas: Binding<Bool>.constant(true), inputSelectedFutureService: -1)
                .updateCarStats(cars[0])
        }
    }
}
