//
//  CarView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct FakeAddExpenseView: View {
    var body: some View {
        Text("SubViewTwo")
    }
}

struct CarView: View {
    @Binding var car: SDCar
    
    @State private var showInfoSheet = false
    
    @State private var showAddFuelSheet = false
    @State private var showAddServiceSheet = false
    @State private var showAddScheduldServiceSheet = false

    @State private var showExistingFuelOrServiceSheet = false
    @State private var showExistingScheduledServiceSheet = false
    
    @State private var existingService: SDService?
    @State private var existingFutureService: SDScheduledService?

    @Query var fuelServices: [SDService]
    @Query var services: [SDService]
    @Query var scheduledServices: [SDScheduledService]

    init(car: Binding<SDCar>) {
        var fetchLimit = UserDefaults.standard.integer(forKey: "itemCountOnCarView")
        if fetchLimit == 0 {
            fetchLimit = 3
        }
        _car = car
        let carId = car.wrappedValue.id
        let fuelPredicate = #Predicate<SDService> {
            $0.car?.id == carId &&
            $0.isFuel
        }
        var fuelDescriptor = FetchDescriptor<SDService>(
            predicate: fuelPredicate,
            sortBy: [
                SortDescriptor(\.odometer, order: .reverse),
                SortDescriptor(\.date, order: .reverse)
            ]
        )
        fuelDescriptor.fetchLimit = fetchLimit
        _fuelServices = Query(fuelDescriptor)
        
        let servicePredicate = #Predicate<SDService> {
            $0.car?.id == carId &&
            !$0.isFuel
        }
        var serviceDescriptor = FetchDescriptor<SDService>(
            predicate: servicePredicate,
            sortBy: [
                SortDescriptor(\.odometer, order: .reverse),
                SortDescriptor(\.date, order: .reverse)
            ]
        )
        serviceDescriptor.fetchLimit = fetchLimit
        _services = Query(serviceDescriptor)

        let scheduledDredicate = #Predicate<SDScheduledService> {
            $0.car?.id == carId
        }
        var scheduledDescriptor = FetchDescriptor<SDScheduledService>(
            predicate: scheduledDredicate,
            sortBy: [
                SortDescriptor(\.frequencyMiles, order: .reverse),
                SortDescriptor(\.frequencyTime, order: .reverse)
            ]
        )
        scheduledDescriptor.fetchLimit = fetchLimit
        _scheduledServices = Query(scheduledDescriptor)
    }
    
    var body: some View {
        VStack {
            List {
                ChartTabView(car: Binding<SDCar>.constant(car))
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .listRowInsets(EdgeInsets())

                Section {
                    ForEach(fuelServices, id: \.self) { service in
                        Button(action: {
                            existingService = service
                            showExistingFuelOrServiceSheet = true
                        }) {
                            HStack {
                                Text("$\(service.cost, specifier: "%.2f")")
                                Spacer()
                                Text("\(service.date, formatter: DateFormatter.taskDateFormat)")
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    NavigationLink {
                        FuelExpenseView(car: Binding<SDCar>.constant(car))
                    } label: {
                        Text("All")
                    }
                } header: {
                    Button(action: { showAddFuelSheet = true }) {
                        HStack {
                            Text("Fuel")
                            Image(systemName: "fuelpump")
                            Spacer()
                            Image(systemName: "plus")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Section {
                    ForEach(services, id: \.self) { service in
                        Button(action: {
                            existingService = service
                            showExistingFuelOrServiceSheet = true
                        }) {
                            HStack {
                                Text("$\(service.cost, specifier: "%.2f")")
                                Spacer()
                                Text(service.name)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(service.date, formatter: DateFormatter.taskDateFormat)"
                                )
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    NavigationLink {
                        MaintenanceExpenseView(car: Binding<SDCar>.constant(car))
                    } label: {
                        Text("All")
                    }
                } header: {
                    Button(action: { showAddServiceSheet = true }) {
                        HStack {
                            Text("Maintenance")
                            Image(systemName: "wrench")
                            Spacer()
                            Image(systemName: "plus")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Section {
                    ForEach(scheduledServices, id: \.self) { service in
                        Button(action: {
                            existingFutureService = service
                            showExistingScheduledServiceSheet = true
                        }) {
                            HStack {
                                Text(service.name)
                                    .foregroundColor(service.pastDue ? Color.red : Color.primary)
                                Spacer()
                                VStack {
                                    Text("\(service.odometerFirstOccurance - service.car!.odometer)/\(service.frequencyMiles)")
                                    Text(service.frequencyTime == 0 ? "" : "\(Calendar.current.date(byAdding: service.frequencyTimeInterval.calendarComponent, value: service.frequencyTime, to: Date())!, formatter: DateFormatter.taskDateFormat)")
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    NavigationLink {
                        FutureServiceView(car: Binding<SDCar>.constant(car))
                    } label: {
                        Text("All")
                    }
                } header: {
                    Button(action: { showAddScheduldServiceSheet = true }) {
                        HStack {
                            Text("Schedule")
                            Image(systemName: "clock")
                            Spacer()
                            Image(systemName: "plus")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Spacer()
        }
        .navigationBarTitle(
            Text(car.visualName),
            displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            CarInfoView(car: $car)
        }
        .sheet(isPresented: $showAddFuelSheet) {
            AddExpenseView(car: Binding<SDCar>.constant(car))
        }
        .sheet(isPresented: $showAddServiceSheet) {
            AddExpenseView(car: Binding<SDCar>.constant(car), isGas: false)
        }
        .sheet(isPresented: $showAddScheduldServiceSheet) {
            AddFutureServiceView(car: Binding<SDCar>.constant(car))
        }
        .sheet(isPresented: $showExistingFuelOrServiceSheet) {
            if let existingService {
                AddExpenseView(car: Binding<SDCar>.constant(car), service: existingService)
            }
        }
        .sheet(isPresented: $showExistingScheduledServiceSheet) {
            if let existingFutureService {
                AddFutureServiceView(car: Binding<SDCar>.constant(car), futureService: existingFutureService)
            }
        }
        .onAppear {
            Analytics.track(
                .servicesCount,
                with: [
                    "fuel": (car.services ?? []).filter({ $0.isFuel }).count,
                    "maintenance": (car.services ?? []).filter({ !$0.isFuel }).count,
                    "scheduled": (car.scheduledServices ?? []).count
                ]
            )
        }
    }
}
