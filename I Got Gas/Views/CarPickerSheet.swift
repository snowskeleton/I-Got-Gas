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
                    Button {
                        lastSelectedCarId = car.id
                        dismiss()
                    } label: {
                        HStack {
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
                            if car.id == lastSelectedCarId {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Button {
                    showAddCar = true
                } label: {
                    Label("Add New Vehicle", systemImage: "plus.circle.fill")
                }
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
