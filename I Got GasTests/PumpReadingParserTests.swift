//
//  PumpReadingParserTests.swift
//  I Got GasTests
//
//  The pump gives two numbers and no way to check them against each other, so
//  every bit of confidence this feature has comes from the cases below. These
//  are the corpus, not an afterthought to it.
//

import Testing
import Foundation
@testable import I_Got_Gas

// MARK: - Helpers

private func context(
    volume: VolumeUnit = .gallonsUS,
    currency: String = "USD",
    band: ClosedRange<Decimal> = PumpScanContext.unboundedPriceBand,
    hint: PumpScanHint? = nil
) -> PumpScanContext {
    PumpScanContext(
        volumeUnit: volume,
        currencyCode: currency,
        priceBand: band,
        hint: hint
    )
}

private func lines(_ texts: String...) -> [ScannedLine] {
    texts.map { ScannedLine(text: $0) }
}

private extension Volume {
    /// Tolerant comparison — the value round-trips through whole millilitres.
    func isApproximately(_ value: Double, _ unit: VolumeUnit) -> Bool {
        abs(converted(to: unit) - value) < 0.001
    }
}

// MARK: - Reading the two numbers apart

struct PumpReadingParserTests {

    @Test func unlabeledUSPumpResolvesOnDecimalCount() {
        // The common case: no legible labels at all. Two decimals is money,
        // three is gallons, and that alone settles it.
        let reading = PumpReadingParser.parse(lines("42.15", "12.048"), context: context())

        #expect(reading.total?.minorUnits == 4215)
        #expect(reading.volume?.isApproximately(12.048, .gallonsUS) == true)
        #expect(reading.isComplete)
        #expect(reading.isPlausible)
    }

    @Test func labelsMergedIntoOneLine() {
        let reading = PumpReadingParser.parse(
            lines("TOTAL SALE $42.15", "GALLONS 12.048"),
            context: context()
        )

        #expect(reading.total?.minorUnits == 4215)
        #expect(reading.volume?.isApproximately(12.048, .gallonsUS) == true)
    }

    @Test func labelsOnSeparateLinesFromTheirNumbers() {
        // How a multi-item recognizer usually reports a pump face: the label
        // and its value arrive as unrelated runs.
        let reading = PumpReadingParser.parse(
            lines("TOTAL SALE", "$42.15", "GALLONS", "12.048"),
            context: context()
        )

        #expect(reading.total?.minorUnits == 4215)
        #expect(reading.volume?.isApproximately(12.048, .gallonsUS) == true)
    }

    @Test func swappedAssignmentLoses() {
        // Reading it backwards implies $0.29/gal. Nothing sells fuel for that.
        let reading = PumpReadingParser.parse(lines("42.15", "12.048"), context: context())
        let price = try! #require(reading.impliedUnitPrice)

        #expect(price > 3.4)
        #expect(price < 3.5)
    }

    @Test func geometryBreaksATie() {
        // Same decimal count both ways, so only the layout can decide: the
        // total sale is the upper, larger display.
        let reading = PumpReadingParser.parse(
            [
                ScannedLine(text: "38.40", midY: 0.25, height: 0.20),
                ScannedLine(text: "24.00", midY: 0.65, height: 0.10),
            ],
            context: context(volume: .liters)
        )

        #expect(reading.total?.minorUnits == 3840)
        #expect(reading.volume?.isApproximately(24.00, .liters) == true)
    }

    // MARK: - Units and locales

    @Test func litresAtTwoDecimalsResolveOnImpliedPrice() {
        // Metric pumps show two decimals for both numbers, so the decimal
        // heuristic abstains and the price band has to carry it.
        let band = PumpScanContext.priceBand(
            fromRecent: [Money(minorUnits: 145, currencyCode: "USD"),
                         Money(minorUnits: 152, currencyCode: "USD")]
        )
        let reading = PumpReadingParser.parse(
            lines("42.15", "31.25"),
            context: context(volume: .liters, band: band)
        )

        #expect(reading.total?.minorUnits == 4215)
        #expect(reading.volume?.isApproximately(31.25, .liters) == true)
    }

    @Test func litresStillResolveWithNoHistoryToLeanOn() {
        // First-ever fill: no band, so this rests on fuel costing more than
        // one currency unit per litre. Thin, but it holds.
        let reading = PumpReadingParser.parse(
            lines("42.15", "31.25"),
            context: context(volume: .liters)
        )

        #expect(reading.total?.minorUnits == 4215)
        #expect(reading.volume?.isApproximately(31.25, .liters) == true)
    }

    @Test func decimalCommaIsReadAsADecimalPoint() {
        let reading = PumpReadingParser.parse(
            lines("42,15", "31,25 L"),
            context: context(volume: .liters)
        )

        #expect(reading.total?.minorUnits == 4215)
        #expect(reading.volume?.isApproximately(31.25, .liters) == true)
    }

    @Test func groupingSeparatorsAreDropped() {
        // The last separator is the decimal point; earlier ones group.
        let reading = PumpReadingParser.parse(
            lines("1.234,56", "GALLONS 45.678"),
            context: context()
        )

        #expect(reading.total?.minorUnits == 123456)
    }

