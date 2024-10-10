//
//  TopDetailView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/11/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct TopDetailView: View {
    @Binding var car: SDCar
    @State private var priceFormat = UserDefaults.standard.string(forKey: "priceFormat") ?? ""
    
    init(car: Binding<SDCar>) {
        self._car = car
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack {
                    Text("Cost/Mile")
                        .font(.system(size: 10))
                    Text("$\(car.costPerMile, specifier: priceFormat)")
                }.padding(.leading)
                
                Spacer()
                
                VStack {
                    Text("Cost/Gal")
                        .font(.system(size: 10))
                    Text("$\(car.costPerGallon, specifier: priceFormat)")
                }
                Spacer()
                
            }
            .padding(.top)
            .font(.largeTitle)

            Text("\(car.odometer)")
        }
    }
}
