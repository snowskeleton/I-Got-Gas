//
//  FutureServiceView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/2/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct FutureServiceView: View {
    @Environment(SyncManager.self) private var syncManager

    @Binding var car: SDCar
    let scheduledServices: [SDScheduledService]

    @State private var showAddScheduledServiceSheet = false
    @State private var showExistingScheduledServiceSheet = false
    @State private var existingFutureService: SDScheduledService?

    private var distanceUnit: DistanceUnit { car.distanceUnit }

    var body: some View {
        List {
            Section("Upcoming") {
                ForEach(scheduledServices, id: \.self) { service in
                    Button {
                        existingFutureService = service
                        showExistingScheduledServiceSheet = true
                    } label: {
                        ScheduleCard(service: service, distanceUnit: distanceUnit)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddScheduledServiceSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddScheduledServiceSheet) {
            AddFutureServiceView(car: $car)
                .environment(syncManager)
        }
        .sheet(isPresented: $showExistingScheduledServiceSheet) {
            if let existingFutureService {
                AddFutureServiceView(car: $car, futureService: existingFutureService)
                    .environment(syncManager)
            }
        }
        .onAppear {
            Analytics.track(.openedScheduledServices)
        }
    }
}

private struct ScheduleCard: View {
    let service: SDScheduledService
    let distanceUnit: DistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(service.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if service.isCompleted {
                    Text("DONE")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                } else if service.isDue {
                    Text("DUE")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            if service.isMileageBased {
                HStack {
                    Label(
                        "Every \(service.frequencyDistance.formatted(as: distanceUnit))",
                        systemImage: "speedometer"
                    )
                    Spacer()
                    if let remaining = service.distanceRemaining {
                        if remaining.meters >= 0 {
                            Text("In \(remaining.formatted(as: distanceUnit))")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(Distance(meters: -remaining.meters).formatted(as: distanceUnit)) overdue")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .font(.subheadline)
            }

            // Next due is derived from the last completion, so this is the
            // real date rather than "today plus the interval".
            if service.isTimeBased, let nextDate = service.nextDueDate {
                HStack {
                    Label(
                        "Every \(service.frequencyTime) \(service.frequencyTimeInterval.description)(s)",
                        systemImage: "calendar"
                    )
                    Spacer()
                    Text(nextDate, format: .dateTime.month(.abbreviated).day().year())
                        .foregroundStyle(service.isDue ? .red : .secondary)
                }
                .font(.subheadline)
            }

            if let last = service.lastCompletion {
                HStack {
                    Label("Last done", systemImage: "checkmark.circle")
                    Spacer()
                    Text(last.date, format: .dateTime.month(.abbreviated).day().year())
                }
                .font(.caption)
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
