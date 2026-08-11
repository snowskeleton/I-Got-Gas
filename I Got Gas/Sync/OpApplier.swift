//
//  OpApplier.swift
//  I Got Gas
//
//  Applies remote ops to the local store, field by field.
//
//  Two things the old merger got wrong and this does not:
//
//   * Relationships are rebound on update, not only on create. A service whose
//     car hadn't arrived yet used to be inserted with `car == nil` and stay
//     orphaned forever, pushing back an empty car id.
//   * An op that can't be placed yet is deferred rather than dropped, so
//     arrival order doesn't matter.
//

import Foundation
import SwiftData

@MainActor
final class OpApplier {
    private let context: ModelContext

    /// Winner per field, mirroring the server's `field_versions`. Without it a
    /// replayed older op would overwrite a newer local edit.
    private var fieldVersions: [String: (ts: Date, device: String)] = [:]

    init(context: ModelContext) {
        self.context = context
    }

    /// Returns the set of car ids that actually changed.
    @discardableResult
    func apply(_ ops: [Op]) throws -> Set<String> {
        var changedCars = Set<String>()
        var deferred: [Op] = []

        for op in ops.sorted(by: { ($0.seq ?? 0) < ($1.seq ?? 0) }) {
            switch applyOne(op) {
            case .applied:
                if !op.carID.isEmpty { changedCars.insert(op.carID) }
            case .skipped:
                break
            case .missingParent:
                deferred.append(op)
            }
        }

        // A second pass catches ops whose parent arrived later in the batch.
        var remaining = deferred
        var lastCount = remaining.count + 1
        while !remaining.isEmpty && remaining.count < lastCount {
            lastCount = remaining.count
            var stillDeferred: [Op] = []
            for op in remaining {
                switch applyOne(op) {
                case .applied:
                    if !op.carID.isEmpty { changedCars.insert(op.carID) }
                case .skipped:
                    break
                case .missingParent:
                    stillDeferred.append(op)
                }
            }
            remaining = stillDeferred
        }

        if !remaining.isEmpty {
            // Not fatal: the parent may simply be in a later page. The cursor
            // for that car isn't advanced past what we could place.
            NSLog("sync: %d op(s) still waiting on a parent record", remaining.count)
        }

        try context.save()
        return changedCars
    }

    private enum Outcome {
        case applied
        case skipped
        case missingParent
    }

    private func applyOne(_ op: Op) -> Outcome {
        // Local edits win over an older remote op, same rule as the server.
        let key = "\(op.entity.rawValue)|\(op.entityID)|\(op.field)"
        if let stored = fieldVersions[key], !op.wins(over: stored.ts, device: stored.device) {
            return .skipped
        }

        let outcome: Outcome
        switch op.entity {
        case .car: outcome = applyCar(op)
        case .service: outcome = applyService(op)
        case .scheduledService: outcome = applySchedule(op)
        case .part: outcome = applyPart(op)
        case .catalogPart: outcome = applyCatalogPart(op)
        case .attachment: outcome = applyAttachment(op)
        case .carSettings: outcome = applyCarSettings(op)
        }

        if outcome == .applied {
            fieldVersions[key] = (op.ts, op.deviceID)
        }
        return outcome
    }

    // MARK: - Car

    private func applyCar(_ op: Op) -> Outcome {
        let car = fetch(SDCar.self, id: op.entityID) ?? {
            let new = SDCar()
            new.id = op.entityID
            context.insert(new)
            return new
        }()

        switch op.field {
        case "make": car.make = op.value.stringValue ?? ""
        case "model": car.model = op.value.stringValue ?? ""
        case "name": car.name = op.value.stringValue ?? ""
        case "plate": car.plate = op.value.stringValue ?? ""
        case "vin": car.vin = op.value.stringValue ?? ""
        case "year": car.year = op.value.intValue
        case "starting_odometer_meters": car.startingOdometerMeters = op.value.intValue ?? 0
        case "distance_unit":
            car.distanceUnit = DistanceUnit(rawValue: op.value.stringValue ?? "") ?? .miles
        case "pinned": car.pinned = op.value.boolValue ?? false
        case "archived": car.archived = op.value.boolValue ?? false
        case "deleted": car.deleted = op.value.boolValue ?? false
        case "owner_id": car.ownerID = op.value.stringValue ?? ""
        default: return .skipped
        }
        car.updatedAt = op.ts
        return .applied
    }

    // MARK: - Service

