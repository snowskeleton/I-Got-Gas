//
//  ContentView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context

    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>

    @Query var pinnedCars: [SDCar]
    @Query var sdcars: [SDCar]
    @Query var oldCars: [SDCar]

    @AppStorage("migratedFrom1.0To2.0") var migrated: Bool = false

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
                    ForEach(pinnedCars, id: \.self) { car in
                        ContentViewItem(car: Binding<SDCar>.constant(car))
                            .swipeActions {
                                Button("Un-Pin") {
                                    car.pinned = false
                                }
                                .tint(.yellow)
                            }
                        Divider()
                    }
                }
                
                ForEach(sdcars, id: \.self) { car in
                    ContentViewItem(car: Binding<SDCar>.constant(car))
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
                                ContentViewItem(car: Binding<SDCar>.constant(car))
                                    .swipeActions(allowsFullSwipe: false) {
                                        Button("Un-Archive") {
                                            car.deleted = true
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        OptionsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AddCarView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            if migrated { return }
            for car in cars {
                let sdcar = SDCar(
                    make: car.make ?? "",
                    model: car.model ?? "",
                    name: car.name ?? "",
                    plate: car.plate ?? "",
                    vin: car.vin ?? "",
                    year: Int(car.year ?? ""),
                    startingOdometer: Int(car.startingOdometer)
                )
                car.services?.forEach { service in
                    let workingService = service as! Service
                    let sdservice = SDService(
                        cost: workingService.cost,
                        datePurchased: workingService.date ?? Date(),
                        dateCompleted: workingService.date ?? Date(),
                        note: workingService.note ?? "",
                        odometer: Int(workingService.odometer)
                    )
                        
                    if let fuel = workingService.fuel {
                        sdservice.isFuel = true
                        sdservice.costPerGallon = fuel.dpg
                        sdservice.isFullTank = fuel.isFullTank
                        sdservice.gallons = fuel.numberOfGallons
                        
                    }
                    if let vendor = workingService.vendor {
                        sdservice.vendorName = vendor.name ?? ""
                    }
                    context.insert(sdservice)
                }
                car.futureSerevice?.forEach { fservice in
                    let workingService = fservice as! FutureService
                    let serviceIntervalInDays = Int(Double(workingService.frequency) * (workingService.monthsOrWeeks == 0 ? 30.437 : 7))
                    let sdscheduledService = SDScheduledService()
                    sdscheduledService.frequencyMiles = Int(workingService.everyXMiles)
                    sdscheduledService.frequencyTime = serviceIntervalInDays
                    sdscheduledService.frequencyTimeInterval = .day
                    sdscheduledService.name = workingService.name ?? ""
                    sdscheduledService.notes = workingService.note ?? ""
                    sdscheduledService.notificationUUID = workingService.notificationUUID ?? ""
                    sdscheduledService.repeating = workingService.repeating
                    sdscheduledService.odometerFirstOccurance = Int(workingService.targetOdometer)
                    sdscheduledService.car = sdcar
                }
                context.insert(sdcar)
            }
            migrated = true
        }
    }
}

struct ContentViewItem: View {
    @Binding var car: SDCar
    var body: some View {
        NavigationLink {
            DetailView(car: Binding<SDCar>.constant(car))
        } label: {
            VStack {
                HStack {
                    HStack {
                        Text(car.year?.description ?? "")
                        Text(car.make)
                        Text(car.model)
                    }
                    .fontWeight(.bold)
                    Spacer()
                    Text(car.plate)
                }
                HStack {
                    Spacer()
                    Text("$\(car.costPerMile, specifier: "%.2f")/mile")
                    Spacer()
                    Text("$\(car.costPerGallon, specifier: "%.3f")/gal")
                    Spacer()
                }
                HStack {
                    Text("Miles:")
                    Text(car.odometer.description)
                    Spacer()
                    Text("Last filled:")
                    Text(car.lastFillup?.description ?? "never")
                }
            }
        }
    }
}

