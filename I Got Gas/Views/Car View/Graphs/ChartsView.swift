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
    @Environment(\.presentationMode) var mode
    @Binding var car: SDCar
    @AppStorage("priceFormat") var priceFormat = "%.3f"
    
    @State private var selectedTab = "MPG"
    @State private var showFilterSheet = false
    @AppStorage("chartHistory") var range: Int = 90
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                LineChartView(
                    title: "Fuel Expenses",
                    services: car.services.completed().fuel().time(.days(range))
                )
                .tag("Fuel")
                
                LineChartView(
                    title: "Maintenence Expenses",
                    services: car.services.completed().maintenance().time(.days(range))
                )
                .tag("Maintenence")
                
                LineChartView(
                    title: "All Expenses",
                    services: car.services.time(.days(range))
                )
                .tag("All")
                
                BarChartView(
                    title: "MPG",
                    services: car.services.fuel().time(.days(range))
                )
                .tag("MPG")
            }
            .tabViewStyle(.page)
            //        .indexViewStyle(.page(backgroundDisplayMode: .always))
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .padding()
                            .contentShape(Rectangle())
                    }
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            List {
                Picker("Date Range", selection: $range) {
                    Text("3 months").tag(90)
                    Text("6 months").tag(180)
                    Text("1 year").tag(365)
                    Text("2 year").tag(730)
                }
            }
            .presentationDetents([.medium])
        }
    }
}
