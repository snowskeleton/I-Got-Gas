//
//  CarDetailView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import CoreData
import SwiftUI

struct CarDetailView: View {
    var fetchRequest: FetchRequest<Car>
    
    init(filter: String) {
        fetchRequest = FetchRequest<Car>(entity: Car.entity(), sortDescriptors: [], predicate: NSPredicate(format: "id BEGINSWITH %@", filter))
    }

    @Binding var show: Bool
    var body: some View {
        Text("\(car.id)")
    }
}

struct CarDetailView_Previews: PreviewProvider {
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
        return CarDetailView(
            predicate: "happy",
            show: Binding.constant(true),
            car: carSelected)
            .environment(\.managedObjectContext, context)
        
        //        CarDetailView()
    }
}
