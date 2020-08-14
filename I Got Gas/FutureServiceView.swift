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
    var carFetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { carFetchRequest.wrappedValue }
    
    var futureServicesFetchRequest: FetchRequest<FutureService>
    var futureServices: FetchedResults<FutureService> { futureServicesFetchRequest.wrappedValue }
    
    @State var showAddFutureExpenseView = false
    
    init(carID: String) {
        
        carFetchRequest = FetchRequest<Car>(entity: Car.entity(),
                                            sortDescriptors: [],
                                            predicate: NSPredicate(
                                                format: "id = %@", carID))
        
        futureServicesFetchRequest = FetchFutureServices(howMany: 0, carID: carID)
    }
    
    
    var body: some View {
        VStack {
            ForEach(car, id: \.self) { car in
                List {
                    ForEach(futureServices, id: \.self) { futureService in
                        VStack {
                            HStack {
                                Text("\(futureService.name ?? "")")
                                Spacer()
                                Text("\(futureService.milesLeft)/\(futureService.startingMiles)")
                            }
                            HStack {
                                Text("\(futureService.note ?? "")")
                                Spacer()
                                Text("\(futureService.date!, formatter: DateFormatter.taskDateFormat)")
                            }
                        }
                    }.onDelete(perform: loseMemory)
                }
                Spacer()
                Button("Schedule Service") {
                    self.showAddFutureExpenseView = true
                }.sheet(isPresented: self.$showAddFutureExpenseView) {
                    AddFutureServiceView(filter: car.id ?? "")
                        .environment(\.managedObjectContext, self.moc)
                }
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

struct FutureServiceView_Previews: PreviewProvider {
    static var previews: some View {
        FuelExpenseView(carID: "")
    }
}
