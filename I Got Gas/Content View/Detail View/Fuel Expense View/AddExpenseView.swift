//
//  AddExpenseView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/27/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct AddExpenseView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var moc

    var futureServicesFetchRequest: FetchRequest<FutureService>
    var futureServices: FetchedResults<FutureService> { futureServicesFetchRequest.wrappedValue }

    @State var selectedFutureService: Int
    @State var isGas = true
    @Binding var car: Car
    @State private var expenseDate = Date()
    @State private var gallonsOfGas = ""
    @State private var vendorName = ""
    @State private var note = ""
    @State private var odometer = ""
    @State private var isFullTank = 0
    @State var service: Service?

    @State private var editingPrice = false
    private var bluePipe = Text("|")
        .foregroundColor(Color.blue)
        .font(.largeTitle)
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


    init(car: Binding<Car>, inputSelectedFutureService: Int) {
        self.init(car: car) //this has to go first, since we're overwriting values next
        _isGas = State(initialValue: false)
        _selectedFutureService = State(initialValue: inputSelectedFutureService)
    }

    init(car: Binding<Car>, isGas: State<Bool>) {
        self.init(car: car) //this has to go first, since we're overwriting values next
        _isGas = isGas
    }

    init(car: Binding<Car>, service: Binding<Service>) {
        self.init(car: car)
        _service = State(initialValue: service.wrappedValue)
        _totalPrice = State(initialValue: String(format: "%.0f", service.cost.wrappedValue * 100)) //this looks weird because service.cost.wrappedValue is a Double, but we need to convert it to a String, but display it as a Double again.
        _expenseDate = State(initialValue: service.date.wrappedValue!)
        _note = State(initialValue: service.note.wrappedValue!)
        _odometer = State(initialValue: "\(service.odometer.wrappedValue)")

        if let vendor = service.vendor.wrappedValue {
            _vendorName = State(initialValue: "\(vendor.name ?? "")")
        }

        if let fuel = service.fuel.wrappedValue {
            _gallonsOfGas = State(initialValue: String(format: "%.0f", fuel.numberOfGallons * 1000))
            _isFullTank = State(initialValue: ( fuel.isFullTank == true ? 0 : 1 ))
        } else {
            _isGas = State(initialValue: false)
        }
    }

    init(car: Binding<Car>) {
        _car = car
        _odometer = State(initialValue: "\(car.odometer.wrappedValue)")
        _selectedFutureService = State(initialValue: -1)
        futureServicesFetchRequest = Fetch.futureServices(howMany: 0, carID: car.id.wrappedValue!)
    }

    var body: some View {
        VStack {
            HStack {
                Text(isGas ? "Gas" : "Service")
            }
            .font(.largeTitle)
            .multilineTextAlignment(.center)
            .padding(.bottom, -5.0)

            NavigationView {
                VStack {
                    Form {
                        Section {
                            HStack {
                                Spacer()
                                DatePicker("Date",
                                           selection: $expenseDate,
                                           displayedComponents: .date)
                                    .labelsHidden()
                                Spacer()
                            }
                        }
                        if !isGas {
                            Picker(selection: $selectedFutureService,
                                   label: Text("Scheduled Service")) {
                                Text("None")
                                    .italic()
                                    .tag(-1)
                                ForEach(0 ..< futureServices.count, id: \.self) {
                                    Text("\(futureServices[$0].name!)")
                                        .foregroundColor(futureServices[$0].important
                                                            ? Color.red
                                                            : (colorScheme == .dark
                                                                ? Color.white
                                                                : Color.black))
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
                                    HStack(spacing: 0) {
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

                            if isGas {
                                Section(header: Text("Gallons")) {
                                ZStack(alignment: .leading) {
                                    Text("\(gallonsOfGasFormatted, specifier: "%.3f")\(editingGallons == true ? bluePipe : emptyText)")
                                        .multilineTextAlignment(TextAlignment.leading)
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
                            TextField("\(car.odometer)", text: $odometer)
                                .keyboardType(.numberPad)

                        }

                        Section(header: Text("Vendor")) {
                            TextField("Vendor name", text: $vendorName)
                            if !isGas {
                                TextField("Service Notes", text: $note)
                            }
                        }

                        Section {
                            VStack {
                                Button(action: {
                                    if maybeEnableButton() {
                                        save()
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }) {
                                    HStack {
                                        Spacer()
                                        Text("Save")
                                        Spacer()
                                    }
                                }
                            }
                        }

                    }
                    // you're gonna want to move the keyboard options down here. Don't do it! It slows down the toggle.
                }.navigationBarTitle(isGas ? "Gas" : "Service", displayMode: .inline)
                .navigationBarHidden(true)
            }
        }
    }

    // programatically determine if enough information is provided
    fileprivate func maybeEnableButton() -> Bool {
//        if totalPrice == "" {
//            return false
//        }
        if odometer == "" {
            return false
        }
        if isGas && gallonsOfGas == "" { //second is only valid if first is true
            return false
        }
        return true //if you got here, you're good to go
    }

    // save info as new expense entry.
    fileprivate func save() -> Void {
        var service: Service
        service = ( (self.service == nil
                        ? Service(context: self.moc)
                        : self.service)!
        )
        service.vendor = ( self.service?.vendor == nil
                            ? Vendor(context: self.moc)
                            : self.service?.vendor
        )
        service.vehicle = car

        updateFutureServices(car)
        setFutureInStone(car)
        updateCarOdometer(car)
        setServiceStats(service)

        try? self.moc.save()

        setFuelDetails(car, service)
        try? self.moc.save()
    }

    fileprivate func updateFutureServices(_ car: FetchedResults<Car>.Element) {

        for service in futureServices {
            if service.everyXMiles != 0 {
                if service.targetOdometer <= Int64(odometer)! {
                    service.important = true
                    AddFutureServiceView(car: Binding<Car>.constant(car)).setFutureServiceNotification(service, now: true)
                }
            }
            if service.date != nil && service.date! < Date() {
                service.important = true
            }
        }
    }

    fileprivate func setFutureInStone(_ car: FetchedResults<Car>.Element) {
        if selectedFutureService > -1 {
            let service = futureServices[selectedFutureService]
            if service.repeating == false {
                moc.delete(service)
                try? self.moc.save()
                return
            }
            service.important = false
            service.targetOdometer = (Int64(odometer)! + service.everyXMiles)

            AddFutureServiceView(car: Binding<Car>.constant(car)).upDate(service, expenseDate)

            AddFutureServiceView(car: Binding<Car>.constant(car)).setFutureServiceNotification(service)
        }
    }

    fileprivate func updateCarOdometer(_ car: FetchedResults<Car>.Element) {
        if Int64(odometer)! > car.odometer {
            car.odometer = Int64(odometer)!
        }
    }

    fileprivate func setFuelDetails(_ car: FetchedResults<Car>.Element, _ service: Service) {
        if isGas {
            car.lastFillup = expenseDate
            service.note = "Fuel"
            service.fuel = Fuel(context: self.moc)
            service.fuel?.isFullTank = ( isFullTank == 0 ? true : false )
            service.fuel?.numberOfGallons = gallonsOfGasFormatted
            service.fuel?.dpg = (totalNumberFormatted / gallonsOfGasFormatted)
        } else {
            service.note = note
        }
    }

    fileprivate func setServiceStats(_ service: Service) {
        service.vendor?.name = vendorName
        service.date = expenseDate
        service.vehicle?.lastFillup = expenseDate

        service.cost = totalNumberFormatted
        service.odometer = Int64(odometer)!
    }

}
