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
    @State var showOptionsView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    ForEach(cars, id: \.self) { car in
                        CarBoxView(car: car)
                            .groupBoxStyle(DetailBoxStyle(destination: DetailView(car: Binding<Car>.constant(car))))
                    }
                }
            }
            .background(Color(.systemGroupedBackground)).edgesIgnoringSafeArea(.bottom)
            .navigationBarItems(leading:
                                    Button(action: {
                                        try? self.moc.save()
                                        self.showOptionsView.toggle()
                                    }) {
                                        Image(systemName: "gearshape")
                                            .sheet(isPresented: $showOptionsView) {
                                                OptionsView()}},
                                trailing:
                                    Button(action: {
                                        self.showAddCarView.toggle()
                                    }) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 30))
                                    }.padding(.leading)
                                    .sheet(isPresented: $showAddCarView) {
                                        AddCarView()
                                        
                                    })
        }
        
    }
}
