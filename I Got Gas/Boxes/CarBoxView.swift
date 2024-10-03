//
//  CarBoxView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/17/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct CarBoxView: View {
    @State private var priceFormat = UserDefaults.standard.string(forKey: "priceFormat") ?? ""
    @Binding var car: Car
    init(car: Binding<Car>) {
        self._car = car
    }

    var body: some View {
        GroupBox(label: Label("\(car.year!) \(car.make!) \(car.model!) \(car.plate!)", systemImage: "car")) {
            VStack {
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
                        car.dpg()
                    }
                    Spacer()
                    
                    VStack {
                        Text("Last Fuel-Up")
                            .font(.system(size: 10))
                        Text(car.lastFillup == nil
                                ? "0"
                                : "\(car.lastFillup!, formatter: DateFormatter.taskDateFormat)")
                    }
                }
                Text("\(car.odometer)")
            }
            .font(.system(size: 20))
        }
    }
}
