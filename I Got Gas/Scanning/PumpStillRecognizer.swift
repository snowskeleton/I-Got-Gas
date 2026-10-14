//
//  PumpStillRecognizer.swift
//  I Got Gas
//
//  Reads text out of one high-resolution photo of a pump display — several
//  times, from several treatments of the same pixels.
//
//  The live `DataScanner` stream can say the shot is framed and steady, but it
//  cannot say what the display reads: its frames are too small and too soft to
//  hold a seven-segment decimal point. At 720px "22.151" comes back "22151".
//
//  A single read of the still isn't enough either, because Vision reports one
//  candidate at confidence 1.00 whether or not it is right. What it will do is
//  fail *differently* on differently processed copies — measured on a real
//  pump photo, the plain image dropped a decimal point that the
//  contrast-boosted copy kept. Reading every variant and voting turns that
//  into the corroboration a two-number display otherwise denies us.
//
//  Language correction stays off throughout. It exists to turn near-misses
//  into real words, which is the opposite of what a wall of digits needs.
//

import Foundation
import CoreImage
import UIKit
import Vision

enum PumpStillRecognizer {

    /// Working size for the long edge before recognition.
    ///
    /// A capture is far larger than the recognizer needs — a 900px copy of a
    /// pump photo reads perfectly — and full-resolution passes cost close to a
    /// second each, which we then pay once per variant. This keeps the digits
    /// comfortably oversized while keeping every pass in the tens of
    /// milliseconds.
    static let workingDimension: CGFloat = 1600

    /// How the image is treated before each pass. The point is that these
    /// disagree: see the file comment.
    ///
    /// There were two more — a 2x upscale and a contrast-boosted 2x upscale —
    /// and they are gone. Between them they accounted for 57% of all the
    /// pixels this pipeline touched and 26MB apiece, and on both real pump
    /// photos in the corpus they changed no outcome: the BP capture read
    /// unanimously with or without them, and the Exxon capture carried its
    /// majority either way. Upscaling also walks text towards the size where
    /// Vision stops reading it at all — digits around 240px read perfectly
    /// and the same digits at 540px came back as "1..".
    enum Variant: CaseIterable {
        case plain
        case contrast
        case highContrast
        case darkened
        case brightened
        case sharpened
    }

    /// How many passes run at once.
    ///
    /// Each pass is a *blocking* `VNRecognizeTextRequest` holding a thread
    /// from the cooperative pool, which on a phone has roughly as many threads
    /// as the device has cores. Submitting every variant at once filled that
    /// pool and held every preprocessed copy of the image in memory at the
    /// same time. Three keeps the pipeline saturated without doing either.
    private static let concurrentPasses = 3

    /// Recognizes the image once per variant. Order matches `Variant.allCases`
    /// and a variant that fails outright contributes an empty array rather
    /// than dropping out, so callers can still tell how many passes ran.
    static func ensemble(for image: UIImage) async -> [[ScannedLine]] {
        let started = Date()
        guard let prepared = downscaled(image) else { return [] }
        let orientation = orientation(of: image)
        let variants = Variant.allCases

        let results = await withTaskGroup(of: (Int, [ScannedLine]).self) { group in
            var results = Array(repeating: [ScannedLine](), count: variants.count)
            var next = 0

            while next < variants.count, next < concurrentPasses {
                let index = next
                let variant = variants[index]
                group.addTask {
                    let treated = apply(variant, to: prepared) ?? prepared
                    return (index, read(treated, orientation: orientation))
                }
                next += 1
            }

            // One more goes in as each one comes out, so at most
            // `concurrentPasses` images exist at a time.
            while let (index, lines) = await group.next() {
                results[index] = lines
                guard next < variants.count else { continue }
                let queued = next
                let variant = variants[queued]
                group.addTask {
                    let treated = apply(variant, to: prepared) ?? prepared
                    return (queued, read(treated, orientation: orientation))
                }
                next += 1
            }
            return results
        }

        NSLog(
            "pump scan: %d passes over %dx%d in %.0f ms, %d runs read",
            variants.count, prepared.width, prepared.height,
            Date().timeIntervalSince(started) * 1000,
            results.reduce(0) { $0 + $1.count }
        )
        return results
    }

    // MARK: - Recognition

    private static func read(
        _ image: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> [ScannedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        do {
            try VNImageRequestHandler(
                cgImage: image,
                orientation: orientation,
                options: [:]
            ).perform([request])
        } catch {
            NSLog("pump scan: recognition failed: %@", error.localizedDescription)
            return []
        }

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox

            return ScannedLine(
                text: candidate.string,
                midX: box.midX,
                // Vision measures from the bottom up; everything downstream —
                // and the pump face itself — reads top down.
                midY: 1 - box.midY,
                height: box.height
            )
        }
    }

    // MARK: - Image preparation

    private static let ciContext = CIContext()

    private static func apply(_ variant: Variant, to image: CGImage) -> CGImage? {
        switch variant {
        case .plain:
            return image

        case .contrast:
            // Drops colour and stretches the gap between lit and unlit
            // segments. This is the variant that rescues a decimal point the
            // plain pass loses.
            return colorControls(image, contrast: 2.0, brightness: 0)

        case .highContrast:
            return colorControls(image, contrast: 3.0, brightness: -0.1)

        case .darkened:
            return gamma(image, power: 1.6)

        case .brightened:
            // Pulls detail out of a display washed out by direct sun.
            return gamma(image, power: 0.6)

        case .sharpened:
            return filter(image) { input in
                let f = CIFilter(name: "CIUnsharpMask")
                f?.setValue(input, forKey: kCIInputImageKey)
                f?.setValue(2.5, forKey: kCIInputRadiusKey)
                f?.setValue(1.5, forKey: kCIInputIntensityKey)
                return f?.outputImage
            }
        }
    }

    private static func colorControls(
        _ image: CGImage,
        contrast: Double,
        brightness: Double
    ) -> CGImage? {
        filter(image) { input in
            let f = CIFilter(name: "CIColorControls")
            f?.setValue(input, forKey: kCIInputImageKey)
            f?.setValue(contrast, forKey: kCIInputContrastKey)
            f?.setValue(brightness, forKey: kCIInputBrightnessKey)
            f?.setValue(0.0, forKey: kCIInputSaturationKey)
            return f?.outputImage
        }
    }

    private static func gamma(_ image: CGImage, power: Double) -> CGImage? {
        filter(image) { input in
            let f = CIFilter(name: "CIGammaAdjust")
            f?.setValue(input, forKey: kCIInputImageKey)
            f?.setValue(power, forKey: "inputPower")
            return f?.outputImage
        }
    }

    private static func filter(
        _ image: CGImage,
        _ build: (CIImage) -> CIImage?
    ) -> CGImage? {
        let input = CIImage(cgImage: image)
        guard let output = build(input)?.cropped(to: input.extent) else { return nil }
        return ciContext.createCGImage(output, from: input.extent)
    }

    private static func downscaled(_ image: UIImage) -> CGImage? {
        guard let cgImage = image.cgImage else { return nil }

        let longest = CGFloat(max(cgImage.width, cgImage.height))
        guard longest > workingDimension else { return cgImage }

        let scale = workingDimension / longest
        let width = Int((CGFloat(cgImage.width) * scale).rounded())
        let height = Int((CGFloat(cgImage.height) * scale).rounded())

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return cgImage }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? cgImage
    }

    private static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
