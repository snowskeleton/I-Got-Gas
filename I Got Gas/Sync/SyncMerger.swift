//
//  SyncMerger.swift
//  I Got Gas
//
//  Created by Claude on 2025.
//

import Foundation
import SwiftData

@MainActor
class SyncMerger {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func apply(_ response: SyncResponse) throws {
        let isoFormatter = ISO8601DateFormatter()

        // Merge cars
        for apiCar in response.changes.cars {
            let carID = apiCar.id
            let predicate = #Predicate<SDCar> { $0.id == carID }
            let descriptor = FetchDescriptor<SDCar>(predicate: predicate)
            let existing = try context.fetch(descriptor).first

            if let existing {
                // Last-write-wins: only apply if remote is newer
                if let remoteDate = isoFormatter.date(from: apiCar.updatedAt),
                   remoteDate > existing.updatedAt {
                    existing.make = apiCar.make
                    existing.model = apiCar.model
                    existing.name = apiCar.name
                    existing.plate = apiCar.plate
                    existing.vin = apiCar.vin
                    existing.year = apiCar.year
                    existing.startingOdometer = apiCar.startingOdometer
                    existing.pinned = apiCar.pinned
                    existing.deleted = apiCar.deleted
                    existing.archived = apiCar.archived
                    existing.ownerID = apiCar.ownerID
                    existing.updatedAt = remoteDate
                    if let d = isoFormatter.date(from: apiCar.createdAt) { existing.createdAt = d }
                }
            } else {
                let car = SDCar()
                car.id = apiCar.id
                car.make = apiCar.make
                car.model = apiCar.model
                car.name = apiCar.name
                car.plate = apiCar.plate
                car.vin = apiCar.vin
                car.year = apiCar.year
                car.startingOdometer = apiCar.startingOdometer
                car.pinned = apiCar.pinned
                car.deleted = apiCar.deleted
                car.archived = apiCar.archived
                car.ownerID = apiCar.ownerID
                if let d = isoFormatter.date(from: apiCar.updatedAt) { car.updatedAt = d }
                if let d = isoFormatter.date(from: apiCar.createdAt) { car.createdAt = d }
                context.insert(car)
            }
        }

        // Merge services
        for apiSvc in response.changes.services {
            let svcID = apiSvc.id
            let predicate = #Predicate<SDService> { $0.id == svcID }
            let descriptor = FetchDescriptor<SDService>(predicate: predicate)
            let existing = try context.fetch(descriptor).first

            if let existing {
                if let remoteDate = isoFormatter.date(from: apiSvc.updatedAt),
                   remoteDate > existing.updatedAt {
                    applyAPIService(apiSvc, to: existing, isoFormatter: isoFormatter)
                }
            } else {
                let svc = SDService()
                svc.id = apiSvc.id
                applyAPIService(apiSvc, to: svc, isoFormatter: isoFormatter)
                // Link to car
                let carID = apiSvc.carID
                let carPred = #Predicate<SDCar> { $0.id == carID }
                let carDesc = FetchDescriptor<SDCar>(predicate: carPred)
                if let car = try context.fetch(carDesc).first {
                    svc.car = car
                }
                context.insert(svc)
            }
        }

        // Merge scheduled services
        for apiSS in response.changes.scheduledServices {
            let ssID = apiSS.id
            let predicate = #Predicate<SDScheduledService> { $0.id == ssID }
            let descriptor = FetchDescriptor<SDScheduledService>(predicate: predicate)
            let existing = try context.fetch(descriptor).first

            if let existing {
                if let remoteDate = isoFormatter.date(from: apiSS.updatedAt),
                   remoteDate > existing.updatedAt {
                    applyAPIScheduledService(apiSS, to: existing, isoFormatter: isoFormatter)
                }
            } else {
                let ss = SDScheduledService()
                ss.id = apiSS.id
                applyAPIScheduledService(apiSS, to: ss, isoFormatter: isoFormatter)
                // Link to car
                let carID = apiSS.carID
                let carPred = #Predicate<SDCar> { $0.id == carID }
                let carDesc = FetchDescriptor<SDCar>(predicate: carPred)
                if let car = try context.fetch(carDesc).first {
                    ss.car = car
                }
                context.insert(ss)
            }
        }

        // Merge car settings
        for apiCS in response.changes.carSettings {
            let carID = apiCS.carID
            let carPred = #Predicate<SDCar> { $0.id == carID }
            let carDesc = FetchDescriptor<SDCar>(predicate: carPred)
            guard let car = try context.fetch(carDesc).first else { continue }

            if let existing = car.settings {
                if let remoteDate = isoFormatter.date(from: apiCS.updatedAt),
                   remoteDate > existing.updatedAt {
                    existing.applyRemote([
                        "selected_tab": apiCS.selectedTab,
                        "range_days": apiCS.rangeDays,
                        "include_fuel": apiCS.includeFuel,
                        "include_maintenance": apiCS.includeMaintenance,
                        "include_completed": apiCS.includeCompleted,
                        "include_pending": apiCS.includePending,
                        "custom": apiCS.custom,
                        "updated_at": apiCS.updatedAt
                    ])
                }
            } else {
                let settings = SDCarSettings()
                settings.car = car
                settings.applyRemote([
                    "selected_tab": apiCS.selectedTab,
                    "range_days": apiCS.rangeDays,
                    "include_fuel": apiCS.includeFuel,
                    "include_maintenance": apiCS.includeMaintenance,
                    "include_completed": apiCS.includeCompleted,
                    "include_pending": apiCS.includePending,
                    "custom": apiCS.custom,
                    "updated_at": apiCS.updatedAt
                ])
                car.settings = settings
            }
        }

        try context.save()
    }

    private func applyAPIService(_ api: APIService, to svc: SDService, isoFormatter: ISO8601DateFormatter) {
        svc.cost = api.cost
        svc.pending = api.pending
        svc.name = api.name
        svc.fullDescription = api.fullDescription
        svc.odometer = api.odometer
        svc.isFuel = api.isFuel
        svc.isFullTank = api.isFullTank
        svc.gallons = api.gallons
        svc.vendorName = api.vendorName
        svc.deleted = api.deleted
        if let d = isoFormatter.date(from: api.date) { svc.date = d }
        if let d = isoFormatter.date(from: api.updatedAt) { svc.updatedAt = d }
        if let d = isoFormatter.date(from: api.createdAt) { svc.createdAt = d }
    }

    private func applyAPIScheduledService(_ api: APIScheduledService, to ss: SDScheduledService, isoFormatter: ISO8601DateFormatter) {
        ss.name = api.name
        ss.fullDescription = api.fullDescription
        ss.repeating = api.repeating
        ss.odometerFirstOccurance = api.odometerFirstOccurance
        ss.frequencyMiles = api.frequencyMiles
        ss.frequencyTime = api.frequencyTime
        ss.deleted = api.deleted
        switch api.frequencyTimeInterval {
        case "day": ss.frequencyTimeInterval = .day
        case "month": ss.frequencyTimeInterval = .month
        case "year": ss.frequencyTimeInterval = .year
        default: break
        }
        if let d = isoFormatter.date(from: api.frequencyTimeStart) { ss.frequencyTimeStart = d }
        if let d = isoFormatter.date(from: api.updatedAt) { ss.updatedAt = d }
        if let d = isoFormatter.date(from: api.createdAt) { ss.createdAt = d }
        // Regenerate notification UUID on new device
        ss.notificationUUID = UUID().uuidString
    }
}
