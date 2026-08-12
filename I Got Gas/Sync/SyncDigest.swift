//
//  SyncDigest.swift
//  I Got Gas
//
//  One half of a contract with the server. Kept free of SwiftData on purpose:
//  the conformance test compiles this file on its own and checks its output
//  against Go's, which is the only way to know the two agree.
//

import CryptoKit
import Foundation

/// The digest contract, implemented identically by `CarDigests` in
/// digest.go on the server.
///
///     line   = "<entity>:<id>"
///     digest = sha256(lines sorted ascending, joined with "\n"), lower-case hex
///
/// Two deliberate exclusions, both of which would cost more than they're worth:
///
///  * No timestamps. Postgres rounds to microseconds and `Date` is a double,
///    so a timestamp-bearing digest would disagree on roughly one record in
///    two thousand — a big car would then mismatch forever. Membership needs
///    no rounding contract, and per-field drift is already what cursors fix.
///  * No deleted rows. Tombstones are purged on independent schedules here and
///    on the server, so counting them would produce a permanent disagreement
///    about records neither side still cares about.
enum SyncDigest {

    /// Sort order is applied here rather than assumed of the caller, so the
    /// digest can't depend on the order SwiftData happened to return rows in.
    static func digest(ofLines lines: [String]) -> String {
        let joined = lines.sorted().joined(separator: "\n")
        let hash = SHA256.hash(data: Data(joined.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
