//
//  AddEntryView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct AddEntryView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>

    @Binding var show: Bool
    let id: String
    var body: some View {
        VStack {
            ShowCarName(filter: id)
        }
    }
}

struct ShowCarName: View {
    var fetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { fetchRequest.wrappedValue }

    init(filter: String) {
        fetchRequest = FetchRequest<Car>(entity: Car.entity(), sortDescriptors: [], predicate: NSPredicate(format: "idea BEGINSWITH %@", filter))
    }
    
    var body: some View {
        ForEach(car, id: \.self) { car in
            Text("\(car.name!)")
        }
    }
}

struct AddEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        //Test data
        let carSelected = Car.init(context: context)
        carSelected.name = ""
        carSelected.year = ""
        carSelected.make = ""
        carSelected.model = ""
        carSelected.plate = ""
        carSelected.vin = ""
        return AddEntryView(show: Binding.constant(true), id: "Hello, darkness").environment(\.managedObjectContext, context)

//        AddEntryView(show: Binding.constant(true), car: "Mine")
    }
}
