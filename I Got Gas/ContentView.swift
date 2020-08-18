//
//  ContentView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    @State var showAddCarView = false
    
    var body: some View {
        NavigationView {
                ScrollView {
                    VStack {
                        ForEach(cars, id: \.self) { car in
                            CarBoxView(car: car)
                                .groupBoxStyle(DetailBoxStyle(destination: DetailView(carID: car.id!)))
                        }.onDelete(perform: crashCar)
                    }
            }
            .background(Color(.systemGroupedBackground)).edgesIgnoringSafeArea(.bottom)
            .navigationBarItems(leading:
                                    Button(action: {
                                        try? self.moc.save()
                                    }) {
                                        Text("Options")},
                                trailing:
                                    Button(action: {
                                        self.showAddCarView.toggle()
                                    }) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 30))
                                    }.padding(.leading)
                                    .sheet(isPresented: $showAddCarView) {
                                        AddCarView(show: self.$showAddCarView)
                                        
                                    })
        }
        
    }
    
    func crashCar(at offsets: IndexSet) {
        for index in offsets {
            let car = cars[index]
            moc.delete(car)
            try? self.moc.save()
        }
    }
    
}
