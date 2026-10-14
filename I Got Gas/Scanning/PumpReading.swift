//
//  PumpReading.swift
//  I Got Gas
//
//  What we managed to read off a pump display, and the detector that decides
//  when the camera is being held still enough to take the picture.
//
//  The live recognizer stream is not where the numbers come from. Live frames
//  are small and motion-blurred, and a seven-segment decimal point is a few
//  pixels wide: at 720px "22.151" comes back as "22151", and with any blur it
//  splits into "22.15 1". The same display photographed at full resolution
//  reads perfectly. So the stream is used only to tell when the shot is framed
//  and steady — the reading itself comes from one high-resolution still.
//

import Foundation

// MARK: - Input

/// One run of text as the recognizer saw it, with just enough geometry to
/// break a tie and to tell whether the frame is holding still.
///
/// Deliberately not a Vision type: the parser has to stay testable against a
/// corpus of strings, with no camera and no pump anywhere near it.
struct ScannedLine: Equatable, Sendable {
    var text: String

    /// Horizontal centre in normalized frame coordinates, 0 at the left.
    var midX: Double

    /// Vertical centre in normalized frame coordinates, 0 at the top. The
    /// total sale is usually the upper of the two displays.
    var midY: Double

    /// Height in normalized frame coordinates. The total sale is usually the
    /// larger of the two displays.
    var height: Double

    init(text: String, midX: Double = 0.5, midY: Double = 0.5, height: Double = 0.1) {
        self.text = text
        self.midX = midX
        self.midY = midY
        self.height = height
    }
}

// MARK: - Pointing at it

/// Where the user said the sale amount is, in the same normalized frame
/// coordinates as `ScannedLine`.
///
/// The live stream transcribes a pump far too poorly to read one — see the
/// note at the top of this file — but it knows precisely *where* the text it
/// found sits, and `DataScannerViewController` will say which run was tapped.
/// That turns a tap into the one thing the parser can never work out on its
/// own: which of two numbers is the money. Every other signal it has, from
/// decimal places to the price band, is an inference standing in for exactly
/// this.
struct PumpScanHint: Equatable, Sendable {
    var midX: Double
    var midY: Double
}

// MARK: - Context

/// Everything the parser needs to know that isn't in the image.
struct PumpScanContext: Sendable {
    /// What the account displays volumes in. Also the fallback for what the
    /// pump is assumed to be dispensing in when its labels aren't legible.
    var volumeUnit: VolumeUnit
    var currencyCode: String

    /// Per-unit prices this user plausibly pays, in major currency units.
    /// Standing in for the arithmetic check, on the pumps that show only two
    /// numbers and so can't offer one.
    var priceBand: ClosedRange<Decimal>

    /// Where the user pointed at the sale amount, if they had to.
    ///
    /// Nothing sets this on a first read. It arrives only after a reading the
    /// user didn't accept, and it outweighs everything else here.
    var hint: PumpScanHint?

    init(
        volumeUnit: VolumeUnit = UnitPreferences.volumeUnit,
        currencyCode: String = UnitPreferences.currencyCode,
        priceBand: ClosedRange<Decimal> = PumpScanContext.unboundedPriceBand,
        hint: PumpScanHint? = nil
    ) {
        self.volumeUnit = volumeUnit
        self.currencyCode = currencyCode
        self.priceBand = priceBand
        self.hint = hint
    }

    /// Used before there's any history to learn from. Wide enough to be
    /// useless as a discriminator, which is the honest position when we have
    /// no idea what fuel costs where this person lives — currencies differ by
    /// three orders of magnitude per litre.
    static let unboundedPriceBand: ClosedRange<Decimal> =
        Decimal(string: "0.05")! ... Decimal(10_000)

    /// Builds the band from what this user has actually been paying.
    ///
    /// Takes the already-computed per-unit prices rather than the entries
    /// themselves — `SDService.costPerVolume` does that work, and keeping
    /// SwiftData out of here keeps the parser testable.
    ///
    /// The window is generous on purpose. It exists to reject the swapped
    /// assignment, which is wrong by roughly a factor of ten, not to police
    /// week-to-week price movement.
    static func priceBand(fromRecent prices: [Money]) -> ClosedRange<Decimal> {
        let amounts = prices.map(\.amount).filter { $0 > 0 }.sorted()
        guard amounts.count >= 2 else { return unboundedPriceBand }

        let median = amounts[amounts.count / 2]
        let low = median * Decimal(string: "0.5")!
        let high = median * Decimal(string: "1.75")!
        guard low > 0, low < high else { return unboundedPriceBand }
        return low...high
    }
}

// MARK: - Reading

/// One interpretation of a pump display. Every field is optional because a
/// display half-lost to glare is the normal case, not the exception.
struct PumpReading: Equatable, Sendable {
    var total: Money?
    var volume: Volume?

    /// The unit we read the pump as dispensing in — from its own labels when
    /// they were legible, otherwise the account's.
    var volumeUnit: VolumeUnit

