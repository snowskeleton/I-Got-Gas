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

struct FuelExpenseView: View {
    @Environment(\.managedObjectContext) var moc
    @State private var priceFormat = UserDefaults.standard.string(forKey: "priceFormat") ?? ""
    @State var showAddExpenseView = false
    @State private var editSelectedExpense = false
    @State private var selectedService = 0

    @Binding var car: SDCar

    @Query var services: [SDService]
    
    init(car: Binding<SDCar>) {
        self._car = car
        let searchId = car.wrappedValue.localId
        let predicate = #Predicate<SDService> {
            $0.car?.localId == searchId &&
            $0.isFuel == true
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
                                Text("$\(service.cost, specifier: "%.2f")($\(service.costPerGallon, specifier: (priceFormat == "" ? "%.3f" : "\(String(describing: priceFormat))")))/g)")
                                Spacer()
                            }
                            HStack {
                                Text(service.odometer.description)
                                Spacer()
                                Text("\((service.dateCompleted ?? service.datePurchased), formatter: DateFormatter.taskDateFormat)")
                            }
                        }
                    }
//                    .sheet(isPresented: self.$editSelectedExpense) {
//                        AddExpenseView(car: Binding<SDCar>.constant(car), service: Binding<SDService>.constant(services[selectedService]))
//                    }
                }.onDelete(perform: loseMemory)

            }
            Spacer()
            Button("Add Expense") {
                self.showAddExpenseView.toggle()
            }
            .padding(.bottom)
//            .sheet(isPresented: self.$showAddExpenseView) {
//                AddExpenseView(car: Binding<SDCar>.constant(car))
//            }
        }
    }
    func loseMemory(at offsets: IndexSet) {
//        for index in offsets     {
//            let service = services[index]
//            let savedCar = service.vehicle
//            moc.delete(service)
//            try? self.moc.save()
//            if services.count > 0 {
//                services[0].vehicle?.odometer = services[0].odometer
//            } else {
//                savedCar!.odometer = savedCar!.startingOdometer
//            }
//            try? self.moc.save()
//        }
    }
}
