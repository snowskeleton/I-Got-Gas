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
    
    var fetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { fetchRequest.wrappedValue }
    
    init(carID: String) {
        fetchRequest = FetchRequest<Car>(entity: Car.entity(),
                                         sortDescriptors: [],
                                         predicate: NSPredicate(
                                            format: "id = %@", carID))
    }
    
    var body: some View {
        ForEach(car, id: \.self) { car in
            
            VStack {
                VStack {
                    HStack {
                        VStack {
                            Text("Cost Per Mile")
                                .font(.system(size: 10))
                            Text("\(car.costPerMile, specifier: "%.2f")/m")
                        }.padding(.leading)
                        
                        Spacer()
                        
                        VStack {
                            Text("Mean Fillup Time")
                                .font(.system(size: 10))
                            Text("6 days")
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("Avg $/gal")
                                .font(.system(size: 10))
                            Text("\(car.costPerGallon, specifier: "%.2f")/gal")
                        }.padding(.trailing)
                    }
                    .padding(.top)
                    .font(.system(size: 30))
                    
                    Text("\(car.odometer)")
                }
                
                Spacer()
                
                VStack {
                    ScrollView {
                        VStack(spacing: 8) {
                            FuelExpenseBoxView(carID: car.id ?? "")
                                .groupBoxStyle(DetailBoxStyle(
                                                color: .black,
                                                destination: FuelExpenseView(carID: car.id ?? "")))
                            MaintenanceBoxView(filter: car.id ?? "")
                            
                        }.padding()
                    }
                }.background(Color(.systemGroupedBackground)).edgesIgnoringSafeArea(.bottom)
                
                Spacer()
                
                Button("Add Expense") {
                    self.showAddExpenseView = true
                }.sheet(isPresented: self.$showAddExpenseView) {
                    AddExpenseView(filter: car.id ?? "")
                        .environment(\.managedObjectContext, self.moc)
                }
            }.navigationBarTitle(Text("\(car.year!) \(car.make!) \(car.model!)"),
                                 displayMode: .inline)
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
