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
            $0.deleted == false &&
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
            $0.deleted == false &&
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
        
        let oldCarPredicate = #Predicate<SDCar> { $0.deleted == true }
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
                                car.deleted = true
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
                                            car.deleted = false
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .toolbar {
//                ToolbarItem(placement: .topBarLeading) {
//                    NavigationLink {
//                        OptionsView()
//                    } label: {
//                        Image(systemName: "gearshape")
//                    }
//                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AddCarView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct CarLineItemView: View {
    @Binding var car: SDCar
    var body: some View {
        NavigationLink {
            DetailView(car: Binding<SDCar>.constant(car))
        } label: {
            VStack {
                HStack {
                    Text(car.visualName)
                    Spacer()
                }
                .fontWeight(.bold)
                HStack {
                    Text("$\(car.costPerMile, specifier: "%.2f")/mile")
                    Spacer()
                    Text("Last filled:")
                    Text(car.lastFillup?.formatted(date: .numeric, time: .omitted) ?? "never")
                }
            }
        }
    }
}

