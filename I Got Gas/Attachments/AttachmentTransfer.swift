//
//  AttachmentTransfer.swift
//  I Got Gas
//
//  Moves image bytes to and from the server.
//
//  Deliberately separate from the op stream: the op records that a photo
//  exists and carries its thumbnail, and the bytes follow on their own
//  schedule. That way a slow or failed upload never blocks a sync, and a
//  photo taken offline still appears everywhere as soon as it can.
//

import Foundation
import SwiftData

@MainActor
final class AttachmentTransfer {

    static let shared = AttachmentTransfer()

    private var running = false

    /// Uploads anything captured here that the server doesn't have yet.
    func uploadPending(context: ModelContext) async {
        guard !running else { return }
        running = true
        defer { running = false }

        let descriptor = FetchDescriptor<SDAttachment>(
            predicate: #Predicate { $0.deleted == false }
        )
        let attachments = (try? context.fetch(descriptor)) ?? []

        for attachment in attachments
        where attachment.uploadState == .pendingUpload && attachment.uploadAttempts < 5 {
            guard let filename = attachment.localFilename,
                  let data = AttachmentStore.read(filename) else {
                // Bytes are gone locally and were never uploaded; nothing to
                // send and nothing to fetch.
                attachment.uploadState = .failed
                continue
            }

            do {
                try await upload(data: data, attachment: attachment)
                attachment.uploadState = .uploaded
                attachment.uploadAttempts = 0
            } catch {
                attachment.uploadAttempts += 1
                if attachment.uploadAttempts >= 5 {
                    attachment.uploadState = .failed
                }
                NSLog("attachments: upload %@ failed: %@", attachment.id, error.localizedDescription)
            }
        }
        try? context.save()
    }

    private func upload(data: Data, attachment: SDAttachment) async throws {
        var request = URLRequest(
            url: APIEndpoints.attachmentBlob(attachment.id)
        )
        request.httpMethod = "POST"
        request.setValue(attachment.mimeType, forHTTPHeaderField: "Content-Type")
        try await APIClient.shared.send(request, body: data)
    }

    /// Fetches the full-size image, caching it on disk. Thumbnails are already
    /// local, so this is only needed when someone opens a photo.
    @discardableResult
    func download(_ attachment: SDAttachment, context: ModelContext) async -> Data? {
        if let path = attachment.localPath, let data = try? Data(contentsOf: path) {
            return data
        }

        var request = URLRequest(url: APIEndpoints.attachmentBlob(attachment.id))
        request.httpMethod = "GET"

        do {
            let data = try await APIClient.shared.fetchData(request)
            if let filename = AttachmentStore.write(data, for: attachment.id) {
                attachment.localFilename = filename
                attachment.uploadState = .uploaded
                try? context.save()
            }
            AttachmentStore.trimCache()
            return data
        } catch {
            NSLog("attachments: download %@ failed: %@", attachment.id, error.localizedDescription)
            return nil
        }
    }
}
