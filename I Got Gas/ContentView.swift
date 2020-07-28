//
//  ContentView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    @State private var showDetailView = false
    
    var body: some View {
        VStack {
            TopMenuBarView()
                .padding(.bottom)
            List {
                ForEach(cars, id: \.self) { car in
                    
                    Button(action: {
                        self.showDetailView = true
                    }) {
                        CarView(id: car.idea!)
                    }
                    .sheet(isPresented: self.$showDetailView) {
                        DetailView(show: self.$showDetailView, id: car.idea!).environment(\.managedObjectContext, self.managedObjectContext)
                }
                    
            }.onDelete(perform: crashCar)
        }
    }
    }
    func crashCar(at offsets: IndexSet) {
        for index in offsets {
            let car = cars[index]
            managedObjectContext.delete(car)
        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        //Test data
        let car = Car.init(context: context)
        car.name = ""
        car.year = ""
        car.make = ""
        car.model = ""
        car.plate = ""
        car.vin = ""
        return ContentView().environment(\.managedObjectContext, context)
        
        //        ContentView()
    }
}
