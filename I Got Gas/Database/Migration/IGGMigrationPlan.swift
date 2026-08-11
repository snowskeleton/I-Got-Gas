//
//  IGGMigrationPlan.swift
//  I Got Gas
//
//  V2 → V3.
//
//  This has to be a custom stage rather than a lightweight one because every
//  interesting change is a rename *and* a retype:
//
//    cost      Double dollars  → costMinor        Int cents
//    gallons   Double US gal   → volumeML         Int millilitres
//    odometer  Int miles       → odometerMeters   Int metres
//    isFuel    Bool            → kind             ServiceKind
//    frequencyMiles Int miles  → frequencyMeters  Int metres
//
//  SwiftData sees the old properties as dropped and the new ones as added, so
//  the values have to be carried across by hand: `willMigrate` reads the V2
//  store into memory, `didMigrate` writes it back onto the V3 models. Rows are
//  matched by `id`, which is unchanged.
//
//  The 2.x scheduling cursors are also folded into the new anchors here, so
//  existing schedules keep the due points they had before the upgrade.
//

import Foundation
import SwiftData

enum IGGMigrationPlan: SchemaMigrationPlan {

    static var schemas: [any VersionedSchema.Type] {
        [IGGSchemaV2.self, IGGSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [v2toV3]
    }

    // MARK: - Carried values

    struct CarSnapshot {
        var startingOdometerMiles: Int
    }

    struct ServiceSnapshot {
        var costDollars: Double
        var gallons: Double
        var odometerMiles: Int
        var isFuel: Bool
    }

    struct ScheduleSnapshot {
        var frequencyMiles: Int
        var frequencyTime: Int
        var frequencyTimeStart: Date
        var nextDueOdometerMiles: Int
        var repeating: Bool
    }

    /// Populated in `willMigrate`, drained in `didMigrate`.
    nonisolated(unsafe) private static var cars: [String: CarSnapshot] = [:]
    nonisolated(unsafe) private static var services: [String: ServiceSnapshot] = [:]
    nonisolated(unsafe) private static var schedules: [String: ScheduleSnapshot] = [:]

    // MARK: - Reporting

    /// Unmatched rows are a bug in this plan, not a user problem: the values
    /// are already converted and the app is usable either way. So this traps
    /// in debug builds where a developer will see it, and only writes to the
    /// log in release. Nothing surfaces in the UI.
    private static func report(cars: Int, services: Int, schedules: Int) {
        guard cars > 0 || services > 0 || schedules > 0 else {
            NSLog("IGG migration: all rows matched a V2 snapshot")
            return
        }

        let message = "IGG migration: no V2 snapshot for \(cars) cars, "
            + "\(services) services, \(schedules) schedules — these kept model defaults"
        NSLog("%@", message)
        assertionFailure(message)
    }

    // MARK: - The stage

    static let v2toV3 = MigrationStage.custom(
        fromVersion: IGGSchemaV2.self,
        toVersion: IGGSchemaV3.self,
        willMigrate: { context in
            cars = [:]
            services = [:]
            schedules = [:]

            for car in try context.fetch(FetchDescriptor<IGGSchemaV2.SDCar>()) {
                cars[car.id] = CarSnapshot(startingOdometerMiles: car.startingOdometer)
            }

            for service in try context.fetch(FetchDescriptor<IGGSchemaV2.SDService>()) {
                services[service.id] = ServiceSnapshot(
                    costDollars: service.cost,
                    gallons: service.gallons,
                    odometerMiles: service.odometer,
                    isFuel: service.isFuel
                )
            }

            for schedule in try context.fetch(FetchDescriptor<IGGSchemaV2.SDScheduledService>()) {
                schedules[schedule.id] = ScheduleSnapshot(
                    frequencyMiles: schedule.frequencyMiles,
                    frequencyTime: schedule.frequencyTime,
                    frequencyTimeStart: schedule.frequencyTimeStart,
                    nextDueOdometerMiles: schedule.odometerFirstOccurance,
                    repeating: schedule.repeating
                )
            }

            NSLog("IGG migration: staged \(cars.count) cars, \(services.count) services, \(schedules.count) schedules")
        },
        didMigrate: { context in
            // Every 2.x install is US customary and USD — the app had no other
            // option — so the conversion factors are unconditional.
            let currency = "USD"
            let gallon = VolumeUnit.gallonsUS
            let mile = DistanceUnit.miles

            // A V3 row with no V2 snapshot means `willMigrate` and
            // `didMigrate` disagree about what's in the store — the row keeps
            // its model defaults, which is wrong but not fatal. Count them and
            // report at the end rather than dropping them on the floor.
            var unmatchedCars = 0
            var unmatchedServices = 0
            var unmatchedSchedules = 0

            for car in try context.fetch(FetchDescriptor<SDCar>()) {
                car.distanceUnit = .miles
                guard let snapshot = cars[car.id] else {
                    unmatchedCars += 1
                    continue
                }
                car.startingOdometerMeters = Distance(
                    value: Double(snapshot.startingOdometerMiles), unit: mile
                ).meters
            }

            for service in try context.fetch(FetchDescriptor<SDService>()) {
                guard let snapshot = services[service.id] else {
                    unmatchedServices += 1
                    continue
                }
                service.costMinor = Money(
                    majorUnits: Decimal(snapshot.costDollars), currencyCode: currency
                ).minorUnits
                service.volumeML = Volume(value: snapshot.gallons, unit: gallon).milliliters
                service.odometerMeters = Distance(
                    value: Double(snapshot.odometerMiles), unit: mile
                ).meters
                service.kind = snapshot.isFuel ? .fuel : .maintenance
            }

            for schedule in try context.fetch(FetchDescriptor<SDScheduledService>()) {
                guard let snapshot = schedules[schedule.id] else {
                    unmatchedSchedules += 1
                    continue
                }
                schedule.frequencyMeters = Distance(
                    value: Double(snapshot.frequencyMiles), unit: mile
                ).meters
                schedule.frequencyTime = snapshot.frequencyTime

                // 2.x stored a moving cursor. Rebuild anchors that reproduce
                // the same next-due, so nobody's reminders shift on upgrade:
                //   next date = frequencyTimeStart + frequencyTime
                //   next odo  = odometerFirstOccurance
                // and the new model computes next = anchor + frequency.
                schedule.anchorDate = snapshot.frequencyTimeStart
                schedule.anchorOdometerMeters = Distance(
                    value: Double(snapshot.nextDueOdometerMiles - snapshot.frequencyMiles),
                    unit: mile
                ).meters
            }

            report(cars: unmatchedCars, services: unmatchedServices, schedules: unmatchedSchedules)

            try context.save()

            // Everything here is new to the op log — see OutboxBackfill.
            UserDefaults.standard.set(true, forKey: "igg_needs_op_backfill")

            let linked = try ScheduleLinkMatcher.linkExistingHistory(in: context)
            NSLog("IGG migration: linked \(linked) entries to schedules by name")

            try context.save()

            cars = [:]
            services = [:]
            schedules = [:]
        }
    )
}
