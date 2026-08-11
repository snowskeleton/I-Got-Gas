//
//  OpBuilder.swift
//  I Got Gas
//
//  Turns a model object into the ops that describe it.
//
//  Views call `record(...)` after saving. That emits one op per field, which
//  is coarser than strictly necessary — but a full field set is what makes a
//  *create* work, and for an edit the redundant fields simply lose their
//  (ts, deviceID) comparisons on the other side and change nothing.
//

import Foundation
import SwiftData

@MainActor
enum OpBuilder {

    // MARK: - Car

    static func ops(for car: SDCar) -> [Op] {
        let ts = car.updatedAt
        return [
            op(.car, car.id, car.id, "make", .string(car.make), ts),
            op(.car, car.id, car.id, "model", .string(car.model), ts),
            op(.car, car.id, car.id, "name", .string(car.name), ts),
            op(.car, car.id, car.id, "plate", .string(car.plate), ts),
            op(.car, car.id, car.id, "vin", .string(car.vin), ts),
            op(.car, car.id, car.id, "year", .optionalInt(car.year), ts),
            op(.car, car.id, car.id, "starting_odometer_meters", .int(car.startingOdometerMeters), ts),
            op(.car, car.id, car.id, "distance_unit", .string(car.distanceUnit.rawValue), ts),
            op(.car, car.id, car.id, "pinned", .bool(car.pinned), ts),
            op(.car, car.id, car.id, "archived", .bool(car.archived), ts),
            op(.car, car.id, car.id, "deleted", .bool(car.deleted), ts),
        ]
    }

    // MARK: - Service

    static func ops(for service: SDService) -> [Op] {
        guard let carID = service.car?.id else { return [] }
        let ts = service.updatedAt
        return [
            op(.service, service.id, carID, "car_id", .string(carID), ts),
            op(.service, service.id, carID, "cost_minor", .int(service.costMinor), ts),
            op(.service, service.id, carID, "date", .date(service.date), ts),
            op(.service, service.id, carID, "name", .string(service.name), ts),
            op(.service, service.id, carID, "full_description", .string(service.fullDescription), ts),
            op(.service, service.id, carID, "odometer_meters", .int(service.odometerMeters), ts),
            op(.service, service.id, carID, "kind", .string(service.kind.rawValue), ts),
            op(.service, service.id, carID, "is_full_tank", .bool(service.isFullTank), ts),
            op(.service, service.id, carID, "volume_ml", .int(service.volumeML), ts),
            op(.service, service.id, carID, "vendor_name", .string(service.vendorName), ts),
            op(.service, service.id, carID, "scheduled_service_id",
               .optionalString(service.scheduledService?.id), ts),
            op(.service, service.id, carID, "linked_manually", .bool(service.linkedManually), ts),
            op(.service, service.id, carID, "deleted", .bool(service.deleted), ts),
        ]
    }

    // MARK: - Scheduled service

    static func ops(for schedule: SDScheduledService) -> [Op] {
        guard let carID = schedule.car?.id else { return [] }
        let ts = schedule.updatedAt
        return [
            op(.scheduledService, schedule.id, carID, "car_id", .string(carID), ts),
            op(.scheduledService, schedule.id, carID, "name", .string(schedule.name), ts),
            op(.scheduledService, schedule.id, carID, "full_description",
               .string(schedule.fullDescription), ts),
            op(.scheduledService, schedule.id, carID, "repeating", .bool(schedule.repeating), ts),
            op(.scheduledService, schedule.id, carID, "frequency_meters",
               .int(schedule.frequencyMeters), ts),
            op(.scheduledService, schedule.id, carID, "frequency_time",
               .int(schedule.frequencyTime), ts),
            op(.scheduledService, schedule.id, carID, "frequency_time_interval",
               .string(intervalWire(schedule.frequencyTimeInterval)), ts),
            op(.scheduledService, schedule.id, carID, "anchor_date", .date(schedule.anchorDate), ts),
            op(.scheduledService, schedule.id, carID, "anchor_odometer_meters",
               .int(schedule.anchorOdometerMeters), ts),
            op(.scheduledService, schedule.id, carID, "completed_at",
               .optionalDate(schedule.completedAt), ts),
            op(.scheduledService, schedule.id, carID, "snoozed_until",
               .optionalDate(schedule.snoozedUntil), ts),
            op(.scheduledService, schedule.id, carID, "deleted", .bool(schedule.deleted), ts),
        ]
    }

    // MARK: - Part