    @Test func zeroDecimalCurrencyKeepsItsWholeNumberTotal() {
        // A yen total legitimately has no decimal point, so the integer filter
        // that kills octane ratings must not fire here.
        let reading = PumpReadingParser.parse(
            lines("5400", "31.25"),
            context: context(volume: .liters, currency: "JPY")
        )

        #expect(reading.total?.minorUnits == 5400)
        #expect(reading.volume?.isApproximately(31.25, .liters) == true)
    }

    @Test func imperialAccountReadsGalAsImperial() {
        let reading = PumpReadingParser.parse(
            lines("TOTAL $42.15", "GAL 12.048"),
            context: context(volume: .gallonsImperial)
        )

        #expect(reading.volumeUnit == .gallonsImperial)
        #expect(reading.volume?.isApproximately(12.048, .gallonsImperial) == true)
    }

    @Test func litreLabelOverridesAGallonAccount() {
        // Someone with a US account filling up in Canada.
        let reading = PumpReadingParser.parse(
            lines("TOTAL $42.15", "LITRES 31.25"),
            context: context(volume: .gallonsUS)
        )

        #expect(reading.volumeUnit == .liters)
        #expect(reading.volume?.isApproximately(31.25, .liters) == true)
    }

    // MARK: - Rejecting what isn't a value

    @Test func octaneAndPumpNumbersAreNotValues() {
        let reading = PumpReadingParser.parse(
            lines("PUMP 4", "OCTANE 87", "REG 87", "TOTAL SALE $42.15", "GALLONS 12.048"),
            context: context()
        )

        #expect(reading.total?.minorUnits == 4215)
        #expect(reading.volume?.isApproximately(12.048, .gallonsUS) == true)
    }

    @Test func nothingLegibleReturnsNothing() {
        let reading = PumpReadingParser.parse(
            lines("UNLEADED", "PLEASE PAY INSIDE"),
            context: context()
        )

        #expect(reading.isEmpty)
        #expect(!reading.isComplete)
    }

    @Test func aGenuinelyOddFillReadsButIsNotPlausible() {
        // $80 of fuel into 4 gallons is $20/gal — wrong, or a very bad day.
        // Either way it parses, and either way it must not lock by itself.
        let band = PumpScanContext.priceBand(
            fromRecent: [Money(minorUnits: 340, currencyCode: "USD"),
                         Money(minorUnits: 355, currencyCode: "USD")]
        )
        let reading = PumpReadingParser.parse(
            lines("TOTAL $80.00", "GALLONS 4.000"),
            context: context(band: band)
        )

        #expect(reading.isComplete)
        #expect(!reading.isPlausible)
    }

    // MARK: - Partial reads

    @Test func oneLabelledNumberFillsOnlyItsOwnField() {
        let reading = PumpReadingParser.parse(lines("GALLONS 12.048"), context: context())

        #expect(reading.total == nil)
        #expect(reading.volume?.isApproximately(12.048, .gallonsUS) == true)
        #expect(!reading.isComplete)
    }

    @Test func oneUnlabelledNumberIsPlacedByItsPrecision() {
        let volumeOnly = PumpReadingParser.parse(lines("12.048"), context: context())
        #expect(volumeOnly.volume?.isApproximately(12.048, .gallonsUS) == true)
        #expect(volumeOnly.total == nil)

        let totalOnly = PumpReadingParser.parse(lines("42.15"), context: context())
        #expect(totalOnly.total?.minorUnits == 4215)
        #expect(totalOnly.volume == nil)
    }

    // MARK: - Real recognizer output

    // The transcripts below are what Vision actually returned for a photo of
    // an Exxon pump, positions included. Two things about it broke the first
    // version of this parser: the caption is "Purchase" rather than "Total",
    // and the seven-segment decimal point in the sale amount was dropped
    // entirely, so $114.28 came back as "11428".

    @Test func exxonPumpAsVisionActuallyReadsIt() {
        let reading = PumpReadingParser.parse(
            [
                ScannedLine(text: "Purchase", midY: 0.432, height: 0.040),
                ScannedLine(text: "$", midY: 0.591, height: 0.133),
                ScannedLine(text: "Gallons", midY: 0.869, height: 0.040),
                ScannedLine(text: "EXon", midY: 0.202, height: 0.155),
                ScannedLine(text: "11428", midY: 0.593, height: 0.265),
                ScannedLine(text: "22.151", midY: 0.765, height: 0.153),
            ],
            context: context()
        )

        #expect(reading.total?.minorUnits == 11428)
        #expect(reading.volume?.isApproximately(22.151, .gallonsUS) == true)
        #expect(reading.isComplete)
    }

    @Test func octaneRatingsAreTooShortToBeValues() {
        // The decimal-point recovery must not reopen the door to octane
        // ratings — and length is what keeps them out. A rating is always two
        // digits; a sale with its point dropped is three to five and a volume
        // four or five, so nothing real is lost by the rule.
        let reading = PumpReadingParser.parse(
            lines("OCTANE 87", "REG 87", "22.151"),
            context: context()
        )

        #expect(reading.total == nil)
        #expect(reading.volume?.isApproximately(22.151, .gallonsUS) == true)
    }

