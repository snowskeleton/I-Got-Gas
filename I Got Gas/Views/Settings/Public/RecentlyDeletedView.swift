//
//  RecentlyDeletedView.swift
//  I Got Gas
//
//  Deleted records are tombstoned rather than removed, and expire after 30
//  days. This is where they can be brought back before that happens — and it
//  is also the only place the tombstones are visible at all, which previously
//  meant a mis-tap was effectively unrecoverable.
//

import SwiftUI
import SwiftData

struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncManager.self) private var syncManager

    @Query(filter: #Predicate<SDService> { $0.deleted == true },
           sort: \SDService.updatedAt, order: .reverse)
    private var services: [SDService]

    @Query(filter: #Predicate<SDScheduledService> { $0.deleted == true },
           sort: \SDScheduledService.updatedAt, order: .reverse)
    private var schedules: [SDScheduledService]

    @Query(filter: #Predicate<SDCar> { $0.deleted == true },
           sort: \SDCar.updatedAt, order: .reverse)
    private var cars: [SDCar]

    private var isEmpty: Bool {
        services.isEmpty && schedules.isEmpty && cars.isEmpty
    }

    var body: some View {
        List {
            if isEmpty {
                ContentUnavailableView(
                    "Nothing Deleted",
                    systemImage: "trash",
                    description: Text("Deleted items appear here for \(TombstoneRetention.days) days.")
                )
            }

            if !cars.isEmpty {
                Section("Vehicles") {
                    ForEach(cars) { car in
                        row(title: car.visualName, deletedAt: car.updatedAt) {
                            car.deleted = false
                            car.touch()
                            syncManager.recordCar(car)
                        }
                    }
                }
            }

            if !services.isEmpty {
                Section("Expenses") {
                    ForEach(services) { service in
                        row(
                            title: service.displayName.isEmpty ? "Expense" : service.displayName,
                            subtitle: service.cost.formatted(),
                            deletedAt: service.updatedAt
                        ) {
                            service.deleted = false
                            service.touch()
                            syncManager.recordService(service)
                        }
                    }
                }
            }

            if !schedules.isEmpty {
                Section("Schedules") {
                    ForEach(schedules) { schedule in
                        row(title: schedule.name, deletedAt: schedule.updatedAt) {
                            schedule.deleted = false
                            schedule.touch()
                            syncManager.recordSchedule(schedule)
                        }
                    }
                }
            }
        }
        .navigationTitle("Recently Deleted")
    }

    @ViewBuilder
    private func row(
        title: String,
        subtitle: String? = nil,
        deletedAt: Date,
        restore: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                HStack(spacing: 4) {
                    if let subtitle {
                        Text(subtitle)
                        Text("·")
                    }
                    Text(TombstoneRetention.remainingDescription(deletedAt: deletedAt))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Restore") {
                restore()
                try? context.save()
                Task { await NotificationReconciler.reconcile(context: context) }
            }
            .buttonStyle(.borderless)
        }
    }
}

/// Retention policy, shared by the UI and the local purge. Must match the
/// server's window in internal/store/postgres/purge.go.
enum TombstoneRetention {
    static let days = 30

    static func expiry(deletedAt: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: deletedAt) ?? deletedAt
    }

    static func remainingDescription(deletedAt: Date) -> String {
        let remaining = Calendar.current.dateComponents(
            [.day], from: Date(), to: expiry(deletedAt: deletedAt)
        ).day ?? 0

        if remaining <= 0 { return "Expires today" }
        if remaining == 1 { return "1 day left" }
        return "\(remaining) days left"
    }
}
