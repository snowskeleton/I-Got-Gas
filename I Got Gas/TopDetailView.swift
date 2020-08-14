//
//  TopDetailView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/11/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct TopDetailView: View {
    var carFetchRequest: FetchRequest<Car>
    var car: FetchedResults<Car> { carFetchRequest.wrappedValue }
    
    init(carID: String) {
        carFetchRequest = Fetch.car(carID: carID)
    }
    
    var body: some View {
        ForEach(car, id: \.self) { car in
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
            
        }
        
    }
}
