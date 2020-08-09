//
//  MaintenanceBoxView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/7/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct MaintenanceBoxView: View {
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    
    var fetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { fetchRequest.wrappedValue }
    init(filter: String) {
        fetchRequest = FetchRequest<Car>(entity: Car.entity(),
                                         sortDescriptors: [],
                                         predicate: NSPredicate(
                                            format: "id BEGINSWITH %@", filter))
    }
    
    
    var body: some View {
        ForEach(car, id: \.self) { car in
            GroupBox(label: ImageAndTextLable(imageName: "wrench", text: "Maintenance")) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Odometer")
                        Spacer()
                        Text("\(car.odometer)")
                    }
                    HStack {
                        Text("Current MPG")
                        Spacer()
                        Text("42/g")
                    }
                    
                }
            }.groupBoxStyle(DetailBoxStyle(color: .black, destination: ServiceView(carID: car.id ?? "").environment(\.managedObjectContext, self.moc)))
        }
    }
}
