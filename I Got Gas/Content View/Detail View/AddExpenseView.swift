//
//  AddExpenseView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/27/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData
import CoreData

struct AddExpenseView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) var context

    @Query var scheduledServices: [SDScheduledService]

    @State var selectedFutureService: SDScheduledService?
    @Binding var car: SDCar
    @State private var expenseDate = Date()
    @State private var gallonsOfGas = ""
    @State private var vendorName = ""
    @State private var note = ""
    @State private var odometer: Int = 0
    @State private var isFullTank = 0
    @State var service: SDService?
    @State private var serviceType = "Gas"
    @State private var isCompletedDifferentDay = false
    @State private var isCompleted = false
    @State private var completedDate = Date()

    @State private var editingPrice = false
    private var bluePipe = Text("|")
        .foregroundColor(Color.blue)
        .fontWeight(.light)
    private var emptyText = Text("")
    @State private var editingGallons = false

    @State private var totalPrice = ""
    var totalNumberFormatted: Double {
        return (Double(totalPrice) ?? 0) / 100
    }
    var gallonsOfGasFormatted: Double {
        return (Double(gallonsOfGas) ?? 0) / 1000
    }
    
    var disableSave: Bool {
        return serviceType == "Gas" && gallonsOfGas.isEmpty
    }


    init(car: Binding<SDCar>, inputSelectedFutureService: SDScheduledService) {
        self.init(car: car) //this has to go first, since we're overwriting values next
        _serviceType = State(initialValue: "Service")
        _selectedFutureService = State(initialValue: inputSelectedFutureService)
    }

    init(car: Binding<SDCar>, isGas: Bool) {
        self.init(car: car) //this has to go first, since we're overwriting values next
        _serviceType = State(initialValue: isGas ? "Gas" : "Service")
    }

    init(car: Binding<SDCar>, service: SDService) {
        self.init(car: car)
        _service = State(initialValue: service)
        _totalPrice = State(initialValue: String(format: "%.0f", service.cost * 100)) //this looks weird because service.cost.wrappedValue is a Double, but we need to convert it to a String, but display it as a Double again.
        _expenseDate = State(initialValue: service.datePurchased)
        _note = State(initialValue: service.note)
        _odometer = State(initialValue: service.odometer)

        _vendorName = State(initialValue: service.vendorName)

        if service.isFuel {
            _gallonsOfGas = State(initialValue: String(format: "%.0f", service.gallons * 1000))
            _isFullTank = State(initialValue: ( service.isFullTank == true ? 0 : 1 ))
        } else {
            _serviceType = .init(initialValue: "Service")
        }
    }

    init(car: Binding<SDCar>) {
        _car = car
        _odometer = State(initialValue: car.wrappedValue.odometer)
        
        let carId = car.wrappedValue.localId
        let predicate = #Predicate<SDScheduledService> {
            $0.car?.localId == carId
        }
        let descriptor = FetchDescriptor<SDScheduledService>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.frequencyMiles, order: .forward),
                SortDescriptor(\.frequencyTime, order: .forward)
            ]
        )
        _scheduledServices = Query(descriptor)
    }

    var body: some View {
        VStack {
            Picker("Service Type", selection: $serviceType) {
                Text("Gas").tag("Gas")
                Text("Service").tag("Service")
            }
            .pickerStyle(SegmentedPickerStyle())
            VStack {
                Form {
                    Section {
                        DatePicker("Purchased",
                                   selection: $expenseDate,
                                   displayedComponents: .date)
                        if serviceType != "Gas"  {
                            Toggle("Completed different day", isOn: $isCompletedDifferentDay)
                            if isCompletedDifferentDay {
                                Toggle("Completed", isOn: $isCompleted)
                                if isCompleted {
                                    DatePicker("Completed",
                                               selection: $completedDate,
                                               displayedComponents: .date)
                                }
                            }
                        }
                    }
                    if serviceType != "Gas"  {
                        Picker("Scheduled Service", selection: $selectedFutureService) {
                            Text("None")
                                .italic()
                                .tag(nil as SDScheduledService?)
                            Divider()
                            ForEach(scheduledServices, id: \.self) { service in
                                Text(service.name)
                                    .foregroundColor(service.pastDue ? Color.red : Color.secondary)
                                    .tag(service)
                            }
                        }
                    } else {
                        Picker(selection: $isFullTank, label: Text("Full Tank?")) {
                            Text("Full Tank").tag(0)
                            Text("Partial tank").tag(1)
                        }.pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section(header: Text("Price")) {
                        
                        ZStack(alignment: .leading) {
                            HStack {
                                Text("$")
                                HStack {
                                    Text("\(totalNumberFormatted, specifier: "%.2f")")
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
                        }
                        
                    }
                    
                    if serviceType == "Gas" {
                        Section(header: Text("Gallons")) {
                            ZStack(alignment: .leading) {
                                HStack {
                                    Text("\(gallonsOfGasFormatted, specifier: "%.3f")")
                                        .multilineTextAlignment(TextAlignment.leading)
                                    Text("\(editingGallons == true ? bluePipe : emptyText)")
                                }
                                TextField("", text: $gallonsOfGas, onEditingChanged: {_ in editingGallons.toggle()})
                                    .foregroundColor(.clear)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .disableAutocorrection(true)
                                    .accentColor(.clear)
                                    .keyboardType(.decimalPad)
                            }
                        }
                    }
                    
                    Section(header: Text("Odometer")) {
                        TextField("\(car.odometer)", value: $odometer, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                        
                    }
                    
                    Section(header: Text("Vendor")) {
                        TextField("Vendor name", text: $vendorName)
                        if serviceType != "Gas"  {
                            TextField("Service Notes", text: $note)
                        }
                    }
                    
                    Section {
                        Button("Save") {
                            save()
                            presentationMode.wrappedValue.dismiss()
                        }.disabled(disableSave)
                    }
                    
                }
            }
        }
        .navigationBarTitle(serviceType, displayMode: .inline)
    }

    fileprivate func save() -> Void {
        var hydratedService: SDService
        if service == nil {
            hydratedService = SDService()
        } else {
            hydratedService = service!
        }
        
        hydratedService.car = car
        hydratedService.vendorName = vendorName
        hydratedService.cost = totalNumberFormatted
        hydratedService.odometer = odometer
        
        hydratedService.datePurchased = expenseDate
        if isCompletedDifferentDay {
            hydratedService.pendingCompletion = true
            if isCompleted {
                hydratedService.pendingCompletion = false
                hydratedService.dateCompleted = completedDate
            }
        }
        
        if serviceType == "Gas" {
            hydratedService.isFuel = true
            hydratedService.note = "Fuel"
            hydratedService.isFullTank = ( isFullTank == 0 ? true : false )
            hydratedService.gallons = gallonsOfGasFormatted
            hydratedService.costPerGallon = (totalNumberFormatted / gallonsOfGasFormatted)
        } else {
            hydratedService.note = note
        }
        
        if !isCompletedDifferentDay || (isCompletedDifferentDay && isCompleted) {
            if let service = selectedFutureService {
                if service.repeating == false {
                    //delete scheduled service
                    return
                }
                service.frequencyTimeStart = Date()
                service.odometerFirstOccurance = (odometer + service.frequencyMiles)
                service.scheduleNotification()
            }
            for service in scheduledServices {
                if service.frequencyMiles != 0 &&
                    service.frequencyTime != 0 {
                    if service.odometerFirstOccurance <= odometer ||
                        service.pastDue {
                        service.scheduleNotification(now: true)
                    }
                }
            }
        }

        context.insert(hydratedService)
    }
}