    @Test func aMoneyLabelDoesNotPromoteATwoDigitDecal() {
        // What this rule used to cost: a money label was an exemption from the
        // bare-integer filter, so a "$25" gift-card sticker became a $0.25
        // sale. Being labelled is not enough; being long enough is.
        let reading = PumpReadingParser.parse(
            lines("Gift Card $25", "22.151"),
            context: context()
        )

        #expect(reading.total == nil)
        #expect(reading.volume?.isApproximately(22.151, .gallonsUS) == true)
    }

    @Test func aCaptionIsNotStolenByADistantNumber() {
        // "Gallons" sits under the volume; it must not reach up past it to
        // label the sale amount.
        let reading = PumpReadingParser.parse(
            [
                ScannedLine(text: "$", midY: 0.30, height: 0.13),
                ScannedLine(text: "58.10", midY: 0.31, height: 0.26),
                ScannedLine(text: "16.402", midY: 0.62, height: 0.15),
                ScannedLine(text: "Gallons", midY: 0.78, height: 0.04),
            ],
            context: context()
        )

        #expect(reading.total?.minorUnits == 5810)
        #expect(reading.volume?.isApproximately(16.402, .gallonsUS) == true)
    }

    // MARK: - Recognizer noise

    @Test func commonGlyphConfusionsAreCorrected() {
        // "l" for 1 and "O" for 0 are the two the recognizer actually makes.
        let reading = PumpReadingParser.parse(
            lines("TOTAL $4O.OO", "GALLONS l2.048"),
            context: context()
        )

        #expect(reading.total?.minorUnits == 4000)
        #expect(reading.volume?.isApproximately(12.048, .gallonsUS) == true)
    }

    @Test func aTrailingLitreSuffixIsNotMistakenForADigit() {
        let reading = PumpReadingParser.parse(
            lines("TOTAL 42.15", "31.25L"),
            context: context(volume: .liters)
        )

        #expect(reading.volume?.isApproximately(31.25, .liters) == true)
    }

    @Test func theSameNumberSeenTwiceDoesNotBlockAReading() {
        // A duplicate would otherwise become its own runner-up and trip the
        // margin check.
        let reading = PumpReadingParser.parse(
            lines("42.15", "42.15", "12.048"),
            context: context()
        )

        #expect(reading.total?.minorUnits == 4215)
        #expect(reading.volume?.isApproximately(12.048, .gallonsUS) == true)
    }

    @Test func parsingTheSameFrameTwiceGivesTheSameAnswer() {
        // Consensus counts repeats, so a parser that wandered between runs
        // would make three "agreeing" frames meaningless.
        let input = lines("42.15", "12.048", "PUMP 3", "OCTANE 87")
        let first = PumpReadingParser.parse(input, context: context())
        let second = PumpReadingParser.parse(input, context: context())

        #expect(first == second)
    }
}

// MARK: - The BP capture

/// The photograph that this whole pass came out of, transcribed from what
/// Vision actually returned for it. The pump read $35.38 for 8.426 gallons and
/// the app offered $0.25 at $0.030/gal.
///
/// Three separate faults had to line up to produce that, and each one has a
/// case below: the sale amount lost its decimal point and was discarded as an
/// octane rating, a gift-card decal kept a money label and was promoted in its
/// place, and a caption most of a frame away reached up and labelled the wrong
/// number.
struct PumpBPCaptureTests {

    /// Heights are the measured ones. The two display numbers stand at 0.150
    /// and 0.100 of the frame; nothing else on the pump clears 0.031.
    private func capture() -> [ScannedLine] {
        [
            ScannedLine(text: "3538", midX: 0.561, midY: 0.386, height: 0.150),
            ScannedLine(text: "8.426", midX: 0.511, midY: 0.520, height: 0.100),
            ScannedLine(text: "DISCOVER", midX: 0.404, midY: 0.728, height: 0.012),
            ScannedLine(text: "VISA", midX: 0.528, midY: 0.730, height: 0.019),
            ScannedLine(text: "Gift Card $25", midX: 0.150, midY: 0.735, height: 0.018),
            ScannedLine(text: "• GiI Cant $25", midX: 0.264, midY: 0.760, height: 0.021),
        ]
    }

    @Test func readsTheSaleWhoseDecimalPointWasLost() {
        // Every one of the eight preprocessing passes returned "3538". The
        // decimal point on this display is not recoverable from the pixels, so
        // it has to come back from the currency's own precision.
        let reading = PumpReadingParser.parse(capture(), context: context())

        #expect(reading.total?.minorUnits == 3538)
        #expect(reading.volume?.isApproximately(8.426, .gallonsUS) == true)
        #expect(reading.isComplete)
    }

    @Test func holdsUpWithAPriceHistoryToCheckAgainst() {
        let band = PumpScanContext.priceBand(
            fromRecent: [Money(minorUnits: 389, currencyCode: "USD"),
                         Money(minorUnits: 402, currencyCode: "USD"),
                         Money(minorUnits: 415, currencyCode: "USD")]
        )
        let reading = PumpReadingParser.parse(capture(), context: context(band: band))

        #expect(reading.total?.minorUnits == 3538)
        #expect(reading.isPlausible)
    }

