//
//  MigrationTests.swift
//  I Got GasTests
//
//  Opens stores written in each shipped 2.x shape with the real migration
//  plan. 3.0 build 4 went to the App Store unable to open any 2.0.1 store,
//  because the plan only knew the unreleased cloud-saves 2.x shape.
//

import Testing
import Foundation
import SwiftData
@testable import I_Got_Gas

@MainActor
struct MigrationTests {

    private func temporaryStoreURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("igg-migration-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("default.store")
    }

    private func openCurrent(at url: URL) throws -> ModelContainer {
        let schema = Schema(IGGSchemaV3.models)
        return try ModelContainer(
            for: schema,
            migrationPlan: IGGMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
    }

    @Test func appStore201StoreMigrates() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        do {
            let schema = Schema(versionedSchema: IGGSchemaV1.self)
            let container = try ModelContainer(
                for: schema, configurations: [ModelConfiguration(schema: schema, url: url)]
            )
            let context = ModelContext(container)
            let car = IGGSchemaV1.SDCar()
            car.id = "car-1"
            car.name = "Civic"
            car.startingOdometer = 40_000
            context.insert(car)

            let fill = IGGSchemaV1.SDService()
            fill.id = "svc-1"
            fill.cost = 41.37
            fill.gallons = 10.5
            fill.odometer = 41_000
            fill.isFuel = true
            fill.car = car
            context.insert(fill)

            let schedule = IGGSchemaV1.SDScheduledService()
            schedule.id = "sched-1"
            schedule.name = "Oil change"
            schedule.frequencyMiles = 5_000
            schedule.odometerFirstOccurance = 45_000
            schedule.frequencyTime = 6
            schedule.car = car
            context.insert(schedule)
            try context.save()
        }

        let container = try openCurrent(at: url)
        let context = ModelContext(container)

        let cars = try context.fetch(FetchDescriptor<SDCar>())
        #expect(cars.map(\.id) == ["car-1"])
        #expect(cars.first?.name == "Civic")

        let services = try context.fetch(FetchDescriptor<SDService>())
        #expect(services.count == 1)
        let service = try #require(services.first)
        #expect(service.costMinor == 4137)
        #expect(service.kind == .fuel)
        #expect(service.car?.id == "car-1")
        #expect(abs(Double(service.volumeML) - 10.5 * 3785.411784) < 1)

        let schedules = try context.fetch(FetchDescriptor<SDScheduledService>())
        #expect(schedules.first?.name == "Oil change")
        #expect(schedules.first?.frequencyTime == 6)
    }

    @Test func cloudSaves2xStoreStillMigrates() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        do {
            let schema = Schema(versionedSchema: IGGSchemaV2.self)
            let container = try ModelContainer(
                for: schema, configurations: [ModelConfiguration(schema: schema, url: url)]
            )
            let context = ModelContext(container)
            let car = IGGSchemaV2.SDCar()
            car.id = "car-2"
            context.insert(car)
            let service = IGGSchemaV2.SDService()
            service.id = "svc-2"
            service.cost = 12.5
            service.car = car
            context.insert(service)
            try context.save()
        }

        let context = ModelContext(try openCurrent(at: url))
        let services = try context.fetch(FetchDescriptor<SDService>())
        #expect(services.first?.costMinor == 1250)
    }
}
