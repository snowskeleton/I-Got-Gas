//
//  CarSettingsTests.swift
//  I Got GasTests
//
//  The chart filters read through SDCarSettings, which redirects to the
//  account defaults whenever a car isn't marked custom. These cover that
//  redirect actually round-tripping — the filters looked stuck otherwise.
//

import Testing
import Foundation
import SwiftData
@testable import I_Got_Gas

@MainActor
struct CarSettingsTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: SDCarSettings.self, SDUserPreferences.self, SDCar.self, SDService.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func nonCustomRangeWritesThroughToAccountDefaults() throws {
        let context = try makeContext()
        let preferences = SDUserPreferences.current(in: context)
        let settings = SDCarSettings()
        context.insert(settings)

        #expect(settings.custom == false)
        settings.range = 365

        #expect(preferences.defaultRange == 365)
        #expect(settings.range == 365)
    }

    @Test func detachedSettingsKeepTheirOwnWrites() throws {
        // Not yet inserted, so there is no context to reach the defaults
        // through — the state a car with no settings row starts in. This used
        // to drop the write and report 90 forever, which read in the UI as the
        // date range being stuck on "3 months".
        let settings = SDCarSettings()
        settings.range = 365
        #expect(settings.range == 365)
    }

    @Test func togglesAndTabAlsoWriteThrough() throws {
        let context = try makeContext()
        let preferences = SDUserPreferences.current(in: context)
        let settings = SDCarSettings()
        context.insert(settings)

        settings.includeFuel = false
        settings.includeMaintenance = false
        settings.selectedTab = "Costs"

        #expect(preferences.defaultIncludeFuel == false)
        #expect(preferences.defaultIncludeMaintenance == false)
        #expect(preferences.defaultSelectedTab == "Costs")
        #expect(settings.includeFuel == false)
        #expect(settings.includeMaintenance == false)
    }

    @Test func switchingToCustomSeedsFromTheAccountDefaults() throws {
        let context = try makeContext()
        let preferences = SDUserPreferences.current(in: context)
        let settings = SDCarSettings()
        context.insert(settings)

        preferences.defaultRange = 180
        settings.custom = true

        #expect(settings.range == 180)
    }

    @Test func customRangeStaysOnTheCar() throws {
        let context = try makeContext()
        let preferences = SDUserPreferences.current(in: context)
        let settings = SDCarSettings()
        context.insert(settings)

        settings.custom = true
        settings.range = 730

        #expect(settings.range == 730)
        #expect(preferences.defaultRange == 90)
    }
}
