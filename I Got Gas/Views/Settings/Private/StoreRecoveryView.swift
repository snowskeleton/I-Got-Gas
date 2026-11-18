//
//  StoreRecoveryView.swift
//  I Got Gas
//
//  Shown when the persistent store could not be opened.
//
//  The app is running on a throwaway in-memory store at this point, so it
//  looks empty. The single most important job of this screen is to stop the
//  user from deleting the app — the data is intact on disk, and reinstalling
//  is the one action that would actually destroy it.
//

import SwiftUI

struct StoreRecoveryView: View {
    let error: Error

    @State private var showDetail = false
    @State private var isExporting = false
    @State private var exportFailure: String?
    @State private var exported: ExportedArchive?

    private struct ExportedArchive: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Your data couldn't be opened")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("Nothing has been lost. Your records are still saved on this "
                 + "device — the app just can't read them right now.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("Please don't delete or reinstall the app. That would erase "
                 + "the data that's currently still safe.")
                .multilineTextAlignment(.center)
                .font(.callout.weight(.medium))

            // Lets the user see for themselves that the records still exist,
            // and gives support a copy to work from.
            Button {
                export()
            } label: {
                if isExporting {
                    ProgressView()
                } else {
                    Label("Export My Data", systemImage: "square.and.arrow.up")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting)

            if let exportFailure {
                Text(exportFailure)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Contact Support") {
                UIApplication.shared.open(URL(string: "mailto:support@igotgas.app")!)
            }
            .buttonStyle(.bordered)

            Button(showDetail ? "Hide Details" : "Show Details") {
                showDetail.toggle()
            }
            .font(.footnote)

            // This screen replaces the entire app, so it also cuts off the
            // usual route to Settings — and restoring a backup is the whole
            // reason someone would be looking at it.
            if Config.appConfiguration != .AppStore {
                NavigationLink {
                    DeveloperMenuView()
                } label: {
                    Label("Developer", systemImage: "hammer.fill")
                        .font(.footnote)
                }
            }

            if showDetail {
                ScrollView {
                    Text(String(describing: error))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            }
        }
        .padding(28)
        .sheet(item: $exported) { PumpScanShareSheet(url: $0.url) }
    }

    private func export() {
        isExporting = true
        exportFailure = nil
        Task { @MainActor in
            // Let the spinner draw before the synchronous copy starts.
            await Task.yield()
            defer { isExporting = false }
            do {
                let url = try RecoveryExport.makeArchive(
                    storeURL: SwiftDataManager.shared.storeURL, error: error
                )
                exported = ExportedArchive(url: url)
            } catch {
                exportFailure = "Couldn't export: \(error.localizedDescription)"
            }
        }
    }
}
