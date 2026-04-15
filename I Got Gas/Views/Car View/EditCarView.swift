//
//  EditCarView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/15/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct EditCarView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) var context
    @Environment(SyncManager.self) private var syncManager

    @State private var showFirstConfirmDeleteRequest = false
    @State private var showSecondConfirmDeleteRequest = false

    @Binding var car: SDCar

    @State var carYear: Int?
    @State var carName: String
    @State var carMake: String
    @State var carModel: String
    @State var carPlate: String
    @State var carVIN: String

    init(car: Binding<SDCar>) {
        self._car = car
        let workingCar = car.wrappedValue

        _carName = .init(initialValue: workingCar.name)
        _carYear = .init(initialValue: workingCar.year)
        _carMake = .init(initialValue: workingCar.make)
        _carModel = .init(initialValue: workingCar.model)
        _carPlate = .init(initialValue: workingCar.plate)
        _carVIN = .init(initialValue: workingCar.vin)
    }

    var body: some View {
        Form {
            Section {
                TextField("Year", value: $carYear, formatter: NumberFormatter())
                TextField("Make", text: $carMake)
                TextField("Model", text: $carModel)
                TextField("Name", text: $carName)
                TextField("Plate", text: $carPlate)
                TextField("VIN", text: $carVIN)
            }

            Section {
                Button("Cancel", role: .cancel) {
                    self.presentationMode.wrappedValue.dismiss()
                }
                Button("Update") {
                    save()
                    self.presentationMode.wrappedValue.dismiss()
                }
            }

            Section {
                Button("Archive", role: .destructive) {
                    car.archived = true
                    car.touch()
                    syncManager.triggerSync()
                }
                // Only show delete for cars the user owns (ownerID is empty for local-only or matches current user)
                if car.ownerID.isEmpty {
                    Button("Delete", role: .destructive) {
                        self.showFirstConfirmDeleteRequest = true
                    }
                    .alert(isPresented: self.$showFirstConfirmDeleteRequest) {
                        Alert(title: Text("Delete this Vehicle"),
                              message: Text("Deleting this vehicle will mark it as deleted and sync across your devices."),
                              primaryButton: .destructive(Text("Delete")) {
                            self.showSecondConfirmDeleteRequest = true
                        },
                              secondaryButton: .cancel())
                    }
                }
            }

        }
        .navigationBarTitle("Update Details")
        .alert(isPresented: self.$showSecondConfirmDeleteRequest) {
            Alert(title: Text("Are you really sure?"),
                  message: Text("This action cannot be undone"),
                  primaryButton: .cancel(),
                  secondaryButton: .destructive(Text("I'm sure")) {
                // Soft delete instead of hard delete
                car.deleted = true
                car.touch()
                syncManager.triggerSync()
                presentationMode.wrappedValue.dismiss()
            }
            )
        }
        .onAppear {
            Analytics.track(
                .openedEditCar
            )
        }
    }

    func save() {
        car.year = carYear
        car.make = carMake
        car.model = carModel
        car.name = carName
        car.plate = carPlate
        car.vin = carVIN
        car.touch()
        syncManager.triggerSync()
    }
}
