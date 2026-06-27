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
    @Environment(\.modelContext) private var context
    @Environment(\.presentationMode) var mode

    @Binding var car: SDCar
    let services: [SDService]
    @Bindable var settings: SDCarSettings

    @State private var showFilterSheet = false

    init(car: Binding<SDCar>, services: [SDService]) {
        _car = car
        self.services = services
        // Use existing settings for display; onAppear will persist one if missing.
        self.settings = car.wrappedValue.settings ?? SDCarSettings()
    }

    var body: some View {
        ZStack {
            TabView(selection: $settings.selectedTab) {
                ChartView(
                    title: "Miles per Gallon",
                    mpg: services.fuel().time(.days(settings.range)),
                    isCurrency: false
                )
                .tag("MPG")

                ChartView(
                    title: "Cost per Mile",
                    costs: services
                        .time(.days(settings.range))
                        .completed(settings.includeCompleted)
                        .pending(settings.includePending)
                        .fuel(settings.includeFuel)
                        .maintenance(settings.includeMaintenance),
                    isCurrency: true
                )
                .tag("Costs")
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
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
                Picker("Date Range", selection: $settings.range) {
                    Text("3 months").tag(90)
                    Text("6 months").tag(180)
                    Text("1 year").tag(365)
                    Text("3 year").tag(730)
                    Text("All time").tag(0)
                }
                Toggle("Fuel", isOn: $settings.includeFuel)
                Toggle("Maintenance", isOn: $settings.includeMaintenance)
                Toggle("Completed", isOn: $settings.includeCompleted)
                Toggle("Pending", isOn: $settings.includePending)

                Section {
                    Toggle("Custom for This Vehicle", isOn: $settings.custom)
                }
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            if car.settings == nil {
                let newSettings = SDCarSettings()
                context.insert(newSettings)
                car.settings = newSettings
            }
            Analytics.track(
                .serviceFilterSettings,
                with: [
                    "tab": settings.selectedTab,
                    "range": settings.range.description,
                    "fuel": settings.includeFuel.description,
                    "maintenance": settings.includeMaintenance.description,
                    "completed": settings.includeCompleted.description,
                    "pending": settings.includePending.description
                ]
            )
        }
    }
}
