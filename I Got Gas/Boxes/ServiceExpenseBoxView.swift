//
//  ExpenseBoxView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/7/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import CoreData

struct ServiceExpenseBoxView: View {
    var serviceFetchRequest: FetchRequest<Service>
    var services: FetchedResults<Service> { serviceFetchRequest.wrappedValue }
    
    init(carID: String) {
        serviceFetchRequest = Fetch.services(howMany: 3,
                                            carID: carID,
                                            filters: [
                                                "vehicle.id = '\(carID)'",
                                                "note != 'Fuel'"
                                            ])
    }
    
    var body: some View {
        GroupBox(label: Label("Services", systemImage: "wrench")) {
//            GroupBox(label: ImageAndTextLable(systemImage: "wrench", text: "Services")) {
            VStack(alignment: .leading) {
                ForEach(services, id: \.self) { service in
                    HStack {
                        Text("$\(service.cost, specifier: "%.2f")")
                        Spacer()
                        Text("\(service.note ?? "")")
                            .lineLimit(1)
                        Spacer()
                        Text("\(service.date!, formatter: DateFormatter.taskDateFormat)")
                    }
                }
            }
        }
    }
}
