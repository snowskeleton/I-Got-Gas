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
                                            format: "id = %@", filter))
    }
    
    
    var body: some View {
        ForEach(car, id: \.self) { car in
            GroupBox(label: ImageAndTextLable(image: "wrench", text: "Maintenance")) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Oil Change")
                        Spacer()
                        Text("eventually")
                    }
                    HStack {
                        Text("Break Check")
                        Spacer()
                        Text("Whenever")
                    }
                    HStack {
                        Text("Paint job")
                        Spacer()
                        Text("As Needed")
                    }
                    
                }
            }.groupBoxStyle(DetailBoxStyle(
                                color: .black,
                                destination: FuelExpenseView(
                                    carID: car.id ?? "").environment(\.managedObjectContext, self.moc)))
        }
    }
}
