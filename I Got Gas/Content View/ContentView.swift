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

    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    @State var showAddCarView = false
    @State var showOptionsView = false

    @Query(sort: \SDCar.make) var sdcars: [SDCar]
    
    @AppStorage("migratedFrom1.0To2.0") var migrated: Bool = false

    var body: some View {
        NavigationView {
            List(sdcars, id: \.self) { car in
                NavigationLink {
//                    DetailView(car: Binding<Car>.constant(car))
                } label: {
                    VStack {
                        HStack {
                            HStack {
                                Text(car.year)
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
                            Text("$\(car.costPerGallon, specifier: "%.3f")/gal)")
                            Spacer()
                        }
                        HStack {
                            Text("Miles:")
                            Text(car.odometer.description)
                            Spacer()
                            Text("Last filled:")
                            Text(car.lastFuelDate?.description ?? "never")
                        }
                    }
                }
            }
            .listStyle(.inset)
            .background(Color(.systemGroupedBackground)).edgesIgnoringSafeArea(.bottom)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        self.showOptionsView.toggle()
                    }) {
                        Image(systemName: "gearshape")
                    }
                    .sheet(isPresented: $showOptionsView) {
                        OptionsView()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        self.showAddCarView.toggle()
                    }) {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                    .sheet(isPresented: $showAddCarView) {
                        AddCarView()
                            .environment(\.managedObjectContext, self.moc)
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
                    year: car.year ?? "",
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
                        //monthsOrWeeks: 0 is months, 1 is weeks
                        
                        let sdvendor = SDVendor(
                            name: vendor.name ?? "",
                            longitude: vendor.longitude,
                            latitude: vendor.latitude
                        )
                        sdservice.vendor = sdvendor
                    }
                    context.insert(sdservice)
                }
                car.futureSerevice?.forEach { fservice in
                    let workingService = fservice as! FutureService
                    let serviceIntervalInDays = Int(Double(workingService.frequency) * (workingService.monthsOrWeeks == 0 ? 30.437 : 7))
                    let sdscheduledService = SDScheduledService(
                        frequencyMiles: Int(workingService.everyXMiles),
                        frequencyDays: serviceIntervalInDays
                        )
                    sdscheduledService.important = workingService.important
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
