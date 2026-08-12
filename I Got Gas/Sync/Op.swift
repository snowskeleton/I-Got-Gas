//
//  Op.swift
//  I Got Gas
//
//  A single field assignment — the unit of sync.
//
//  Whole-record last-write-wins discarded one side whenever two devices
//  touched the same record, even if they edited different fields. Per-field
//  ops mean both edits survive, and conflict resolution is (ts, deviceID) so
//  every device converges on the same answer regardless of arrival order.
//

import Foundation
import SwiftData

enum OpEntity: String, Codable, Sendable {
    case car
    case service
    case scheduledService = "scheduled_service"
    case part
    case catalogPart = "catalog_part"
    case attachment
    case carSettings = "car_settings"
}

/// The model version this client speaks. The server stamps each car with the
/// version that last wrote it; a client below a car's stamp may read it but
/// not write to it.
enum SchemaVersion {
    static let current = 3
}

struct Op: Codable, Identifiable, Sendable {
    var seq: Int64?
    var opID: String
    var carID: String
    var entity: OpEntity
    var entityID: String
    var field: String
    /// Kept as raw JSON so the op layer never has to know every field's type.
    var value: JSONValue
    var ts: Date
    var deviceID: String

    var id: String { opID }

    enum CodingKeys: String, CodingKey {
        case seq
        case opID = "op_id"
        case carID = "car_id"
        case entity
        case entityID = "entity_id"
        case field, value, ts
        case deviceID = "device_id"
    }

    init(
        entity: OpEntity,
        entityID: String,
        carID: String,
        field: String,
        value: JSONValue,
        ts: Date = Date(),
        deviceID: String = SyncMetadata.deviceID,
        opID: String = UUID().uuidString
    ) {
        self.opID = opID
        self.entity = entity
        self.entityID = entityID
        self.carID = carID
        self.field = field
        self.value = value
        self.ts = ts
        self.deviceID = deviceID
    }

    /// Whether this op beats a stored (timestamp, device) pair.
    /// Ties break on device id so the result doesn't depend on arrival order.
    func wins(over otherTS: Date, device otherDevice: String) -> Bool {
        if ts > otherTS { return true }
        if ts == otherTS { return deviceID > otherDevice }
        return false
    }
}

// MARK: - Wire envelope

struct OpSyncRequest: Codable {
    var deviceID: String
    var schemaVersion: Int
    var cursors: [String: Int64]
    var ops: [Op]

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case schemaVersion = "schema_version"
        case cursors, ops
    }
}

struct OpSyncResponse: Codable {
    var ops: [Op]?
    var cursors: [String: Int64]?
    var appliedOpIDs: [String]?
    var rejected: [OpRejection]?
    var blockedCarIDs: [String]?
    /// Shared cars that are readable but not writable because their *owner* is
    /// still on 2.x. Kept apart from `blockedCarIDs` because the fix is the
    /// opposite one: somebody else has to update, not the person reading this.
    var ownerUpgradeCarIDs: [String]?
    var revokedCarIDs: [String]?
    /// Every car the server holds for this account. A local car missing from
    /// this list has never made it up — see `SyncReconciler`.
    var knownCarIDs: [String]?
    /// Membership fingerprint per car. Compared against `SyncDigest.digest`.
    var carDigests: [String: String]?
    var serverTime: Date?
    var minClientVersion: Int?
    var currentVersion: Int?
    var shares: SyncShares?

    enum CodingKeys: String, CodingKey {
        case ops, cursors, rejected, shares
        case appliedOpIDs = "applied_op_ids"
        case blockedCarIDs = "blocked_car_ids"
        case ownerUpgradeCarIDs = "owner_upgrade_car_ids"
        case revokedCarIDs = "revoked_car_ids"
        case knownCarIDs = "known_car_ids"
        case carDigests = "car_digests"
        case serverTime = "server_time"
        case minClientVersion = "min_client_version"
        case currentVersion = "current_version"
    }
}

struct OpRejection: Codable {
    var opID: String
    var reason: String
    var detail: String?

    enum CodingKeys: String, CodingKey {
        case opID = "op_id"
        case reason, detail
    }

    /// Rejections that will never succeed on retry, so the op should be
    /// dropped from the outbox rather than resent forever.
    var isPermanent: Bool {
        switch reason {
        case "forbidden", "unknown_field", "bad_value", "cross_car", "unknown_car":
            return true
        default:
            return false
        }
    }

    /// Rejections that are waiting on a version change rather than failing.
    ///
    /// These need their own category because neither of the others is right:
    /// the op is not permanently invalid, but the wait is measured in app
    /// updates rather than retries. Counting them as transient failures would
    /// burn the ten-attempt budget in an afternoon and drop edits that would
    /// have applied cleanly once the other side upgraded — the local record
    /// would keep the change and the server would never hear about it.
    var isWaitingOnUpgrade: Bool {
        reason == "client_too_old" || reason == "owner_too_old"
    }
}

// MARK: - JSONValue

/// A minimal any-JSON box. Op values are heterogeneous and we never need to
/// interpret them generically — only to carry them intact in both directions.
enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case data(Data)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .data(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    // Convenience accessors used by the applier.
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .double(let value): return Int(value)
        default: return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var dataValue: Data? {
        switch self {
        case .data(let value): return value
        case .string(let value): return Data(base64Encoded: value)
        default: return nil
        }
    }

    var dateValue: Date? {
        guard case .string(let value) = self else { return nil }
        return ISO8601.parse(value)
    }

    var decimalValue: Decimal? {
        switch self {
        case .string(let value): return Decimal(string: value)
        case .int(let value): return Decimal(value)
        case .double(let value): return Decimal(value)
        default: return nil
        }
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    static func date(_ value: Date) -> JSONValue { .string(ISO8601.string(from: value)) }
    static func optionalDate(_ value: Date?) -> JSONValue {
        value.map { .string(ISO8601.string(from: $0)) } ?? .null
    }
    static func optionalString(_ value: String?) -> JSONValue {
        value.map { .string($0) } ?? .null
    }
    static func optionalInt(_ value: Int?) -> JSONValue {
        value.map { .int($0) } ?? .null
    }
}

// MARK: - Timestamps

/// One formatter configuration, used everywhere.
///
/// The default `ISO8601DateFormatter` rejects fractional seconds, which is
/// exactly what Go's `time.Time` emits. Every remote timestamp silently failed
/// to parse, and the merge then skipped the update without reporting anything.
enum ISO8601 {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let withoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func string(from date: Date) -> String {
        withFraction.string(from: date)
    }

    static func parse(_ value: String) -> Date? {
        if let date = withFraction.date(from: value) { return date }
        if let date = withoutFraction.date(from: value) { return date }
        NSLog("sync: could not parse timestamp %@", value)
        return nil
    }
}
