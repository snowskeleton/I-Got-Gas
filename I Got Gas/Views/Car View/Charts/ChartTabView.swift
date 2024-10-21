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
    @AppStorage("chartIncludeFuel") var includeFuel: Bool = true
    @AppStorage("chartIncludeMaintenance") var includeMaintenance: Bool = false
    @AppStorage("chartIncludePending") var includePending: Bool = false
    @AppStorage("chartIncludeCompleted") var includeCompleted: Bool = true

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ChartView(
                    title: "Miles per Gallon",
                    mpg: services.fuel().time(.days(range)),
                    isCurrency: false
                )
                .tag("MPG")
                
                ChartView(
                    title: "Cost per Mile",
                    costs: services
                        .time(.days(range))
                        .completed(includeCompleted)
                        .pending(includePending)
                        .fuel(includeFuel)
                        .maintenance(includeMaintenance),
                    isCurrency: true
                )
                .tag("Costs")
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
                Toggle("Fuel", isOn: $includeFuel)
                Toggle("Maintenance", isOn: $includeMaintenance)
                Toggle("Completed", isOn: $includeCompleted)
                Toggle("Pending", isOn: $includePending)
            }
            .presentationDetents([.medium])
        }
    }
}
