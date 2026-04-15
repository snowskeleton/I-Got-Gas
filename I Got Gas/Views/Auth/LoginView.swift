//
//  LoginView.swift
//  I Got Gas
//
//  Created by Claude on 2025.
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var email = ""

    var body: some View {
        @Bindable var auth = authManager

        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "fuelpump.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("I Got Gas")
                    .font(.largeTitle.bold())

                Text("Sign in to sync your vehicles across devices and share with others.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if authManager.magicLinkSent {
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)

                        Text("Check your email")
                            .font(.headline)

                        Text("We sent a login link to **\(authManager.email)**")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        ProgressView()
                            .padding(.top, 8)
                        Text("Waiting for you to click the link...")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Use a different email") {
                            authManager.stopPolling()
                            authManager.magicLinkSent = false
                        }
                        .font(.subheadline)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        TextField("Email address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)

                        Button {
                            Task { await authManager.requestMagicLink(email: email) }
                        } label: {
                            if authManager.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Send Login Link")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(email.isEmpty || authManager.isLoading)
                        .padding(.horizontal)
                    }
                }

                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }


                Button("Continue without cloud saves") {
                    authManager.skipLogin()
                }
                .font(.subheadline)
                Spacer()

                Text("No password needed. We'll email you a secure login link.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
