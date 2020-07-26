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
    
    var body: some View {
        VStack {
            TopMenuBarView()
                .padding(.bottom)
            NavigationView {
                VStack {
                    List {
                        ForEach(cars, id: \.self) { car in
                            CarView(name: car.name!, make: car.make!, model: car.model!, year: car.year!)
                        }
                    }
                    //                CarView(name: "Julie", make: "Jeep", model: "Rangler", year: "2010")
                    //                Spacer()
                }
            }
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