    @Test func printedDecalsAreNotDisplayNumbers() {
        // The $25 stickers are a fifth the height of the sale amount. That
        // alone has to be enough to keep them out of the running.
        let reading = PumpReadingParser.parse(capture(), context: context())

        #expect(reading.total?.minorUnits != 25)
        #expect(reading.impliedUnitPrice ?? 0 > 1)
    }

    @Test func aCaptionCannotReachAcrossTheFrameToLabelANumber() {
        // The flip that survived the first two fixes. A "Total" caption sits
        // three display-heights below the volume — far too far to be its
        // caption — and labelling the volume as money inverted the reading on
        // five of eight passes.
        let reading = PumpReadingParser.parse(
            capture() + [ScannedLine(text: "Total", midX: 0.351, midY: 0.831, height: 0.012)],
            context: context()
        )

        #expect(reading.total?.minorUnits == 3538)
        #expect(reading.volume?.isApproximately(8.426, .gallonsUS) == true)
    }
}

// MARK: - The Shell capture

/// A display whose sale amount ends in a 1 — two thin strokes, the first thing
/// to go — photographed through a reflection. The app read it as $36.30.
///
/// What made this one different from the BP capture is that the passes
/// disagreed, and the wrong answer had the majority: of six, one returned
/// "3631", three lost the final digit, and two couldn't read the display at
/// all. Counting votes picked the loss.
struct PumpShellCaptureTests {

    /// Positions and heights as Vision returned them for the `plain` pass.
    private func capture(total: String) -> [ScannedLine] {
        [
            ScannedLine(text: "This Sale", midX: 0.507, midY: 0.037, height: 0.025),
            ScannedLine(text: "$", midX: 0.146, midY: 0.115, height: 0.064),
            ScannedLine(text: total, midX: 0.599, midY: 0.156, height: 0.116),
            ScannedLine(text: "9.408", midX: 0.569, midY: 0.252, height: 0.087),
            ScannedLine(text: "Gallons", midX: 0.510, midY: 0.326, height: 0.022),
            ScannedLine(text: "Do you want a receipt?", midX: 0.463, midY: 0.585, height: 0.028),
            ScannedLine(text: "Yes", midX: 0.249, midY: 0.761, height: 0.025),
            ScannedLine(text: "No", midX: 0.243, midY: 0.848, height: 0.025),
            ScannedLine(text: "VISA", midX: 0.845, midY: 0.973, height: 0.007),
        ]
    }

    @Test func theSaleReadsWhenEveryDigitSurvived() {
        let reading = PumpReadingParser.parse(capture(total: "3631"), context: context())

        #expect(reading.total?.minorUnits == 3631)
        #expect(reading.volume?.isApproximately(9.408, .gallonsUS) == true)
    }

    @Test func theLostDigitLosesOnPriceRatherThanOnVoteCounting() {
        // How this display is actually settled. Three of six passes dropped
        // the final stroke and agreed on "363"; read as money at the only
        // precision a pump shows, that is $3.63 for 9.408 gallons — 39 cents a
        // gallon, which this driver has never paid. The plausibility tier
        // drops all three and the pass that read every digit is left holding
        // the only believable reading.
        let band = PumpScanContext.priceBand(
            fromRecent: [Money(minorUnits: 389, currencyCode: "USD"),
                         Money(minorUnits: 402, currencyCode: "USD"),
                         Money(minorUnits: 415, currencyCode: "USD")]
        )
        let whole = PumpReadingParser.parse(capture(total: "3631"), context: context(band: band))
        let lost = PumpReadingParser.parse(capture(total: "363"), context: context(band: band))

        #expect(whole.isPlausible)
        #expect(!lost.isPlausible)

        let outcome = PumpBallot.winner(among: [lost, lost, lost, whole])
        #expect(outcome?.reading.total?.minorUnits == 3631)
    }

    @Test func aSaleMissingADigitIsRefusedRatherThanRoundedOff() {
        // "36.3" is not a $36.30 sale. It is 36.31 with its last stroke lost,
        // and the missing digit is not something we can invent — so the run is
        // refused as money and the volume comes through on its own. A pass
        // that degrades to half an answer can't outvote one that read it all.
        let reading = PumpReadingParser.parse(capture(total: "36.3"), context: context())

        #expect(reading.total == nil)
        #expect(reading.volume?.isApproximately(9.408, .gallonsUS) == true)
        #expect(!reading.isComplete)
    }

