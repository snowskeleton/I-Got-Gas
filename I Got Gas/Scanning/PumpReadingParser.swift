//
//  PumpReadingParser.swift
//  I Got Gas
//
//  Turns recognized text from a pump display into a total and a volume.
//
//  Most pumps give two numbers and no way for them to check each other, so
//  working out which is which comes down to a stack of signals, in roughly
//  this order of strength:
//
//    1. Size and shape. The sale and volume are printed at the same scale and
//       stacked one over the other, and nothing else on a pump pairs up that
//       way. Size is judged within each pair rather than against the whole
//       frame: on a real BP capture an ad topper's "$4.49" stood twice as tall
//       as the display, and measuring against it threw out the gallons.
//       Octane ratings, bay numbers and gift-card prices are small and sit
//       below the display, and that is a fact about geometry: answering it
//       with a rule about decimal points is what once cost us the sale amount
//       itself.
//    2. What the user pointed at. Only present after a read they didn't
//       accept, and the only signal here that isn't an inference.
//    3. A third number, when the pump shows its unit price too. The only
//       signal that can be checked rather than believed: price × volume has
//       to come back as the total.
//    4. Labels, when they're lit and legible — often they aren't, and a
//       caption more than about one display-height away is captioning
//       something else.
//    5. Length and decimal places. A USD total carries two decimals, gallons
//       carry three, and a bare integer is a value only if it is long enough
//       to be one with its point knocked out.
//    6. The implied per-unit price, checked against what this user actually
//       pays. The swapped assignment is wrong by roughly a factor of ten and
//       this is what catches it.
//    7. Layout, as a tiebreak: the sale is the upper and larger display.
//
//  When the top of that stack is silent and the rest ties, the parser returns
//  nothing rather than guessing. Parsing is deterministic, so a coin-flip
//  would flip the same way on every variant and sail through the ballot.
//
//  Nothing here imports Vision or UIKit, which is the point: the hard part is
//  the interpretation, and it has to be testable against a corpus of strings
//  rather than against a road trip.
//

import Foundation

enum PumpReadingParser {

    // MARK: - Entry

    static func parse(_ lines: [ScannedLine], context: PumpScanContext) -> PumpReading {
        let unit = volumeUnit(in: lines, accountUnit: context.volumeUnit)
        let currencyDigits = Money.fractionDigits(for: context.currencyCode)

        // Labels and their values usually arrive as separate runs: a pump face
        // captioned "Purchase" over a "$" over the digits gives four items,
        // only one of which is a number.
        var found: [Candidate] = []
        var orphanLabels: [(field: Field, midY: Double)] = []

        for line in lines {
            let inLine = candidates(in: line)
            if inLine.isEmpty {
                if let label = label(in: line.text) {
                    orphanLabels.append((label, line.midY))
                }
            } else {
                found.append(contentsOf: inLine)
            }
        }

        // Before anything else gets a vote: the display towers over the rest
        // of the pump, and nothing printed on the machine can compete. A run
        // the user pointed at is exempt — they can see the pump and we can't.
        markHinted(&found, hint: context.hint)
        found = atDisplayScale(found)

        adoptNearbyLabels(orphanLabels, into: &found)

        let numbers = deduplicated(found.filter { $0.isUsable(currencyDigits: currencyDigits) })

        guard !numbers.isEmpty else {
            return PumpReading(volumeUnit: unit)
        }

        if let pair = bestPair(among: numbers, unit: unit, context: context) {
            return reading(
                total: pair.totalPlacement,
                volume: pair.volumePlacement,
                unit: unit,
                context: context
            )
        }

        // One number legible is still half the typing saved — but only when
        // we can say which one it is without guessing.
        if let lone = unambiguousLone(
            among: numbers,
            currencyDigits: currencyDigits,
            volumeDigits: unit.entryFractionDigits
        ) {
            switch lone.field {
            case .total:
                // A run that can't be read as money at all is not an answer,
                // however clearly it was labelled as one.
                guard let placement = lone.candidate.primaryMoney(
                    currencyDigits: currencyDigits
                ) else {
                    return PumpReading(volumeUnit: unit)
                }
                return reading(
                    total: placement,
                    volume: nil,
                    unit: unit,
                    context: context
                )
            case .volume:
                guard let placement = lone.candidate.primaryVolume(
                    fractionDigits: unit.entryFractionDigits
                ) else {
                    return PumpReading(volumeUnit: unit)
                }
                return reading(
                    total: nil,
                    volume: placement,
                    unit: unit,
                    context: context
                )
            }
        }

        return PumpReading(volumeUnit: unit)
    }

    // MARK: - Display scale

