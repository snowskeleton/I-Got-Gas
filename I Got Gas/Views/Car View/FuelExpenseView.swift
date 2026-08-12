//
//  FuelExpenseView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct FuelExpenseView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncManager.self) private var syncManager

    @Binding var car: SDCar
    let services: [SDService]
    let allServices: [SDService]
    @Bindable private var settings: SDCarSettings

    @State private var showAddFuelSheet = false
    @State private var showExistingFuelOrServiceSheet = false
    @State private var existingService: SDService?
    @State private var filtersHidden = false

    private let chartAnchor = "fuelChart"

    init(car: Binding<SDCar>, services: [SDService], allServices: [SDService]) {
        _car = car
        self.services = services
        self.allServices = allServices
        // Displayed as-is; onAppear persists one if the car doesn't have any.
        self.settings = car.wrappedValue.settings ?? SDCarSettings()
    }

    // Pairs each fill-up with the gap back to the previous entry: distance
    // driven, days elapsed, and the economy those miles imply.
    // services is sorted odometer descending, so services[i+1] is the prior fill.
    private struct Entry: Identifiable {
        let service: SDService
        let distance: Distance?
        let days: Int?
        let economy: FuelEconomy?

        var id: SDService { service }
        var hasGap: Bool { distance != nil || days != nil }
    }

    private var entries: [Entry] {
        services.enumerated().map { i, service in
            guard i < services.count - 1 else {
                return Entry(service: service, distance: nil, days: nil, economy: nil)
            }
            let previous = services[i + 1]

            let driven = service.odometer - previous.odometer
            let distance = driven.meters > 0 ? driven : nil

            let elapsed = Calendar.current.dateComponents(
                [.day], from: previous.date, to: service.date
            ).day
            let days = (elapsed ?? 0) >= 0 ? elapsed : nil

            var economy: FuelEconomy?
            if let distance {
                economy = FuelEconomy(distance: distance, volume: service.volume)
            }

            return Entry(service: service, distance: distance, days: days, economy: economy)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            list
                .hideChartFilters(below: chartAnchor, using: proxy, hidden: $filtersHidden)
        }
    }

    private var list: some View {
        List {
            Section {
                ChartFilterPanel(settings: settings, showsKindToggles: false)
            }

            Section {
                ChartView(economyOf: services.time(.days(settings.range)), car: car)
                    .frame(minHeight: 200)
                    .listRowInsets(EdgeInsets())
                    .id(chartAnchor)
            }

            Section {
                ForEach(entries) { entry in
                    Button {
                        existingService = entry.service
                        showExistingFuelOrServiceSheet = true
                    } label: {
                        FuelExpenseCard(
                            service: entry.service,
                            economy: entry.economy,
                            distanceUnit: car.distanceUnit
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)

                    if entry.hasGap {
                        GapRow(
                            distance: entry.distance,
                            days: entry.days,
                            distanceUnit: car.distanceUnit
                        )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 20))
                    }
                }
            }
        }
        .listRowSpacing(10.0)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddFuelSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddFuelSheet) {
            AddExpenseView(car: $car)
                .environment(syncManager)
        }
        .sheet(isPresented: $showExistingFuelOrServiceSheet) {
            if let existingService {
                AddExpenseView(car: $car, service: existingService)
                    .environment(syncManager)
            }
        }
        .onAppear {
            if car.settings == nil {
                context.insert(settings)
                car.settings = settings
            }
            Analytics.track(.openedFuelExpenses)
        }
    }
}

// Sits in the space between two fill-ups and describes the trip between them.
private struct GapRow: View {
    let distance: Distance?
    let days: Int?
    let distanceUnit: DistanceUnit

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .foregroundStyle(.quaternary)

            HStack(spacing: 4) {
                if let distance {
                    Text(distance.formatted(as: distanceUnit))
                }
                if distance != nil && days != nil {
                    Text("·").foregroundStyle(.tertiary)
                }
                if let days {
                    Text(days == 1 ? "1 day" : "\(days) days")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(minHeight: 28)
    }
}

private struct FuelExpenseCard: View {
    let service: SDService
    let economy: FuelEconomy?
    let distanceUnit: DistanceUnit

    private var volumeUnit: VolumeUnit { UnitPreferences.volumeUnit }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack {
                    Text(service.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(service.odometer.formatted(as: distanceUnit))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            
            HStack {
                VStack {
                    Text(service.cost.formatted())
                        .font(.title3).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    if let perUnit = service.costPerVolume {
                        Text("\(perUnit.formattedPerUnit())/\(volumeUnit.abbreviation)")
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack {
                    Text(service.volume.formatted(as: volumeUnit))
                        .foregroundStyle(.secondary)
                    if let economy {
                        Text(economy.formatted(
                            distance: distanceUnit,
                            volume: volumeUnit,
                            style: .preferred(distance: distanceUnit, volume: volumeUnit)
                        ))
                        .foregroundStyle(.secondary)
                    }
                }
            }
            
//            HStack {
//                Spacer()
//                if !service.vendorName.isEmpty {
//                    Text(service.vendorName)
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
//                        .lineLimit(1)
//                }
//            }
        }
        .padding(.vertical, 8)
    }
}
