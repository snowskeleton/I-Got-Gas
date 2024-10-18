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
    @State private var priceFormat = UserDefaults.standard.string(forKey: "priceFormat") ?? ""

    @Binding var car: SDCar

    @Query var services: [SDService]
    
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
                    NavigationLink {
                        AddExpenseView(car: Binding<SDCar>.constant(car), service: service)
                    } label: {
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
                }.onDelete(perform: loseMemory)

            }
            Spacer()
            NavigationLink {
                AddExpenseView(car: Binding<SDCar>.constant(car))
            } label: {
                Text("Add Expense")
            }
            .padding(.bottom)
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
