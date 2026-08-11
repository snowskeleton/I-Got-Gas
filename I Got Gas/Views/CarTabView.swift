//
//  CarTabView.swift
//  I Got Gas
//
//  Created by snow on 6/27/25.
//  Copyright © 2025 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct CarTabView: View {
    @Environment(AuthManager.self) private var authManager

    @Binding var car: SDCar
    @Binding var lastSelectedCarId: String

    @State private var showCarPicker = false
    @State private var showCarInfo = false

    @Query var allServices: [SDService]
    @Query var scheduledServices: [SDScheduledService]

    init(car: Binding<SDCar>, lastSelectedCarId: Binding<String>) {
        _car = car
        _lastSelectedCarId = lastSelectedCarId
        let carId = car.wrappedValue.id

        let servicesPredicate = #Predicate<SDService> {
            $0.car?.id == carId && $0.deleted == false
        }
        _allServices = Query(FetchDescriptor<SDService>(
            predicate: servicesPredicate,
            sortBy: [
                SortDescriptor(\.odometer, order: .reverse),
                SortDescriptor(\.date, order: .reverse)
            ]
        ))

        let scheduledPredicate = #Predicate<SDScheduledService> {
            $0.car?.id == carId && $0.deleted == false
        }
        _scheduledServices = Query(FetchDescriptor<SDScheduledService>(
            predicate: scheduledPredicate,
            sortBy: [SortDescriptor(\.frequencyMiles, order: .reverse)]
        ))
    }

    private var fuelServices: [SDService] {
        allServices.filter { $0.isFuel }
    }

    private var maintenanceServices: [SDService] {
        allServices.filter { !$0.isFuel }
    }

    var body: some View {
        TabView {
            NavigationStack {
                FuelExpenseView(car: $car, services: fuelServices, allServices: allServices)
                    .navigationTitle("Fuel")
                    .toolbar { carToolbar }
            }
            .tabItem { Label("Fuel", systemImage: "fuelpump") }

            NavigationStack {
                MaintenanceExpenseView(car: $car, services: maintenanceServices, allServices: allServices)
                    .navigationTitle("Maintenance")
                    .toolbar { carToolbar }
            }
            .tabItem { Label("Maintenance", systemImage: "wrench") }

            NavigationStack {
                FutureServiceView(car: $car, scheduledServices: scheduledServices)
                    .navigationTitle("Schedule")
                    .toolbar { carToolbar }
            }
            .tabItem { Label("Schedule", systemImage: "clock") }

            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            carPickerButton
                        }
                    }
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .sheet(isPresented: $showCarPicker) {
            CarPickerSheet(lastSelectedCarId: $lastSelectedCarId)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCarInfo) {
            CarInfoView(car: $car)
                .environment(authManager)
        }
    }

    private var carPickerButton: some View {
        Button {
            showCarPicker = true
        } label: {
            HStack(spacing: 3) {
                Text(car.visualName)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
        }
    }

    @ToolbarContentBuilder
    private var carToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            carPickerButton
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showCarInfo = true
            } label: {
                Image(systemName: "info.circle")
            }
        }
    }
}
