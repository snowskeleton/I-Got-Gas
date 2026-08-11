//
//  MainView.swift
//  I Got Gas
//
//  Created by snow on 6/27/25.
//  Copyright © 2025 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var context
    @Query var cars: [SDCar]
    @AppStorage("lastSelectedCarId") var lastSelectedCarId: String = ""
    @State private var showAddCar = false
    @State private var showLinkReview = false

    init() {
        let predicate = #Predicate<SDCar> {
            $0.archived == false && $0.deleted == false
        }
        _cars = Query(FetchDescriptor<SDCar>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.year, order: .reverse),
                SortDescriptor(\.make),
                SortDescriptor(\.model)
            ]
        ))
    }

    private var selectedCar: SDCar? {
        cars.first(where: { $0.id == lastSelectedCarId }) ?? cars.first
    }

    var body: some View {
        content
            .sheet(isPresented: $showLinkReview) {
                ScheduleLinkReviewView()
            }
            .task {
                // One-time after the 3.0 upgrade: confirm the links the
                // migration guessed from entry names.
                showLinkReview = ScheduleLinkReview.isPending(context: context)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let car = selectedCar {
            CarTabView(car: .constant(car), lastSelectedCarId: $lastSelectedCarId)
                .id(car.id)
        } else {
            NavigationStack {
                VStack(spacing: 20) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("No Vehicles Yet")
                        .font(.title2).fontWeight(.semibold)
                    Text("Add your first vehicle to get started.")
                        .foregroundStyle(.secondary)
                    Button("Add Vehicle") {
                        showAddCar = true
                    }
                    .buttonStyle(.borderedProminent)

                    // Settings lives inside the car tabs, so with no car there
                    // is no other way in — and an empty app after a bad
                    // migration is exactly when the backup tools are needed.
                    if Config.appConfiguration != .AppStore {
                        NavigationLink {
                            DeveloperMenuView()
                        } label: {
                            Label("Developer", systemImage: "hammer.fill")
                                .font(.footnote)
                        }
                        .padding(.top, 12)
                    }
                }
                .navigationTitle("I Got Gas")
            }
            .sheet(isPresented: $showAddCar) {
                AddCarView()
            }
        }
    }
}