    @Test func aLostDigitDoesNotMigrateIntoTheGallonsField() {
        // The worst reading this scanner has produced, and it came from
        // half-finishing the rule above. "36.31" arrived as "36.3" and
        // "9.408" as "9408". Money was strict, so the sale was refused — and
        // then accepted as 36.300 *gallons*, which left the gallons free to
        // become a $94.08 sale. Both numbers wrong, both fields filled, and
        // an implied $2.59/gal that every check waved through.
        //
        // No pump meters to one decimal place either.
        let reading = PumpReadingParser.parse(
            [
                ScannedLine(text: "This Sale", midX: 0.507, midY: 0.037, height: 0.025),
                ScannedLine(text: "$", midX: 0.146, midY: 0.115, height: 0.064),
                ScannedLine(text: "36.3", midX: 0.599, midY: 0.156, height: 0.116),
                ScannedLine(text: "9408", midX: 0.569, midY: 0.252, height: 0.087),
                ScannedLine(text: "Gallons", midX: 0.510, midY: 0.326, height: 0.022),
            ],
            context: context()
        )

        #expect(reading.total == nil)
        #expect(reading.volume?.isApproximately(9.408, .gallonsUS) == true)
    }

    @Test func aVolumeMeteredToOnePlaceIsRefusedToo() {
        // The symmetric case, stated on its own: a pump meters to two places
        // or three, never one, and the field a corrupted run gets refused
        // from must not be a field it can fall into instead.
        let reading = PumpReadingParser.parse(
            lines("TOTAL $42.15", "GALLONS 12.0"),
            context: context()
        )

        #expect(reading.total?.minorUnits == 4215)
        #expect(reading.volume == nil)
    }

    @Test func aShorterSaleIsNotStretchedToFitThePrice() {
        // The pass that returned "363" must read it as $3.63 — an obviously
        // wrong answer the user can see — and never as $36.30, which is wrong
        // in the one way the price check cannot catch. Money is shown at the
        // currency's precision and nowhere else.
        let reading = PumpReadingParser.parse(capture(total: "363"), context: context())

        #expect(reading.total?.minorUnits == 363)
    }
}

// MARK: - Three numbers on the panel

struct PumpThirdNumberTests {

    @Test func aPricePerUnitDisplayConfirmsTheAssignment() {
        // When the pump shows its unit price too, the reading stops being a
        // guess: 8.426 × 4.199 has to come back as 35.38, and it only does so
        // with the decimal points in one place.
        let reading = PumpReadingParser.parse(
            [
                ScannedLine(text: "3538", midY: 0.30, height: 0.15),
                ScannedLine(text: "8.426", midY: 0.50, height: 0.10),
                ScannedLine(text: "4199", midY: 0.68, height: 0.09),
            ],
            context: context()
        )

        #expect(reading.total?.minorUnits == 3538)
        #expect(reading.volume?.isApproximately(8.426, .gallonsUS) == true)
    }
}

// MARK: - Displays that disagree about their own precision

struct PumpDecimalPlacementTests {

    @Test func aLitrePumpMeteringToThreePlacesIsStillRead() {
        // We assume two decimals for litres, and this pump shows three. The
        // assumed position implies €0.11/L, which is nothing like what this
        // driver pays; the next position along implies €1.10 and is taken.
        let band = PumpScanContext.priceBand(
            fromRecent: [Money(minorUnits: 110, currencyCode: "EUR"),
                         Money(minorUnits: 115, currencyCode: "EUR"),
                         Money(minorUnits: 120, currencyCode: "EUR")]
        )
        let reading = PumpReadingParser.parse(
            [
                ScannedLine(text: "4215", midY: 0.30, height: 0.15),
                ScannedLine(text: "38250", midY: 0.55, height: 0.11),
            ],
            context: context(volume: .liters, currency: "EUR", band: band)
        )

        #expect(reading.total?.minorUnits == 4215)
        #expect(reading.volume?.isApproximately(38.250, .liters) == true)
    }

    @Test func theExpectedPrecisionIsStillPreferredWhenItWorks() {
        // The alternates must not become a free parameter: where the assumed
        // position gives a believable price, it wins.
        let band = PumpScanContext.priceBand(
            fromRecent: [Money(minorUnits: 340, currencyCode: "USD"),
                         Money(minorUnits: 355, currencyCode: "USD")]
        )
        let reading = PumpReadingParser.parse(
            lines("4215", "12048"),
            context: context(band: band)
        )

        #expect(reading.total?.minorUnits == 4215)
        #expect(reading.volume?.isApproximately(12.048, .gallonsUS) == true)
    }

    @Test func twoBareIntegersWithNothingToSeparateThemAreRefused() {
        // The same frame with no history behind it. $42.15 for 12.048 gallons
        // and $120.48 for 4.215 both read as fuel, the digits support each
        // equally, and there is no geometry to break it. Answering anyway
        // would answer the same way on every variant and sail through the
        // ballot, so the honest result is no result.
        let reading = PumpReadingParser.parse(lines("4215", "12048"), context: context())

        #expect(reading.isEmpty)
    }
}

// MARK: - Cost

struct PumpParserCostTests {