    /// Drops the fine print, and bounds how many runs reach the scoring.
    ///
    /// On the capture that produced a $0.030/gal reading, the sale and volume
    /// digits measured 0.150 and 0.100 of the frame height while every other
    /// run on the pump — the card decals, the brand marks, the "$25" gift-card
    /// price that was read as the total — came in at 0.031 or below.
    ///
    /// This used to be the whole display-scale test, measured against the
    /// tallest run in the frame, and real captures broke it. A phone held at
    /// arm's length takes in the whole pump face, and at a BP station the
    /// tallest text in every frame was a nicotine ad on the topper: "$4.49" at
    /// 0.11 of the frame against a display at 0.04–0.07. Measured against
    /// that, the gallons fell below the cut on every pass, and what was left
    /// read "$4.49" as the sale and the real $9.90 as 0.990 gallons — a
    /// believable price, agreed on by three passes of four. The tallest thing
    /// in the frame is not necessarily the display, so the real scale test is
    /// now made per pair, in `isDisplayPair`; this one only has to be loose
    /// enough never to cut the display under a sign twice its size.
    private static func atDisplayScale(_ candidates: [Candidate]) -> [Candidate] {
        guard let tallest = candidates.map(\.height).max(), tallest > 0 else {
            return candidates
        }
        let kept = candidates.filter { $0.isHinted || $0.height >= tallest * finePrintFloor }
        guard kept.count > maximumCandidates else { return kept }

        // Keep the biggest, and whatever the user pointed at. Ties break on
        // value so the same frame always keeps the same runs — the ballot is
        // counting agreement between passes, and a parser that wandered would
        // make that meaningless.
        let ranked = kept.enumerated().sorted {
            if $0.element.isHinted != $1.element.isHinted { return $0.element.isHinted }
            if $0.element.height != $1.element.height {
                return $0.element.height > $1.element.height
            }
            return $0.element.value > $1.element.value
        }
        let survivors = Set(ranked.prefix(maximumCandidates).map(\.offset))
        return kept.enumerated().filter { survivors.contains($0.offset) }.map(\.element)
    }

    /// A hard ceiling on how many runs reach the scoring.
    ///
    /// Scoring is quartic in this number: every ordered pair, times every
    /// placement of both decimal points, times a sweep over the remaining
    /// candidates looking for a unit price. At two candidates that is 6ms and
    /// at twenty it is 670ms — times eight variants, times two attempts, on a
    /// phone, on the main actor. That is what "stuck reading the display"
    /// was, and the height filter alone does not bound it: a photograph of a
    /// whole pump carries far more numeric runs than a tight one, and the
    /// older rule that threw out every unlabelled bare integer was hiding the
    /// cost rather than fixing it.
    ///
    /// Six is already generous. A display shows two numbers, or three where it
    /// prints the unit price, and this keeps the tallest six of whatever
    /// cleared the filter.
    private static let maximumCandidates = 6

    // MARK: - What the user pointed at

    /// Marks the run nearest the tap as the sale amount.
    ///
    /// Nearest in the plane rather than by row: the two displays can sit side
    /// by side as readily as stacked, and a tap that only knew about height
    /// would be a coin flip on the pumps that put them in a row.
    private static func markHinted(_ candidates: inout [Candidate], hint: PumpScanHint?) {
        guard let hint, !candidates.isEmpty else { return }

        var nearest = 0
        var shortest = Double.infinity
        for (index, candidate) in candidates.enumerated() {
            let dx = candidate.midX - hint.midX
            let dy = candidate.midY - hint.midY
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance < shortest {
                shortest = distance
                nearest = index
            }
        }
        candidates[nearest].isHinted = true
    }

    /// How much shorter than the tallest number in the frame a run may be and
    /// still be considered at all.
    ///
    /// Half of `displayScaleFloor`, so a display can sit under a sign twice
    /// its height — the BP topper measured 1.5–2.5x — and still be read.
    /// Printed decals at 0.21 of the display can now get through this; it is
    /// the pair test that keeps them from pairing with it.
    private static let finePrintFloor: Double = 0.20

    /// How much shorter one number of a pair may be than the other and still
    /// be on the same display.
    ///
    /// The gap it sits in is wide. The volume is routinely rendered smaller
    /// than the sale — 0.67 of it on the capture above, 0.58 on an Exxon
    /// display, 0.50 on the narrowest real case in the corpus — while printed
    /// junk came in at 0.21. Anywhere in between works; this is the middle.
    private static let displayScaleFloor: Double = 0.40

