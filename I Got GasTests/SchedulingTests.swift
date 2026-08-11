//
//  SchedulingTests.swift
//  I Got GasTests
//
//  The point of the whole rework: next-due is derived from the entries that
//  fulfilled a schedule, so backfilling old history can't corrupt it.
//
//  2.x wrote "now" into frequencyTimeStart and `odometer + frequencyMiles`
//  into odometerFirstOccurance every time an expense was saved. Adding a
//  service dated two years ago therefore reset the schedule to two years ago.
//

import Testing
import Foundation
import SwiftData
@testable import I_Got_Gas

@MainActor
struct SchedulingTests {

    /// A fresh in-memory store, so tests never touch the real database.
    private func makeContext() throws -> ModelContext {
        let schema = Schema(IGGSchemaV3.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func makeCar(in context: ModelContext, odometerMiles: Double = 50_000) -> SDCar {
        let car = SDCar()
        car.distanceUnit = .miles
        car.startingOdometer = Distance(value: odometerMiles, unit: .miles)
        context.insert(car)
        return car
    }

    private func makeSchedule(
        on car: SDCar, in context: ModelContext,
        everyMonths: Int = 6, everyMiles: Double = 5_000
    ) -> SDScheduledService {
        let schedule = SDScheduledService()
        schedule.name = "Oil Change"
        schedule.car = car
        schedule.repeating = true
        schedule.frequencyTime = everyMonths
        schedule.frequencyTimeInterval = .month
        schedule.frequencyDistance = Distance(value: everyMiles, unit: .miles)
        schedule.anchorDate = Date()
        schedule.anchorOdometer = car.odometer
        context.insert(schedule)
        return schedule
    }

    @discardableResult
    private func complete(
        _ schedule: SDScheduledService, on car: SDCar, in context: ModelContext,
        date: Date, odometerMiles: Double
    ) -> SDService {
        let entry = SDService()
        entry.car = car
        entry.kind = .maintenance
        entry.name = "Oil Change"
        entry.date = date
        entry.odometer = Distance(value: odometerMiles, unit: .miles)
        entry.scheduledService = schedule
        context.insert(entry)
        return entry
    }

    // MARK: - The retroactive-entry case

    @Test func addingAnOldEntryDoesNotMoveNextDue() throws {
        let context = try makeContext()
        let car = makeCar(in: context)
        let schedule = makeSchedule(on: car, in: context)

        let today = Date()
        complete(schedule, on: car, in: context, date: today, odometerMiles: 50_000)

        let dueDateBefore = try #require(schedule.nextDueDate)
        let dueOdometerBefore = try #require(schedule.nextDueOdometer)

        // Backfill something from two years ago. Under the old cursor model
        // this reset the schedule; under derived next-due it changes nothing,
        // because the most recent completion is still today's.
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: today)!
        let old = complete(
            schedule, on: car, in: context, date: twoYearsAgo, odometerMiles: 20_000
        )

        #expect(schedule.nextDueDate == dueDateBefore)
        #expect(schedule.nextDueOdometer == dueOdometerBefore)

        // And removing it again is equally uneventful.
        context.delete(old)
        #expect(schedule.nextDueDate == dueDateBefore)
        #expect(schedule.nextDueOdometer == dueOdometerBefore)
    }

    @Test func nextDueFollowsTheMostRecentCompletion() throws {
        let context = try makeContext()
        let car = makeCar(in: context)
        let schedule = makeSchedule(on: car, in: context, everyMonths: 6, everyMiles: 5_000)

        let lastService = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        complete(schedule, on: car, in: context, date: lastService, odometerMiles: 52_000)

        let expectedDate = Calendar.current.date(byAdding: .month, value: 6, to: lastService)
        #expect(schedule.nextDueDate == expectedDate)
        #expect(schedule.nextDueOdometer?.rounded(to: .miles) == 57_000)
    }

    @Test func withNoCompletionsTheAnchorIsUsed() throws {
        let context = try makeContext()
        let car = makeCar(in: context)
        let schedule = makeSchedule(on: car, in: context)
        schedule.anchorOdometer = Distance(value: 50_000, unit: .miles)

        #expect(schedule.lastCompletion == nil)
        #expect(schedule.nextDueOdometer?.rounded(to: .miles) == 55_000)
    }

    @Test func deletedCompletionsAreIgnored() throws {
        let context = try makeContext()
        let car = makeCar(in: context)
        let schedule = makeSchedule(on: car, in: context)

        let entry = complete(
            schedule, on: car, in: context, date: Date(), odometerMiles: 52_000
        )
        #expect(schedule.lastCompletion != nil)

        entry.deleted = true
        #expect(schedule.lastCompletion == nil)
    }

    // MARK: - OR semantics

    @Test func mileageAloneCanMakeItDue() throws {
        let context = try makeContext()
        let car = makeCar(in: context, odometerMiles: 60_000)
        let schedule = makeSchedule(on: car, in: context, everyMonths: 12, everyMiles: 5_000)
        schedule.anchorDate = Date() // time interval nowhere near elapsed
        schedule.anchorOdometer = Distance(value: 50_000, unit: .miles)

        // 60,000 is well past the 55,000 due point, even though a year hasn't
        // passed. 2.x checked time only, so this read as not due.
        #expect(schedule.isDue)
    }

    @Test func timeAloneCanMakeItDue() throws {
        let context = try makeContext()
        let car = makeCar(in: context, odometerMiles: 50_000)
        let schedule = makeSchedule(on: car, in: context, everyMonths: 6, everyMiles: 5_000)
        schedule.anchorDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        schedule.anchorOdometer = Distance(value: 49_000, unit: .miles)

        // A year has passed against a six-month interval, though the car has
        // only covered 1,000 of the 5,000 miles.
        #expect(schedule.isDue)
    }

    @Test func neitherThresholdMeansNotDue() throws {
        let context = try makeContext()
        let car = makeCar(in: context, odometerMiles: 50_000)
        let schedule = makeSchedule(on: car, in: context, everyMonths: 6, everyMiles: 5_000)
        schedule.anchorDate = Date()
        schedule.anchorOdometer = Distance(value: 50_000, unit: .miles)

        #expect(!schedule.isDue)
    }

    @Test func snoozeSuppressesTheDueState() throws {
        let context = try makeContext()
        let car = makeCar(in: context, odometerMiles: 60_000)
        let schedule = makeSchedule(on: car, in: context, everyMonths: 12, everyMiles: 5_000)
        schedule.anchorOdometer = Distance(value: 50_000, unit: .miles)
        #expect(schedule.isDue)

        schedule.snoozedUntil = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        #expect(!schedule.isDue)
    }

    @Test func completedNonRepeatingSchedulesAreNeverDue() throws {
        let context = try makeContext()
        let car = makeCar(in: context, odometerMiles: 90_000)
        let schedule = makeSchedule(on: car, in: context)
        schedule.repeating = false
        schedule.anchorOdometer = Distance(value: 50_000, unit: .miles)
        #expect(schedule.isDue)

        // Kept as a record rather than deleted, so it can still anchor history.
        schedule.completedAt = Date()
        #expect(!schedule.isDue)
        #expect(schedule.isCompleted)
    }

    // MARK: - Cross-car links

    @Test func aScheduleCannotBeFulfilledByAnotherCarsEntry() throws {
        let context = try makeContext()
        let mine = makeCar(in: context)
        let theirs = makeCar(in: context)
        let schedule = makeSchedule(on: mine, in: context)

        let entry = SDService()
        entry.car = theirs
        context.insert(entry)

        #expect(!schedule.canBeFulfilled(by: entry))

        let ownEntry = SDService()
        ownEntry.car = mine
        context.insert(ownEntry)
        #expect(schedule.canBeFulfilled(by: ownEntry))
    }
}

@MainActor
struct ServiceDisplayTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(IGGSchemaV3.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
    }

