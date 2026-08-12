//
//  DefaultFiltersView.swift
//  I Got Gas
//
//  Created by snow on 11/12/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//
//  The account-wide chart filters. Every vehicle not marked "Custom for This
//  Vehicle" reads these. They used to be @AppStorage, which stopped being the
//  backing store in 3.0 — this screen was editing keys nothing read.
//

import SwiftUI
import SwiftData

struct DefaultFiltersView: View {
    @Environment(\.modelContext) private var context

    @Query private var preferences: [SDUserPreferences]

    private var current: SDUserPreferences {
        preferences.first ?? SDUserPreferences.current(in: context)
    }

    var body: some View {
        @Bindable var preferences = current

        List {
            Picker("Date Range", selection: $preferences.defaultRange) {
                ForEach(ChartFilterRange.all, id: \.self) { days in
                    Text(ChartFilterRange.label(days)).tag(days)
                }
            }
            Toggle("Fuel", isOn: $preferences.defaultIncludeFuel)
            Toggle("Maintenance", isOn: $preferences.defaultIncludeMaintenance)
        }
        .navigationTitle("Default Filters")
        .onDisappear {
            current.touch()
            try? context.save()
        }
    }
}
