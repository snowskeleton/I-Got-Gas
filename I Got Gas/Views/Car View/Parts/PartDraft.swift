//
//  PartDraft.swift
//  I Got Gas
//
//  Editable copy of a parts line.
//
//  The expense form edits drafts rather than live `SDPart` models so that
//  cancelling actually discards — SwiftData would otherwise have already
//  written every keystroke into the store.
//

import Foundation
import SwiftData

struct PartDraft: Identifiable, Equatable {
    var id: String = UUID().uuidString

    /// Set when this draft came from an existing row.
    var existingID: String?

    var name: String = ""
    var partNumber: String = ""
    var brand: String = ""
    var notes: String = ""
    var quantity: Decimal = 1
    var unit: String = PartUnit.each

    /// Price for one unit, in currency minor units.
    var unitCostMinor: Int?

    var saveToCatalog: Bool = true
    var catalogEntryID: String?

    var isEmpty: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty && unitCostMinor == nil
    }

    var unitCost: Money? {
        get { unitCostMinor.map { Money(minorUnits: $0) } }
        set { unitCostMinor = newValue?.minorUnits }
    }

    var lineTotal: Money? {
        guard let unitCost else { return nil }
        return unitCost * quantity
    }

    /// Shown under the row only when it says something the fields don't
    /// already — i.e. when a quantity is actually multiplying the price.
    var helperMath: String? {
        guard let unitCost, let lineTotal, quantity != 1 else { return nil }
        let qty = quantity.formatted(.number.precision(.fractionLength(0...3)))
        return "\(qty) × \(unitCost.formatted()) = \(lineTotal.formatted())"
    }

    init() { }

    init(from part: SDPart) {
        self.id = part.id
        self.existingID = part.id
        self.name = part.name
        self.partNumber = part.partNumber ?? ""
        self.brand = part.brand ?? ""
        self.notes = part.notes ?? ""
        self.quantity = part.quantity
        self.unit = part.unit
        self.unitCostMinor = part.unitCostMinor
        self.catalogEntryID = part.catalogEntry?.id
        self.saveToCatalog = false
    }

    /// Copies the draft onto a model. Position comes from the caller so
    /// ordering stays a property of the list, not the row.
    func apply(to part: SDPart, position: Int) {
        part.name = name
        part.partNumber = partNumber.isEmpty ? nil : partNumber
        part.brand = brand.isEmpty ? nil : brand
        part.notes = notes.isEmpty ? nil : notes
        part.quantity = quantity
        part.unit = unit
        part.unitCostMinor = unitCostMinor
        part.position = position
        part.deleted = false
        part.touch()
    }
}
