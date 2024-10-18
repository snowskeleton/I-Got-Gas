//
//  ChartTabView.swift
//  I Got Gas
//
//  Created by snow on 10/16/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData
import Charts

struct ChartTabView: View {
    @Environment(\.presentationMode) var mode
    @Binding var car: SDCar
    var services: [SDService] {
        car.services ?? []
    }
    
    @State private var showFilterSheet = false
    
    @AppStorage("selectedChart") var selectedTab = "MPG"
    @AppStorage("chartHistory") var range: Int = 90
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ChartView(
                    title: "MPG",
                    mpg: services.fuel().time(.days(range)),
                    isCurrency: false
                )
                .tag("MPG")
                
                ChartView(
                    title: "Fuel Expenses",
                    costs: services.completed().fuel().time(.days(range)),
                    isCurrency: true
                )
                .tag("Fuel")
                
                ChartView(
                    title: "Maintenence Expenses",
                    costs: services.completed().maintenance().time(.days(range)),
                    isCurrency: true
                )
                .tag("Maintenence")
                
                ChartView(
                    title: "All Expenses",
                    costs: services.time(.days(range)),
                    isCurrency: true
                )
                .tag("All")
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