    /// Whether two runs are printed at the scale of one display.
    ///
    /// A run the user pointed at is exempt, as it is from the frame-wide
    /// filter: a glare-clipped sale amount is exactly the one they would have
    /// had to point at.
    private static func isDisplayPair(_ a: Candidate, _ b: Candidate) -> Bool {
        if a.isHinted || b.isHinted { return true }
        let shorter = min(a.height, b.height)
        let taller = max(a.height, b.height)
        return shorter >= taller * displayScaleFloor
    }

    /// Whether two runs sit one directly above the other, as a pump display
    /// stacks its sale and volume.
    ///
    /// Signage doesn't: the topper's prices stood side by side, and the one
    /// that happened to sit over the display was five digit-heights above it.
    /// The sale and volume were one digit-height apart.
    private static func isStacked(_ a: Candidate, _ b: Candidate) -> Bool {
        let shorter = min(a.height, b.height)
        return abs(a.midX - b.midX) < stackAlignment
            && abs(a.midY - b.midY) <= shorter * stackReach
    }

    /// How far apart, across the frame, two stacked numbers' centres may be.
    /// Numbers on a pump are right-aligned, so a shorter volume under a longer
    /// sale is offset by a digit or two; the real captures came in under 0.05.
    private static let stackAlignment: Double = 0.15

    /// How far apart, down the frame, two stacked numbers may be, as a
    /// multiple of the shorter one's height.
    private static let stackReach: Double = 2.0

    // MARK: - Fields

    private enum Field {
        case total
        case volume
    }

    /// One reading of a number whose decimal point may not have survived the
    /// recognizer.
    private struct Placement {
        var value: Decimal
        var decimals: Int

        /// Whether this is the precision the display was expected to show.
        var isPrimary: Bool
    }

    private struct Candidate {
        var value: Decimal
        var decimals: Int

        /// How many digits the run had. The length of a bare integer is what
        /// separates a sale amount from an octane rating — see `isUsable`.
        var digits: Int

        var label: Field?
        var midX: Double
        var midY: Double
        var height: Double

        /// Whether the user tapped this run to say it is the sale amount.
        var isHinted: Bool = false

        /// A bare two-digit integer is an octane rating, a pump number or a
        /// bay number, and must never become a value. A longer one is the
        /// opposite: a pump always shows its decimals, so a four-digit sale
        /// amount is a sale whose decimal point the recognizer dropped.
        /// Measured on real captures — an Exxon display read "11428" for
        /// $114.28, and a BP display read "3538" for $35.38 on all eight
        /// preprocessing passes, every one of them losing the point.
        ///
        /// A money label used to be an exemption here, which is precisely how
        /// a "$25" gift-card decal became a $0.25 total while the real sale
        /// was discarded for having no point. Length decides instead, and the
        /// decal loses on length. Octane ratings are always two digits;
        /// stripped totals are three to five and stripped volumes four or
        /// five, so nothing real is lost.
        func isUsable(currencyDigits: Int) -> Bool {
            decimals > 0 || digits >= 3
        }

        /// How this run reads as money, likeliest first — or not at all.
        ///
        /// A pump shows its sale amount at the currency's own precision,
        /// always. A run that came back with some *other* number of decimals
        /// is a corrupted read, not an unusual sale: a Shell display showing
        /// 36.31 returned "36.3" on three of six passes, and reading that as a
        /// $36.30 sale is inventing the digit that was lost. We can't know
        /// what it was, so this refuses the run rather than guessing it — and
        /// refusing is what lets the pass that saw all four digits win.
        func moneyPlacements(currencyDigits: Int) -> [Placement] {
            guard decimals == 0 || decimals == currencyDigits else { return [] }

            // Exactly one position, never the neighbours. A volume genuinely
            // varies — a litre pump metering to three places is a real
            // machine — but a sale amount is shown at the currency's own
            // precision on every pump there is. Offering alternatives here
            // only reconstructs a lost digit as a zero: on a display reading
            // 36.31, a pass that returned "363" was being read as $36.30,
            // which is wrong in the one way the price check can't see.
            return Array(placements(assuming: currencyDigits).prefix(1))
        }

        /// How it reads as a volume.
        ///
        /// The same discipline as money, with one degree of freedom: a pump
        /// meters to two or three places depending on the unit and the
        /// machine, where a currency has exactly one answer. What no pump does
        /// is meter to a single place, so "36.3" is a 36.31 that lost its last
        /// digit — not a volume.
        ///
        /// Leaving this side open while money was strict is what produced the
        /// worst reading of the lot: the sale amount, refused as money, was
        /// accepted as 36.300 gallons instead, and the gallons were promoted
        /// to a $94.08 sale. Both numbers wrong, both fields filled, and an
        /// implied price of $2.59 that sailed through every check.
        func volumePlacements(fractionDigits: Int) -> [Placement] {
            guard decimals == 0 || (2...3).contains(decimals) else { return [] }
            return placements(assuming: fractionDigits)
        }

