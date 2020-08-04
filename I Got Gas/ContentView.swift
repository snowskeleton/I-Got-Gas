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
    @State var selectedCarID = ""
    @State var showAddCarView = false
    
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(
                    destination: DetailView(
                        filter: self.selectedCarID)
                    .navigationBarHidden(false),
                        isActive: self.$showDetailView)
                    { EmptyView() }
                List {
                    ForEach(cars, id: \.self) { car in
                        
                        Button(action: {
                            self.selectedCarID = car.id ?? ""
                            self.showDetailView.toggle()
                        }) {
                            CarView(filter: car.id ?? "")
                        }
                        
                    }.onDelete(perform: crashCar)
                }
            }
            .navigationBarItems(leading:
                Button(action: {
                    self.showAddCarView.toggle()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 30))
                }.padding(.leading)
                    .sheet(isPresented: $showAddCarView) {
                        AddCarView(show: self.$showAddCarView).environment(\.managedObjectContext, self.managedObjectContext)},
                                trailing:
                Button(action: {
                    try? self.managedObjectContext.save()
                }) {
                    Text("Options")
            })
        
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
