//
//  PumpRealCaptureTests.swift
//  I Got GasTests
//
//  Real scans off a phone, replayed. Each fixture in PumpScans/ is what the
//  device's own Vision returned for every preprocessing pass of one capture,
//  so these run the parser and the ballot exactly as the phone did — no
//  camera, no Vision, and no Mac recognizer standing in for the phone's (the
//  two disagree; see the debug recorder's notes).
//
//  The first batch is twelve captures from one BP station, eight displays
//  with one scanned four times. They are here because they broke an
//  assumption the synthetic corpus never tested: the tallest text in the frame
//  was a nicotine ad on the topper, not the display.
//

import Testing
import Foundation
@testable import I_Got_Gas

private final class FixtureBundleToken {}

private struct RealCapture: Decodable, CustomTestStringConvertible {
    struct Line: Decodable {
        let text: String
        let midX: Double
        let midY: Double
        let height: Double
    }

    struct Pass: Decodable {
        let variant: String
        let lines: [Line]
    }

    var name = ""
    let expectedTotal: String
    let expectedVolume: String
    let currencyCode: String
    let volumeUnit: String
    let priceBandLow: String
    let priceBandHigh: String
    let passes: [Pass]

    private enum CodingKeys: String, CodingKey {
        case expectedTotal, expectedVolume, currencyCode, volumeUnit
        case priceBandLow, priceBandHigh, passes
    }

    var testDescription: String { name }

    var context: PumpScanContext {
        PumpScanContext(
            volumeUnit: VolumeUnit(rawValue: volumeUnit) ?? .gallonsUS,
            currencyCode: currencyCode,
            priceBand: Decimal(string: priceBandLow)!...Decimal(string: priceBandHigh)!
        )
    }

    var outcome: PumpBallot.Outcome? {
        let readings = passes.map { pass in
            PumpReadingParser.parse(
                pass.lines.map {
                    ScannedLine(text: $0.text, midX: $0.midX, midY: $0.midY, height: $0.height)
                },
                context: context
            )
        }
        return PumpBallot.winner(among: readings)
    }

    static func all() -> [RealCapture] {
        let bundle = Bundle(for: FixtureBundleToken.self)
        let urls = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("pump-scan-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  var capture = try? JSONDecoder().decode(RealCapture.self, from: data)
            else { return nil }
            capture.name = url.deletingPathExtension().lastPathComponent
            return capture
        }
    }
}

struct PumpRealCaptureTests {

    @Test func theFixturesAreBundled() {
        // A fixture that silently failed to load would pass every test below.
        #expect(RealCapture.all().count == 12)
    }

    /// 10.207 on the display, read as 10.201 by three passes of five: the
    /// final seven lost its top stroke and became a one. The majority is
    /// wrong, and nothing in the frame can say so. Left visible rather than
    /// fitted, so a change that fixes it — or a fixture that stops tripping
    /// it — shows up here.
    private static let lostStroke: Set<String> = ["pump-scan-bp-011825-1"]

    @Test(arguments: RealCapture.all())
    fileprivate func readsWhatThePumpShowed(_ capture: RealCapture) throws {
        let outcome = try #require(capture.outcome)
        let expectedVolume = try #require(Double(capture.expectedVolume))
        let expectedTotal = try #require(Decimal(string: capture.expectedTotal))

        #expect(outcome.reading.total?.amount == expectedTotal)

        let volume = outcome.reading.volume?.converted(to: .gallonsUS) ?? 0
        if Self.lostStroke.contains(capture.name) {
            withKnownIssue("a seven-segment 7 read as 1 by the majority") {
                #expect(abs(volume - expectedVolume) < 0.001)
            }
        } else {
            #expect(abs(volume - expectedVolume) < 0.001)
        }
    }
}