        func primaryMoney(currencyDigits: Int) -> Placement? {
            moneyPlacements(currencyDigits: currencyDigits).first
        }

        func primaryVolume(fractionDigits: Int) -> Placement? {
            volumePlacements(fractionDigits: fractionDigits).first
        }

        /// Seven-segment displays put the decimal point in the gap between
        /// digits, small and unlit-looking, and Vision drops it more often
        /// than not. Reinstating it from the display's own precision is the
        /// first guess and almost always the right one.
        ///
        /// The neighbouring positions exist for displays that don't show the
        /// precision we assumed — a litre pump metering to three places, say.
        /// They carry a penalty and are only ever reached when the expected
        /// position implies a price nothing like what this user pays.
        private func placements(assuming expected: Int) -> [Placement] {
            guard decimals == 0, expected > 0 else {
                return [Placement(value: value, decimals: decimals, isPrimary: true)]
            }

            var result = [
                Placement(value: shifted(by: expected), decimals: expected, isPrimary: true)
            ]
            for alternate in [expected + 1, expected - 1]
            where alternate > 0 && alternate < digits {
                result.append(
                    Placement(value: shifted(by: alternate), decimals: alternate, isPrimary: false)
                )
            }
            return result
        }

        private func shifted(by places: Int) -> Decimal {
            value / pow(Decimal(10), places)
        }
    }

    // MARK: - Orphaned labels

    /// Attaches a caption with no number of its own to the number it sits
    /// nearest.
    ///
    /// Each label goes to its single closest candidate, closest label first.
    /// If that candidate already carries a label the caption is dropped rather
    /// than pushed onto its second choice — "Purchase" and "$" both describe
    /// the same figure, and a caption that has to reach past a labelled number
    /// to find a home is describing something this frame didn't capture. A tie
    /// is dropped for the same reason: without real geometry, and every line
    /// reporting the same position, proximity means nothing.
    ///
    /// Nearest is not enough on its own, though. A caption printed anywhere on
    /// the pump used to be able to reach all the way up to the display and
    /// claim a number, and on a real capture one did: a "Total" caption a
    /// third of a frame below the sale amount labelled the *volume* as money
    /// and flipped the whole reading, on five of eight passes. A caption that
    /// far from a number is captioning something else.
    private static func adoptNearbyLabels(
        _ orphans: [(field: Field, midY: Double)],
        into numbers: inout [Candidate]
    ) {
        guard !numbers.isEmpty, !orphans.isEmpty else { return }

        let ranked = orphans
            .map { orphan -> (orphan: (field: Field, midY: Double), distance: Double) in
                let best = numbers.map { abs($0.midY - orphan.midY) }.min() ?? .infinity
                return (orphan, best)
            }
            .sorted { $0.distance < $1.distance }

        for entry in ranked {
            let distances = numbers.map { abs($0.midY - entry.orphan.midY) }
            guard let shortest = distances.min() else { continue }
            let nearest = distances.enumerated().filter { $0.element == shortest }
            guard nearest.count == 1, let index = nearest.first?.offset else { continue }
            guard numbers[index].label == nil else { continue }
            // Measured against the number's own size, because that is the only
            // scale in the frame that tracks how far away the display is.
            guard shortest <= numbers[index].height * labelReach else { continue }
            numbers[index].label = entry.orphan.field
        }
    }

    /// How far a caption may sit from a number, as a multiple of that number's
    /// height, and still be describing it.
    ///
    /// Captions sit directly above or below their value — on the real captures
    /// in the corpus, "Gallons" lands 0.68 of a digit height from its number
    /// and "$" lands 0.01 away. The caption that caused the flip was 3.1 away.
    private static let labelReach: Double = 1.5

    // MARK: - Assignment

    private struct Pair {
        var total: Candidate
        var volume: Candidate
        var totalPlacement: Placement
        var volumePlacement: Placement
        var score: Double
    }

