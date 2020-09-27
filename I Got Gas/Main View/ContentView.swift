//
//  ContentView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @State private var adOnTop = UserDefaults.standard.bool(forKey: "isAdOnTop")
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    @State var showAddCarView = false
    @State var showOptionsView = false
    
    var body: some View {
        VStack {
            NavigationView {
                ScrollView {
                    VStack {
                        ForEach(cars, id: \.self) { car in
                            CarBoxView(car: Binding<Car>.constant(car))
                                .groupBoxStyle(DetailBoxStyle(
                                                destination: DetailView(
                                                    car: Binding<Car>.constant(car))
                                                    .environment(\.managedObjectContext, self.moc)))
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
                                                .font(.largeTitle)
                                        }.padding(.leading)
                                        .sheet(isPresented: $showAddCarView) {
                                            AddCarView()
                                                .environment(\.managedObjectContext, self.moc)
                                        })
            }
            Banner()
        }
    }
}