    /// `total ÷ volume` in major currency units. Never stored: `SDService` has
    /// no field for it. It's the sanity check, and the number the user
    /// eyeballs to confirm at a glance that we read the display the right way
    /// round.
    var impliedUnitPrice: Decimal?

    /// Whether `impliedUnitPrice` landed inside the expected band. This goes
    /// false for a genuinely unusual fill as readily as for a misread, so it
    /// colours the readout but never blocks the user from accepting it.
    var isPlausible: Bool

    init(
        total: Money? = nil,
        volume: Volume? = nil,
        volumeUnit: VolumeUnit,
        impliedUnitPrice: Decimal? = nil,
        isPlausible: Bool = false
    ) {
        self.total = total
        self.volume = volume
        self.volumeUnit = volumeUnit
        self.impliedUnitPrice = impliedUnitPrice
        self.isPlausible = isPlausible
    }

    /// Both numbers read.
    var isComplete: Bool { total != nil && volume != nil }

    /// Nothing usable at all.
    var isEmpty: Bool { total == nil && volume == nil }

    /// Two readings are the same vote when they say the same thing about the
    /// pump. The bookkeeping around them — how much of the display a pass
    /// recovered, what it implied about the price — is not part of that, and
    /// counting it would split one answer into several.
    static func == (lhs: PumpReading, rhs: PumpReading) -> Bool {
        lhs.total == rhs.total
            && lhs.volume == rhs.volume
            && lhs.volumeUnit == rhs.volumeUnit
    }
}

// MARK: - Steadiness

/// Decides when the live preview has settled enough to be worth photographing.
///
/// This is the only job the live recognizer stream has. It watches where the
/// numeric text sits and how big it is, and reports when that has stopped
/// moving. It deliberately ignores *what* the text says: the live transcripts
/// are unreliable enough that waiting for them to agree would mean waiting
/// forever, and the still we capture is what actually gets read.
struct PumpScanSteadiness {

    /// How long the framing must hold before we take the shot.
    ///
    /// Short, deliberately. A blurred capture is cheap to recover from — the
    /// reading gets voted down and another photo is taken — whereas making the
    /// user hold a phone motionless is not. Waiting for certainty here was
    /// what made the first version take fifteen seconds to produce anything.
    static let requiredHold: TimeInterval = 0.35

    /// How far the text may drift and still count as still, as a fraction of
    /// the frame.
    static let tolerance: Double = 0.025

    /// The box the numeric text occupies, and nothing else.
    ///
    /// An earlier version compared how *many* runs were in view. That was the
    /// bug behind the fifteen-second first scan: the live recognizer splits and
    /// merges runs constantly — "22.151" arrives as one run, then as "22.15"
    /// and "1" — so the count almost never held still for long enough, and the
    /// hold restarted over and over while the camera was in fact perfectly
    /// still. Where the text sits is stable even while what it says is not.
    private struct Snapshot {
        let minY: Double
        let maxY: Double
        let centerX: Double

        func matches(_ other: Snapshot) -> Bool {
            abs(minY - other.minY) <= PumpScanSteadiness.tolerance
                && abs(maxY - other.maxY) <= PumpScanSteadiness.tolerance
                && abs(centerX - other.centerX) <= PumpScanSteadiness.tolerance
        }
    }

    private var held: Snapshot?
    private var heldSince: Date?

    /// How close the framing is to triggering a capture, 0...1.
    private(set) var progress: Double = 0

    init() { }

    /// Feeds one frame of recognized text in. Returns true the moment the
    /// framing has held still long enough to photograph.
    mutating func observe(_ lines: [ScannedLine], at now: Date = Date()) -> Bool {
        guard let snapshot = Self.snapshot(of: lines) else {
            reset()
            return false
        }

        // Compared against the snapshot that started the hold, not the
        // previous frame, so a slow continuous drift can't creep past the
        // tolerance one imperceptible step at a time.
        guard let held, let heldSince, held.matches(snapshot) else {
            self.held = snapshot
            self.heldSince = now
            progress = 0
            return false
        }

        let elapsed = now.timeIntervalSince(heldSince)
        progress = min(1, elapsed / Self.requiredHold)
        return elapsed >= Self.requiredHold
    }

    mutating func reset() {
        held = nil
        heldSince = nil
        progress = 0
    }

    /// Built from the numeric runs alone. Captions flicker in and out of the
    /// live stream constantly, and letting that reset the hold would mean it
    /// never completes.
    ///
    /// One numeric run is enough to start holding. Requiring two meant a frame
    /// where the recognizer briefly merged both displays into a single run
    /// counted as nothing in view.
    private static func snapshot(of lines: [ScannedLine]) -> Snapshot? {
        let numeric = lines.filter { $0.text.filter(\.isNumber).count >= 2 }
        guard !numeric.isEmpty else { return nil }

        let tops = numeric.map { $0.midY - $0.height / 2 }
        let bottoms = numeric.map { $0.midY + $0.height / 2 }

        return Snapshot(
            minY: tops.min() ?? 0,
            maxY: bottoms.max() ?? 0,
            centerX: numeric.reduce(0) { $0 + $1.midX } / Double(numeric.count)
        )
    }
}
