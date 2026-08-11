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

    private var currentOdometer: Int {
        car.odometer
    }

    var body: some View {
        List {
            Section("Upcoming") {
                ForEach(scheduledServices, id: \.self) { service in
                    Button {
                        existingFutureService = service
                        showExistingScheduledServiceSheet = true
                    } label: {
                        ScheduleCard(service: service, currentOdometer: currentOdometer)
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
    let currentOdometer: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(service.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if service.pastDue {
                    Text("PAST DUE")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            if service.frequencyMiles > 0 {
                let milesLeft = service.odometerFirstOccurance - currentOdometer
                HStack {
                    Label("Every \(service.frequencyMiles) mi", systemImage: "speedometer")
                    Spacer()
                    if milesLeft >= 0 {
                        Text("In \(milesLeft) mi")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(-milesLeft) mi overdue")
                            .foregroundStyle(.red)
                    }
                }
                .font(.subheadline)
            }

            if service.frequencyTime > 0,
               let nextDate = Calendar.current.date(
                byAdding: service.frequencyTimeInterval.calendarComponent,
                value: service.frequencyTime,
                to: Date()
               ) {
                HStack {
                    Label(
                        "Every \(service.frequencyTime) \(service.frequencyTimeInterval.description)(s)",
                        systemImage: "calendar"
                    )
                    Spacer()
                    Text(nextDate, format: .dateTime.month(.abbreviated).year())
                        .foregroundStyle(service.pastDue ? .red : .secondary)
                }
                .font(.subheadline)
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
