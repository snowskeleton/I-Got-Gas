//
//  ShareManager.swift
//  I Got Gas
//
//  Created by Claude on 2025.
//

import Foundation

@Observable
class ShareManager {
    var isLoading = false
    var errorMessage: String?
    var shares: [ShareResponse] = []
    var receivedShares: [ShareResponse] = []

    var pendingShares: [ShareResponse] {
        receivedShares.filter { $0.status == "pending" }
    }

    func createShare(carID: String, email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let body = CreateShareRequest(email: email)
            let response: ShareResponse = try await APIClient.shared.request(
                APIEndpoints.carShares(carID),
                method: "POST",
                body: body
            )
            await MainActor.run {
                shares.append(response)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func listShares(carID: String) async {
        isLoading = true
        do {
            let response: [ShareResponse] = try await APIClient.shared.request(
                APIEndpoints.carShares(carID),
                method: "GET"
            )
            await MainActor.run {
                shares = response
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func revokeShare(carID: String, shareID: String) async {
        do {
            try await APIClient.shared.requestNoContent(
                APIEndpoints.revokeShare(carID, shareID),
                method: "DELETE"
            )
            await MainActor.run {
                shares.removeAll { $0.id == shareID }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    func fetchReceivedShares() async {
        do {
            let response: [ShareResponse] = try await APIClient.shared.request(
                APIEndpoints.receivedShares,
                method: "GET"
            )
            await MainActor.run {
                receivedShares = response
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    func acceptShare(shareID: String) async {
        do {
            let _: [String: String] = try await APIClient.shared.request(
                APIEndpoints.acceptShare(shareID),
                method: "POST"
            )
            await MainActor.run {
                receivedShares.removeAll { $0.id == shareID }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    func declineShare(shareID: String) async {
        do {
            let _: [String: String] = try await APIClient.shared.request(
                APIEndpoints.declineShare(shareID),
                method: "POST"
            )
            await MainActor.run {
                receivedShares.removeAll { $0.id == shareID }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    func leaveShare(shareID: String) async {
        do {
            let _: [String: String] = try await APIClient.shared.request(
                APIEndpoints.leaveShare(shareID),
                method: "POST"
            )
            await MainActor.run {
                receivedShares.removeAll { $0.id == shareID }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}
