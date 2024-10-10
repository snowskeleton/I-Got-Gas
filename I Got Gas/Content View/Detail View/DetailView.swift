//
//  AddEntryView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData
import CoreData

struct DetailView: View {
    @Environment(\.managedObjectContext) var moc
    
    @State var showAddExpenseView = false
    @State var showFuelExpenseView = false
    
    @State private var showEditCarView = false
    
    @Binding var car: SDCar
    
    @Query var fuelServices: [SDService]
    @Query var services: [SDService]
    @Query var scheduledServices: [SDScheduledService]

    init(car: Binding<SDCar>) {
        _car = car
        let carId = car.wrappedValue.localId
        let fuelPredicate = #Predicate<SDService> {
            $0.car?.localId == carId &&
            $0.isFuel
        }
        var fuelDescriptor = FetchDescriptor<SDService>(
            predicate: fuelPredicate,
            sortBy: [
                SortDescriptor(\.odometer, order: .reverse),
                SortDescriptor(\.datePurchased, order: .reverse)
            ]
        )
        fuelDescriptor.fetchLimit = 3
        _fuelServices = Query(fuelDescriptor)
        
        let servicePredicate = #Predicate<SDService> {
            $0.car?.localId == carId &&
            !$0.isFuel
        }
        var serviceDescriptor = FetchDescriptor<SDService>(
            predicate: servicePredicate,
            sortBy: [
                SortDescriptor(\.odometer, order: .reverse),
                SortDescriptor(\.datePurchased, order: .reverse)
            ]
        )
        serviceDescriptor.fetchLimit = 3
        _services = Query(serviceDescriptor)

        let scheduledDredicate = #Predicate<SDScheduledService> {
            $0.car?.localId == carId
        }
        var scheduledDescriptor = FetchDescriptor<SDScheduledService>(
            predicate: scheduledDredicate,
            sortBy: [
                SortDescriptor(\.frequencyMiles, order: .reverse),
                SortDescriptor(\.frequencyTime, order: .reverse)
            ]
        )
        scheduledDescriptor.fetchLimit = 3
        _scheduledServices = Query(scheduledDescriptor)
    }
    
    var body: some View {
        VStack {
            TopDetailView(car: Binding<SDCar>.constant(car))
            List {
                Section {
                    ForEach(fuelServices, id: \.self) { service in
                        NavigationLink {
                            AddExpenseView(car: Binding<SDCar>.constant(car), service: service)
                        } label: {
                            HStack {
                                Text("$\(service.cost, specifier: "%.2f")")
                                Spacer()
                                Text("\(service.datePurchased, formatter: DateFormatter.taskDateFormat)")
                            }
                        }
                    }
                    NavigationLink {
                        FuelExpenseView(car: Binding<SDCar>.constant(car))
                    } label: {
                        Text("All")
                    }
                } header: {
                    NavigationLink {
                        AddExpenseView(car: Binding<SDCar>.constant(car))
                    } label: {
                        HStack {
                            Text("Fuel")
                            Image(systemName: "fuelpump")
                            Spacer()
                            Image(systemName: "plus")
                        }
                    }
                }
                
                Section {
                    ForEach(services, id: \.self) { service in
                        NavigationLink {
                            AddExpenseView(car: Binding<SDCar>.constant(car), service: service)
                        } label: {
                            HStack {
                                Text("$\(service.cost, specifier: "%.2f")")
                                Spacer()
                                Text(service.note)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(service.datePurchased, formatter: DateFormatter.taskDateFormat)"
                                )
                            }
                        }
                    }
                    NavigationLink {
                        ServiceExpenseView(car: Binding<SDCar>.constant(car))
                    } label: {
                        Text("All")
                    }
                } header: {
                    NavigationLink {
                        AddExpenseView(car: Binding<SDCar>.constant(car), isGas: false)
                    } label: {
                        HStack {
                            Text("Service")
                            Image(systemName: "wrench")
                            Spacer()
                            Image(systemName: "plus")
                        }
                    }
                }
                
                Section {
                    ForEach(scheduledServices, id: \.self) { service in
                        NavigationLink {
                            AddFutureServiceView(car: Binding<SDCar>.constant(car), futureService: service)
                        } label: {
                            VStack {
                                HStack {
                                    Text(service.name)
                                        .foregroundColor(service.pastDue ? Color.red : Color.primary)
                                    Spacer()
                                    Text("\(service.odometerFirstOccurance - service.car!.odometer)/\(service.frequencyMiles)")
                                }
                                HStack {
                                    Spacer()
                                    Text(service.frequencyTime == 0 ? "" : "\(Calendar.current.date(byAdding: service.frequencyTimeInterval.calendarComponent, value: service.frequencyTime, to: Date())!, formatter: DateFormatter.taskDateFormat)")
                                }
                            }
                        }
                    }
                } header: {
                    NavigationLink {
                        AddFutureServiceView(car: Binding<SDCar>.constant(car))
                    } label: {
                        HStack {
                            Text("Schedule")
                            Image(systemName: "clock")
                            Spacer()
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            Spacer()
        }
        .navigationBarTitle(
            Text("\(car.year) \(car.make) \(car.model)"),
            displayMode: .inline)
        .navigationBarItems(trailing:
                                Button("Edit") {
            self.showEditCarView.toggle()
        }
//            .sheet(isPresented: self.$showEditCarView) {
//                EditCarView(car: Binding<Car>.constant(car))
//                    .environment(\.managedObjectContext, self.moc)
//            }
        )
    }
}
