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
    @Environment(SyncManager.self) private var syncManager

    @Binding var car: SDCar
    let services: [SDService]
    let allServices: [SDService]

    @State private var showAddServiceSheet = false
    @State private var showExistingServiceSheet = false
    @State private var existingService: SDService?

    // Pairs each service with the gap back to the previous one: miles driven
    // and days elapsed.
    // services is sorted odometer descending, so services[i+1] is the prior service.
    private struct Entry: Identifiable {
        let service: SDService
        let miles: Int?
        let days: Int?

        var id: SDService { service }
        var hasGap: Bool { miles != nil || days != nil }
    }

    private var entries: [Entry] {
        services.enumerated().map { i, service in
            guard i < services.count - 1 else {
                return Entry(service: service, miles: nil, days: nil)
            }
            let previous = services[i + 1]

            let milesDriven = service.odometer - previous.odometer
            let miles = milesDriven > 0 ? milesDriven : nil

            let elapsed = Calendar.current.dateComponents(
                [.day], from: previous.date, to: service.date
            ).day
            let days = (elapsed ?? 0) >= 0 ? elapsed : nil

            return Entry(service: service, miles: miles, days: days)
        }
    }

    var body: some View {
        List {
            Section {
                ChartView(title: "Cost per Mile", costs: allServices, isCurrency: true)
                    .frame(minHeight: 200)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                ForEach(entries) { entry in
                    Button {
                        existingService = entry.service
                        showExistingServiceSheet = true
                    } label: {
                        MaintenanceExpenseCard(service: entry.service)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)

                    if entry.hasGap {
                        GapRow(miles: entry.miles, days: entry.days)
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
                    showAddServiceSheet = true
                } label: {
                    Image(systemName: "plus")
                }
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
            Analytics.track(.openedMaintenanceExpenses)
        }
    }

}

// Sits in the space between two services and describes the gap between them.
private struct GapRow: View {
    let miles: Int?
    let days: Int?

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .foregroundStyle(.quaternary)

            HStack(spacing: 4) {
                if let miles {
                    Text("\(miles) mi")
                }
                if miles != nil && days != nil {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if service.pending {
                Text("PENDING")
                    .font(.caption2).bold()
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            HStack {
                Text(service.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(service.odometer) mi")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(service.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("$\(service.cost, specifier: "%.2f")")
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
