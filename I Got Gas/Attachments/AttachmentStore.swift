//
//  AttachmentStore.swift
//  I Got Gas
//
//  On-device storage and preparation of receipt images.
//
//  Photos are re-encoded before they go anywhere: a receipt does not need
//  twelve megapixels, and uploading originals over cellular is rude. EXIF is
//  dropped in the process, which also means we aren't quietly syncing the GPS
//  coordinates of wherever the photo was taken.
//

import Foundation
import ImageIO
import UIKit
import CryptoKit
import UniformTypeIdentifiers

enum AttachmentStore {

    /// Long edge of the stored image. Enough to read the fine print on a
    /// receipt, far less than a modern camera produces.
    static let maxDimension: CGFloat = 2048
    static let jpegQuality: CGFloat = 0.8

    /// Long edge of the inline thumbnail that syncs with the op.
    static let thumbnailDimension: CGFloat = 256

    struct Prepared {
        let data: Data
        let thumbnail: Data
        let width: Int
        let height: Int
        let sha256: String
    }

    // MARK: - Locations

    static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("Attachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            // Receipts are re-downloadable, but they're also the user's
            // records — don't hand them to iCloud backup by default.
            var url = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
        return directory
    }

    // MARK: - Preparation

    /// Downscales, strips metadata, and produces the thumbnail.
    static func prepare(_ image: UIImage) -> Prepared? {
        guard let full = downscale(image, to: maxDimension),
              let data = full.jpegData(compressionQuality: jpegQuality) else {
            return nil
        }
        guard let small = downscale(image, to: thumbnailDimension),
              let thumbnail = small.jpegData(compressionQuality: 0.7) else {
            return nil
        }

        return Prepared(
            data: data,
            thumbnail: thumbnail,
            width: Int(full.size.width),
            height: Int(full.size.height),
            sha256: digest(of: data)
        )
    }

    /// Decodes image data (including HEIC) and prepares it.
    static func prepare(data: Data) -> Prepared? {
        guard let image = UIImage(data: data) else { return nil }
        return prepare(image)
    }

    private static func downscale(_ image: UIImage, to maxEdge: CGFloat) -> UIImage? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }

        // Never upscale — a small photo stays as it is.
        let scale = min(1, maxEdge / longest)
        let target = CGSize(
            width: (image.size.width * scale).rounded(),
            height: (image.size.height * scale).rounded()
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    static func digest(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Disk

    @discardableResult
    static func write(_ data: Data, for attachmentID: String) -> String? {
        let filename = "\(attachmentID).jpg"
        let url = cacheDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            NSLog("attachments: could not write %@: %@", filename, error.localizedDescription)
            return nil
        }
    }

    static func read(_ filename: String) -> Data? {
        try? Data(contentsOf: cacheDirectory.appendingPathComponent(filename))
    }

    static func remove(_ filename: String) {
        try? FileManager.default.removeItem(
            at: cacheDirectory.appendingPathComponent(filename)
        )
    }

    /// Trims the cache to a size budget, oldest-accessed first. Anything
    /// evicted can be fetched again from the server.
    static func trimCache(toBytes budget: Int = 200 * 1024 * 1024) {
        let manager = FileManager.default
        guard let entries = try? manager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey]
        ) else { return }

        var files: [(url: URL, accessed: Date, size: Int)] = []
        var total = 0
        for url in entries {
            guard let values = try? url.resourceValues(
                forKeys: [.contentAccessDateKey, .fileSizeKey]
            ) else { continue }
            let size = values.fileSize ?? 0
            files.append((url, values.contentAccessDate ?? .distantPast, size))
            total += size
        }
        guard total > budget else { return }

        for file in files.sorted(by: { $0.accessed < $1.accessed }) {
            if total <= budget { break }
            try? manager.removeItem(at: file.url)
            total -= file.size
        }
    }
}
