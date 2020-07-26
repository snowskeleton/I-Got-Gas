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
    let id: UUID
    var body: some View {
        Text("\(id)")
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
        return AddEntryView(show: Binding.constant(true), id: "Hello darkness" as! UUID).environment(\.managedObjectContext, context)

//        AddEntryView(show: Binding.constant(true), car: "Mine")
    }
}
