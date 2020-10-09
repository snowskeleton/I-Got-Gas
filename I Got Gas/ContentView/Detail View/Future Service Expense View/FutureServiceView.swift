//
//  TestView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import CoreData

struct FutureServiceView: View {
    @Environment(\.managedObjectContext) var moc
    
    var futureServicesFetchRequest: FetchRequest<FutureService>
    var futureServices: FetchedResults<FutureService> { futureServicesFetchRequest.wrappedValue }
    
    @Binding var car: Car
    @State var showAddFutureExpenseView = false
    @State var showAddExpenseView = false
    @State private var selectedFutureService = -1
    
    init(carID: String, car: Binding<Car>) {
        self._car = car
        futureServicesFetchRequest = Fetch.futureServices(howMany: 0, carID: carID)
    }
    
    
    var body: some View {
        VStack {
            List {
                ForEach(futureServices, id: \.self) { futureService in
                    Button(action: {
                        selectedFutureService = Int(futureServices.firstIndex(of: futureService)!)
                        self.showAddExpenseView = true
                    }) {
                        VStack {
                            HStack {
                                Text("\(futureService.name ?? "")")
                                Spacer()
                                Text("\(futureService.targetOdometer - car.odometer)/\(futureService.everyXMiles)")
                            }
                            HStack {
                                Text("\(futureService.note ?? "")")
                                Spacer()
                                Text(futureService.date == nil ? "" : "\(futureService.date!, formatter: DateFormatter.taskDateFormat)")
                            }
                        }
                    }
                    .sheet(isPresented: self.$showAddExpenseView) {
                        AddExpenseView(car: Binding<Car>.constant(car),
                                       inputSelectedFutureService: selectedFutureService)
                            .environment(\.managedObjectContext, self.moc)
                    }

                }.onDelete(perform: loseMemory)
            }
            Button("Schedule Service") {
                self.showAddFutureExpenseView = true
            }
            .padding(.bottom)
            .sheet(isPresented: self.$showAddFutureExpenseView) {
                AddFutureServiceView(car: Binding<Car>.constant(car))
            }
        }
    }
    
    func loseMemory(at offsets: IndexSet) {
        for index in offsets {
            let service = futureServices[index]
            moc.delete(service)
            try? self.moc.save()
        }
    }
}
