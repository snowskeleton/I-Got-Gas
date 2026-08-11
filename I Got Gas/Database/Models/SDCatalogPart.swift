//
//  SDCatalogPart.swift
//  I Got Gas
//
//  Per-account catalog of parts the user has entered before, so a filter
//  typed once is offered on every car and every device.
//
//  Catalog entries are templates. Filling a part from one copies the values
//  across; it does not create a live reference, so correcting a catalog entry
//  never rewrites a repair that already happened.
//

import Foundation
import SwiftData

@Model
class SDCatalogPart: Identifiable {
    var id: String = UUID().uuidString

    var name: String = ""
    var partNumber: String?
    var brand: String?
    var defaultUnit: String = PartUnit.each
    var defaultUnitCostMinor: Int?

    var deleted: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() { }

    init(name: String, unit: String = PartUnit.each, unitCostMinor: Int? = nil) {
        self.name = name
        self.defaultUnit = unit
        self.defaultUnitCostMinor = unitCostMinor
    }

    var defaultUnitCost: Money? {
        get { defaultUnitCostMinor.map { Money(minorUnits: $0) } }
        set { defaultUnitCostMinor = newValue?.minorUnits }
    }

    /// Case- and whitespace-insensitive key used for matching and dedupe.
    var matchKey: String {
        SDCatalogPart.matchKey(for: name)
    }

    static func matchKey(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    func touch() {
        updatedAt = Date()
    }

    /// Copies this template onto a part line.
    func apply(to part: SDPart) {
        part.name = name
        part.partNumber = partNumber
        part.brand = brand
        part.unit = defaultUnit
        part.unitCostMinor = defaultUnitCostMinor
        part.catalogEntry = self
    }
}
