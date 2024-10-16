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

    // 1.x - 2.0 migration migration
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    @AppStorage("migratedFrom1.0To2.0") var migrated: Bool = false
    @State private var showQuitAlert = false
    @State private var showProgressAlert = false
    @State private var alertTitle = "Default title"
    @State private var alertMessage = "Default message"
    // end migration

    var body: some View {
        TabView {
            AllCarsView()
                .tabItem {
                    Label("Vehicles", systemImage: "car.side")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        // 1.x - 2.0 migration migration
        .alert(isPresented: $showQuitAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("Quit")) { exit(0) }
            )
        }
        .alert(isPresented: $showProgressAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage)
            )
        }
        .onAppear {
            if migrated { return }
            var carCount = 0
            for car in cars {
                carCount += 1
                alertTitle = "Migrating \(carCount) of \(cars.count)"
                alertMessage = ""
                showProgressAlert = true

                let sdcar = SDCar(
                    make: car.make ?? "",
                    model: car.model ?? "",
                    name: car.name ?? "",
                    plate: car.plate ?? "",
                    vin: car.vin ?? "",
                    year: Int(car.year ?? ""),
                    startingOdometer: Int(car.startingOdometer)
                )
                var serviceCount = 0
                let totalServices = (car.services ?? [])
                print(totalServices.count)
                for service in totalServices {
                    serviceCount += 1
                    alertMessage = "Migrating service \(serviceCount)/\(totalServices.count)"
                    let workingService = service as! Service
                    let sdservice = SDService(
                        cost: workingService.cost,
                        datePurchased: workingService.date ?? Date(),
                        dateCompleted: workingService.date ?? Date(),
                        name: workingService.note ?? "",
                        odometer: Int(workingService.odometer)
                    )
                    
                    if let fuel = workingService.fuel {
                        sdservice.isFuel = true
                        sdservice.isFullTank = fuel.isFullTank
                        sdservice.gallons = fuel.numberOfGallons
                        
                    }
                    if let vendor = workingService.vendor {
                        sdservice.vendorName = vendor.name ?? ""
                    }
                    sdservice.car = sdcar
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
                    sdscheduledService.fullDescription = workingService.note ?? ""
                    sdscheduledService.notificationUUID = workingService.notificationUUID ?? ""
                    sdscheduledService.repeating = workingService.repeating
                    sdscheduledService.odometerFirstOccurance = Int(workingService.targetOdometer)
                    sdscheduledService.car = sdcar
                }
                context.insert(sdcar)
            }
            do {
                try context.save()
                migrated = true
                showProgressAlert = false
            } catch {
                alertTitle = "Migration failed"
                alertMessage = "Please close app and try again"
                showQuitAlert = true
            }
        }
        // end migration
    }
}
