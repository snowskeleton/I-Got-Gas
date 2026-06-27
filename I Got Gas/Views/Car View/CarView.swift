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
    @Environment(SyncManager.self) private var syncManager
    @Environment(AuthManager.self) private var authManager
    @Binding var car: SDCar

    let fetchLimit: Int

    @State private var showInfoSheet = false
    @State private var showAddFuelSheet = false
    @State private var showAddServiceSheet = false
    @State private var showAddScheduldServiceSheet = false
    @State private var showExistingFuelOrServiceSheet = false
    @State private var showExistingScheduledServiceSheet = false

    @State private var existingService: SDService?
    @State private var existingFutureService: SDScheduledService?

    @Query var allServices: [SDService]
    @Query var scheduledServices: [SDScheduledService]

    init(car: Binding<SDCar>) {
        var limit = UserDefaults.standard.integer(forKey: "itemCountOnCarView")
        if limit == 0 { limit = 3 }
        fetchLimit = limit

        _car = car
        let carId = car.wrappedValue.id

        let servicesPredicate = #Predicate<SDService> {
            $0.car?.id == carId &&
            $0.deleted == false
        }
        _allServices = Query(FetchDescriptor<SDService>(
            predicate: servicesPredicate,
            sortBy: [
                SortDescriptor(\.odometer, order: .reverse),
                SortDescriptor(\.date, order: .reverse)
            ]
        ))

        let scheduledPredicate = #Predicate<SDScheduledService> {
            $0.car?.id == carId &&
            $0.deleted == false
        }
        var scheduledDescriptor = FetchDescriptor<SDScheduledService>(
            predicate: scheduledPredicate,
            sortBy: [
                SortDescriptor(\.frequencyMiles, order: .reverse),
                SortDescriptor(\.frequencyTime, order: .reverse)
            ]
        )
        scheduledDescriptor.fetchLimit = limit
        _scheduledServices = Query(scheduledDescriptor)
    }

    private var fuelServices: [SDService] {
        Array(allServices.filter { $0.isFuel }.prefix(fetchLimit))
    }

    private var maintenanceServices: [SDService] {
        Array(allServices.filter { !$0.isFuel }.prefix(fetchLimit))
    }

    var body: some View {
        let carOdometer = max(
            fuelServices.first?.odometer ?? 0,
            maintenanceServices.first?.odometer ?? 0,
            car.startingOdometer
        )
        VStack {
            List {
                ChartTabView(car: $car, services: allServices)
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
                    NavigationLink("All") { FuelExpenseView(car: $car) }
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
                    ForEach(maintenanceServices, id: \.self) { service in
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
                                Text("\(service.date, formatter: DateFormatter.taskDateFormat)")
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    NavigationLink("All") { MaintenanceExpenseView(car: $car) }
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
                                    Text("\(service.odometerFirstOccurance - carOdometer)/\(service.frequencyMiles)")
                                    Text(service.frequencyTime == 0 ? "" : "\(Calendar.current.date(byAdding: service.frequencyTimeInterval.calendarComponent, value: service.frequencyTime, to: Date())!, formatter: DateFormatter.taskDateFormat)")
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    NavigationLink("All") { FutureServiceView(car: $car) }
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
                .environment(authManager)
        }
        .sheet(isPresented: $showAddFuelSheet) {
            AddExpenseView(car: $car)
                .environment(syncManager)
        }
        .sheet(isPresented: $showAddServiceSheet) {
            AddExpenseView(car: $car, isGas: false)
                .environment(syncManager)
        }
        .sheet(isPresented: $showAddScheduldServiceSheet) {
            AddFutureServiceView(car: $car)
                .environment(syncManager)
        }
        .sheet(isPresented: $showExistingFuelOrServiceSheet) {
            if let existingService {
                AddExpenseView(car: $car, service: existingService)
                    .environment(syncManager)
            }
        }
        .sheet(isPresented: $showExistingScheduledServiceSheet) {
            if let existingFutureService {
                AddFutureServiceView(car: $car, futureService: existingFutureService)
                    .environment(syncManager)
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