    @Test func aBusyFrameStillParsesQuickly() {
        // Scoring is quartic in the candidate count: every ordered pair, times
        // every placement of both decimal points, times a sweep for a unit
        // price. A photograph of a whole pump carries far more numeric runs
        // than a tight one, and without a ceiling on how many reach the
        // scoring this ran for minutes on a phone — on the main actor — and
        // the scanner hung on "Reading the display…".
        var lines: [ScannedLine] = [
            ScannedLine(text: "3538", midX: 0.56, midY: 0.386, height: 0.150),
            ScannedLine(text: "8.426", midX: 0.51, midY: 0.520, height: 0.100),
        ]
        for index in 0..<40 {
            lines.append(
                ScannedLine(
                    text: "\(1000 + index * 37)",
                    midX: 0.2 + Double(index % 5) * 0.15,
                    midY: 0.60 + Double(index) * 0.005,
                    height: 0.09
                )
            )
        }

        let started = Date()
        _ = PumpReadingParser.parse(lines, context: context())
        let elapsed = Date().timeIntervalSince(started)

        // Loose on purpose — this is a cliff detector, not a benchmark. The
        // same frame took well over ten seconds before the ceiling.
        #expect(elapsed < 0.5)
    }

    @Test func theDisplayStillWinsInACrowdedFrame() {
        // The ceiling keeps the tallest runs, so the display survives being
        // outnumbered by small print.
        var lines: [ScannedLine] = [
            ScannedLine(text: "3538", midX: 0.56, midY: 0.386, height: 0.150),
            ScannedLine(text: "8.426", midX: 0.51, midY: 0.520, height: 0.100),
        ]
        for index in 0..<30 {
            lines.append(
                ScannedLine(
                    text: "\(1000 + index * 37)",
                    midX: 0.3,
                    midY: 0.70 + Double(index) * 0.005,
                    height: 0.02
                )
            )
        }

        let reading = PumpReadingParser.parse(lines, context: context())

        #expect(reading.total?.minorUnits == 3538)
        #expect(reading.volume?.isApproximately(8.426, .gallonsUS) == true)
    }
}

// MARK: - Pointing at it

/// The escape hatch, and the only signal here that isn't an inference. Every
/// other rule in the parser — decimal places, the price band, which display
/// sits higher — exists to guess what a tap simply states.
struct PumpScanHintTests {

    private func framed() -> [ScannedLine] {
        [
            ScannedLine(text: "4215", midX: 0.5, midY: 0.30, height: 0.15),
            ScannedLine(text: "12048", midX: 0.5, midY: 0.60, height: 0.12),
        ]
    }

    @Test func aTapSettlesWhatTheParserRefusedToGuess() {
        // Side by side and the same size, so there is no layout to lean on:
        // $42.15 for 12.048 gallons and $120.48 for 4.215 are both fuel and
        // nothing separates them. The parser refuses, as it should, and the
        // tap is what breaks the deadlock — picked out horizontally, which is
        // the arrangement a row of displays would defeat if the hint only
        // knew about height.
        let sideBySide = [
            ScannedLine(text: "4215", midX: 0.3, midY: 0.5, height: 0.12),
            ScannedLine(text: "12048", midX: 0.7, midY: 0.5, height: 0.12),
        ]
        #expect(PumpReadingParser.parse(sideBySide, context: context()).isEmpty)

        let reading = PumpReadingParser.parse(
            sideBySide,
            context: context(hint: PumpScanHint(midX: 0.3, midY: 0.5))
        )

        #expect(reading.total?.minorUnits == 4215)
        #expect(reading.volume?.isApproximately(12.048, .gallonsUS) == true)
    }

    @Test func theTapDecidesEvenAgainstTheLayout() {
        // Pointing at the lower, smaller display has to win anyway. The user
        // can see the pump; the heuristics are standing in for that and must
        // give way to it.
        let reading = PumpReadingParser.parse(
            framed(),
            context: context(hint: PumpScanHint(midX: 0.5, midY: 0.60))
        )

        #expect(reading.total?.minorUnits == 12048)
    }

    @Test func aTappedRunSurvivesTheDisplayScaleFilter() {
        // Whatever the user pointed at is in the running, however small it
        // came out — a glare-clipped sale amount is exactly the case where
        // they would have had to point at it.
        let reading = PumpReadingParser.parse(
            [
                ScannedLine(text: "8.426", midX: 0.5, midY: 0.30, height: 0.15),
                ScannedLine(text: "3538", midX: 0.5, midY: 0.80, height: 0.02),
            ],
            context: context(hint: PumpScanHint(midX: 0.5, midY: 0.80))
        )

        #expect(reading.total?.minorUnits == 3538)
        #expect(reading.volume?.isApproximately(8.426, .gallonsUS) == true)
    }
}

// MARK: - Price band

struct PumpPriceBandTests {

    @Test func tooLittleHistoryLeavesTheBandOpen() {
        let band = PumpScanContext.priceBand(
            fromRecent: [Money(minorUnits: 349, currencyCode: "USD")]
        )
        #expect(band == PumpScanContext.unboundedPriceBand)
    }

    @Test func bandBracketsTheMedianGenerously() {
        let band = PumpScanContext.priceBand(
            fromRecent: [
                Money(minorUnits: 320, currencyCode: "USD"),
                Money(minorUnits: 340, currencyCode: "USD"),
                Money(minorUnits: 360, currencyCode: "USD"),
            ]
        )

        // Wide enough for real price movement...
        #expect(band.contains(Decimal(string: "2.80")!))
        #expect(band.contains(Decimal(string: "4.50")!))
        // ...and still narrow enough to reject a swapped reading.
        #expect(!band.contains(Decimal(string: "0.29")!))
    }
}

