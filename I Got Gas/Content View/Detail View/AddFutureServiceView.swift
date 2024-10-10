//
//  AddExpenseView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/27/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import UserNotifications

struct AddFutureServiceView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var moc
    @Environment(\.modelContext) var context
    
    @State private var frequencyTimeInterval: FrequencyTimeInterval = .month
    @State private var date: Date = Date()
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var repeating: Bool = true
    @State private var frequencyTime: Int = 30
    @State private var frequencyMiles: Int = 5000
    @Binding var car: SDCar
    @State private var futureService: SDScheduledService?
    
    init(car: Binding<SDCar>) {
        _car = car
    }

    init(car: Binding<SDCar>, futureService: Binding<SDScheduledService>) {
        _car = car
        _futureService = .init(initialValue: futureService.wrappedValue)
        _name = .init(initialValue: futureService.name.wrappedValue)
        _notes = .init(initialValue: futureService.notes.wrappedValue)
        _repeating = .init(initialValue: futureService.repeating.wrappedValue)
        _date = .init(initialValue: futureService.frequencyTimeStart.wrappedValue)
        _frequencyTimeInterval = .init(initialValue: futureService.frequencyTimeInterval.wrappedValue)
        _frequencyTime = .init(initialValue: futureService.frequencyTime.wrappedValue)
        _frequencyMiles = .init(initialValue: futureService.frequencyMiles.wrappedValue)
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    self.repeating.toggle()
                }) {
                    HStack {
                        Text( self.repeating ? ("Repeating") : ("One Time"))
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 12))
                    }
                }
                .font(.largeTitle)
                .padding()
            }
            
            Form {
                TextField("Service Description", text: self.$name)
                
                Section(header: Text("Every...")) {
                    ZStack(alignment: .leading) {
                        HStack {
                            Spacer()
                            Text(frequencyTimeInterval.description)
                                .foregroundColor(.gray)
                        }
                        TextField("3, 6, 12...", value: self.$frequencyTime, formatter: NumberFormatter())
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
                        TextField("3,000, 15,000...", value: self.$frequencyMiles, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                    }
                }
                
                Section(header: Text("Starting...")) {
                    DatePicker("Date",
                               selection: self.$date,
                               displayedComponents: .date)
                    
                    .labelsHidden()
                }
                Button("Save") {
                    self.save()
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .navigationBarTitle("Schedule Service")
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
        hydratedService.notes = notes
        hydratedService.repeating = repeating
        hydratedService.frequencyMiles = frequencyMiles
        hydratedService.frequencyTime = frequencyTime
        hydratedService.frequencyTimeInterval = frequencyTimeInterval
        hydratedService.frequencyTimeStart = date
        hydratedService.odometerFirstOccurance = car.odometer
        
        context.insert(hydratedService)
        
        hydratedService.scheduleNotification()
        presentationMode.wrappedValue.dismiss()
    }
}
