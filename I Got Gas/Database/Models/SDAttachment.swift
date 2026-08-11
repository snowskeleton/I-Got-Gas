//
//  SDAttachment.swift
//  I Got Gas
//
//  A receipt photo attached to an expense.
//
//  The row and its thumbnail travel through the op log, so a list can render
//  on any device without a network round trip. The full-size image is uploaded
//  and downloaded separately, and cached on disk.
//

import Foundation
import SwiftData

enum AttachmentUploadState: String, Codable, CaseIterable, Sendable {
    /// Captured here, bytes not yet on the server.
    case pendingUpload
    /// Bytes are on the server and also cached locally.
    case uploaded
    /// Known to exist on the server; bytes not fetched yet.
    case remote
    /// Upload failed enough times to stop trying automatically.
    case failed
}

@Model
class SDAttachment: Identifiable {
    var id: String = UUID().uuidString

    var service: SDService?

    var filename: String = ""
    var mimeType: String = "image/jpeg"
    var byteSize: Int = 0

    /// Content hash, used to verify the upload and to skip re-adding
    /// the same photo twice.
    var sha256: String = ""

    var width: Int = 0
    var height: Int = 0

    /// Small enough to sync inline. This is what list views draw.
    @Attribute(.externalStorage)
    var thumbnailData: Data?

    var uploadStateRaw: String = AttachmentUploadState.pendingUpload.rawValue

    /// Filename within the app's attachment cache directory, when the
    /// full-size image is present locally.
    var localFilename: String?

    var uploadAttempts: Int = 0

    var deleted: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() { }

    var uploadState: AttachmentUploadState {
        get { AttachmentUploadState(rawValue: uploadStateRaw) ?? .pendingUpload }
        set { uploadStateRaw = newValue.rawValue }
    }

    /// Absolute path to the cached full-size image, if it's here.
    var localPath: URL? {
        guard let localFilename else { return nil }
        let url = AttachmentStore.cacheDirectory.appendingPathComponent(localFilename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func touch() {
        updatedAt = Date()
    }
}
