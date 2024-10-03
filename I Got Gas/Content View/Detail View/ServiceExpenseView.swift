//
//  TestView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import CoreData

struct ServiceExpenseView: View {
    @Environment(\.managedObjectContext) var moc

    @State var showAddExpenseView = false
    @State private var editSelectedExpense = false
    @Binding var car: Car
    @State private var selectedService = 0

    var serviceFetchRequest: FetchRequest<Service>
    var services: FetchedResults<Service> { serviceFetchRequest.wrappedValue }

    init(car: Binding<Car>) {
        self._car = car
        serviceFetchRequest = Fetch.services(howMany: 0,
                                             carID: car.id.wrappedValue!,
                                             filters: [
                                                "vehicle.id = '\(car.id.wrappedValue!)'",
                                                "note != 'Fuel'"
                                             ])
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
                                Text("\(service.date!, formatter: DateFormatter.taskDateFormat)")
                            }
                            HStack {
                                Text("\(service.odometer)")
                                Spacer()
                                Text("\(service.note ?? "")")
                                Spacer()
                                Text("\(service.vendor?.name ?? "")")
                            }
                        }
                    }
                    .sheet(isPresented: self.$editSelectedExpense) {
                        AddExpenseView(car: Binding<Car>.constant(car), service: Binding<Service>.constant(services[selectedService]))
                            .environment(\.managedObjectContext, self.moc)
                    }
                }.onDelete(perform: loseMemory)
            }
            Spacer()
            Button("Add Expense") {
                self.showAddExpenseView.toggle()
            }
            .padding(.bottom)
            .sheet(isPresented: self.$showAddExpenseView) {
                AddExpenseView(car: Binding<Car>.constant(car),
                               isGas: State(initialValue: false))
                    .environment(\.managedObjectContext, self.moc)
            }
        }
    }
    func loseMemory(at offsets: IndexSet) {
        for index in offsets {
            let service = services[index]
            moc.delete(service)
            try? self.moc.save()
        }
    }
}