    /// Scores every ordered pair and returns the winner, but only when it
    /// clears the runner-up by a real margin.
    ///
    /// The margin matters more than it looks. Parsing is deterministic, so a
    /// coin-flip between two near-equal assignments would flip the same way on
    /// every frame and sail straight through the consensus check. Refusing to
    /// answer is the only way a tie stays a tie.
    private static func bestPair(
        among candidates: [Candidate],
        unit: VolumeUnit,
        context: PumpScanContext
    ) -> Pair? {
        guard candidates.count >= 2 else { return nil }

        var scored: [Pair] = []
        for total in candidates {
            for volume in candidates where volume.value != total.value {
                guard volume.value > 0, total.value > 0 else { continue }
                guard isDisplayPair(total, volume) else { continue }
                // Everything outside this pair is a possible third display.
                let others = candidates.filter {
                    $0.value != total.value && $0.value != volume.value
                }
                guard let pair = resolve(
                    total: total,
                    volume: volume,
                    others: others,
                    unit: unit,
                    context: context
                ) else { continue }
                scored.append(pair)
            }
        }

        // Ordered by value on ties, because two assignments that score the
        // same must still resolve the same way on every frame — otherwise the
        // consensus check is counting noise.
        scored.sort {
            $0.score == $1.score ? $0.total.value > $1.total.value : $0.score > $1.score
        }
        guard let best = scored.first, best.score > 0 else { return nil }

        // The runner-up only counts if it actually disagrees about the values.
        let rival = scored.first {
            $0.total.value != best.total.value || $0.volume.value != best.volume.value
        }
        if let rival, best.score - rival.score < minimumMargin { return nil }

        return best
    }

    private static let minimumMargin: Double = 1.0

    /// Settles where the decimal points go for one assignment, then scores it.
    ///
    /// Exactly one pair comes back per assignment, deliberately: alternate
    /// placements of the same two runs would otherwise turn up as each other's
    /// runner-up, and the margin check would throw out a good reading over a
    /// disagreement it had with itself.
    private static func resolve(
        total: Candidate,
        volume: Candidate,
        others: [Candidate],
        unit: VolumeUnit,
        context: PumpScanContext
    ) -> Pair? {
        let currencyDigits = Money.fractionDigits(for: context.currencyCode)

        var best: Pair?
        for totalPlacement in total.moneyPlacements(currencyDigits: currencyDigits) {
            for volumePlacement in volume.volumePlacements(
                fractionDigits: unit.entryFractionDigits
            ) {
                guard totalPlacement.value > 0, volumePlacement.value > 0 else { continue }

                let candidate = Pair(
                    total: total,
                    volume: volume,
                    totalPlacement: totalPlacement,
                    volumePlacement: volumePlacement,
                    score: score(
                        total: total,
                        totalPlacement: totalPlacement,
                        volume: volume,
                        volumePlacement: volumePlacement,
                        others: others,
                        unit: unit,
                        context: context
                    )
                )
                if best == nil || candidate.score > best!.score { best = candidate }
            }
        }
        return best
    }

    private static func score(
        total: Candidate,
        totalPlacement: Placement,
        volume: Candidate,
        volumePlacement: Placement,
        others: [Candidate],
        unit: VolumeUnit,
        context: PumpScanContext
    ) -> Double {
        var score = 0.0
        let currencyDigits = Money.fractionDigits(for: context.currencyCode)

        // What the user pointed at, which is not a guess and so outscores
        // every signal below that is.
        if total.isHinted { score += 6 }
        if volume.isHinted { score -= 6 }

        // The shape of a display. Signage that survived the size test still
        // doesn't stack its numbers over one another, and this is what kept
        // the topper's prices from pairing with the sale on real captures.
        // It says nothing about which of the two is the money, so it can only
        // separate a display from signage, never decide an assignment.
        if isStacked(total, volume) { score += 3 }

        // Labels, when the pump bothered to light them.
        switch total.label {
        case .total: score += 3
        case .volume: score -= 3
        case nil: break
        }
        switch volume.label {
        case .volume: score += 3
        case .total: score -= 3
        case nil: break
        }

        // Precision. A USD total shows exactly two decimals; gallons show
        // three. Litres commonly show two as well, so this settles the
        // American case and abstains on the metric one.
        if totalPlacement.decimals == currencyDigits { score += 2 }
        if volumePlacement.decimals > currencyDigits { score += 2 }

        // Putting a point anywhere but where the display was expected to show
        // it is a last resort, not a free parameter.
        if !totalPlacement.isPrimary { score -= 1 }
        if !volumePlacement.isPrimary { score -= 1 }

        let price = totalPlacement.value / volumePlacement.value

        // Standing in for the arithmetic check the display denies us. The band
        // was learned in the account's unit, so a litre pump has to be
        // converted before it can be compared against a history of gallons.
        if context.priceBand.contains(normalized(price, from: unit, to: context.volumeUnit)) {
            score += 4
        } else {
            score -= 4
        }

        // Nearly everywhere on earth, a unit of fuel costs more than one unit
        // of the local currency. Weak, but it survives having no history to
        // compare against, which is exactly when everything else is weakest.
        if price > 1 { score += 2 }

        // A third number that multiplies out is worth more than any heuristic
        // above, because it is the only one that can be checked rather than
        // believed.
        //
        // The arithmetic alone can't say which of the two lower displays is
        // the volume and which is the price — `35.38 = 8.426 × 4.199` reads
        // the same both ways round, and without the layout to separate them
        // the two assignments tie and the margin check throws the reading out.
        // So the position pays for itself here: a pump face runs sale, volume,
        // unit price from the top down, and the price is the smallest of the
        // three.
        if let price = corroborating(
            totalAmount: totalPlacement.value,
            volumeAmount: volumePlacement.value,
            others: others
        ) {
            score += 4
            if price.midY > volume.midY { score += 2 }
            if price.height <= volume.height { score += 1 }
        }

        // Tiebreaks. The total sale is usually the upper and larger display.
        if total.midY < volume.midY { score += 0.5 }
        if total.height > volume.height { score += 0.5 }

        return score
    }

