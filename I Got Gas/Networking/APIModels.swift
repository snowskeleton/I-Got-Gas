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
//
// The record-level types are gone: sync is an op exchange now, and its wire
// types live in Sync/Op.swift. What remains here is sharing, which is still a
// plain REST resource.

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

// MARK: - Devices

struct RegisterDeviceRequest: Codable {
    let deviceID: String
    let token: String
    let platform: String
    let notifyMode: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case token, platform
        case notifyMode = "notify_mode"
    }
}

struct UnregisterDeviceRequest: Codable {
    let deviceID: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
    }
}

struct APIError: Codable {
    let error: String
}
