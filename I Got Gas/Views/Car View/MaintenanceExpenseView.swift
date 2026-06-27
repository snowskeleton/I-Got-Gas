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
    @Environment(\.modelContext) var context
    @Environment(SyncManager.self) private var syncManager

    @Binding var car: SDCar

    @State private var services: [SDService] = []

    @State private var showAddFuelSheet = false
    @State private var showExistingFuelOrServiceSheet = false
    @State private var existingService: SDService?

    var body: some View {
        VStack {
            List {
                ForEach(services, id: \.self) { service in
                    Button(action: {
                        existingService = service
                        showExistingFuelOrServiceSheet = true
                    }) {
                        VStack {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(service.name)
                                    Text("$\(service.cost, specifier: "%.2f")")
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(service.date, formatter: DateFormatter.taskDateFormat)
                                    Text(service.odometer.description)
                                }
                            }
                            if !service.fullDescription.isEmpty {
                                Text(service.fullDescription)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            Spacer()
            Button(action: { showAddFuelSheet = true }) {
                Text("Add Expense")
            }
            .padding(.bottom)
        }
        .sheet(isPresented: $showAddFuelSheet, onDismiss: fetchServices) {
            AddExpenseView(car: $car)
                .environment(syncManager)
        }
        .sheet(isPresented: $showExistingFuelOrServiceSheet, onDismiss: fetchServices) {
            if let existingService {
                AddExpenseView(car: $car, service: existingService)
                    .environment(syncManager)
            }
        }
        .navigationTitle("Maintenance")
        .onAppear {
            fetchServices()
            Analytics.track(.openedMaintenanceExpenses)
        }
    }

    private func fetchServices() {
        let searchId = car.id
        let predicate = #Predicate<SDService> {
            $0.car?.id == searchId &&
            $0.isFuel == false &&
            $0.deleted == false
        }
        let descriptor = FetchDescriptor<SDService>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        services = (try? context.fetch(descriptor)) ?? []
    }

    func loseMemory(at offsets: IndexSet) {
        do {
            let _ = try offsets
                .map { _ in
                    try context
                        .delete(
                            model: SDScheduledService.self,
                            where: #Predicate<SDScheduledService> { $0.id == $0.id }
                        )}
        } catch { }
    }
}
