//
//  ChartFilterPanel.swift
//  I Got Gas
//
//  Created by snow on 8/11/26.
//  Copyright © 2026 Blizzard Skeleton. All rights reserved.
//
//  The chart filters live in the top-right of the toolbar on the Fuel and
//  Maintenance screens. The chart itself prints whichever range is selected,
//  so the icon doesn't need a label to explain itself.
//

import SwiftUI
import SwiftData

/// The date ranges offered by both the per-vehicle sheet and the account
/// defaults screen, so the two can't drift apart.
enum ChartFilterRange {
    static let all = [90, 180, 365, 730, 0]

    static func label(_ days: Int) -> String {
        switch days {
        case 90: "3 months"
        case 180: "6 months"
        case 365: "1 year"
        case 730: "2 years"
        default: "All time"
        }
    }
}

/// Toolbar button that opens the chart filters in a half sheet.
struct ChartFilterButton: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncManager.self) private var syncManager

    @Bindable var settings: SDCarSettings

    /// The fuel/maintenance toggles only mean something for the cost chart,
    /// which draws on every kind of service.
    var showsKindToggles: Bool

    @State private var showFilterSheet = false

    var body: some View {
        Button {
            showFilterSheet = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Chart Filters")
        .sheet(isPresented: $showFilterSheet) {
            NavigationStack {
                List {
                    Picker("Date Range", selection: $settings.range) {
                        ForEach(ChartFilterRange.all, id: \.self) { days in
                            Text(ChartFilterRange.label(days)).tag(days)
                        }
                    }

                    if showsKindToggles {
                        Toggle("Fuel", isOn: $settings.includeFuel)
                        Toggle("Maintenance", isOn: $settings.includeMaintenance)
                    }

                    Section {
                        Toggle("Custom for This Vehicle", isOn: $settings.custom)
                    } footer: {
                        Text("Off, these filters follow the account defaults and apply to every vehicle.")
                    }
                }
                .navigationTitle("Chart Filters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showFilterSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .onDisappear { persist() }
        }
    }

    private func persist() {
        settings.touch()
        try? context.save()
        syncManager.recordSettings(settings)
        Analytics.track(
            .serviceFilterSettings,
            with: [
                "range": settings.range.description,
                "fuel": settings.includeFuel.description,
                "maintenance": settings.includeMaintenance.description
            ]
        )
    }
}