// MARK: - Steadiness

/// The live stream's only job is to say when the shot is framed and still.
/// These cover that it doesn't fire early, doesn't fire on nothing, and isn't
/// derailed by captions flickering in and out.
struct PumpScanSteadinessTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func framed(offset: Double = 0) -> [ScannedLine] {
        [
            ScannedLine(text: "11428", midX: 0.5, midY: 0.40 + offset, height: 0.26),
            ScannedLine(text: "22.151", midX: 0.5, midY: 0.70 + offset, height: 0.15),
        ]
    }

    @Test func doesNotFireBeforeTheHoldElapses() {
        var detector = PumpScanSteadiness()
        #expect(detector.observe(framed(), at: start) == false)
        #expect(detector.observe(framed(), at: start.addingTimeInterval(0.3)) == false)
        #expect(detector.progress > 0)
        #expect(detector.progress < 1)
    }

    @Test func firesOnceTheFramingHasHeld() {
        var detector = PumpScanSteadiness()
        _ = detector.observe(framed(), at: start)
        let fired = detector.observe(
            framed(),
            at: start.addingTimeInterval(PumpScanSteadiness.requiredHold + 0.01)
        )

        #expect(fired)
        #expect(detector.progress == 1)
    }

    @Test func movementRestartsTheHold() {
        let hold = PumpScanSteadiness.requiredHold
        var detector = PumpScanSteadiness()

        _ = detector.observe(framed(), at: start)
        // Panned well past the tolerance just before the hold would complete.
        _ = detector.observe(framed(offset: 0.20), at: start.addingTimeInterval(hold * 0.8))

        // Only a fraction of a fresh hold has passed since the camera moved.
        let fired = detector.observe(
            framed(offset: 0.20),
            at: start.addingTimeInterval(hold * 0.8 + hold * 0.5)
        )
        #expect(fired == false)
    }

    @Test func slowDriftCannotCreepPastTheTolerance() {
        // Each step is tiny, but they are all measured against the frame that
        // started the hold, so the total drift is what counts.
        var detector = PumpScanSteadiness()
        _ = detector.observe(framed(), at: start)
        for step in 1...7 {
            let fired = detector.observe(
                framed(offset: Double(step) * 0.01),
                at: start.addingTimeInterval(Double(step) * 0.1)
            )
            #expect(fired == false)
        }
    }

    @Test func nothingInViewNeverFires() {
        var detector = PumpScanSteadiness()
        let noise = [ScannedLine(text: "Exxon"), ScannedLine(text: "Purchase")]
        _ = detector.observe(noise, at: start)
        let fired = detector.observe(noise, at: start.addingTimeInterval(5))

        #expect(fired == false)
        #expect(detector.progress == 0)
    }

    @Test func flickeringCaptionsDoNotResetTheHold() {
        // "$" and "Gallons" drop in and out of the live stream constantly. If
        // that restarted the hold it would never complete.
        var detector = PumpScanSteadiness()
        _ = detector.observe(framed() + [ScannedLine(text: "$")], at: start)
        _ = detector.observe(framed(), at: start.addingTimeInterval(0.3))
        let fired = detector.observe(
            framed() + [ScannedLine(text: "Gallons"), ScannedLine(text: "$")],
            at: start.addingTimeInterval(PumpScanSteadiness.requiredHold + 0.01)
        )

        #expect(fired)
    }

    @Test func resetClearsProgress() {
        var detector = PumpScanSteadiness()
        _ = detector.observe(framed(), at: start)
        _ = detector.observe(framed(), at: start.addingTimeInterval(0.3))
        detector.reset()
        #expect(detector.progress == 0)
    }
}

// MARK: - Ballot

/// Vision reports one candidate at confidence 1.00 whether or not it is right,
/// so voting across differently-preprocessed reads of the same photo is the
/// only corroboration available.
struct PumpBallotTests {

    private func reading(_ minor: Int?, _ ml: Int?, plausible: Bool = true) -> PumpReading {
        PumpReading(
            total: minor.map { Money(minorUnits: $0, currencyCode: "USD") },
            volume: ml.map { Volume(milliliters: $0) },
            volumeUnit: .gallonsUS,
            impliedUnitPrice: Decimal(string: "5.16"),
            isPlausible: plausible
        )
    }

