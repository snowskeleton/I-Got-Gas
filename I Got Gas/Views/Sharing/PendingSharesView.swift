//
//  SharedVehiclesView.swift
//  I Got Gas
//
//  Created by Claude on 2025.
//

import SwiftUI
import SwiftData

struct SharedVehiclesView: View {
    @Environment(ShareManager.self) private var shareManager
    @Environment(SyncManager.self) private var syncManager
    @Query(filter: #Predicate<SDCar> { $0.deleted == false }) private var cars: [SDCar]

    private var pendingShares: [ShareResponse] {
        shareManager.receivedShares.filter { $0.status == "pending" }
    }

    private var activeShares: [ShareResponse] {
        shareManager.receivedShares.filter { $0.status == "accepted" }
    }

    var body: some View {
        List {
            if !pendingShares.isEmpty {
                Section("Pending Invitations") {
                    ForEach(pendingShares) { share in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Vehicle shared with you")
                                    .font(.headline)
                                Text(share.ownerEmail ?? "Unknown")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Accept") {
                                Task {
                                    await shareManager.acceptShare(shareID: share.id)
                                    syncManager.triggerSync()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button("Decline") {
                                Task { await shareManager.declineShare(shareID: share.id) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Decline", role: .destructive) {
                                Task { await shareManager.declineShare(shareID: share.id) }
                            }
                        }
                    }
                }
            }

            if !activeShares.isEmpty {
                Section("Active") {
                    ForEach(activeShares) { share in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(carName(for: share.carID))
                                    .font(.headline)
                                Text(share.ownerEmail ?? "Unknown")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Leave", role: .destructive) {
                                Task { await shareManager.leaveShare(shareID: share.id) }
                            }
                        }
                    }
                }
            }

            if pendingShares.isEmpty && activeShares.isEmpty {
                Text("No shared vehicles")
                    .foregroundStyle(.secondary)
            }

            if let error = shareManager.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("Shared Vehicles")
        .task {
            await shareManager.fetchReceivedShares()
        }
    }

    private func carName(for carID: String) -> String {
        if let car = cars.first(where: { $0.id == carID }) {
            let name = car.name.isEmpty ? "\(car.make) \(car.model)" : car.name
            return name.trimmingCharacters(in: .whitespaces).isEmpty ? "Shared Vehicle" : name
        }
        return "Shared Vehicle"
    }
}
