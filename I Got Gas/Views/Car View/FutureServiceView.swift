//
//  FutureServiceView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct FutureServiceView: View {
    @Binding var car: SDCar
    
    @Query var futureServices: [SDScheduledService]
    
    init(car: Binding<SDCar>) {
        self._car = car
        let searchId = car.wrappedValue.id
        let predicate = #Predicate<SDScheduledService> {
            $0.car?.id == searchId
        }
        let descriptor = FetchDescriptor<SDScheduledService>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.frequencyTime, order: .forward)]
        )
        _futureServices = Query(descriptor)
    }
    
    var body: some View {
        VStack {
            List(futureServices, id: \.self) { futureService in
                NavigationLink {
                    AddFutureServiceView(car: Binding<SDCar>.constant(car), futureService: futureService)
                } label: {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(futureService.name)
                            Spacer()
                            VStack {
                                Text(futureService.frequencyTime == 0 ? "" : "\(Calendar.current.date(byAdding: futureService.frequencyTimeInterval.calendarComponent, value: futureService.frequencyTime, to: Date())!, formatter: DateFormatter.taskDateFormat)")
                                Text(futureService.odometerFirstOccurance.description)
                            }
                        }
                        if !futureService.fullDescription.isEmpty {
                            Text(futureService.fullDescription)
                                .font(.subheadline)
                        }
                    }
                }
            }
            //.onDelete(perform: loseMemory)
            NavigationLink {
                AddFutureServiceView(car: Binding<SDCar>.constant(car))
            } label: {
                Text("Schedule Service")
            }
            .padding(.bottom)
        }
    }
    
//    func loseMemory(at offsets: IndexSet) {
//        for index in offsets {
//            let service = futureServices[index]
//            moc.delete(service)
//            try? self.moc.save()
//        }
//    }
}
