//
//  CarPickerSheet.swift
//  I Got Gas
//
//  Created by snow on 6/27/25.
//  Copyright © 2025 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct CarPickerSheet: View {
    @Query var cars: [SDCar]
    @Binding var lastSelectedCarId: String
    @Environment(\.dismiss) private var dismiss
    @State private var showAddCar = false
    @State private var detailsCar: SDCar?

    init(lastSelectedCarId: Binding<String>) {
        _lastSelectedCarId = lastSelectedCarId
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

    var body: some View {
        NavigationStack {
            List {
                ForEach(cars, id: \.self) { car in
                    HStack {
                        // Selecting the vehicle and opening its details are two
                        // separate taps, so each gets its own button.
                        Button {
                            lastSelectedCarId = car.id
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .opacity(car.id == lastSelectedCarId ? 1 : 0)
                                VStack(alignment: .leading) {
                                    Text(car.visualName)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    if !car.plate.isEmpty {
                                        Text(car.plate)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button("Details") {
                            detailsCar = car
                        }
                        .buttonStyle(.borderless)
                        .font(.subheadline)
                    }
                }
                Button {
                    showAddCar = true
                } label: {
                    Label("Add New Vehicle", systemImage: "plus.circle.fill")
                }
            }
            .navigationDestination(item: $detailsCar) { car in
                CarInfoView(car: Binding<SDCar>.constant(car))
            }
            .navigationTitle("Select Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showAddCar) {
            AddCarView()
        }
    }
}
