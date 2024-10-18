//
//  MaintenanceExpenseView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct MaintenanceExpenseView: View {
    @Binding var car: SDCar

    @Query var services: [SDService]
    
    init(car: Binding<SDCar>) {
        self._car = car
        let searchId = car.wrappedValue.id
        let predicate = #Predicate<SDService> {
            $0.car?.id == searchId &&
            $0.isFuel == false
        }
        let descriptor = FetchDescriptor<SDService>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        _services = Query(descriptor)
    }
    
    
    var body: some View {
        VStack {
            List(services, id: \.self) { service in
                NavigationLink {
                    AddExpenseView(car: Binding<SDCar>.constant(car), service: service)
                } label: {
                    VStack {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(service.name)
                                Text("$\(service.cost, specifier: "%.2f")")
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(service.date, formatter: DateFormatter.taskDateFormat)
                                Text(service.odometer.description)
                            }
                        }
                        if !service.fullDescription.isEmpty {
                            Text(service.fullDescription)
                        }
                    }
                }
            }
            //.onDelete(perform: loseMemory)
            Spacer()
            NavigationLink {
                AddExpenseView(
                    car: Binding<SDCar>.constant(car),
                    isGas: false
                )
            } label: {
                Text("Add Expense")
            }
            .padding(.bottom)
        }
        .navigationTitle("Maintencance")
    }
//    func loseMemory(at offsets: IndexSet) {
//        for index in offsets {
//            let service = services[index]
//            moc.delete(service)
//            try? self.moc.save()
//        }
//    }
}
