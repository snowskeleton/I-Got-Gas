//
//  IGGSchemaV2.swift
//  I Got Gas
//
//  The shipped 2.x shape, preserved verbatim so the V3 migration has
//  something to read from. Nothing here should ever change again — if you
//  find yourself editing this file, you want a V4 instead.
//
//  These models keep the `@Attribute(originalName:)` mappings back to the
//  original Core Data column names, because that is genuinely what is on
//  disk in a 2.x store.
//

import Foundation
import SwiftData

enum IGGSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

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
        /// 2.x advanced this to "now" every time an expense was saved.
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
        var _notifyOnChange: Bool = true
        var updatedAt: Date = Date()

        var car: SDCar?

        init() { }
    }
}
