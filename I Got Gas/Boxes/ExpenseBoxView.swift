//
//  ExpenseBoxView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/7/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import CoreData

struct ExpensesBoxView: View {
    var fetchRequest: FetchRequest<Service>
    var services: FetchedResults<Service> { fetchRequest.wrappedValue }
    
    init(filter: String) {
        let request: NSFetchRequest<Service> = Service.fetchRequest()
        request.fetchLimit = 4
        request.predicate = NSPredicate(format: "vehicle.id BEGINSWITH %@", filter)
        request.sortDescriptors = []
        fetchRequest = FetchRequest<Service>(fetchRequest: request)
        
    }
    
    var body: some View {
        
        GroupBox(label: ExpenseLable()) {
            VStack(alignment: .leading) {
                ForEach(services, id: \.self) { service in
                    HStack {
                        Text("$\(service.cost, specifier: "%.2f")")
                        Spacer()
                        Text("\(service.date!, formatter: ServiceView.self.taskDateFormat)")
                    }
                }
            }
        }
    }
}
