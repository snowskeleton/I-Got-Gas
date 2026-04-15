//
//  APIModels.swift
//  I Got Gas
//
//  Created by Claude on 2025.
//

import Foundation

// MARK: - Auth

struct AuthRequestBody: Codable {
    let email: String
}

struct AuthRequestResponse: Codable {
    let message: String
    let pollToken: String

    enum CodingKeys: String, CodingKey {
        case message
        case pollToken = "poll_token"
    }
}

struct PollRequestBody: Codable {
    let pollToken: String

    enum CodingKeys: String, CodingKey {
        case pollToken = "poll_token"
    }
}

struct PollResponse: Codable {
    let status: String
}

struct AuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct RefreshRequestBody: Codable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

// MARK: - Sync

struct APICar: Codable {
    let id: String
    var ownerID: String
    var make: String
    var model: String
    var name: String
    var plate: String
    var vin: String
    var year: Int?
    var startingOdometer: Int
    var pinned: Bool
    var deleted: Bool
    var archived: Bool
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case make, model, name, plate, vin, year
        case startingOdometer = "starting_odometer"
        case pinned, deleted, archived
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct APIService: Codable {
    let id: String
    var carID: String
    var cost: Double
    var date: String
    var pending: Bool
    var name: String
    var fullDescription: String
    var odometer: Int
    var isFuel: Bool
    var isFullTank: Bool
    var gallons: Double
    var vendorName: String
    var deleted: Bool
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case carID = "car_id"
        case cost, date, pending, name
        case fullDescription = "full_description"
        case odometer
        case isFuel = "is_fuel"
        case isFullTank = "is_full_tank"
        case gallons
        case vendorName = "vendor_name"
        case deleted
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct APIScheduledService: Codable {
    let id: String
    var carID: String
    var name: String
    var fullDescription: String
    var notificationUUID: String
    var repeating: Bool
    var odometerFirstOccurance: Int
    var frequencyMiles: Int
    var frequencyTime: Int
    var frequencyTimeInterval: String
    var frequencyTimeStart: String
    var deleted: Bool
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case carID = "car_id"
        case name
        case fullDescription = "full_description"
        case notificationUUID = "notification_uuid"
        case repeating
        case odometerFirstOccurance = "odometer_first_occurance"
        case frequencyMiles = "frequency_miles"
        case frequencyTime = "frequency_time"
        case frequencyTimeInterval = "frequency_time_interval"
        case frequencyTimeStart = "frequency_time_start"
        case deleted
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct APICarSettings: Codable {
    var id: String?
    var carID: String
    var userID: String?
    var selectedTab: String
    var rangeDays: Int
    var includeFuel: Bool
    var includeMaintenance: Bool
    var includeCompleted: Bool
    var includePending: Bool
    var custom: Bool
    var createdAt: String?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case carID = "car_id"
        case userID = "user_id"
        case selectedTab = "selected_tab"
        case rangeDays = "range_days"
        case includeFuel = "include_fuel"
        case includeMaintenance = "include_maintenance"
        case includeCompleted = "include_completed"
        case includePending = "include_pending"
        case custom
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SyncRequest: Codable {
    let deviceID: String
    let lastSyncedAt: String?
    let changes: SyncChanges

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case lastSyncedAt = "last_synced_at"
        case changes
    }
}

struct SyncChanges: Codable {
    var cars: [APICar]
    var services: [APIService]
    var scheduledServices: [APIScheduledService]
    var carSettings: [APICarSettings]

    enum CodingKeys: String, CodingKey {
        case cars, services
        case scheduledServices = "scheduled_services"
        case carSettings = "car_settings"
    }
}

struct SyncResponse: Codable {
    let syncedAt: String
    let changes: SyncChanges
    let shares: SyncShares

    enum CodingKeys: String, CodingKey {
        case syncedAt = "synced_at"
        case changes, shares
    }
}

struct SyncShares: Codable {
    let owned: [OwnedShare]
    let received: [ReceivedShare]
}

struct OwnedShare: Codable {
    let carID: String
    let sharedWith: [SharePerson]

    enum CodingKeys: String, CodingKey {
        case carID = "car_id"
        case sharedWith = "shared_with"
    }
}

struct ReceivedShare: Codable {
    let carID: String
    let ownerEmail: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case carID = "car_id"
        case ownerEmail = "owner_email"
        case status
    }
}

struct SharePerson: Codable {
    let email: String
    let status: String
}

// MARK: - Sharing

struct CreateShareRequest: Codable {
    let email: String
}

struct ShareResponse: Codable, Identifiable {
    let id: String
    let carID: String
    let invitedEmail: String
    let status: String
    let ownerEmail: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case carID = "car_id"
        case invitedEmail = "invited_email"
        case status
        case ownerEmail = "owner_email"
        case createdAt = "created_at"
    }
}

// MARK: - User

struct MeResponse: Codable {
    let id: String
    let email: String
}

struct APIError: Codable {
    let error: String
}
