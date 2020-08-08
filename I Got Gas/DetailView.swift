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
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    
    
    @State var showAddExpenseView = false
    @State var showServiceView = false
    
    var fetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { fetchRequest.wrappedValue }
    
    static let taskDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    init(filter: String) {
        fetchRequest = FetchRequest<Car>(entity: Car.entity(),
                                         sortDescriptors: [],
                                         predicate: NSPredicate(
                                            format: "id BEGINSWITH %@", filter))
    }
    
    var body: some View {
        ForEach(car, id: \.self) { car in
            
            VStack {
                CarView(filter: car.id ?? "").padding()
                Spacer()
                
                VStack {
                    
                    
                    ScrollView {
                        VStack(spacing: 8) {
//                            ExpensesBoxView(filter: car.id ?? "").environment(\.managedObjectContext, self.moc)

                            ExpensesBoxView(filter: car.id ?? "")
                                .environment(\.managedObjectContext, self.moc)
                                .groupBoxStyle(HealthGroupBoxStyle(
                                                color: .black,
                                                destination: ServiceView(filter: car.id ?? "")
                                                    .environment(\.managedObjectContext, self.moc)))
                            
                            
                            //more boxes
                            MaintainanceBoxView(filter: car.id ?? "").environment(\.managedObjectContext, self.moc)
                            
                        }.padding()
                        
                        
                        //                        Section(header: Text("General information")) {
                        //                            HStack {
                        //                                Text("Odometer")
                        //                                Spacer()
                        //                                Text("\(car.odometer)")
                        //                            }
                        //                            HStack {
                        //                                Text("Current MPG")
                        //                                Spacer()
                        //                                Text("42/g")
                        //                            }
                        //                            HStack {
                        //                                Text("Last Fillup")
                        //                                Spacer()
                        //                                Text(car.lastFillup == nil ? "" : "\( car.lastFillup!, formatter: ServiceView.self.taskDateFormat)")
                        //                            }
                        //                        }
                        //                        Section(header: Text("Service")) {
                        //                            Text("Oil change")
                        //                            Text("Break Check")
                        //                            Text("Other service")
                        //                            Text("Something important")
                        //                        }
                    }                        }.background(Color(.systemGroupedBackground)).edgesIgnoringSafeArea(.bottom)
                
                
                Spacer()
                Button("Services") {
                    self.showServiceView = true
                }.sheet(isPresented: self.$showServiceView) {
                    ServiceView(filter: car.id ?? "")
                        .environment(\.managedObjectContext, self.moc)
                }
                
                Button("Add Expense") {
                    self.showAddExpenseView = true
                }.sheet(isPresented: self.$showAddExpenseView) {
                    AddExpenseView(filter: car.id ?? "")
                        .environment(\.managedObjectContext, self.moc)
                }
                
                
            }.navigationBarTitle(Text(""), displayMode: .inline)
        }
    }
}

struct ExpensesBoxView: View {
    var fetchRequest: FetchRequest<Service>
    var services: FetchedResults<Service> { fetchRequest.wrappedValue }
    
    init(filter: String) {
        let request: NSFetchRequest<Service> = Service.fetchRequest()
        request.fetchLimit = 4
        request.predicate = NSPredicate(format: "vehicle.id BEGINSWITH %@", filter)
        request.sortDescriptors = []
        fetchRequest = FetchRequest<Service>(fetchRequest: request)
        
    }
    
    var body: some View {
        
        GroupBox(label: ExpenseLable()) {
            VStack(alignment: .leading) {
                ForEach(services, id: \.self) { service in
                    HStack {
                        Text("$\(service.cost, specifier: "%.2f")")
                        Spacer()
                        Text("\(service.date!, formatter: ServiceView.self.taskDateFormat)")
                    }
                }
            }
        }
    }
}

struct MaintainanceBoxView: View {
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    
    var fetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { fetchRequest.wrappedValue }
    init(filter: String) {
        fetchRequest = FetchRequest<Car>(entity: Car.entity(),
                                         sortDescriptors: [],
                                         predicate: NSPredicate(
                                            format: "id BEGINSWITH %@", filter))
    }
    
    
    var body: some View {
        ForEach(car, id: \.self) { car in
            GroupBox(label: MaintainanceLable()) {
                VStack(alignment: .leading) {
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
                    
                }
            }.groupBoxStyle(HealthGroupBoxStyle(color: .black, destination: ServiceView(filter: car.id ?? "").environment(\.managedObjectContext, self.moc)))
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
