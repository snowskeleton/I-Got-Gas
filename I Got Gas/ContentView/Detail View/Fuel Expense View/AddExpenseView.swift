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
    @State var isGas: Bool = true
    @Binding var car: Car
    @State private var expenseDate = Date()
    @State private var gallonsOfGas = ""
    @State private var vendorName = ""
    @State private var note = ""
    @State private var odometer: String = ""
    @State private var isFullTank: Int = 0

    @State private var totalPrice = ""
    var totalNumberFormatted: Double {
        return (Double(totalPrice) ?? 0) / 100
    }

    
    init(car: Binding<Car>, inputSelectedFutureService: Int) {
        self.init(car: car) //this has to go first, since we're overwriting values next
        self._isGas = State(initialValue: false)
        self._selectedFutureService = State(initialValue: inputSelectedFutureService)
    }

    init(car: Binding<Car>, isGas: State<Bool>) {
        self.init(car: car) //this has to go first, since we're overwriting values next
        self._isGas = isGas
    }

    init(car: Binding<Car>) {
        self._car = car
        self._odometer = State(initialValue: "\(car.odometer.wrappedValue)")
        self._selectedFutureService = State(initialValue: -1)
        futureServicesFetchRequest = Fetch.futureServices(howMany: 0, carID: car.id.wrappedValue!)
    }

    var body: some View {
        VStack {
            HStack {
                Text(self.isGas ? "Gas" : "Service")
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
                                           selection: self.$expenseDate,
                                           displayedComponents: .date)
                                    .labelsHidden()
                                Spacer()
                            }
                        }
                        if !self.isGas {
                            Picker(selection: self.$selectedFutureService,
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
                            Picker(selection: self.$isFullTank, label: Text("Full Tank?")) {
                                Text("Full Tank").tag(0)
                                Text("Partial tank").tag(1)
                            }.pickerStyle(SegmentedPickerStyle())
                        }
                        
                        Section(header: Text("Details")) {

                            ZStack(alignment: .leading) {
                                HStack {
                                    Text("$")
                                        .font(.largeTitle)
                                    Text("\(totalNumberFormatted, specifier: "%.2f")")
                                        .font(.largeTitle)
                                        .multilineTextAlignment(TextAlignment.leading)
                                }
                                TextField("", text: $totalPrice)
                                    .keyboardType(.numberPad)
                                    .foregroundColor(.clear)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .disableAutocorrection(true)
                                    .accentColor(.clear)

                            }

                            if self.isGas {
                                TextField("Gallons", text: self.$gallonsOfGas)
                                    .dismissKeyboardOnSwipe()
                                    .dismissKeyboardOnTap()
                                    .keyboardType(.decimalPad)
                                    .font(.largeTitle)
                            }
                        }

                        Section(header: Text("Odometer")) {
                            TextField("\(car.odometer)", text: self.$odometer)
                                .dismissKeyboardOnSwipe()
                                .dismissKeyboardOnTap()
                                .keyboardType(.numberPad)
                                .font(.largeTitle)
                            
                        }
                        
                        Section(header: Text("Vendor")) {
                            TextField("Vendor name", text: self.$vendorName)
                                .dismissKeyboardOnSwipe()
                                .dismissKeyboardOnTap()
                                .font(.largeTitle)
                            if !self.isGas {
                                TextField("Service Notes", text: self.$note)
                                    .dismissKeyboardOnSwipe()
                                    .dismissKeyboardOnTap()
                                    .font(.largeTitle)
                            }
                        }
                        
                        Section {
                            VStack {
                                Button(action: {
                                    if maybeEnableButton() {
                                        self.save()
                                        self.presentationMode.wrappedValue.dismiss()
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
                }.navigationBarTitle(self.isGas ? "Gas" : "Service", displayMode: .inline)
                .navigationBarHidden(true)
            }
        }
    }
    
    fileprivate func maybeEnableButton() -> Bool {
        if self.totalPrice == "" {
            return false
        }
        if self.odometer == "" {
            return false
        }
        if isGas && self.gallonsOfGas == "" {
            return false
        }
        return true
    }
    
    fileprivate func save() -> Void {
        let service = Service(context: self.moc)
        service.vendor = Vendor(context: self.moc)
        service.vehicle = car
        
        updateFutureServices(car)
        setFutureInStone(car)
        updateCarOdometer(car)
        setServiceStats(service)
        
        try? self.moc.save()
        
        setFuelDetails(car, service)
        if isFullTank == 0 { //0 is true, 1 is false. Selected by Picker.
            updateCarStats(car)
        }
        try? self.moc.save()
    }
    
    fileprivate func updateFutureServices(_ car: FetchedResults<Car>.Element) {
        
        for service in futureServices {
            if service.everyXMiles != 0 {
                if service.targetOdometer <= Int64(self.odometer)! {
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
                return
            }
            service.important = false
            service.targetOdometer = (Int64(self.odometer)! + service.everyXMiles)
            
            AddFutureServiceView(car: Binding<Car>.constant(car)).upDate(service, expenseDate)
            
            AddFutureServiceView(car: Binding<Car>.constant(car)).setFutureServiceNotification(service)
        }
    }
    
    fileprivate func updateCarOdometer(_ car: FetchedResults<Car>.Element) {
        if Int64(self.odometer)! > car.odometer {
            car.odometer = Int64(self.odometer)!
        }
    }
    
    fileprivate func setFuelDetails(_ car: FetchedResults<Car>.Element, _ service: Service) {
        if isGas {
            car.lastFillup = self.expenseDate
            service.note = "Fuel"
            service.fuel = Fuel(context: self.moc)
            service.fuel?.numberOfGallons = Double(self.gallonsOfGas) ?? 0.00
            service.fuel?.dpg = (totalNumberFormatted / (Double(self.gallonsOfGas) ?? 0.00))
        } else {
            service.note = self.note
        }
    }
    
    public func updateCarStats(_ car: FetchedResults<Car>.Element) {
        
        var totalCost = 0.00
        var fuelCost = 0.00
        
        for service in car.services! {
            totalCost += ((service as AnyObject).cost)
            
            if ((service as AnyObject).fuel as AnyObject).dpg != nil {
                fuelCost += ((service as AnyObject).fuel as AnyObject).dpg
            }
        }
        car.costPerGallon = fuelCost / Double(car.services!.count)
        car.costPerMile = totalCost / (Double(car.odometer) - Double(car.startingOdometer))
        try? self.moc.save()
    }
    
    fileprivate func setServiceStats(_ service: Service) {
        service.vendor?.name = self.vendorName
        service.date = self.expenseDate
        service.vehicle?.lastFillup = self.expenseDate
        
        service.cost = totalNumberFormatted
        service.odometer = Int64(self.odometer)!
    }
    
}
