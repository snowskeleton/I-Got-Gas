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
    @Query var cars: [SDCar]
    @AppStorage("lastSelectedCarId") var lastSelectedCarId: String = ""
    @State private var showAddCar = false

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
                }
                .navigationTitle("I Got Gas")
            }
            .sheet(isPresented: $showAddCar) {
                AddCarView()
            }
        }
    }
}
