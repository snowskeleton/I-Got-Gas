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
    
    @State private var testvar = 0.00
    
    var carFetchRequest: FetchRequest<Car>
    var car: Car { carFetchRequest.wrappedValue[0] }
    
    init(carID: String) {
        carFetchRequest = Fetch.car(carID: carID)
    }
    
    var body: some View {
        VStack {
            TopDetailView(carID: car.id ?? "")
            
            Spacer()
            
            VStack {
                ScrollView {
                    VStack(spacing: 8) {
                        EmptyView()
                        FuelExpenseBoxView(carID: car.id ?? "")
                            .groupBoxStyle(DetailBoxStyle(destination: FuelExpenseView(carID: car.id ?? "")))
                        
                        
                        
                        ServiceExpenseBoxView(carID: car.id ?? "")
                            .groupBoxStyle(DetailBoxStyle(destination: ServiceExpenseView(carID: car.id ?? "")))
                        
                        FutureServiceBoxView(carID: car.id ?? "")
                            .groupBoxStyle(DetailBoxStyle(destination: FutureServiceView(
                                                            carID: car.id ?? "")))
                        
                        
                    }.padding()
                }
            }.background(Color(.systemGroupedBackground)).edgesIgnoringSafeArea(.bottom)
            
            Spacer()
            
            Button("Add Expense") {
                self.showAddExpenseView = true
            }.sheet(isPresented: self.$showAddExpenseView) {
                AddExpenseView(carID: car.id ?? "")
                    .environment(\.managedObjectContext, self.moc)
            }
        }.navigationBarTitle(Text("\(car.year!) \(car.make!) \(car.model!)"),
                             displayMode: .inline)
    }
}