    private func applyService(_ op: Op) -> Outcome {
        let service = fetch(SDService.self, id: op.entityID) ?? {
            let new = SDService()
            new.id = op.entityID
            context.insert(new)
            return new
        }()

        // Rebind every time, not just on insert.
        if service.car == nil || service.car?.id != op.carID {
            guard let car = fetch(SDCar.self, id: op.carID) else { return .missingParent }
            service.car = car
        }

        switch op.field {
        case "car_id": break // handled by the rebind above
        case "cost_minor": service.costMinor = op.value.intValue ?? 0
        case "date": service.date = op.value.dateValue ?? service.date
        case "name": service.name = op.value.stringValue ?? ""
        case "full_description": service.fullDescription = op.value.stringValue ?? ""
        case "odometer_meters": service.odometerMeters = op.value.intValue ?? 0
        case "kind": service.kind = ServiceKind(rawValue: op.value.stringValue ?? "") ?? .maintenance
        case "is_full_tank": service.isFullTank = op.value.boolValue ?? true
        case "volume_ml": service.volumeML = op.value.intValue ?? 0
        case "vendor_name": service.vendorName = op.value.stringValue ?? ""
        case "linked_manually": service.linkedManually = op.value.boolValue ?? false
        case "deleted": service.deleted = op.value.boolValue ?? false
        case "scheduled_service_id":
            if op.value.isNull {
                service.scheduledService = nil
            } else if let scheduleID = op.value.stringValue {
                guard let schedule = fetch(SDScheduledService.self, id: scheduleID) else {
                    return .missingParent
                }
                // Cross-car links are refused here too, not only on the server.
                guard schedule.car?.id == service.car?.id else { return .skipped }
                service.scheduledService = schedule
            }
        default: return .skipped
        }
        service.updatedAt = op.ts
        return .applied
    }

    // MARK: - Scheduled service

    private func applySchedule(_ op: Op) -> Outcome {
        let schedule = fetch(SDScheduledService.self, id: op.entityID) ?? {
            let new = SDScheduledService()
            new.id = op.entityID
            context.insert(new)
            return new
        }()

        if schedule.car == nil || schedule.car?.id != op.carID {
            guard let car = fetch(SDCar.self, id: op.carID) else { return .missingParent }
            schedule.car = car
        }

        switch op.field {
        case "car_id": break
        case "name": schedule.name = op.value.stringValue ?? ""
        case "full_description": schedule.fullDescription = op.value.stringValue ?? ""
        case "repeating": schedule.repeating = op.value.boolValue ?? false
        case "frequency_meters": schedule.frequencyMeters = op.value.intValue ?? 0
        case "frequency_time": schedule.frequencyTime = op.value.intValue ?? 0
        case "frequency_time_interval":
            schedule.frequencyTimeInterval = OpBuilder.interval(fromWire: op.value.stringValue ?? "")
        case "anchor_date": schedule.anchorDate = op.value.dateValue ?? schedule.anchorDate
        case "anchor_odometer_meters": schedule.anchorOdometerMeters = op.value.intValue ?? 0
        case "completed_at": schedule.completedAt = op.value.isNull ? nil : op.value.dateValue
        case "snoozed_until": schedule.snoozedUntil = op.value.isNull ? nil : op.value.dateValue
        case "deleted": schedule.deleted = op.value.boolValue ?? false
        default: return .skipped
        }
        schedule.updatedAt = op.ts
        return .applied
    }

    // MARK: - Part

    private func applyPart(_ op: Op) -> Outcome {
        let part = fetch(SDPart.self, id: op.entityID) ?? {
            let new = SDPart()
            new.id = op.entityID
            context.insert(new)
            return new
        }()

        switch op.field {
        case "service_id":
            guard let serviceID = op.value.stringValue,
                  let service = fetch(SDService.self, id: serviceID) else {
                return .missingParent
            }
            part.service = service
        case "name": part.name = op.value.stringValue ?? ""
        case "part_number": part.partNumber = op.value.isNull ? nil : op.value.stringValue
        case "brand": part.brand = op.value.isNull ? nil : op.value.stringValue
        case "notes": part.notes = op.value.isNull ? nil : op.value.stringValue
        case "quantity": part.quantity = op.value.decimalValue ?? 1
        case "unit": part.unit = op.value.stringValue ?? PartUnit.each
        case "unit_cost_minor": part.unitCostMinor = op.value.isNull ? nil : op.value.intValue
        case "position": part.position = op.value.intValue ?? 0
        case "catalog_part_id":
            if op.value.isNull {
                part.catalogEntry = nil
            } else if let catalogID = op.value.stringValue {
                // A missing catalog entry is not worth deferring for — the
                // link is decorative and the part stands on its own.
                part.catalogEntry = fetch(SDCatalogPart.self, id: catalogID)
            }
        case "deleted": part.deleted = op.value.boolValue ?? false
        default: return .skipped
        }

        // A part with no service can't be shown or queried; wait for its parent.
        if part.service == nil && op.field != "service_id" {
            return .missingParent
        }
        part.updatedAt = op.ts
        return .applied
    }

