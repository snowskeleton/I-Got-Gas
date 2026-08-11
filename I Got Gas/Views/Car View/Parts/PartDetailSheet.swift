//
//  PartDetailSheet.swift
//  I Got Gas
//
//  Everything about a part that doesn't fit on one row. Deliberately excludes
//  the id and the timestamps — those aren't the user's business.
//

import SwiftUI

struct PartDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: PartDraft

    /// Set when the user picks "Other…" so they can type their own unit.
    @State private var customUnit: String = ""
    @State private var usingCustomUnit = false

    private var unitOptions: [String] {
        var options = PartUnit.presets
        if !draft.unit.isEmpty, !options.contains(draft.unit) {
            options.append(draft.unit)
        }
        return options
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Part") {
                    TextField("Name", text: $draft.name)
                    TextField("Brand", text: $draft.brand)
                    TextField("Part number", text: $draft.partNumber)
                }

                Section("Quantity") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField(
                            "1",
                            value: $draft.quantity,
                            format: .number.precision(.fractionLength(0...3))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    }

                    Picker("Unit", selection: unitSelection) {
                        ForEach(unitOptions, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                        Text("Other…").tag(PartDetailSheet.otherTag)
                    }

                    if usingCustomUnit {
                        TextField("Unit", text: $customUnit)
                            .onChange(of: customUnit) { _, new in
                                draft.unit = new
                            }
                    }
                }

                Section("Price") {
                    HStack {
                        Text("Price per \(draft.unit)")
                        Spacer()
                        TextField(
                            "0",
                            value: $draft.unitCostDecimal,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    }

                    if let total = draft.lineTotal {
                        HStack {
                            Text("Line total")
                            Spacer()
                            Text(total.formatted()).foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Toggle("Save to my parts list", isOn: $draft.saveToCatalog)
                } footer: {
                    Text("Saved parts are suggested the next time you type this name, on any of your vehicles.")
                }
            }
            .navigationTitle("Part Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if !PartUnit.presets.contains(draft.unit) {
                    usingCustomUnit = true
                    customUnit = draft.unit
                }
            }
        }
    }

    private static let otherTag = "\u{0000}other"

    private var unitSelection: Binding<String> {
        Binding(
            get: { usingCustomUnit ? PartDetailSheet.otherTag : draft.unit },
            set: { selection in
                if selection == PartDetailSheet.otherTag {
                    usingCustomUnit = true
                    customUnit = draft.unit
                } else {
                    usingCustomUnit = false
                    draft.unit = selection
                }
            }
        )
    }
}
