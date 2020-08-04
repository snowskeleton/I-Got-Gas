//
//  TestView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct DataView: View {
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
        VStack {
            List {
                ForEach(car, id: \.self) { car in
                    ForEach(car.serviceArray, id: \.self) { service in
                        VStack {
                            Text("Hello service")
                            Text("\(service.odometer)")
                            Text("\(service.cost, specifier: "%.2f")")
                        }
                    }
                }
            }
        }
    }
}

struct DataView_Previews: PreviewProvider {
    static var previews: some View {
        DataView(filter: "")
    }
}