    /// The third number on the panel that multiplies out, if there is one.
    ///
    /// A pump that shows its per-unit price alongside the sale hands us the
    /// one thing a two-number display never does: an equation. `price ×
    /// volume` has to come back as the total, and because it only closes at
    /// one position of the price's own decimal point, trying every position
    /// places that point and confirms the assignment in the same step.
    private static func corroborating(
        totalAmount: Decimal,
        volumeAmount: Decimal,
        others: [Candidate]
    ) -> Candidate? {
        guard totalAmount > 0, volumeAmount > 0, !others.isEmpty else { return nil }

        // Loose enough for a pump that rounds the sale to the cent, tight
        // enough that an unrelated number passing is close to a miracle.
        let tolerance = totalAmount * Decimal(string: "0.015")!

        for other in others {
            // A price that kept its own decimal point is taken as it reads;
            // only a bare integer needs its point hunting for.
            let positions = other.decimals > 0 ? [0] : Array(0...4)
            for places in positions {
                let product = (other.value / pow(Decimal(10), places)) * volumeAmount
                let difference = product > totalAmount
                    ? product - totalAmount
                    : totalAmount - product
                if difference <= tolerance { return other }
            }
        }
        return nil
    }

    /// The one-number case. Only answers when the label or the decimal count
    /// says which field it is — a bare number with nothing to place it is left
    /// alone rather than dropped into whichever field seems likelier.
    private static func unambiguousLone(
        among candidates: [Candidate],
        currencyDigits: Int,
        volumeDigits: Int
    ) -> (candidate: Candidate, field: Field)? {
        // A run that cannot be read as the thing it is labelled is not a
        // candidate for anything, and dropping it is what lets the number
        // beside it come through on its own. On the Shell display, "36.3"
        // under its "$" is unreadable, but the gallons under "Gallons" are
        // perfectly legible — and half an answer is still half the typing.
        let labelled = candidates.compactMap { candidate -> (Candidate, Field)? in
            guard let label = candidate.label else { return nil }
            switch label {
            case .total:
                guard candidate.primaryMoney(currencyDigits: currencyDigits) != nil else {
                    return nil
                }
            case .volume:
                guard candidate.primaryVolume(fractionDigits: volumeDigits) != nil else {
                    return nil
                }
            }
            return (candidate, label)
        }
        if labelled.count == 1 { return labelled[0] }

        guard candidates.count == 1, let only = candidates.first else { return nil }
        if only.decimals > currencyDigits { return (only, .volume) }
        if only.decimals == currencyDigits, currencyDigits > 0 { return (only, .total) }
        return nil
    }

    // MARK: - Building the reading

    private static func reading(
        total: Placement?,
        volume: Placement?,
        unit: VolumeUnit,
        context: PumpScanContext
    ) -> PumpReading {
        var reading = PumpReading(volumeUnit: unit)

        if let total {
            reading.total = Money(
                majorUnits: total.value,
                currencyCode: context.currencyCode
            )
        }
        if let volume {
            reading.volume = Volume(
                value: NSDecimalNumber(decimal: volume.value).doubleValue,
                unit: unit
            )
        }

        if let total, let volume, volume.value > 0 {
            let price = total.value / volume.value
            // Shown in the pump's own unit, so it matches the sign the user is
            // standing in front of. The band check works in the account's.
            reading.impliedUnitPrice = price
            reading.isPlausible = context.priceBand.contains(
                normalized(price, from: unit, to: context.volumeUnit)
            )
        }

        return reading
    }

