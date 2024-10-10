//
//  TestView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData
import CoreData

struct ServiceExpenseView: View {
    @Environment(\.managedObjectContext) var moc

    @State var showAddExpenseView = false
    @State private var editSelectedExpense = false
    @Binding var car: SDCar
    @State private var selectedService = 0

//    var serviceFetchRequest: FetchRequest<Service>
//    var services: FetchedResults<Service> { serviceFetchRequest.wrappedValue }

    @Query var services: [SDService]
    
    init(car: Binding<SDCar>) {
        self._car = car
        let searchId = car.wrappedValue.localId
        let predicate = #Predicate<SDService> {
            $0.car?.localId == searchId &&
            $0.isFuel == false
        }
        let descriptor = FetchDescriptor<SDService>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.datePurchased)]
        )
        //        descriptor.fetchLimit = 5
        _services = Query(descriptor)
    }
    
    
    var body: some View {
        VStack {
            List(services, id: \.self) { service in
                NavigationLink {
                    AddExpenseView(
                        car: Binding<SDCar>.constant(car),
                        service: Binding<SDService>.constant(service)
                    )
                } label: {
                    VStack {
                        HStack {
                            Text("$\(service.cost, specifier: "%.2f")")
                            Spacer()
                            Text("\(service.datePurchased, formatter: DateFormatter.taskDateFormat)")
                        }
                        HStack {
                            Text("\(service.odometer)")
                            Spacer()
                            Text(service.note)
                            Spacer()
                            Text(service.vendorName)
                        }
                    }
                }
            }
            //.onDelete(perform: loseMemory)
            Spacer()
            NavigationLink {
                AddExpenseView(
                    car: Binding<SDCar>.constant(car),
                    isGas: State(initialValue: false)
                )
            } label: {
                Text("Add Expense")
            }
            .padding(.bottom)
        }
        .navigationTitle("Services")
    }
//    func loseMemory(at offsets: IndexSet) {
//        for index in offsets {
//            let service = services[index]
//            moc.delete(service)
//            try? self.moc.save()
//        }
//    }
}
