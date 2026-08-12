//
//  MaintenanceExpenseView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct MaintenanceExpenseView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncManager.self) private var syncManager

    @Binding var car: SDCar
    let services: [SDService]
    let allServices: [SDService]
    @Bindable private var settings: SDCarSettings

    @State private var showAddServiceSheet = false
    @State private var showExistingServiceSheet = false
    @State private var existingService: SDService?

    init(car: Binding<SDCar>, services: [SDService], allServices: [SDService]) {
        _car = car
        self.services = services
        self.allServices = allServices
        // Displayed as-is; onAppear persists one if the car doesn't have any.
        self.settings = car.wrappedValue.settings ?? SDCarSettings()
    }

    private var chartServices: [SDService] {
        allServices
            .time(.days(settings.range))
            .fuel(settings.includeFuel)
            .maintenance(settings.includeMaintenance)
    }

    // Pairs each service with the gap back to the previous one: distance driven
    // and days elapsed.
    // services is sorted odometer descending, so services[i+1] is the prior service.
    private struct Entry: Identifiable {
        let service: SDService
        let distance: Distance?
        let days: Int?

        var id: SDService { service }
        var hasGap: Bool { distance != nil || days != nil }
    }

    private var entries: [Entry] {
        services.enumerated().map { i, service in
            guard i < services.count - 1 else {
                return Entry(service: service, distance: nil, days: nil)
            }
            let previous = services[i + 1]

            let driven = service.odometer - previous.odometer
            let distance = driven.meters > 0 ? driven : nil

            let elapsed = Calendar.current.dateComponents(
                [.day], from: previous.date, to: service.date
            ).day
            let days = (elapsed ?? 0) >= 0 ? elapsed : nil

            return Entry(service: service, distance: distance, days: days)
        }
    }

    var body: some View {
        List {
            Section {
                ChartView(costsOf: chartServices, car: car, range: settings.range)
                    .frame(minHeight: 200)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                ForEach(entries) { entry in
                    Button {
                        existingService = entry.service
                        showExistingServiceSheet = true
                    } label: {
                        MaintenanceExpenseCard(
                            service: entry.service,
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
        .floatingAddButton { showAddServiceSheet = true }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ChartFilterButton(settings: settings, showsKindToggles: true)
            }
        }
        .sheet(isPresented: $showAddServiceSheet) {
            AddExpenseView(car: $car, isGas: false)
                .environment(syncManager)
        }
        .sheet(isPresented: $showExistingServiceSheet) {
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
            Analytics.track(.openedMaintenanceExpenses)
        }
    }

}

// Sits in the space between two services and describes the gap between them.
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

private struct MaintenanceExpenseCard: View {
    let service: SDService
    let distanceUnit: DistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(service.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(service.odometer.formatted(as: distanceUnit))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(service.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(service.cost.formatted())
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            if !service.fullDescription.isEmpty {
                Text(service.fullDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
    }
}
