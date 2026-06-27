//
//  AllCarsView.swift
//  I Got Gas
//
//  Created by snow on 10/16/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct AllCarsView: View {
    @Environment(SyncManager.self) private var syncManager
    @Environment(ShareManager.self) private var shareManager
    @State private var showSettings = false
    @Query var pinnedCars: [SDCar]
    @Query var sdcars: [SDCar]
    @Query var oldCars: [SDCar]

    init() {
        let newCarPredicate = #Predicate<SDCar> {
            $0.archived == false &&
            $0.pinned == false &&
            $0.deleted == false
        }
        let newCarDescriptors = FetchDescriptor<SDCar>(
            predicate: newCarPredicate,
            sortBy: [
                SortDescriptor(\.year, order: .reverse),
                SortDescriptor(\.make),
                SortDescriptor(\.model)
            ]
        )
        _sdcars = Query(newCarDescriptors)

        let pinnedCarPredicate = #Predicate<SDCar> {
            $0.archived == false &&
            $0.pinned == true &&
            $0.deleted == false
        }
        let pinnedCarDescriptors = FetchDescriptor<SDCar>(
            predicate: pinnedCarPredicate,
            sortBy: [
                SortDescriptor(\.year, order: .reverse),
                SortDescriptor(\.make),
                SortDescriptor(\.model)
            ]
        )

        _pinnedCars = Query(pinnedCarDescriptors)

        let oldCarPredicate = #Predicate<SDCar> {
            $0.archived == true &&
            $0.deleted == false
        }
        let oldCarDescriptors = FetchDescriptor<SDCar>(
            predicate: oldCarPredicate,
            sortBy: [
                SortDescriptor(\.year, order: .reverse),
                SortDescriptor(\.make),
                SortDescriptor(\.model)
            ]
        )
        _oldCars = Query(oldCarDescriptors)
    }

    var body: some View {
        NavigationStack {
            List {
                if !pinnedCars.isEmpty {
                    Section("Pinned") {
                        ForEach(pinnedCars, id: \.self) { car in
                            CarLineItemView(car: Binding<SDCar>.constant(car))
                                .swipeActions {
                                    Button("Un-Pin") {
                                        car.pinned = false
                                        car.touch()
                                        syncManager.triggerSync()
                                    }
                                    .tint(.yellow)
                                }
                        }
                    }
                }

                ForEach(sdcars, id: \.self) { car in
                    CarLineItemView(car: Binding<SDCar>.constant(car))
                        .swipeActions {
                            Button("Pin") {
                                car.pinned = true
                                car.touch()
                                syncManager.triggerSync()
                            }
                            .tint(.yellow)
                            Button("Archive", role: .destructive) {
                                car.archived = true
                                car.touch()
                                syncManager.triggerSync()
                            }
                        }
                }
                if !oldCars.isEmpty {
                    Section {
                        DisclosureGroup("Archived") {
                            ForEach(oldCars, id: \.self) { car in
                                CarLineItemView(car: Binding<SDCar>.constant(car))
                                    .swipeActions(allowsFullSwipe: false) {
                                        Button("Un-Archive") {
                                            car.archived = false
                                            car.touch()
                                            syncManager.triggerSync()
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .refreshable {
                syncManager.syncNow()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AddCarView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .overlay(alignment: .topTrailing) {
                                if shareManager.pendingShares.count > 0 {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 4, y: -4)
                                }
                            }
                    }
                }
            }
            .navigationTitle("Vehicles")
//            .navigationViewStyle(.columns)
//
//            Text("Select a Vehicle")
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .onAppear {
            Analytics.track(
                .carCount,
                with: [
                    "totalCars": pinnedCars.count + sdcars.count + oldCars.count,
                    "regularCars": sdcars.count,
                    "pinnedCars": pinnedCars.count,
                    "oldCars": oldCars.count
                ]
            )
        }
    }
}

struct CarLineItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(AuthManager.self) private var authManager
    @Binding var car: SDCar
    @Bindable var settings: SDCarSettings
    @Query var services: [SDService]

    init(car: Binding<SDCar>) {
        _car = car
        let carId = car.wrappedValue.id
        let predicate = #Predicate<SDService> {
            $0.car?.id == carId &&
            $0.deleted == false
        }
        _services = Query(FetchDescriptor<SDService>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))
        // Use existing settings for display; onAppear will persist one if missing.
        self.settings = car.wrappedValue.settings ?? SDCarSettings()
    }

    var body: some View {
        NavigationLink {
            CarView(car: Binding<SDCar>.constant(car))
        } label: {
            VStack {
                HStack {
                    Text(car.visualName)
                    if !car.ownerID.isEmpty && !authManager.userID.isEmpty && car.ownerID != authManager.userID {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .fontWeight(.bold)
                HStack {
                    let filteredServices = services
                        .time(.days(settings.range))
                        .completed(settings.includeCompleted)
                        .pending(settings.includePending)
                        .fuel(settings.includeFuel)
                        .maintenance(settings.includeMaintenance)
                    Text("\(filteredServices.costPerMile, format: .currency(code: "USD"))/mile")
                    Spacer()
                    Text("Last fuel:")
                    Text(services.lastFillup?.formatted(date: .numeric, time: .omitted) ?? "never")
                }
            }
        }
        .onAppear {
            if car.settings == nil {
                let newSettings = SDCarSettings()
                context.insert(newSettings)
                car.settings = newSettings
            }
        }
    }
}
