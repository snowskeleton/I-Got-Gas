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

//    init(car: Binding<SDCar>) {
//        self._car = car
//        serviceFetchRequest = Fetch.services(howMany: 0,
//                                             carID: car.id.wrappedValue!,
//                                             filters: [
//                                                "vehicle.id = '\(car.id.wrappedValue!)'",
//                                                "note != 'Fuel'"
//                                             ])
    }
    
    
    var body: some View {
        VStack {
            List {
                ForEach(services, id: \.self) { service in
                    Button(action: {
                        selectedService = Int(services.firstIndex(of: service)!)
                        if (selectedService >= 0) && (selectedService <= services.count - 1) {
                            editSelectedExpense.toggle()
                        }
                    }) {
                        VStack {
                            HStack {
                                Text("$\(service.cost, specifier: "%.2f")")
                                Spacer()
                                Text("\(service.dateCompleted!, formatter: DateFormatter.taskDateFormat)")
                            }
                            HStack {
                                Text("\(service.odometer!)")
                                Spacer()
                                Text(service.note)
                                Spacer()
                                Text(service.vendor?.name ?? "")
                            }
                        }
                    }
//                    .sheet(isPresented: self.$editSelectedExpense) {
//                        AddExpenseView(car: Binding<SDCar>.constant(car), service: Binding<Service>.constant(services[selectedService]))
//                            .environment(\.managedObjectContext, self.moc)
//                    }
                }
                //.onDelete(perform: loseMemory)
            }
            Spacer()
            Button("Add Expense") {
                self.showAddExpenseView.toggle()
            }
            .padding(.bottom)
//            .sheet(isPresented: self.$showAddExpenseView) {
//                AddExpenseView(car: Binding<Car>.constant(car),
//                               isGas: State(initialValue: false))
//                    .environment(\.managedObjectContext, self.moc)
//            }
        }
    }
//    func loseMemory(at offsets: IndexSet) {
//        for index in offsets {
//            let service = services[index]
//            moc.delete(service)
//            try? self.moc.save()
//        }
//    }
}
