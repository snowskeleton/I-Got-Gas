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
    @Environment(SyncManager.self) private var syncManager

    @Binding var car: SDCar
    let services: [SDService]
    let allServices: [SDService]

    @State private var showAddFuelSheet = false
    @State private var showExistingFuelOrServiceSheet = false
    @State private var existingService: SDService?

    // Pairs each fill-up with the gap back to the previous entry: miles driven,
    // days elapsed, and the MPG those miles imply.
    // services is sorted odometer descending, so services[i+1] is the prior fill.
    private struct Entry: Identifiable {
        let service: SDService
        let miles: Int?
        let days: Int?
        let mpg: Double?

        var id: SDService { service }
        var hasGap: Bool { miles != nil || days != nil }
    }

    private var entries: [Entry] {
        services.enumerated().map { i, service in
            guard i < services.count - 1 else {
                return Entry(service: service, miles: nil, days: nil, mpg: nil)
            }
            let previous = services[i + 1]

            let milesDriven = service.odometer - previous.odometer
            let miles = milesDriven > 0 ? milesDriven : nil

            let elapsed = Calendar.current.dateComponents(
                [.day], from: previous.date, to: service.date
            ).day
            let days = (elapsed ?? 0) >= 0 ? elapsed : nil

            var mpg: Double?
            if let miles, service.gallons > 0 {
                mpg = Double(miles) / service.gallons
            }

            return Entry(service: service, miles: miles, days: days, mpg: mpg)
        }
    }

    var body: some View {
        List {
            Section {
                ChartView(title: "Miles per Gallon", mpg: services, isCurrency: false)
                    .frame(minHeight: 200)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                ForEach(entries) { entry in
                    Button {
                        existingService = entry.service
                        showExistingFuelOrServiceSheet = true
                    } label: {
                        FuelExpenseCard(service: entry.service, mpg: entry.mpg)
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
            Analytics.track(.openedFuelExpenses)
        }
    }
}

// Sits in the space between two fill-ups and describes the trip between them.
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

private struct FuelExpenseCard: View {
    let service: SDService
    let mpg: Double?

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
                HStack {
                    Text(service.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(service.odometer) mi")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            
            HStack {
                VStack {
                    Text("$\(service.cost, specifier: "%.2f")")
                        .font(.title3).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("$\(service.costPerGallon, specifier: "%.3f")/gal")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(service.gallons, specifier: "%.2f") gal")
                        .foregroundStyle(.secondary)
                    if let mpg {
                        Text("\(mpg, specifier: "%.1f") MPG")
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
