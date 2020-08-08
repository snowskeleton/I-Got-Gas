//
//  TestView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct ServiceView: View {
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    var fetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { fetchRequest.wrappedValue }
    
    @State var showAddExpenseView = false

    
    static let taskDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    init(filter: String) {
        
        fetchRequest = FetchRequest<Car>(entity: Car.entity(),
                                         sortDescriptors: [],
                                         predicate: NSPredicate(
                                            format: "id BEGINSWITH %@", filter))
    }

    
    var body: some View {
        VStack {
                ForEach(car, id: \.self) { car in
                    List {

                    ForEach(car.serviceArray, id: \.self) { service in
                        VStack {
                            HStack {
                                Text("$\(service.cost, specifier: "%.2f")")
                            }
                            HStack {
                                Text("\(service.odometer)")
                                Spacer()
                                Text("\(service.date!, formatter: ServiceView.self.taskDateFormat)")
                            }
                        }
                    }
                    
                }
                    Spacer()
                    Button("Add Expense") {
                        self.showAddExpenseView = true
                    }.sheet(isPresented: self.$showAddExpenseView) {
                        AddExpenseView(filter: car.id ?? "")
                            .environment(\.managedObjectContext, self.moc)
                    }
            }
        }
    }
}

struct ServiceView_Previews: PreviewProvider {
    static var previews: some View {
        ServiceView(filter: "")
    }
}
