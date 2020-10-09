//
//  AddEntryView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import CoreData

struct DetailView: View {
    @Environment(\.managedObjectContext) var moc
    
    @State var showAddExpenseView = false
    @State var showFuelExpenseView = false
    
    @State private var showEditCarView = false
    
    @Binding var car: Car
    
    init(car: Binding<Car>) {
        self._car = car
    }
    
    var body: some View {
        
        VStack {
            TopDetailView(car: Binding<Car>.constant(car))
            VStack {
                ScrollView {
                    VStack(spacing: 25) {
                        FuelExpenseBoxView(carID: car.id!)
                            .groupBoxStyle(DetailBoxStyle(destination: FuelExpenseView(
                                                            car: Binding<Car>.constant(car))
                                                            .environment(\.managedObjectContext, self.moc)))
                        
                        ServiceExpenseBoxView(carID: car.id!)
                            .groupBoxStyle(DetailBoxStyle(destination: ServiceExpenseView(
                                                            car: Binding<Car>.constant(car))
                                                            .environment(\.managedObjectContext, self.moc)))
                        
                        FutureServiceBoxView(carID: car.id!)
                            .groupBoxStyle(DetailBoxStyle(destination: FutureServiceView(
                                                            car: Binding<Car>.constant(car))
                                                            .environment(\.managedObjectContext, self.moc)))
                        
                        
                    }.padding()
                }
            }.background(Color(.systemGroupedBackground)).edgesIgnoringSafeArea(.bottom)
            
            Spacer()
            
            Button("Add Expense") {
                self.showAddExpenseView = true
            }
            .padding(.bottom)
            .sheet(isPresented: self.$showAddExpenseView) {
                AddExpenseView(car: Binding<Car>.constant(car))
                    .environment(\.managedObjectContext, self.moc)
            }
        }.navigationBarTitle(Text("\(car.year!) \(car.make!) \(car.model!)"),
                             displayMode: .inline)
        .navigationBarItems(trailing:
                                Button("Edit") {
                                    self.showEditCarView.toggle()
                                }.sheet(isPresented: self.$showEditCarView) {
                                    EditCarView(car: Binding<Car>.constant(car))
                                        .environment(\.managedObjectContext, self.moc)
                                })
    }
}
