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
    
    @State private var selectedTab = "Default"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FuelChart90DayView(car: Binding<SDCar>.constant(car))
                .tag("Default")
            
            MaintenenceChart90DayView(car: Binding<SDCar>.constant(car))
                .tag("Optional")
        }
        .tabViewStyle(.page)
    }
}