    /// Restates a per-unit price from one volume unit into another. `$1.35/L`
    /// becomes `$5.11/gal`, which is what a gallons-based history knows how to
    /// judge.
    private static func normalized(
        _ price: Decimal,
        from pumpUnit: VolumeUnit,
        to accountUnit: VolumeUnit
    ) -> Decimal {
        guard pumpUnit != accountUnit else { return price }
        let ratio = Decimal(accountUnit.millilitersPerUnit)
            / Decimal(pumpUnit.millilitersPerUnit)
        return price * ratio
    }

    // MARK: - Units

    private static func volumeUnit(in lines: [ScannedLine], accountUnit: VolumeUnit) -> VolumeUnit {
        let joined = lines.map(\.text).joined(separator: " ").uppercased()

        if joined.contains("LITER") || joined.contains("LITRE") || joined.contains("LTR") {
            return .liters
        }
        if joined.contains("GAL") {
            // "GAL" can't tell US from Imperial. If the account already thinks
            // in Imperial gallons, so does the pump in front of them.
            return accountUnit == .gallonsImperial ? .gallonsImperial : .gallonsUS
        }
        return accountUnit
    }

    // MARK: - Labels

    private static func label(in text: String) -> Field? {
        let upper = text.uppercased()

        let volumeWord = upper.contains("GAL")
            || upper.contains("LITER") || upper.contains("LITRE") || upper.contains("LTR")
            || upper.contains("VOLUME") || upper.contains("QTY")
            || upper.range(of: #"\bL\b"#, options: .regularExpression) != nil

        let currencySymbol = currencySymbols.contains { upper.contains($0) }
        let moneyWord = upper.contains("TOTAL") || upper.contains("SALE")
            || upper.contains("AMOUNT") || upper.contains("COST")
            || upper.contains("PURCHASE") || upper.contains("FUEL SALE")

        // A currency symbol sitting in the same run as a volume word means the
        // recognizer merged two fields into one line. Nothing here can say
        // which number belongs to which, so it says nothing — a wrong label
        // costs more than a missing one.
        if volumeWord && currencySymbol { return nil }

        // "TOTAL GALLONS" is labelling the gallons, so volume wins over a bare
        // money word.
        if volumeWord { return .volume }
        if moneyWord || currencySymbol { return .total }

        return nil
    }

    private static let currencySymbols: [String] = ["$", "€", "£", "¥", "₹", "₽", "R$", "kr"]

    // MARK: - Number extraction

    /// Runs of characters that could be a number, allowing for the handful of
    /// glyphs a text recognizer reliably confuses with digits.
    private static let numberPattern = try! NSRegularExpression(
        pattern: "[0-9OoIl|/][0-9OoIl|/.,:]*"
    )

    private static func candidates(in line: ScannedLine) -> [Candidate] {
        let text = rejoinSplitDigits(in: line.text)
        let lineLabel = label(in: text)
        let full = NSRange(text.startIndex..<text.endIndex, in: text)

        return numberPattern.matches(in: text, range: full).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            guard let parsed = number(from: String(text[range])) else { return nil }

            return Candidate(
                value: parsed.value,
                decimals: parsed.decimals,
                digits: parsed.digits,
                label: lineLabel,
                midX: line.midX,
                midY: line.midY,
                height: line.height
            )
        }
    }

    /// Closes a gap the recognizer opened in the middle of a number.
    ///
    /// The last digit of a seven-segment reading is often a lone thin stroke,
    /// and the recognizer punts it into its own word: "22.151" arrives as
    /// "22.15 1", and "11428" as "1 1428". Both were observed on real pump
    /// photos.
    ///
    /// The guard is that a decimal point may not appear on *both* sides of the
    /// gap. Two numbers sharing one line — "42.15 12.048" — look exactly like
    /// a split number otherwise, and welding those together would invent a
    /// value out of two real ones.
    private static func rejoinSplitDigits(in text: String) -> String {
        guard text.contains(" ") else { return text }

        let separators: Set<Character> = [".", ","]
        let parts = text.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return text }

