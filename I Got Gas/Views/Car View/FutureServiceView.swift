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
    @Environment(\.modelContext) var context
    @Environment(SyncManager.self) private var syncManager

    @Binding var car: SDCar

    @State private var futureServices: [SDScheduledService] = []

    @State private var showAddScheduldServiceSheet = false
    @State private var showExistingScheduledServiceSheet = false
    @State private var existingFutureService: SDScheduledService?

    var body: some View {
        VStack {
            List {
                ForEach(futureServices, id: \.self) { futureService in
                    Button(action: {
                        existingFutureService = futureService
                        showExistingScheduledServiceSheet = true
                    }) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(futureService.name)
                                Spacer()
                                VStack {
                                    Text(futureService.frequencyTime == 0 ? "" : "\(Calendar.current.date(byAdding: futureService.frequencyTimeInterval.calendarComponent, value: futureService.frequencyTime, to: Date())!, formatter: DateFormatter.taskDateFormat)")
                                    Text(futureService.odometerFirstOccurance.description)
                                }
                            }
                            if !futureService.fullDescription.isEmpty {
                                Text(futureService.fullDescription)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            Button("Schedule Service") {
                showAddScheduldServiceSheet = true
            }
            .padding(.bottom)
        }
        .sheet(isPresented: $showAddScheduldServiceSheet, onDismiss: fetchServices) {
            AddFutureServiceView(car: $car)
                .environment(syncManager)
        }
        .sheet(isPresented: $showExistingScheduledServiceSheet, onDismiss: fetchServices) {
            if let existingFutureService {
                AddFutureServiceView(car: $car, futureService: existingFutureService)
                    .environment(syncManager)
            }
        }
        .onAppear {
            fetchServices()
            Analytics.track(.openedScheduledServices)
        }
    }

    private func fetchServices() {
        let searchId = car.id
        let predicate = #Predicate<SDScheduledService> {
            $0.car?.id == searchId &&
            $0.deleted == false
        }
        let descriptor = FetchDescriptor<SDScheduledService>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.frequencyTime, order: .forward)]
        )
        futureServices = (try? context.fetch(descriptor)) ?? []
    }

    func loseMemory(at offsets: IndexSet) {
        do {
            let _ = try offsets
                .map { _ in
                    try context
                        .delete(
                            model: SDService.self,
                            where: #Predicate<SDService> { $0.id == $0.id }
                        )}
        } catch { }
    }
}
