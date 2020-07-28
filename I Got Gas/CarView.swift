//
//  SwiftUIView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

//struct CarView: View {
//    @Environment(\.managedObjectContext) var managedObjectContext
//    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
//
////    let id: String
//
//    var body: some View {
//        CarSubView(filter: id)
//    }
//}

struct CarView: View {
    var fetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { fetchRequest.wrappedValue }
    
    init(filter: String) {
        fetchRequest = FetchRequest<Car>(entity: Car.entity(), sortDescriptors: [], predicate: NSPredicate(format: "idea BEGINSWITH %@", filter))
    }
    
    var body: some View {
        ForEach(car, id: \.self) { car in
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .padding(.leading)
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text(car.name ?? "")
                    Text("\(car.year ?? "") \(car.make ?? "") \(car.model ?? "")")
                    Text("Some number stats")
                }
                
                Spacer()
            }
            .padding(.vertical, 20)
            .background(Color.blue)
            .opacity(0.8)
            .cornerRadius(20)
            .padding(.horizontal, 20)
            
        }
    }
}

struct CarView_Previews: PreviewProvider {
    static var previews: some View {
        CarView(filter: "Hello, Doctor")
    }
}
