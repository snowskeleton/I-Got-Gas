//
//  StoreMaintenance.swift
//  I Got Gas
//
//  Developer-only store surgery: wipe the database, or replace it with a
//  freshly written 2.x store so the V2→V3 migration can be exercised for real.
//
//  Both operations have the same constraint as restore — the store cannot be
//  replaced while it is open — so they are staged to a flag and applied during
//  the next launch, before the container is built.
//

import Foundation
import SwiftData

enum StoreMaintenance {

    private static let pendingActionKey = "igg_pending_store_action"

    enum Action: String {
        /// Delete the store outright and start from an empty database.
        case reset
        /// Delete the store and write a 2.x-shaped one in its place.
        case seedV2
    }

    static func stage(_ action: Action) {
        UserDefaults.standard.set(action.rawValue, forKey: pendingActionKey)

        // Both actions produce a database with no relationship to whatever the
        // server has already seen, so the cursors have to start over.
        SyncMetadata.clearCursors()

        // See the note in `StoreBackup.stageRestore` — `exit(0)` skips the
        // normal UserDefaults flush.
        UserDefaults.standard.synchronize()
    }

    static var pending: Action? {
        UserDefaults.standard.string(forKey: pendingActionKey).flatMap(Action.init(rawValue:))
    }

    /// Must run before the V3 container is constructed.
    static func applyPendingAction(configuration: ModelConfiguration) {
        guard let action = pending else { return }
        UserDefaults.standard.removeObject(forKey: pendingActionKey)

        let storeURL = StoreBackup.storeURL(for: configuration)
        StoreBackup.removeStore(at: storeURL)

        switch action {
        case .reset:
            NSLog("StoreMaintenance: store reset to empty")
        case .seedV2:
            seedV2(at: storeURL)
        }

        // Whatever is on disk now predates the current schema, so the next
        // open has to be treated as a fresh transition — that is what makes
        // the migration (and its backup) run again.
        StoreBackup.forgetVersionMarker()
    }

    // MARK: - Seeding a 2.x store

    /// Writes a store using the frozen V2 schema, so the next launch opens it
    /// with the V3 plan and runs the real migration — rather than the fake
    /// data generator's shortcut of building V3 objects directly.
    private static func seedV2(at storeURL: URL) {
        do {
            let schema = Schema(IGGSchemaV2.models, version: IGGSchemaV2.versionIdentifier)
            let configuration = ModelConfiguration(schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let car = IGGSchemaV2.SDCar()
            car.make = "Toyota"
            car.model = "Camry"
            car.name = "Migration Test"
            car.plate = "V2TEST"
            car.vin = "1HGBH41JXMN109186"
            car.year = 2015
            car.startingOdometer = 20_000
            context.insert(car)

            let calendar = Calendar.current
            var date = calendar.date(byAdding: .year, value: -3, to: Date())!
            var odometer = car.startingOdometer

            while date < Date() {
                let gallons = randomDouble(min: 10.0, max: 15.0)
                odometer += randomInt(min: 450, max: 800)

                let fuel = IGGSchemaV2.SDService()
                fuel.cost = gallons * randomDouble(min: 2.5, max: 4.0)
                fuel.date = date
                fuel.name = "Fuel"
                fuel.odometer = odometer
                fuel.isFuel = true
                fuel.gallons = gallons
                fuel.car = car
                context.insert(fuel)

                date = calendar.date(byAdding: .day, value: 14, to: date)!
            }

            // Named to match the schedule below, so the V2→V3 link matcher has
            // something real to chew on.
            for offset in 1...4 {
                let service = IGGSchemaV2.SDService()
                service.cost = randomDouble(min: 40.0, max: 90.0)
                service.date = calendar.date(byAdding: .month, value: -offset * 6, to: Date())!
                service.name = "Oil Change"
                service.odometer = car.startingOdometer + offset * 5_000
                service.car = car
                context.insert(service)
            }

            let schedule = IGGSchemaV2.SDScheduledService()
            schedule.name = "Oil Change"
            schedule.repeating = true
            schedule.frequencyMiles = 5_000
            schedule.frequencyTime = 6
            schedule.frequencyTimeInterval = .month
            schedule.frequencyTimeStart = calendar.date(byAdding: .month, value: -3, to: Date())!
            schedule.odometerFirstOccurance = odometer + 2_000
            schedule.car = car
            context.insert(schedule)

            try context.save()
            NSLog("StoreMaintenance: seeded a 2.x store, migration will run on open")
        } catch {
            NSLog("StoreMaintenance: seeding failed: %@", error.localizedDescription)
        }
    }
}