    static func ops(for part: SDPart) -> [Op] {
        guard let service = part.service, let carID = service.car?.id else { return [] }
        let ts = part.updatedAt
        return [
            op(.part, part.id, carID, "service_id", .string(service.id), ts),
            op(.part, part.id, carID, "name", .string(part.name), ts),
            op(.part, part.id, carID, "part_number", .optionalString(part.partNumber), ts),
            op(.part, part.id, carID, "brand", .optionalString(part.brand), ts),
            op(.part, part.id, carID, "notes", .optionalString(part.notes), ts),
            // A decimal string, so 2.5 qt survives the round trip exactly.
            op(.part, part.id, carID, "quantity", .string("\(part.quantity)"), ts),
            op(.part, part.id, carID, "unit", .string(part.unit), ts),
            op(.part, part.id, carID, "unit_cost_minor", .optionalInt(part.unitCostMinor), ts),
            op(.part, part.id, carID, "position", .int(part.position), ts),
            op(.part, part.id, carID, "catalog_part_id",
               .optionalString(part.catalogEntry?.id), ts),
            op(.part, part.id, carID, "deleted", .bool(part.deleted), ts),
        ]
    }

    // MARK: - Catalog part (account-scoped, so no car id)

    static func ops(for entry: SDCatalogPart) -> [Op] {
        let ts = entry.updatedAt
        return [
            op(.catalogPart, entry.id, "", "name", .string(entry.name), ts),
            op(.catalogPart, entry.id, "", "part_number", .optionalString(entry.partNumber), ts),
            op(.catalogPart, entry.id, "", "brand", .optionalString(entry.brand), ts),
            op(.catalogPart, entry.id, "", "default_unit", .string(entry.defaultUnit), ts),
            op(.catalogPart, entry.id, "", "default_unit_cost_minor",
               .optionalInt(entry.defaultUnitCostMinor), ts),
            op(.catalogPart, entry.id, "", "deleted", .bool(entry.deleted), ts),
        ]
    }

    // MARK: - Attachment

    static func ops(for attachment: SDAttachment) -> [Op] {
        guard let service = attachment.service, let carID = service.car?.id else { return [] }
        let ts = attachment.updatedAt
        var ops: [Op] = [
            op(.attachment, attachment.id, carID, "service_id", .string(service.id), ts),
            op(.attachment, attachment.id, carID, "car_id", .string(carID), ts),
            op(.attachment, attachment.id, carID, "filename", .string(attachment.filename), ts),
            op(.attachment, attachment.id, carID, "mime_type", .string(attachment.mimeType), ts),
            op(.attachment, attachment.id, carID, "byte_size", .int(attachment.byteSize), ts),
            op(.attachment, attachment.id, carID, "sha256", .string(attachment.sha256), ts),
            op(.attachment, attachment.id, carID, "width", .int(attachment.width), ts),
            op(.attachment, attachment.id, carID, "height", .int(attachment.height), ts),
            op(.attachment, attachment.id, carID, "deleted", .bool(attachment.deleted), ts),
        ]
        // The thumbnail rides along so other devices can render a list without
        // fetching anything. The full image is uploaded separately.
        if let thumbnail = attachment.thumbnailData {
            ops.append(op(.attachment, attachment.id, carID, "thumbnail", .data(thumbnail), ts))
        }
        return ops
    }

    // MARK: - Car settings

    static func ops(for settings: SDCarSettings) -> [Op] {
        guard let carID = settings.car?.id else { return [] }
        let ts = settings.updatedAt
        return [
            op(.carSettings, carID, carID, "selected_tab", .string(settings.selectedTab), ts),
            op(.carSettings, carID, carID, "range_days", .int(settings.range), ts),
            op(.carSettings, carID, carID, "include_fuel", .bool(settings.includeFuel), ts),
            op(.carSettings, carID, carID, "include_maintenance",
               .bool(settings.includeMaintenance), ts),
            op(.carSettings, carID, carID, "custom", .bool(settings.custom), ts),
        ]
    }

    // MARK: - Helpers

    private static func op(
        _ entity: OpEntity, _ entityID: String, _ carID: String,
        _ field: String, _ value: JSONValue, _ ts: Date
    ) -> Op {
        Op(entity: entity, entityID: entityID, carID: carID,
           field: field, value: value, ts: ts)
    }

    static func intervalWire(_ interval: FrequencyTimeInterval) -> String {
        switch interval {
        case .day: return "day"
        case .month: return "month"
        case .year: return "year"
        }
    }

    static func interval(fromWire wire: String) -> FrequencyTimeInterval {
        switch wire {
        case "day": return .day
        case "year": return .year
        default: return .month
        }
    }
}
