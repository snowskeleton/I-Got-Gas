//
//  AddEntryView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct DetailView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    
    @State var showAddExpenseView = false
    
    var fetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { fetchRequest.wrappedValue }
    
    init(filter: String) {
        fetchRequest = FetchRequest<Car>(entity: Car.entity(),
                                         sortDescriptors: [],
                                         predicate: NSPredicate(
                                            format: "idea BEGINSWITH %@", filter))
    }
    
    var body: some View {
        ForEach(car, id: \.self) { car in
            
            VStack {
                CarView(filter: car.idea ?? "").padding()
                Spacer()
                
                VStack {
                    Form {
                        Section(header: Text("General information")) {
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
                            HStack {
                                Text("Last fill-up")
                                Spacer()
                                Text("7/10/2020")
                            }
                            HStack {
                                Text("Horoscope")
                                Spacer()
                                Text("Aries")
                            }
                        }
                        Section(header: Text("Service")) {
                            Text("Oil change")
                            Text("Break Check")
                            Text("Other service")
                            Text("Something important")
                        }
                    }
                    Spacer()
                    
                    Button(action: {
                        self.showAddExpenseView = true
                    }) {
                        Text("Add Expense")
                    }
                    .sheet(isPresented: self.$showAddExpenseView) {
                        AddExpenseView(show: self.$showAddExpenseView,
                                       id: car.idea ?? "")
                            .environment(\.managedObjectContext, self.managedObjectContext)
                    }
                }
                
            }
        }
    }
}





//struct DetailView_Previews: PreviewProvider {
//    static var previews: some View {
//        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
//        //Test data
//        let carSelected = Car.init(context: context)
//        carSelected.name = ""
//        carSelected.year = ""
//        carSelected.make = ""
//        carSelected.model = ""
//        carSelected.plate = ""
//        carSelected.vin = ""
//        return DetailView(filter: "Howdy, doody")
//            .environment(\.managedObjectContext, context)
//
//        //        AddEntryView(show: Binding.constant(true), car: "Mine")
//    }
//}
