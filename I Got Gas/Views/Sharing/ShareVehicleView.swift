//
//  ShareVehicleView.swift
//  I Got Gas
//
//  Created by Claude on 2025.
//

import SwiftUI

struct ShareVehicleView: View {
    let carID: String
    let carName: String

    @State private var shareManager = ShareManager()
    @State private var inviteEmail = ""

    var body: some View {
        List {
            Section("Invite") {
                HStack {
                    TextField("Email address", text: $inviteEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    Button("Send") {
                        let email = inviteEmail
                        inviteEmail = ""
                        Task { await shareManager.createShare(carID: carID, email: email) }
                    }
                    .disabled(inviteEmail.isEmpty || shareManager.isLoading)
                }
            }

            if !shareManager.shares.isEmpty {
                Section("Shared With") {
                    ForEach(shareManager.shares) { share in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(share.invitedEmail)
                                Text(share.status.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(statusColor(share.status))
                            }
                            Spacer()
                        }
                        .swipeActions {
                            if share.status != "revoked" {
                                Button("Revoke", role: .destructive) {
                                    Task { await shareManager.revokeShare(carID: carID, shareID: share.id) }
                                }
                            }
                        }
                    }
                }
            }

            if let error = shareManager.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Share \(carName)")
        .task {
            await shareManager.listShares(carID: carID)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "accepted": return .green
        case "pending": return .orange
        case "declined", "revoked": return .red
        default: return .secondary
        }
    }
}
