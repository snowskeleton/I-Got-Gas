//
//  AddExpenseView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/27/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.presentationMode) var mode
    @Environment(\.modelContext) var context
    @Environment(SyncManager.self) private var syncManager

    @FocusState private var focusPriceField: Bool

    @Query var scheduledServices: [SDScheduledService]

    @State private var showCancelWarning = false
    @State private var showDeleteConfirmation = false

    @State var selectedFutureService: SDScheduledService?
    @Binding var car: SDCar
    @State private var expenseDate = Date()
    @State private var vendorName = ""
    @State private var name = ""
    @State private var odometer: Int = 0
    @State private var isFullTank = 0
    @State var service: SDService?
    @State private var kind: ServiceKind = .fuel
    @State private var partDrafts: [PartDraft] = []

    /// Schedules whose state changed during this save, so their ops are
    /// recorded alongside the entry's.
    @State private var touchedSchedules: [SDScheduledService] = []

    @State private var editingPrice = false
    private var bluePipe = Text("|")
        .foregroundColor(Color.blue)
        .fontWeight(.light)
    private var emptyText = Text("")
    @State private var editingVolume = false

    /// Both entry fields are digit strings scaled by a fixed factor, which is
    /// how this form has always worked. Money being integer minor units now
    /// means the price field needs no conversion at all.
    @State private var totalPrice = ""
    @State private var volumeDigits = ""

    private var distanceUnit: DistanceUnit { car.distanceUnit }
    private var volumeUnit: VolumeUnit { UnitPreferences.volumeUnit }
    private var currencyCode: String { UnitPreferences.currencyCode }

    private var totalMinorUnits: Int {
        Int(totalPrice) ?? 0
    }

    private var enteredCost: Money {
        Money(minorUnits: totalMinorUnits, currencyCode: currencyCode)
    }

    /// Volume is typed in thousandths of the display unit.
    private var enteredVolumeValue: Double {
        (Double(volumeDigits) ?? 0) / 1000
    }

    private var enteredVolume: Volume {
        Volume(value: enteredVolumeValue, unit: volumeUnit)
    }

    private var allowCancel: Bool {
        if kind == .fuel {
            return volumeDigits.isEmpty && totalPrice.isEmpty
        } else {
            return volumeDigits.isEmpty
                && totalPrice.isEmpty
                && vendorName.isEmpty
                && name.isEmpty
                && partDrafts.allSatisfy(\.isEmpty)
        }
    }

    private var disableSave: Bool {
        kind == .fuel && volumeDigits.isEmpty
    }

    /// Only schedules on this car — a maintenance entry may never fulfil a
    /// schedule belonging to another vehicle.
    private var linkableSchedules: [SDScheduledService] {
        scheduledServices.filter { $0.car?.id == car.id && !$0.deleted }
    }

    // MARK: - Init

    init(car: Binding<SDCar>, inputSelectedFutureService: SDScheduledService) {
        self.init(car: car) // has to go first, since we're overwriting values next
        _kind = State(initialValue: .maintenance)
        _selectedFutureService = State(initialValue: inputSelectedFutureService)
    }

    init(car: Binding<SDCar>, isGas: Bool) {
        self.init(car: car)
        _kind = State(initialValue: isGas ? .fuel : .maintenance)
    }

    init(car: Binding<SDCar>, service: SDService) {
        self.init(car: car)
        _service = State(initialValue: service)
        // Money is already minor units, so the round-trip through
        // String(format: "%.0f", cost * 100) — which silently floored — is gone.
        _totalPrice = State(initialValue: String(service.costMinor))
        _expenseDate = State(initialValue: service.date)
        _name = State(initialValue: service.name)
        _odometer = State(
            initialValue: service.odometer.rounded(to: car.wrappedValue.distanceUnit)
        )
        _vendorName = State(initialValue: service.vendorName)
        _selectedFutureService = State(initialValue: service.scheduledService)
        _partDrafts = State(initialValue: service.liveParts.map(PartDraft.init(from:)))
        _kind = State(initialValue: service.kind)

        if service.kind == .fuel {
            let value = service.volume.converted(to: UnitPreferences.volumeUnit)
            _volumeDigits = State(initialValue: String(Int((value * 1000).rounded())))
            _isFullTank = State(initialValue: service.isFullTank ? 0 : 1)
        }
    }

    init(car: Binding<SDCar>) {
        _car = car
        _odometer = State(
            initialValue: car.wrappedValue.odometer.rounded(to: car.wrappedValue.distanceUnit)
        )

        let carId = car.wrappedValue.id
        let predicate = #Predicate<SDScheduledService> {
            $0.car?.id == carId && $0.deleted == false
        }
        let descriptor = FetchDescriptor<SDScheduledService>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.frequencyMeters, order: .forward),
                SortDescriptor(\.frequencyTime, order: .forward)
            ]
        )
        _scheduledServices = Query(descriptor)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Service Type", selection: $kind) {
                    Text("Gas").tag(ServiceKind.fuel)
                    Text("Service").tag(ServiceKind.maintenance)
                }
                .pickerStyle(SegmentedPickerStyle())
                VStack {
                    Form {
                        Section {
                            DatePicker("Purchased",
                                       selection: $expenseDate,
                                       displayedComponents: .date)
                        }

                        if kind == .maintenance {
                            Picker("Scheduled Service", selection: $selectedFutureService) {
                                Text("None")
                                    .italic()
                                    .tag(nil as SDScheduledService?)
                                Divider()
                                ForEach(linkableSchedules, id: \.self) { schedule in
                                    Text(schedule.name)
                                        .foregroundColor(schedule.isDue ? Color.red : Color.secondary)
                                        .tag(schedule as SDScheduledService?)
                                }
                            }
                        }

                        Section(header: Text("Price")) {
                            ZStack(alignment: .leading) {
                                HStack {
                                    HStack {
                                        Text(enteredCost.formatted())
                                            .multilineTextAlignment(TextAlignment.leading)
                                        Text("\(editingPrice == true ? bluePipe : emptyText)")
                                    }
                                }
                                TextField("", text: $totalPrice, onEditingChanged: {_ in editingPrice.toggle()})
                                    .keyboardType(.numberPad)
                                    .foregroundColor(.clear)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .disableAutocorrection(true)
                                    .accentColor(.clear)
                                    .focused($focusPriceField)
                                    .onAppear {
                                        focusPriceField = true
                                    }
                            }
                        }

                        if kind == .fuel {
                            Section(header: Text(volumeUnit.displayName)) {
                                ZStack(alignment: .leading) {
                                    HStack {
                                        Text(enteredVolume.formatted(
                                            as: volumeUnit,
                                            fractionDigits: volumeUnit.entryFractionDigits
                                        ))
                                        .multilineTextAlignment(TextAlignment.leading)
                                        Text("\(editingVolume == true ? bluePipe : emptyText)")
                                    }
                                    // Digits only — the value is scaled, so a
                                    // typed decimal point would be ambiguous.
                                    TextField("", text: $volumeDigits, onEditingChanged: {_ in editingVolume.toggle()})
                                        .foregroundColor(.clear)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .disableAutocorrection(true)
                                        .accentColor(.clear)
                                        .keyboardType(.numberPad)
                                }
                            }
                        }

                        Section(header: Text("Odometer")) {
                            HStack {
                                TextField(
                                    "\(car.odometer.rounded(to: distanceUnit))",
                                    value: $odometer,
                                    formatter: NumberFormatter()
                                )
                                .keyboardType(.numberPad)
                                Text(distanceUnit.abbreviation)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section(header: Text("Vendor")) {
                            TextField("Vendor name", text: $vendorName)
                            if kind == .maintenance {
                                TextField("Service Notes", text: $name)
                            }
                        }

                        // Parts are a maintenance idea. The model doesn't
                        // forbid them on fuel, there's just no reason to ask.
                        if kind == .maintenance {
                            PartsSection(drafts: $partDrafts, entryTotal: enteredCost)
                        }

                        ReceiptSection(service: service)

                        Section {
                            Button("Save") {
                                save()
                                mode.wrappedValue.dismiss()
                            }.disabled(disableSave)
                        }

                        if service != nil {
                            Section {
                                Button("Delete", role: .destructive) {
                                    showDeleteConfirmation = true
                                }
                            } footer: {
                                Text("Deleted expenses can be restored for \(TombstoneRetention.days) days.")
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                        mode.wrappedValue.dismiss()
                    }.disabled(disableSave)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if allowCancel {
                            mode.wrappedValue.dismiss()
                        } else {
                            showCancelWarning = true
                        }
                    }
                }
            }
        }
        .alert(isPresented: $showCancelWarning) {
            Alert(
                title: Text("Unsaved data"),
                message: Text("Are you sure you want to cancel?"),
                primaryButton: .cancel(),
                secondaryButton: .destructive(Text("Discard")) {
                    mode.wrappedValue.dismiss()
                }
            )
        }
        .confirmationDialog(
            "Delete this expense?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteEntry()
                mode.wrappedValue.dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You can restore it from Settings for \(TombstoneRetention.days) days.")
        }
        .interactiveDismissDisabled(!allowCancel)
        .navigationBarTitle(kind == .fuel ? "Gas" : "Service", displayMode: .inline)
        .onAppear {
            Analytics.track(
                .addExpense,
                with: [
                    "type": kind.rawValue
                ]
            )
        }
    }

    // MARK: - Save

    fileprivate func save() -> Void {
        let hydratedService = service ?? SDService()

        hydratedService.car = car
        hydratedService.vendorName = vendorName
        hydratedService.cost = enteredCost
        hydratedService.odometer = Distance(value: Double(odometer), unit: distanceUnit)
        hydratedService.date = expenseDate
        hydratedService.kind = kind

        if kind == .fuel {
            hydratedService.name = "Fuel"
            hydratedService.isFullTank = (isFullTank == 0)
            hydratedService.volume = enteredVolume
        } else {
            hydratedService.name = name
            hydratedService.volume = .zero
        }

        // The entry is inserted before the link is bound so the relationship
        // has something to attach to.
        context.insert(hydratedService)

        if kind == .maintenance {
            applyPartDrafts(to: hydratedService)
            applyScheduleLink(to: hydratedService)
        } else {
            hydratedService.scheduledService = nil
        }

        hydratedService.touch()
        car.touch()

        try? context.save()

        // Record what changed. The entry, every part line, and any schedule
        // whose completion state moved.
        syncManager.recordService(hydratedService)
        for part in hydratedService.parts ?? [] {
            syncManager.recordPart(part)
            if let catalogEntry = part.catalogEntry {
                syncManager.recordCatalogPart(catalogEntry)
            }
        }
        for schedule in touchedSchedules {
            syncManager.recordSchedule(schedule)
        }

        // Schedules are derived from their completions now, so nothing here
        // advances a cursor. Reminders are recomputed from scratch instead.
        Task { await NotificationReconciler.reconcile(context: context) }

        Analytics.track(
            .saveExpenseDetails,
            with: [
                "scheduledService": selectedFutureService == nil,
                "odometer": odometer,
                "vendorNameIsEmpty": vendorName.isEmpty,
                "serviceNotesIsEmpty": name.isEmpty,
                "partCount": partDrafts.filter { !$0.isEmpty }.count,
            ]
        )
    }

    /// Tombstones the entry and everything hanging off it. Soft delete, so it
    /// stays restorable and the deletion still propagates to other devices.
    private func deleteEntry() {
        guard let service else { return }
        service.deleted = true
        service.touch()
        for part in service.parts ?? [] where !part.deleted {
            part.deleted = true
            part.touch()
        }
        for attachment in service.attachments ?? [] where !attachment.deleted {
            attachment.deleted = true
            attachment.touch()
        }
        // The schedule's next-due is derived from its completions, so removing
        // one changes what's due — recorded and reconciled below.
        let schedule = service.scheduledService
        schedule?.touch()

        car.touch()
        try? context.save()

        syncManager.recordService(service)
        for part in service.parts ?? [] { syncManager.recordPart(part) }
        for attachment in service.attachments ?? [] { syncManager.recordAttachment(attachment) }
        if let schedule { syncManager.recordSchedule(schedule) }

        Task { await NotificationReconciler.reconcile(context: context) }

        Analytics.track(.saveExpenseDetails, with: ["deleted": true])
    }

    /// Binds the entry to its schedule, and retires a non-repeating schedule
    /// by marking it complete — it is kept, because a deleted schedule can no
    /// longer anchor history.
    private func applyScheduleLink(to entry: SDService) {
        let previous = entry.scheduledService
        touchedSchedules = []

        guard let schedule = selectedFutureService else {
            entry.scheduledService = nil
            if let previous {
                previous.touch()
                touchedSchedules.append(previous)
            }
            return
        }

        // Cross-car links are not allowed.
        guard schedule.car?.id == car.id else {
            entry.scheduledService = nil
            return
        }

        entry.scheduledService = schedule
        entry.linkedManually = true

        if !schedule.repeating {
            schedule.completedAt = Date()
        }
        schedule.touch()
        touchedSchedules.append(schedule)
        if let previous, previous !== schedule {
            previous.touch()
            touchedSchedules.append(previous)
        }
    }

    /// Reconciles the edited drafts against the stored rows: update what
    /// survived, insert what's new, tombstone what the user removed.
    private func applyPartDrafts(to entry: SDService) {
        let drafts = partDrafts.filter { !$0.isEmpty }
        let existing = entry.parts ?? []
        let survivingIDs = Set(drafts.compactMap(\.existingID))

        for part in existing where !part.deleted && !survivingIDs.contains(part.id) {
            part.deleted = true
            part.touch()
        }

        for (index, draft) in drafts.enumerated() {
            let part: SDPart
            if let existingID = draft.existingID,
               let match = existing.first(where: { $0.id == existingID }) {
                part = match
            } else {
                part = SDPart()
                part.service = entry
                context.insert(part)
            }
            draft.apply(to: part, position: index)

            if draft.saveToCatalog {
                part.catalogEntry = upsertCatalogEntry(for: draft)
            } else if let catalogID = draft.catalogEntryID {
                part.catalogEntry = fetchCatalogPart(id: catalogID)
            }
        }
    }

    private func upsertCatalogEntry(for draft: PartDraft) -> SDCatalogPart? {
        let key = SDCatalogPart.matchKey(for: draft.name)
        guard !key.isEmpty else { return nil }

        let descriptor = FetchDescriptor<SDCatalogPart>(
            predicate: #Predicate<SDCatalogPart> { $0.deleted == false }
        )
        let all = (try? context.fetch(descriptor)) ?? []

        if let existing = all.first(where: { $0.matchKey == key }) {
            return existing
        }

        let entry = SDCatalogPart(
            name: draft.name,
            unit: draft.unit,
            unitCostMinor: draft.unitCostMinor
        )
        entry.brand = draft.brand.isEmpty ? nil : draft.brand
        entry.partNumber = draft.partNumber.isEmpty ? nil : draft.partNumber
        context.insert(entry)
        return entry
    }

    private func fetchCatalogPart(id: String) -> SDCatalogPart? {
        let descriptor = FetchDescriptor<SDCatalogPart>(
            predicate: #Predicate<SDCatalogPart> { $0.id == id }
        )
        return (try? context.fetch(descriptor))?.first
    }
}