    @Test func nameFallsBackToTheCommaJoinedParts() throws {
        let context = try makeContext()
        let service = SDService()
        context.insert(service)

        let pads = SDPart(name: "Brake Pads", position: 0)
        pads.service = service
        let rotors = SDPart(name: "Rotors", position: 1)
        rotors.service = service
        context.insert(pads)
        context.insert(rotors)

        #expect(service.displayName == "Brake Pads, Rotors")

        // An explicit name always wins.
        service.name = "Front Brake Job"
        #expect(service.displayName == "Front Brake Job")
    }

    @Test func partsRespectTheirOrderAndSkipDeletions() throws {
        let context = try makeContext()
        let service = SDService()
        context.insert(service)

        let second = SDPart(name: "Filter", position: 1)
        second.service = service
        let first = SDPart(name: "Oil", position: 0)
        first.service = service
        let removed = SDPart(name: "Wiper", position: 2)
        removed.service = service
        removed.deleted = true
        context.insert(second)
        context.insert(first)
        context.insert(removed)

        #expect(service.displayName == "Oil, Filter")
    }

    @Test func partsTotalDoesNotOverwriteTheEntryTotal() throws {
        let context = try makeContext()
        let service = SDService()
        service.cost = Money(minorUnits: 25_000, currencyCode: "USD") // $250, incl. labor
        context.insert(service)

        let part = SDPart(name: "Brake Pads", position: 0)
        part.service = service
        part.quantity = 2
        part.unitCostMinor = 4_500 // $45 each
        context.insert(part)

        #expect(service.partsTotal.minorUnits == 9_000)
        // The entry total is authoritative and untouched.
        #expect(service.costMinor == 25_000)
    }

    @Test func costPerVolumeIsNilRatherThanInfinite() throws {
        let context = try makeContext()
        let maintenance = SDService()
        maintenance.kind = .maintenance
        maintenance.cost = Money(minorUnits: 25_000)
        maintenance.volume = .zero
        context.insert(maintenance)

        // 2.x computed cost / gallons unguarded and printed "$inf/gal".
        #expect(maintenance.costPerVolume == nil)
    }
}
