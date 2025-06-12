//
//  AddFutureServiceView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/27/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import UserNotifications

struct AddFutureServiceView: View {
    @Environment(\.presentationMode) var mode
    @Environment(\.modelContext) var context
    
    @State private var showCancelWarning = false
    
    @State private var frequencyTimeInterval: FrequencyTimeInterval = .month
    @State private var date: Date = Date()
    @State private var name: String = ""
    @State private var fullDescription: String = ""
    @State private var repeating: Bool = true
    @State private var frequencyTime: Int = 6
    @State private var frequencyMiles: Int = 5000
    @Binding var car: SDCar
    @State private var futureService: SDScheduledService?
    
    var allowCancel: Bool {
        return name.isEmpty &&
        fullDescription.isEmpty
    }
    
    init(car: Binding<SDCar>) {
        _car = car
    }

    init(car: Binding<SDCar>, futureService: SDScheduledService) {
        _car = car
        _futureService = .init(initialValue: futureService)
        _name = .init(initialValue: futureService.name)
        _fullDescription = .init(initialValue: futureService.fullDescription)
        _repeating = .init(initialValue: futureService.repeating)
        _date = .init(initialValue: futureService.frequencyTimeStart)
        _frequencyTimeInterval = .init(initialValue: futureService.frequencyTimeInterval)
        _frequencyTime = .init(initialValue: futureService.frequencyTime)
        _frequencyMiles = .init(initialValue: futureService.frequencyMiles)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section {
                        TextField("Name", text: $name)
                    }
                    Section {
                        TextField("Description", text: $fullDescription, axis: .vertical)
                    }
                    
                    Section {
                        Toggle("Repeating", isOn: $repeating)
                    }
                    Section(repeating ? "Every..." : "In...") {
                        ZStack(alignment: .leading) {
                            HStack {
                                Spacer()
                                Text(frequencyTimeInterval.description)
                                    .foregroundColor(.gray)
                            }
                            TextField("3, 6, 12...", value: $frequencyTime, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                        }
                        
                        Picker(selection: $frequencyTimeInterval, label: Text("Interval")) {
                            ForEach(FrequencyTimeInterval.allCases, id: \.self) {
                                Text($0.description).tag($0)
                            }
                        }.pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section(header: Text("Or...")) {
                        ZStack(alignment: .leading) {
                            HStack {
                                Spacer()
                                Text("miles")
                                    .foregroundColor(.gray)
                            }
                            TextField("3,000, 15,000...", value: $frequencyMiles, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                        }
                    }
                    
                    Section(header: Text("Starting...")) {
                        DatePicker("Date",
                                   selection: $date,
                                   displayedComponents: .date)
                        
                        .labelsHidden()
                    }
                    Button("Save") {
                        save()
                        mode.wrappedValue.dismiss()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                        mode.wrappedValue.dismiss()
                    }
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
        .interactiveDismissDisabled(!allowCancel)
        .navigationBarTitle("Schedule Service")
        .onAppear {
            Analytics.track(
                .openedAddScheduleService
            )
        }
    }
    
    func save() -> Void {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("All set!")
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
        
        var hydratedService: SDScheduledService
        if futureService == nil {
            hydratedService = SDScheduledService()
            hydratedService.car = car
        } else {
            hydratedService = futureService!
        }

        hydratedService.name = name
        hydratedService.fullDescription = fullDescription
        hydratedService.repeating = repeating
        hydratedService.frequencyMiles = frequencyMiles
        hydratedService.frequencyTime = frequencyTime
        hydratedService.frequencyTimeInterval = frequencyTimeInterval
        hydratedService.frequencyTimeStart = date
        hydratedService.odometerFirstOccurance = car.odometer
        
        context.insert(hydratedService)
        
        hydratedService.scheduleNotification()
        
        Analytics.track(
            .saveScheduleService,
            with: [
                "nameEmpty": name.isEmpty,
                "fullDescriptionEmpty": fullDescription.isEmpty,
                "repeating": repeating,
                "frequencyTime": frequencyTime,
                "frequencyTimeInterval": frequencyTimeInterval,
                "frequencyMiles": frequencyMiles
            ]
        )
    }
}
