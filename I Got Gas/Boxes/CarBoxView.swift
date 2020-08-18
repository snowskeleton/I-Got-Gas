//
//  CarBoxView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/17/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct CarBoxView: View {
    @Environment(\.colorScheme) var colorScheme
    var car: Car
    
    var body: some View {
        GroupBox(label: ImageAndTextLable(systemImage: "car.circle", text: "\(car.year!) \(car.make!) \(car.model!)")) {
            HStack {
                VStack {
                    Text("Cost Per Mile")
                        .font(.system(size: 10))
                    Text("\(car.costPerMile, specifier: "%.2f")/m")
                }.padding(.leading)
                
                Spacer()
                
                VStack {
                    Text("Avg $/gal")
                        .font(.system(size: 10))
                    Text("\(car.costPerGallon, specifier: "%.2f")/gal")
                }
                Spacer()
                
                VStack {
                    Text("Last Fuel-Up")
                        .font(.system(size: 10))
                    Text(car.lastFillup == nil ? "0" : "\(car.lastFillup!)")
                }
            }
            .font(.system(size: 20))
        }
    }
}
