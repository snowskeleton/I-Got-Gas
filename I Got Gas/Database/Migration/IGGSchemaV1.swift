//
//  IGGSchemaV1.swift
//  I Got Gas
//
//  The shape that actually shipped on the App Store as 2.0.0 and 2.0.1,
//  preserved verbatim from `appstoreVersion_2.0.1`.
//
//  2.1 added the cloud-saves columns (IGGSchemaV1_1), and IGGSchemaV2 is a
//  later unreleased shape on top of that. Without this version in the plan, SwiftData cannot match an App
//  Store 2.0.1 store to any known schema and refuses to open it at all —
//  3.0 build 4 shipped with exactly that bug.
//
//  Nothing here should ever change. If it differs from what 2.0.1 wrote by
//  even one property, the store hash stops matching and the bug comes back.
//

import Foundation
import SwiftData

enum IGGSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

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

        var car: SDCar?

        init() { }
    }
}
