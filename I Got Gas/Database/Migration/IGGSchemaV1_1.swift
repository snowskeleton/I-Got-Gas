//
//  IGGSchemaV1_1.swift
//  I Got Gas
//
//  The shape that shipped on the App Store as 2.1 (build 2, commit 09b08e4),
//  preserved verbatim. It is IGGSchemaV1 plus the cloud-saves columns
//  (ownerID, createdAt/updatedAt, soft-delete on services and schedules,
//  SDCarSettings.updatedAt) — but *not* SDCarSettings._notifyOnChange,
//  which arrived later with push notifications and never shipped.
//
//  So the App Store history is V1 (2.0.x) → V1_1 (2.1) → V3 (3.0), and
//  IGGSchemaV2 is an unreleased step in between. 3.0.1 knew V1 and V2 but
//  not this, and refused every 2.1 store as an unknown model version.
//
//  Checked against a real 2.1 user's store: the entity version hashes match
//  exactly. Nothing here should ever change.
//

import Foundation
import SwiftData

enum IGGSchemaV1_1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [SDCar.self, SDService.self, SDScheduledService.self, SDCarSettings.self]
    }

    @Model
    final class SDCar {
        @Attribute(originalName: "localId")
        var id: String = UUID().uuidString
        var make: String = ""
        var model: String = ""
        var name: String = ""
        var plate: String = ""
        var vin: String = ""
        var year: Int?
        /// Miles.
        var startingOdometer: Int = 0
        var pinned: Bool = false
        var deleted: Bool = false
        var archived: Bool = false
        var ownerID: String = ""
        var createdAt: Date = Date()
        var updatedAt: Date = Date()

        @Relationship var services: [SDService]? = []
        @Relationship var scheduledServices: [SDScheduledService]? = []
        @Relationship var settings: SDCarSettings?

        init() { }
    }

    @Model
    final class SDService {
        @Attribute(originalName: "localId")
        var id: String = UUID().uuidString

        /// Dollars.
        var cost: Double = 0.0
        @Attribute(originalName: "datePurchased")
        var date = Date()
        @Attribute(originalName: "isCompleted")
        var pending: Bool = false
        @Attribute(originalName: "note")
        var name: String = ""
        var fullDescription: String = ""
        /// Miles.
        var odometer: Int = 0

        var isFuel: Bool = false
        var isFullTank: Bool = true
        /// US gallons.
        var gallons: Double = 0.0

        var vendorName = ""
        var deleted: Bool = false
        var createdAt: Date = Date()
        var updatedAt: Date = Date()

        @Relationship var car: SDCar?

        init() { }
    }

    @Model
    final class SDScheduledService {
        @Attribute(originalName: "localId")
        var id: String = UUID().uuidString

        var name: String = ""
        var fullDescription: String = ""
        var notificationUUID: String = UUID().uuidString
        var repeating: Bool = false

        /// Despite the name, 2.x wrote the *next due* odometer here, in miles.
        var odometerFirstOccurance: Int = 0

        var frequencyMiles: Int = 0
        var frequencyTime: Int = 0
        var frequencyTimeInterval: FrequencyTimeInterval = FrequencyTimeInterval.month
        var frequencyTimeStart: Date = Date()
        var deleted: Bool = false
        var createdAt: Date = Date()
        var updatedAt: Date = Date()

        var car: SDCar?

        init() { }
    }

    @Model
    final class SDCarSettings {
        var _selectedTab: String = "MPG"
        var _range: Int = 90
        var _includeFuel: Bool = true
        var _includeMaintenance: Bool = true
        var _includeCompleted: Bool = true
        var _includePending: Bool = false
        var _custom: Bool = false
        var updatedAt: Date = Date()

        var car: SDCar?

        init() { }
    }
}
