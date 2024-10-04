//
//  TopDetailView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/11/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct TopDetailView: View {
    @Binding var car: Car
    @State private var priceFormat = UserDefaults.standard.string(forKey: "priceFormat") ?? ""
    
    init(car: Binding<Car>) {
        self._car = car
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack {
                    Text("Cost Per Mile")
                        .font(.system(size: 10))
                    Text("\(car.costPerMile, specifier: "%.2f")/m")
                }.padding(.leading)
                
                Spacer()
                
                VStack {
                    Text("Avg $/gal")
                        .font(.system(size: 10))
                    Text(car.dpg)
                }
                Spacer()
                
            }
            .padding(.top)
            .font(.largeTitle)

            Text("\(car.odometer)")
        }
    }
}