        var result = String(parts[0])
        for part in parts.dropFirst() {
            let leftRun = result.reversed().prefix { !$0.isWhitespace }

            let bothNumeric = leftRun.contains(where: \.isNumber)
                && part.contains(where: \.isNumber)
            let separatorOnBothSides = leftRun.contains { separators.contains($0) }
                && part.contains { separators.contains($0) }

            if bothNumeric && !separatorOnBothSides {
                result += part
            } else {
                result += " " + part
            }
        }
        return result
    }

    /// Cleans one matched run and parses it, or gives up.
    private static func number(from run: String) -> (value: Decimal, decimals: Int, digits: Int)? {
        var token = run

        // Same story as the slash: a final thin stroke rendered as punctuation.
        // Only at the end — an interior colon is something else entirely, and
        // rewriting "12:34" into "1234" would be worse than losing a digit.
        if token.last == ":" { token.removeLast(); token.append("1") }

        // A trailing "L" is a unit, not a mangled 1. The reverse mistake — a
        // final 1 recognized as an l — is possible but far rarer than a litre
        // suffix riding along on the number.
        while token.last == "l" || token.last == "L" {
            token.removeLast()
        }

        // A run made entirely of look-alike glyphs is a word the character
        // class happened to match — the "O" in TOTAL, the "OI" in OIL. Without
        // this, substitution would turn them into perfectly good numbers.
        guard token.contains(where: \.isNumber) else { return nil }

        // Only the two substitutions worth making. S/5 and B/8 look tempting
        // but S appears in "$" and "SALE", and correcting a letter that was
        // never a digit is worse than missing one that was.
        //
        // This runs before the trailing trim, not after: "$4O.OO" ends in
        // glyphs that are digits once corrected, and trimming first would eat
        // the number down to "4".
        var cleaned = ""
        for character in token {
            switch character {
            case "O", "o": cleaned.append("0")
            // A seven-segment 1 is two strokes; lose the top one to glare and
            // the recognizer reports the remainder as "l", "|" or "/".
            // Observed directly: "22.151" coming back as "22.15/".
            case "I", "l", "|", "/": cleaned.append("1")
            default: cleaned.append(character)
            }
        }

        // Whatever still trails the number — a stray separator, a smudge —
        // isn't part of it.
        while let last = cleaned.last, !last.isNumber {
            cleaned.removeLast()
        }
        guard !cleaned.isEmpty else { return nil }

        // What's left has to be a number and nothing else. `Decimal(string:)`
        // parses "12:34" as 12 and silently drops the rest, which left the
        // run claiming four digits while holding a two-digit value — and
        // length is now what decides whether a bare integer may become a sale
        // amount. A clock read as a twelve-dollar fill is worse than no
        // reading at all.
        let groupingMarks: Set<Character> = [".", ","]
        guard cleaned.allSatisfy({ $0.isNumber || groupingMarks.contains($0) }) else {
            return nil
        }

        let digitCount = cleaned.filter(\.isNumber).count
        guard digitCount >= 2 else { return nil }
        guard Double(digitCount) / Double(cleaned.count) >= 0.6 else { return nil }

        guard let normalized = normalizeSeparators(cleaned) else { return nil }
        guard let value = Decimal(string: normalized.text, locale: Locale(identifier: "en_US_POSIX"))
        else { return nil }

        return (value, normalized.decimals, digitCount)
    }

    /// The last separator in the run is the decimal point; every other one is
    /// a grouping mark and gets dropped.
    ///
    /// One rule covers "42.15", "42,15", "1.234,56" and "1,234.56". It reads
    /// "1,234" as 1.234 rather than 1234, which is the right call here: a
    /// 1.234-gallon splash is an ordinary purchase and a 1,234-unit one is not.
    private static func normalizeSeparators(_ token: String) -> (text: String, decimals: Int)? {
        let separators: Set<Character> = [".", ","]
        guard let lastSeparator = token.lastIndex(where: { separators.contains($0) }) else {
            return (token, 0)
        }

        let whole = token[token.startIndex..<lastSeparator].filter { !separators.contains($0) }
        let fraction = token[token.index(after: lastSeparator)...]
        guard !fraction.isEmpty, fraction.allSatisfy(\.isNumber) else { return nil }
        guard !whole.isEmpty else { return nil }

        return ("\(whole).\(fraction)", fraction.count)
    }

    // MARK: - Deduplication

    /// The recognizer can surface the same number twice in one frame. Left
    /// alone, the duplicate becomes its own runner-up and the margin check
    /// throws out a perfectly good reading.
    /// Order is preserved deliberately: a dictionary's iteration order varies
    /// between runs, and the scoring below has to be reproducible frame to
    /// frame for consensus to mean anything.
    private static func deduplicated(_ candidates: [Candidate]) -> [Candidate] {
        var result: [Candidate] = []
        for candidate in candidates {
            if let index = result.firstIndex(where: { $0.value == candidate.value }) {
                // A labelled sighting beats an unlabelled one of the same number.
                if result[index].label == nil, candidate.label != nil {
                    result[index] = candidate
                }
                // A pointed-at sighting is never the one thrown away.
                if candidate.isHinted { result[index].isHinted = true }
                continue
            }
            result.append(candidate)
        }
        return result
    }
}
