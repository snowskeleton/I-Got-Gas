//
//  FuelExpenseView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct FuelExpenseView: View {
    @Environment(\.modelContext) var context
    
    @State private var priceFormat = UserDefaults.standard.string(forKey: "priceFormat") ?? ""
    
    @Binding var car: SDCar
    
    @Query var services: [SDService]
    
    @State private var showAddFuelSheet = false
    @State private var showExistingFuelOrServiceSheet = false
    @State private var existingService: SDService?

    init(car: Binding<SDCar>) {
        self._car = car
        let searchId = car.wrappedValue.id
        let predicate = #Predicate<SDService> {
            $0.car?.id == searchId &&
            $0.isFuel == true
        }
        let descriptor = FetchDescriptor<SDService>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.odometer, order: .reverse),
                SortDescriptor(\.date, order: .reverse)
            ]
        )
        _services = Query(descriptor)
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(services, id: \.self) { service in
                    Button(action: {
                        existingService = service
                        showExistingFuelOrServiceSheet = true
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("$\(service.costPerGallon, specifier: (priceFormat == "" ? "%.3f" : "\(String(describing: priceFormat))"))/gal")
                                Text("\(service.gallons.description) gal")
                                Text("$\(service.cost, specifier: "%.2f")")
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\((service.date), formatter: DateFormatter.taskDateFormat)")
                                Text("\(service.odometer.description)")
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
//                .onDelete(perform: loseMemory)
            }
            Spacer()
            Button(action: { showAddFuelSheet = true }) {
                Text("Add Expense")
            }
            .padding(.bottom)
        }
        .sheet(isPresented: $showAddFuelSheet) {
            AddExpenseView(car: Binding<SDCar>.constant(car))
        }
        .sheet(isPresented: $showExistingFuelOrServiceSheet) {
            if let existingService {
                AddExpenseView(car: Binding<SDCar>.constant(car), service: existingService)
            }
        }
        .onAppear {
            Analytics.track(
                .openedFuelExpenses
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