    @Test func aSplitVoteOnTheVolumeIsDecidedByTheReadingNotByTheDictionary() {
        // Two passes agreeing on the sale and differing on the volume, one
        // vote each. The tiebreak used to compare the total alone, which
        // separated these by nothing at all — so the winner came down to
        // whatever order the dictionary enumerated in, and the same photo
        // answered differently run to run. Both orderings must now agree.
        #expect(
            PumpBallot.winner(among: [reading(3603, 36264), reading(3603, 36288)])?
                .reading.volume?.milliliters == 36288
        )
        #expect(
            PumpBallot.winner(among: [reading(3603, 36288), reading(3603, 36264)])?
                .reading.volume?.milliliters == 36288
        )
    }

    @Test func oneOutlierCannotOverrideAnAgreedReading() {
        // A tier that preferred whichever pass found the longest number lived
        // here briefly. It meant a single pass picking up a serial number or a
        // misread decided the scan on its own, and the same pump stopped
        // giving the same answer twice. Agreement is the point.
        let outcome = PumpBallot.winner(among: [
            reading(3631, 83853),
            reading(3631, 83853),
            reading(3631, 83853),
            reading(363100, 83853),
        ])

        #expect(outcome?.reading.total?.minorUnits == 3631)
        #expect(outcome?.votes == 3)
    }

    @Test func theMajorityReadingWins() {
        let outcome = PumpBallot.winner(among: [
            reading(11428, 83853),
            reading(11428, 83853),
            reading(1428, 83853),   // a variant that dropped a digit
        ])

        #expect(outcome?.reading.total?.minorUnits == 11428)
        #expect(outcome?.votes == 2)
        #expect(outcome?.isUnanimous == false)
    }

    @Test func aPlausibleReadingBeatsAnImplausibleMajority() {
        // Two variants agreeing on $14.28 for 22 gallons are two variants
        // making the same mistake. 65 cents a gallon is not a price.
        let outcome = PumpBallot.winner(among: [
            reading(1428, 83853, plausible: false),
            reading(1428, 83853, plausible: false),
            reading(11428, 83853, plausible: true),
        ])

        #expect(outcome?.reading.total?.minorUnits == 11428)
    }

    @Test func unanimityIsReported() {
        let outcome = PumpBallot.winner(among: [
            reading(11428, 83853), reading(11428, 83853), reading(11428, 83853),
        ])

        #expect(outcome?.isUnanimous == true)
        #expect(outcome?.votes == 3)
    }

    @Test func aCompleteReadingBeatsAPartialOne() {
        let outcome = PumpBallot.winner(among: [
            reading(nil, 83853), reading(nil, 83853), reading(11428, 83853),
        ])

        #expect(outcome?.reading.isComplete == true)
    }

    @Test func partialsAreStillBetterThanNothing() {
        let outcome = PumpBallot.winner(among: [reading(nil, 83853), reading(nil, 83853)])

        #expect(outcome?.reading.volume?.milliliters == 83853)
        #expect(outcome?.reading.isComplete == false)
    }

    @Test func noReadingsMeansNoWinner() {
        #expect(PumpBallot.winner(among: []) == nil)
    }

    @Test func aSplitVoteResolvesTheSameWayEveryTime() {
        let ballots = [reading(11428, 83853), reading(9999, 83853)]
        let first = PumpBallot.winner(among: ballots)?.reading
        let second = PumpBallot.winner(among: ballots)?.reading
        #expect(first == second)
    }
}

// MARK: - Split and mangled digits

/// Every string below came out of Vision on a real pump photo under some
/// degradation. The last digit of a seven-segment reading is a lone thin
/// stroke and it gets mangled far more often than any digit gets confused for
/// another.
struct PumpDigitRepairTests {

    private func volume(_ text: String) -> Volume? {
        PumpReadingParser.parse(
            [ScannedLine(text: "TOTAL $114.28"), ScannedLine(text: "GALLONS \(text)")],
            context: context()
        ).volume
    }

    @Test func aSplitTrailingDigitIsRejoined() {
        #expect(volume("22.15 1")?.isApproximately(22.151, .gallonsUS) == true)
    }

    @Test func aTrailingSlashIsAOne() {
        #expect(volume("22.15/")?.isApproximately(22.151, .gallonsUS) == true)
    }

    @Test func aTrailingColonIsAOne() {
        #expect(volume("22.15:")?.isApproximately(22.151, .gallonsUS) == true)
    }

    @Test func aTrailingPipeIsAOne() {
        #expect(volume("22.15|")?.isApproximately(22.151, .gallonsUS) == true)
    }

    @Test func aSplitLeadingDigitIsRejoined() {
        // Real geometry, so the "$" can find the number it belongs to — the
        // total arrives with no decimal point and needs that label to be read
        // as money at all.
        let reading = PumpReadingParser.parse(
            [
                ScannedLine(text: "$", midY: 0.591, height: 0.133),
                ScannedLine(text: "1 1428", midY: 0.593, height: 0.265),
                ScannedLine(text: "22.151", midY: 0.765, height: 0.153),
            ],
            context: context()
        )
        #expect(reading.total?.minorUnits == 11428)
    }

    @Test func twoNumbersOnOneLineAreNotWeldedTogether() {
        // The guard on rejoining: a decimal point on both sides of the gap
        // means these are two values, not one split one.
        let reading = PumpReadingParser.parse(
            lines("42.15 12.048"),
            context: context()
        )
        #expect(reading.total?.minorUnits != 4215120)
        #expect(reading.volume?.isApproximately(12.048, .gallonsUS) == true)
    }

    @Test func anInteriorColonIsNotRewritten() {
        // A clock is not a fuel volume, and turning "12:34" into 1234 would be
        // worse than ignoring it.
        let reading = PumpReadingParser.parse(
            [ScannedLine(text: "12:34"), ScannedLine(text: "GALLONS 22.151")],
            context: context()
        )
        #expect(reading.total == nil)
    }
}
