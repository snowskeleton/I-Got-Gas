//
//  ChartsView.swift
//  I Got Gas
//
//  Created by snow on 10/16/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData
import Charts

struct ChartsView: View {
    @Binding var car: SDCar
    @AppStorage("priceFormat") var priceFormat = "%.3f"
    
    @State private var selectedTab = "Fuel"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GenericChartView(
                title: "Fuel Expenses",
                services: car.services.completed().fuel()
            )
            .tag("Fuel")

            GenericChartView(
                title: "Maintenence Expenses",
                services: car.services.completed().maintenance()
            )
            .tag("Maintenence")
            
            GenericChartView(
                title: "All Expenses",
                services: car.services
            )
            .tag("All")
        }
        .tabViewStyle(.page)
//        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}
