//
//  PartsSection.swift
//  I Got Gas
//
//  The parts list on a maintenance entry: a Name field, a Price field, and a
//  More button per row. Everything else lives behind More so the common case
//  stays two taps.
//

import SwiftUI
import SwiftData

struct PartsSection: View {
    @Binding var drafts: [PartDraft]

    /// The entry total, so the footer can show what the parts don't account for.
    let entryTotal: Money

    @Query(
        filter: #Predicate<SDCatalogPart> { $0.deleted == false },
        sort: \SDCatalogPart.name
    )
    private var catalog: [SDCatalogPart]

    @State private var editingDraftID: String?

    private var partsTotal: Money {
        drafts.compactMap(\.lineTotal).total()
    }

    private var unaccounted: Money {
        entryTotal - partsTotal
    }

    var body: some View {
        Section {
            ForEach($drafts) { $draft in
                PartRow(
                    draft: $draft,
                    catalog: catalog,
                    onMore: { editingDraftID = draft.id }
                )
            }
            .onDelete { drafts.remove(atOffsets: $0) }
            .onMove { drafts.move(fromOffsets: $0, toOffset: $1) }

            Button {
                drafts.append(PartDraft())
            } label: {
                Label("Add Part", systemImage: "plus.circle")
            }
        } header: {
            Text("Parts")
        } footer: {
            if !drafts.compactMap(\.lineTotal).isEmpty {
                // Informational only. The entry total is what was actually
                // paid and is never rewritten from this.
                VStack(alignment: .leading, spacing: 2) {
                    Text("Parts total \(partsTotal.formatted())")
                    if unaccounted.minorUnits > 0 {
                        Text("Unaccounted \(unaccounted.formatted()) — labor, tax, fees")
                    } else if unaccounted.minorUnits < 0 {
                        Text("Parts exceed the entry total by \(Money(minorUnits: -unaccounted.minorUnits).formatted())")
                    }
                }
            }
        }
        .sheet(item: editingDraftBinding) { identified in
            if let index = drafts.firstIndex(where: { $0.id == identified.id }) {
                PartDetailSheet(draft: $drafts[index])
            }
        }
    }

    /// Bridges the selected-row id into something `.sheet(item:)` accepts.
    private var editingDraftBinding: Binding<IdentifiedID?> {
        Binding(
            get: { editingDraftID.map(IdentifiedID.init) },
            set: { editingDraftID = $0?.id }
        )
    }

    struct IdentifiedID: Identifiable {
        let id: String
    }
}

private struct PartRow: View {
    @Binding var draft: PartDraft
    let catalog: [SDCatalogPart]
    let onMore: () -> Void

    @FocusState private var nameFocused: Bool

    /// Case-insensitive matches on what's been typed so far.
    private var suggestions: [SDCatalogPart] {
        let key = SDCatalogPart.matchKey(for: draft.name)
        guard key.count >= 2 else { return [] }
        guard !catalog.contains(where: { $0.matchKey == key }) else { return [] }
        return catalog
            .filter { $0.matchKey.contains(key) }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("Part name", text: $draft.name)
                    .focused($nameFocused)

                TextField("Price", value: $draft.unitCostDecimal, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)

                Button(action: onMore) {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("More part details")
            }

            if let math = draft.helperMath {
                Text(math)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if nameFocused, !suggestions.isEmpty {
                ForEach(suggestions) { suggestion in
                    Button {
                        draft.name = suggestion.name
                        draft.partNumber = suggestion.partNumber ?? ""
                        draft.brand = suggestion.brand ?? ""
                        draft.unit = suggestion.defaultUnit
                        if draft.unitCostMinor == nil {
                            draft.unitCostMinor = suggestion.defaultUnitCostMinor
                        }
                        draft.catalogEntryID = suggestion.id
                        draft.saveToCatalog = false
                        nameFocused = false
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                            Text(suggestion.name)
                            if let brand = suggestion.brand, !brand.isEmpty {
                                Text(brand).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

extension PartDraft {
    /// Decimal bridge for the price field. `Money` is integer minor units,
    /// but a text field wants a decimal the user can type into.
    var unitCostDecimal: Decimal? {
        get { unitCost?.amount }
        set { unitCostMinor = newValue.map { Money(majorUnits: $0).minorUnits } }
    }
}
