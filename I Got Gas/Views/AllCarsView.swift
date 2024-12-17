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
    @Query var pinnedCars: [SDCar]
    @Query var sdcars: [SDCar]
    @Query var oldCars: [SDCar]
    
    init() {
        let newCarPredicate = #Predicate<SDCar> {
            $0.archived == false &&
            $0.pinned == false
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
            $0.pinned == true
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
        
        let oldCarPredicate = #Predicate<SDCar> { $0.archived == true }
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
        NavigationView {
            List {
                if !pinnedCars.isEmpty {
                    Section("Pinned") {
                        ForEach(pinnedCars, id: \.self) { car in
                            CarLineItemView(car: Binding<SDCar>.constant(car))
                                .swipeActions {
                                    Button("Un-Pin") {
                                        car.pinned = false
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
                            }
                            .tint(.yellow)
                            Button("Archive", role: .destructive) {
                                car.archived = true
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
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AddCarView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationTitle("Vehicles")
            .navigationViewStyle(.columns)

            Text("Select a Vehicle")
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
    @Binding var car: SDCar
    @Bindable var settings: SDCarSettings
    
    init(car: Binding<SDCar>) {
        _car = car
        if let settings = car.wrappedValue.settings {
            self.settings = settings
        } else {
            let settings = SDCarSettings()
            car.wrappedValue.settings = settings
            self.settings = settings
        }
    }

    var body: some View {
        NavigationLink {
            CarView(car: Binding<SDCar>.constant(car))
        } label: {
            VStack {
                HStack {
                    Text(car.visualName)
                    Spacer()
                }
                .fontWeight(.bold)
                HStack {
                    let services = (car.services ?? [])
                        .time(.days(settings.range))
                        .completed(settings.includeCompleted)
                        .pending(settings.includePending)
                        .fuel(settings.includeFuel)
                        .maintenance(settings.includeMaintenance)
                    Text("\(services.costPerMile, format: .currency(code: "USD"))/mile")
                    Spacer()
                    Text("Last fuel:")
                    Text(car.services?.lastFillup?.formatted(date: .numeric, time: .omitted) ?? "never")
                }
            }
        }
    }
}

