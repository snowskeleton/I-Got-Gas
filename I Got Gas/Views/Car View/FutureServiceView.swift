//
//  FutureServiceView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct FutureServiceView: View {
    @Environment(\.modelContext) var context

    @Binding var car: SDCar
    
    @Query var futureServices: [SDScheduledService]
    
    @State private var showAddScheduldServiceSheet = false
    @State private var showExistingScheduledServiceSheet = false
    @State private var existingFutureService: SDScheduledService?

    init(car: Binding<SDCar>) {
        self._car = car
        let searchId = car.wrappedValue.id
        let predicate = #Predicate<SDScheduledService> {
            $0.car?.id == searchId
        }
        let descriptor = FetchDescriptor<SDScheduledService>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.frequencyTime, order: .forward)]
        )
        _futureServices = Query(descriptor)
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(futureServices, id: \.self) { futureService in
                    Button(action: {
                        existingFutureService = futureService
                        showExistingScheduledServiceSheet = true
                    }) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(futureService.name)
                                Spacer()
                                VStack {
                                    Text(futureService.frequencyTime == 0 ? "" : "\(Calendar.current.date(byAdding: futureService.frequencyTimeInterval.calendarComponent, value: futureService.frequencyTime, to: Date())!, formatter: DateFormatter.taskDateFormat)")
                                    Text(futureService.odometerFirstOccurance.description)
                                }
                            }
                            if !futureService.fullDescription.isEmpty {
                                Text(futureService.fullDescription)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
//                .onDelete(perform: loseMemory)
            }
            Button("Schedule Service") {
                showAddScheduldServiceSheet = true
            }
            .padding(.bottom)
        }
        .sheet(isPresented: $showAddScheduldServiceSheet) {
            AddFutureServiceView(car: Binding<SDCar>.constant(car))
        }
        .sheet(isPresented: $showExistingScheduledServiceSheet) {
            if let existingFutureService {
                AddFutureServiceView(car: Binding<SDCar>.constant(car), futureService: existingFutureService)
            }
        }

        .onAppear {
            Analytics.track(
                .openedScheduledServices
            )
        }

    }
    
    func loseMemory(at offsets: IndexSet) {
        do {
            let _ = try offsets
                .map { _ in
                    try context
                        .delete(
                            model: SDService.self,
                            where: #Predicate<SDService> { $0.id == $0.id }
                        )}
        } catch { }
        
        //        // Get the services to delete
        //        let servicesToDelete = offsets.map { services[$0] }
        //
        //        // Delete the services
        //        for service in servicesToDelete {
        //            service.delete()
        //        }
        //
        ////        // Update the car's odometer
        ////        if let mostRecentService = services.first(where: { $0.isFuel }) {
        ////            car.odometer = mostRecentService.odometer
        ////        } else {
        ////            // No fuel services left, reset to starting odometer
        ////            car.odometer = car.startingOdometer
        ////        }
        ////
        ////        // Save changes
        ////        try? car.save()
    }
}
