//
//  UnitsView.swift
//  I Got Gas
//
//  Volume and currency are per-account. Distance is per-car, and is edited
//  on the car itself, because a household can reasonably keep one vehicle in
//  miles and another in kilometres.
//

import SwiftUI
import SwiftData

struct UnitsView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncManager.self) private var syncManager

    @Query(filter: #Predicate<SDCar> { $0.deleted == false }, sort: \SDCar.name)
    private var cars: [SDCar]

    @State private var volumeUnit: VolumeUnit = UnitPreferences.volumeUnit
    @State private var currencyCode: String = UnitPreferences.currencyCode

    /// Currencies the device knows about, most-likely first.
    private var currencyOptions: [String] {
        var codes = Set(Locale.commonISOCurrencyCodes.prefix(40))
        codes.insert(UnitPreferences.currencyCode)
        if let local = Locale.current.currency?.identifier { codes.insert(local) }
        return codes.sorted()
    }

    var body: some View {
        Form {
            Section {
                Picker("Volume", selection: $volumeUnit) {
                    ForEach(VolumeUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .onChange(of: volumeUnit) { _, new in
                    let preferences = SDUserPreferences.current(in: context)
                    preferences.volumeUnit = new
                    preferences.touch()
                    UnitPreferences.mirror(from: preferences)
                    try? context.save()
                }

                Picker("Currency", selection: $currencyCode) {
                    ForEach(currencyOptions, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .onChange(of: currencyCode) { _, new in
                    let preferences = SDUserPreferences.current(in: context)
                    preferences.currencyCode = new
                    preferences.touch()
                    UnitPreferences.mirror(from: preferences)
                    try? context.save()
                }
            } header: {
                Text("Account")
            } footer: {
                Text("Changing these only changes how values are displayed. Nothing that's already recorded is altered.")
            }

            Section {
                ForEach(cars) { car in
                    Picker(car.visualName, selection: distanceBinding(for: car)) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }
            } header: {
                Text("Distance")
            } footer: {
                Text("Each vehicle has its own distance unit.")
            }
        }
        .navigationTitle("Units")
    }

    private func distanceBinding(for car: SDCar) -> Binding<DistanceUnit> {
        Binding(
            get: { car.distanceUnit },
            set: { newValue in
                car.distanceUnit = newValue
                car.touch()
                syncManager.recordCar(car)
            }
        )
    }
}
