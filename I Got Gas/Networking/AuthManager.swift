//
//  AuthManager.swift
//  I Got Gas
//
//  Created by Claude on 2025.
//

import Foundation
import SwiftUI

@MainActor
@Observable
class AuthManager {
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var email: String = ""
    var userID: String = ""
    var errorMessage: String?
    var magicLinkSent: Bool = false
    var pollStatus: String?
    var skippedLogin: Bool = UserDefaults.standard.bool(forKey: "skippedLogin") {
        didSet { UserDefaults.standard.set(skippedLogin, forKey: "skippedLogin") }
    }

    private var pollToken: String?
    private var pollTask: Task<Void, Never>?

    init() {
        isAuthenticated = KeychainHelper.read(.accessToken) != nil
        email = KeychainHelper.read(.userEmail) ?? ""
        userID = KeychainHelper.read(.userID) ?? ""
    }

    func fetchEmailIfNeeded() async {
        guard isAuthenticated, email.isEmpty || userID.isEmpty else { return }
        do {
            let me: MeResponse = try await APIClient.shared.request(
                APIEndpoints.me,
                method: "GET"
            )
            email = me.email
            userID = me.id
            KeychainHelper.save(me.email, for: .userEmail)
            KeychainHelper.save(me.id, for: .userID)
        } catch { }
    }

    func skipLogin() {
        skippedLogin = true
    }

    func requestMagicLink(email: String) async {
        self.email = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainHelper.save(self.email, for: .userEmail)
        isLoading = true
        errorMessage = nil

        do {
            let body = AuthRequestBody(email: self.email)
            let response: AuthRequestResponse = try await APIClient.shared.request(
                APIEndpoints.authRequest,
                method: "POST",
                body: body,
                authenticated: false
            )
            pollToken = response.pollToken
            magicLinkSent = true
            isLoading = false
            startPolling()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func handleDeepLinkTokens(accessToken: String, refreshToken: String) {
        stopPolling()
        KeychainHelper.save(accessToken, for: .accessToken)
        KeychainHelper.save(refreshToken, for: .refreshToken)
        isAuthenticated = true
        magicLinkSent = false
        pollStatus = nil
    }

    func startPolling() {
        stopPolling()
        guard let pollToken else { return }

        pollTask = Task { [weak self] in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let body = PollRequestBody(pollToken: pollToken)
            let bodyData = try? encoder.encode(body)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }

                // If already authenticated (e.g. deep link fired), stop
                if self?.isAuthenticated == true {
                    return
                }

                var request = URLRequest(url: APIEndpoints.authPoll)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = bodyData

                guard let (data, response) = try? await URLSession.shared.data(for: request),
                      let http = response as? HTTPURLResponse else {
                    continue
                }

                switch http.statusCode {
                case 200:
                    // Got tokens
                    guard let tokens = try? decoder.decode(AuthTokenResponse.self, from: data) else { continue }
                    self?.stopPolling()
                    KeychainHelper.save(tokens.accessToken, for: .accessToken)
                    KeychainHelper.save(tokens.refreshToken, for: .refreshToken)
                    self?.isAuthenticated = true
                    self?.magicLinkSent = false
                    self?.pollStatus = nil
                    return
                case 202:
                    // Still pending
                    continue
                case 410:
                    // Expired
                    self?.errorMessage = "Login link expired. Please try again."
                    self?.magicLinkSent = false
                    self?.pollStatus = nil
                    return
                default:
                    continue
                }
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func logout() async {
        stopPolling()
        if let refreshToken = KeychainHelper.read(.refreshToken) {
            let body = RefreshRequestBody(refreshToken: refreshToken)
            try? await APIClient.shared.requestNoContent(
                APIEndpoints.authLogout,
                method: "POST",
                body: body,
                authenticated: false
            )
        }
        KeychainHelper.deleteAll()
        isAuthenticated = false
        skippedLogin = false
        magicLinkSent = false
        pollToken = nil
        pollStatus = nil
    }
}
