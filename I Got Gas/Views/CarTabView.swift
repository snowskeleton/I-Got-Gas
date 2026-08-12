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
    @Environment(SyncManager.self) private var syncManager

    @Binding var car: SDCar
    @Binding var lastSelectedCarId: String

    @State private var showCarPicker = false

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
                SortDescriptor(\.odometerMeters, order: .reverse),
                SortDescriptor(\.date, order: .reverse)
            ]
        ))

        let scheduledPredicate = #Predicate<SDScheduledService> {
            $0.car?.id == carId && $0.deleted == false
        }
        _scheduledServices = Query(FetchDescriptor<SDScheduledService>(
            predicate: scheduledPredicate,
            sortBy: [SortDescriptor(\.frequencyMeters, order: .reverse)]
        ))
    }

    private var fuelServices: [SDService] {
        allServices.filter { $0.kind == .fuel }
    }

    private var maintenanceServices: [SDService] {
        allServices.filter { $0.kind == .maintenance }
    }

    var body: some View {
        VStack(spacing: 0) {
            if syncManager.blockedCarIDs.contains(car.id) {
                UpdateRequiredBanner(reason: .clientTooOld)
            } else if syncManager.ownerUpgradeCarIDs.contains(car.id) {
                UpdateRequiredBanner(reason: .ownerTooOld)
            }
            tabs
        }
    }

    private var tabs: some View {
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
    }
}
