//
//  SDCar.swift
//  I Got Gas
//
//  Created by snow on 10/4/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftData

@Model
class SDCar: Identifiable {
    var id: String = UUID().uuidString
    var make: String = ""
    var model: String = ""
    var name: String = ""
    var plate: String = ""
    var vin: String = ""
    var year: Int?

    /// Odometer reading when the car was added, in whole metres.
    var startingOdometerMeters: Int = 0

    /// Distance unit this car is read in. Per-car rather than per-account so
    /// a household can keep one car in miles and another in kilometres.
    var distanceUnit: DistanceUnit = DistanceUnit.miles

    var pinned: Bool = false
    var deleted: Bool = false
    var archived: Bool = false
    var ownerID: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship
    var services: [SDService]? = []

    @Relationship
    var scheduledServices: [SDScheduledService]? = []

    @Relationship
    var settings: SDCarSettings?

    init() { }
    init(
        make: String,
        model: String,
        name: String,
        plate: String,
        vin: String,
        year: Int?,
        startingOdometer: Distance,
        distanceUnit: DistanceUnit = UnitPreferences.newCarDistanceUnit
    ) {
        self.make = make
        self.model = model
        self.name = name
        self.plate = plate
        self.vin = vin
        self.year = year
        self.startingOdometerMeters = startingOdometer.meters
        self.distanceUnit = distanceUnit
    }

    // MARK: - Typed accessors

    var startingOdometer: Distance {
        get { Distance(meters: startingOdometerMeters) }
        set { startingOdometerMeters = newValue.meters }
    }

    var joinedModel: String {
        return [year?.description ?? "", make, model].joined(separator: " ")
    }

    var visualName: String {
        if name.isEmpty {
            return joinedModel
        } else {
            return name
        }
    }

    /// Highest reading seen, never below where the car started.
    var odometer: Distance {
        let readings = liveServices.map(\.odometerMeters)
        return Distance(meters: max(readings.max() ?? 0, startingOdometerMeters))
    }

    private var liveServices: [SDService] {
        (services ?? []).filter { !$0.deleted }
    }

    /// Average price paid per unit of fuel across all fill-ups.
    /// Nil when nothing has been filled up — the old version averaged in the
    /// `inf` that every maintenance entry produced.
    var costPerVolume: Money? {
        let prices = liveServices.compactMap(\.costPerVolume)
        guard !prices.isEmpty else { return nil }
        return Money(minorUnits: prices.map(\.minorUnits).reduce(0, +) / prices.count)
    }

    func touch() {
        updatedAt = Date()
    }
}
