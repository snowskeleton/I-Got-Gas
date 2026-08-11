//
//  APIClient.swift
//  I Got Gas
//
//  Created by Claude on 2025.
//

import Foundation

actor APIClient {
    static let shared = APIClient()

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    private var refreshTask: Task<Bool, Error>?

    // MARK: - Core request method

    func request<T: Decodable>(
        _ url: URL,
        method: String = "GET",
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated {
            if let token = KeychainHelper.read(.accessToken) {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        if let body {
            req.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        // 401 → try refresh
        if http.statusCode == 401 && authenticated {
            let refreshed = try await refreshTokens()
            if refreshed {
                // Retry with new token
                req.setValue("Bearer \(KeychainHelper.read(.accessToken) ?? "")", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await session.data(for: req)
                guard let retryHttp = retryResponse as? HTTPURLResponse else {
                    throw APIClientError.invalidResponse
                }
                if retryHttp.statusCode == 401 {
                    throw APIClientError.unauthorized
                }
                return try decoder.decode(T.self, from: retryData)
            } else {
                throw APIClientError.unauthorized
            }
        }

        // 204 No Content
        if http.statusCode == 204 {
            if let empty = EmptyResponse() as? T {
                return empty
            }
            throw APIClientError.noContent
        }

        guard (200...299).contains(http.statusCode) else {
            if let apiErr = try? decoder.decode(APIError.self, from: data) {
                throw APIClientError.server(apiErr.error)
            }
            throw APIClientError.httpError(http.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }

    // Fire-and-forget for 204 endpoints
    func requestNoContent(
        _ url: URL,
        method: String = "POST",
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let token = KeychainHelper.read(.accessToken) {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if http.statusCode == 401 && authenticated {
            let refreshed = try await refreshTokens()
            if refreshed {
                req.setValue("Bearer \(KeychainHelper.read(.accessToken) ?? "")", forHTTPHeaderField: "Authorization")
                let (_, retryResp) = try await session.data(for: req)
                if let retryHttp = retryResp as? HTTPURLResponse, retryHttp.statusCode == 401 {
                    throw APIClientError.unauthorized
                }
                return
            }
            throw APIClientError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            if let apiErr = try? decoder.decode(APIError.self, from: data) {
                throw APIClientError.server(apiErr.error)
            }
            throw APIClientError.httpError(http.statusCode)
        }
    }

    // MARK: - Raw bytes
    //
    // Receipt images don't go through the JSON path: they're megabytes of
    // binary and there's nothing to decode.

    /// Sends a body and discards the response. Retries once after a refresh.
    func send(_ request: URLRequest, body: Data) async throws {
        var req = request
        req.httpBody = body
        if let token = KeychainHelper.read(.accessToken) {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.upload(for: req, from: body)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if http.statusCode == 401, try await refreshTokens() {
            req.setValue("Bearer \(KeychainHelper.read(.accessToken) ?? "")",
                         forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await session.upload(for: req, from: body)
            guard let retryHTTP = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHTTP.statusCode) else {
                throw apiError(from: retryData, status: (retryResponse as? HTTPURLResponse)?.statusCode ?? 0)
            }
            return
        }

        guard (200...299).contains(http.statusCode) else {
            throw apiError(from: data, status: http.statusCode)
        }
    }

    /// Fetches raw bytes.
    func fetchData(_ request: URLRequest) async throws -> Data {
        var req = request
        if let token = KeychainHelper.read(.accessToken) {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if http.statusCode == 401, try await refreshTokens() {
            req.setValue("Bearer \(KeychainHelper.read(.accessToken) ?? "")",
                         forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await session.data(for: req)
            guard let retryHTTP = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHTTP.statusCode) else {
                throw APIClientError.unauthorized
            }
            return retryData
        }

        guard (200...299).contains(http.statusCode) else {
            throw apiError(from: data, status: http.statusCode)
        }
        return data
    }

    private func apiError(from data: Data, status: Int) -> APIClientError {
        if let apiErr = try? decoder.decode(APIError.self, from: data) {
            return .server(apiErr.error)
        }
        return .httpError(status)
    }

    // MARK: - Token refresh

    private func refreshTokens() async throws -> Bool {
        // If a refresh is already in flight, wait for its result
        // instead of sending a duplicate request with the same token
        if let existing = refreshTask {
            return try await existing.value
        }

        let task = Task { () throws -> Bool in
            guard let refreshToken = KeychainHelper.read(.refreshToken) else {
                return false
            }

            let body = RefreshRequestBody(refreshToken: refreshToken)
            var req = URLRequest(url: APIEndpoints.authRefresh)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(body)

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: req)
            } catch {
                return false
            }

            guard let http = response as? HTTPURLResponse else {
                return false
            }

            if http.statusCode == 200 {
                let tokens = try decoder.decode(AuthTokenResponse.self, from: data)
                KeychainHelper.save(tokens.accessToken, for: .accessToken)
                KeychainHelper.save(tokens.refreshToken, for: .refreshToken)
                return true
            }

            if http.statusCode == 401 || http.statusCode == 403 {
                KeychainHelper.delete(.accessToken)
                KeychainHelper.delete(.refreshToken)
            }

            return false
        }

        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }
}

struct EmptyResponse: Codable {}

enum APIClientError: LocalizedError {
    case invalidResponse
    case unauthorized
    case noContent
    case httpError(Int)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .unauthorized: return "Session expired. Please log in again."
        case .noContent: return "No content"
        case .httpError(let code): return "HTTP error \(code)"
        case .server(let msg): return msg
        }
    }
}
