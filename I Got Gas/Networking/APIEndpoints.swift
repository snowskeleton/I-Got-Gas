//
//  APIEndpoints.swift
//  I Got Gas
//
//  Created by Claude on 2025.
//

import Foundation

enum APIEndpoints {
    static var baseURL: String {
        IGGServerSecrets.baseURL
    }

    // Auth
    static var authRequest: URL { url("/v1/auth/request") }
    static var authVerify: URL { url("/v1/auth/verify") }
    static var authRefresh: URL { url("/v1/auth/refresh") }
    static var authLogout: URL { url("/v1/auth/logout") }
    static var authPoll: URL { url("/v1/auth/poll") }

    // Sync
    static var sync: URL { url("/v1/sync") }

    // Sharing
    static func carShares(_ carID: String) -> URL {
        url("/v1/cars/\(carID)/shares")
    }
    static func revokeShare(_ carID: String, _ shareID: String) -> URL {
        url("/v1/cars/\(carID)/shares/\(shareID)")
    }
    static var pendingShares: URL { url("/v1/shares/pending") }
    static var receivedShares: URL { url("/v1/shares/received") }
    static func leaveShare(_ shareID: String) -> URL {
        url("/v1/shares/\(shareID)/leave")
    }
    static func acceptShare(_ shareID: String) -> URL {
        url("/v1/shares/\(shareID)/accept")
    }
    static func declineShare(_ shareID: String) -> URL {
        url("/v1/shares/\(shareID)/decline")
    }

    // User
    static var me: URL { url("/v1/me") }
    static var health: URL { url("/v1/health") }

    private static func url(_ path: String) -> URL {
        URL(string: baseURL + path)!
    }
}
