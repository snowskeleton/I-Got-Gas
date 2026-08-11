//
//  SDPart.swift
//  I Got Gas
//
//  A single line item on a maintenance entry.
//
//  Parts are rows rather than an embedded blob so they can be sorted and
//  aggregated across cars ("what have I spent on brake pads?"), and so two
//  people editing the same repair don't clobber each other's list.
//

import Foundation
import SwiftData

@Model
class SDPart: Identifiable {
    var id: String = UUID().uuidString

    var name: String = ""
    var partNumber: String?
    var brand: String?
    var notes: String?

    /// Fractional quantities are allowed — 2.5 qt of oil is a real thing.
    var quantity: Decimal = Decimal(1)

    /// Preset from `PartUnit.presets`, or whatever the user typed.
    var unit: String = PartUnit.each

    /// Price per unit, in currency minor units. Nil = not tracked; the entry
    /// total is authoritative either way.
    var unitCostMinor: Int?

    /// Stable ordering within the entry.
    var position: Int = 0

    var service: SDService?

    /// Soft backlink to the catalog entry this was filled from. A snapshot,
    /// not a reference — editing the catalog must not rewrite history.
    var catalogEntry: SDCatalogPart?

    var deleted: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() { }

    init(name: String, position: Int) {
        self.name = name
        self.position = position
    }

    // MARK: - Typed accessors

    var unitCost: Money? {
        get { unitCostMinor.map { Money(minorUnits: $0) } }
        set { unitCostMinor = newValue?.minorUnits }
    }

    /// quantity × unit cost, when both are known.
    var lineTotal: Money? {
        guard let unitCost else { return nil }
        return unitCost * quantity
    }

    /// "3 × $4.99 = $14.97", or nil when there's nothing to compute.
    var helperMath: String? {
        guard let unitCost, let lineTotal else { return nil }
        let qty = quantity.formatted(.number.precision(.fractionLength(0...3)))
        return "\(qty) \(unit) × \(unitCost.formatted()) = \(lineTotal.formatted())"
    }

    func touch() {
        updatedAt = Date()
    }
}

enum PartUnit {
    static let each = "ea"

    /// Offered in the picker; the user can also type their own.
    static let presets = ["ea", "set", "pair", "qt", "L", "gal", "oz", "mL", "ft", "m"]
}
