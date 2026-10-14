//
//  PumpBallot.swift
//  I Got Gas
//
//  Picks a winner from several independent readings of the same photo.
//
//  Vision returns exactly one candidate per run of text, at confidence 1.00,
//  and it is just as confident when it is wrong — `topCandidates(4)` hands
//  back a single string. So there is no confidence to threshold and no
//  alternative to fall back on.
//
//  What there is: the same still, preprocessed differently, fails differently.
//  A frame where the plain image loses a decimal point is one where the
//  contrast-boosted copy keeps it, and a copy that invents an error invents a
//  different one. Those mistakes are uncorrelated, so the reading that shows
//  up in the most variants is almost always the true one.
//

import Foundation

enum PumpBallot {

    struct Outcome {
        let reading: PumpReading
        /// How many variants read it this way.
        let votes: Int
        /// How many variants produced any complete reading at all.
        let ballots: Int

        /// Agreement across independent reads is the only corroboration this
        /// feature gets, so it's worth surfacing.
        var isUnanimous: Bool { ballots > 0 && votes == ballots }
    }

    /// Counts the ballots.
    ///
    /// Tiers before tallies: a complete, plausible reading beats a complete
    /// implausible one however many variants produced it, because an implied
    /// price nothing like what this user pays means the digits are wrong no
    /// matter how many copies of the image agree on them.
    static func winner(among readings: [PumpReading]) -> Outcome? {
        let complete = readings.filter(\.isComplete)

        if let outcome = tally(complete.filter(\.isPlausible), ballots: complete.count) {
            return outcome
        }
        if let outcome = tally(complete, ballots: complete.count) {
            return outcome
        }
        // Nothing whole — fall back to the best partial, which still saves the
        // user one of the two fields.
        return tally(readings.filter { !$0.isEmpty }, ballots: 0)
    }

    // A "most digits wins" tier lived here briefly and was removed. It was an
    // argmax over a noisy statistic, which is the opposite of what a ballot is
    // for: instead of the answer the passes agreed on, it elected whichever
    // pass had found the longest number, so one outlier picking up a serial
    // number or a misread decided the whole scan. Results stopped being stable
    // between attempts on the same pump. Measured afterwards, it had changed
    // no outcome on any real capture — the plausibility tier above was already
    // doing the work. The fix for a majority agreeing on a wrong answer is to
    // make that answer fail a check, not to stop counting.

    private static func tally(_ readings: [PumpReading], ballots: Int) -> Outcome? {
        guard !readings.isEmpty else { return nil }

        var counts: [PumpReading: Int] = [:]
        for reading in readings {
            counts[reading, default: 0] += 1
        }

        // Ordered on ties by the reading's own values, so a split vote
        // resolves the same way every time rather than on dictionary order.
        //
        // Both numbers have to take part. Comparing the total alone left two
        // readings that agreed on the sale and differed on the volume — a BP
        // display read as 9.586 by one pass and 9.580 by another, one vote
        // each — with nothing to separate them, so the winner came down to
        // whatever order the dictionary happened to enumerate in. Same photo,
        // different answer, run to run.
        //
        // Where it still comes to magnitude, the larger value wins, and that
        // is not arbitrary either: these passes fail by dropping a trailing
        // digit, so of two readings this close the longer one kept it.
        let best = counts.max { left, right in
            if left.value != right.value { return left.value < right.value }
            let leftTotal = left.key.total?.minorUnits ?? 0
            let rightTotal = right.key.total?.minorUnits ?? 0
            if leftTotal != rightTotal { return leftTotal < rightTotal }
            return (left.key.volume?.milliliters ?? 0) < (right.key.volume?.milliliters ?? 0)
        }
        guard let best else { return nil }

        return Outcome(reading: best.key, votes: best.value, ballots: max(ballots, best.value))
    }
}

extension PumpReading: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(total?.minorUnits)
        hasher.combine(volume?.milliliters)
    }
}