    // MARK: - Catalog part

    private func applyCatalogPart(_ op: Op) -> Outcome {
        let entry = fetch(SDCatalogPart.self, id: op.entityID) ?? {
            let new = SDCatalogPart()
            new.id = op.entityID
            context.insert(new)
            return new
        }()

        switch op.field {
        case "name": entry.name = op.value.stringValue ?? ""
        case "part_number": entry.partNumber = op.value.isNull ? nil : op.value.stringValue
        case "brand": entry.brand = op.value.isNull ? nil : op.value.stringValue
        case "default_unit": entry.defaultUnit = op.value.stringValue ?? PartUnit.each
        case "default_unit_cost_minor":
            entry.defaultUnitCostMinor = op.value.isNull ? nil : op.value.intValue
        case "deleted": entry.deleted = op.value.boolValue ?? false
        default: return .skipped
        }
        entry.updatedAt = op.ts
        return .applied
    }

    // MARK: - Attachment

    private func applyAttachment(_ op: Op) -> Outcome {
        let attachment = fetch(SDAttachment.self, id: op.entityID) ?? {
            let new = SDAttachment()
            new.id = op.entityID
            context.insert(new)
            return new
        }()

        switch op.field {
        case "service_id":
            guard let serviceID = op.value.stringValue,
                  let service = fetch(SDService.self, id: serviceID) else {
                return .missingParent
            }
            attachment.service = service
        case "car_id": break
        case "filename": attachment.filename = op.value.stringValue ?? ""
        case "mime_type": attachment.mimeType = op.value.stringValue ?? "image/jpeg"
        case "byte_size": attachment.byteSize = op.value.intValue ?? 0
        case "sha256": attachment.sha256 = op.value.stringValue ?? ""
        case "width": attachment.width = op.value.intValue ?? 0
        case "height": attachment.height = op.value.intValue ?? 0
        case "thumbnail": attachment.thumbnailData = op.value.dataValue
        case "deleted": attachment.deleted = op.value.boolValue ?? false
        default: return .skipped
        }

        if attachment.service == nil && op.field != "service_id" {
            return .missingParent
        }
        // Arriving from elsewhere means the bytes are on the server, not here.
        if attachment.uploadState == .pendingUpload && attachment.localPath == nil {
            attachment.uploadState = .remote
        }
        attachment.updatedAt = op.ts
        return .applied
    }

    // MARK: - Car settings

    private func applyCarSettings(_ op: Op) -> Outcome {
        guard let car = fetch(SDCar.self, id: op.entityID) else { return .missingParent }
        let settings = car.settings ?? {
            let new = SDCarSettings()
            context.insert(new)
            car.settings = new
            return new
        }()

        switch op.field {
        case "selected_tab": settings.selectedTab = op.value.stringValue ?? "MPG"
        case "range_days": settings.range = op.value.intValue ?? 90
        case "include_fuel": settings.includeFuel = op.value.boolValue ?? true
        case "include_maintenance": settings.includeMaintenance = op.value.boolValue ?? true
        case "custom": settings.custom = op.value.boolValue ?? false
        default: return .skipped
        }
        settings.updatedAt = op.ts
        return .applied
    }

    // MARK: - Fetching

    private func fetch<T: PersistentModel>(_ type: T.Type, id: String) -> T? {
        // Predicates can't be built generically over `id`, so each type gets
        // its own narrow lookup.
        switch type {
        case is SDCar.Type:
            return try? context.fetch(
                FetchDescriptor<SDCar>(predicate: #Predicate { $0.id == id })
            ).first as? T
        case is SDService.Type:
            return try? context.fetch(
                FetchDescriptor<SDService>(predicate: #Predicate { $0.id == id })
            ).first as? T
        case is SDScheduledService.Type:
            return try? context.fetch(
                FetchDescriptor<SDScheduledService>(predicate: #Predicate { $0.id == id })
            ).first as? T
        case is SDPart.Type:
            return try? context.fetch(
                FetchDescriptor<SDPart>(predicate: #Predicate { $0.id == id })
            ).first as? T
        case is SDCatalogPart.Type:
            return try? context.fetch(
                FetchDescriptor<SDCatalogPart>(predicate: #Predicate { $0.id == id })
            ).first as? T
        case is SDAttachment.Type:
            return try? context.fetch(
                FetchDescriptor<SDAttachment>(predicate: #Predicate { $0.id == id })
            ).first as? T
        default:
            return nil
        }
    }
}
