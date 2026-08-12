//
//  ChartFilterPanel.swift
//  I Got Gas
//
//  Created by snow on 8/11/26.
//  Copyright © 2026 Blizzard Skeleton. All rights reserved.
//
//  The chart filters that used to live behind a button on the chart itself.
//  The link to them now sits in a section above the top of the list, off
//  screen until the user pulls down — see `hideChartFilters(below:)`.
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

/// A single row that opens the filters in a half sheet. Meant to be dropped
/// straight into a `Section` so it picks up normal list row styling.
struct ChartFilterPanel: View {
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
            HStack {
                Label("Chart Filters", systemImage: "line.3.horizontal.decrease.circle")
                Spacer()
                Text(ChartFilterRange.label(settings.range))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
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

// MARK: - Pull-down reveal

extension View {
    /// Starts the list scrolled so everything above `anchor` — the filter
    /// section — is off screen. Pulling down brings it back, Mail-search style.
    func hideChartFilters(below anchor: String, using proxy: ScrollViewProxy, hidden: Binding<Bool>) -> some View {
        onAppear {
            guard !hidden.wrappedValue else { return }
            hidden.wrappedValue = true
            Task { @MainActor in
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
    }
}
