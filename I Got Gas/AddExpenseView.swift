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
    
    @State private var expenseDate = Date()
    
    @Binding var isGas: Bool
    @Binding var car: Car
    @State private var totalPrice: Double?
    @State private var gallonsOfGas = ""
    @State private var vendorName = ""
    @State private var note = ""
    @State private var odometer: String = ""
    @State private var isFullTank: Int = 0
    
    init(carID: String, car: Binding<Car>, isGas: Binding<Bool>, inputSelectedFutureService: Int) {
        self._isGas = isGas
        self._car = car
        self._selectedFutureService = State(initialValue: inputSelectedFutureService)
        
        futureServicesFetchRequest = Fetch.futureServices(howMany: 0, carID: carID)
    }
    
    var body: some View {
        
        VStack {
            Text(self.isGas ? "Gas" : "Service")
                .font(.system(size: 30))
                .padding()
            
            NavigationView {
                VStack {
                    Form {
                        Section(header: Text("Date")) {
                            DatePicker("Date",
                                       selection: self.$expenseDate,
                                       displayedComponents: .date)
                                
                                .labelsHidden()
                        }
                        if !self.isGas {
                            Picker(selection: self.$selectedFutureService,
                                   label: Text("Scheduled Service")) {
                                Text("").tag(-1)
                                ForEach(0 ..< futureServices.count) {
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
                            
                            
                            CurrencyTextField("Price", value: self.$totalPrice)
                                .font(.largeTitle)
                                .multilineTextAlignment(TextAlignment.leading)
                            
                            
                            if self.isGas {
                                TextField("Gallons", text: self.$gallonsOfGas)
                                    .dismissKeyboardOnSwipe()
                                    .dismissKeyboardOnTap()
                                    .keyboardType(.decimalPad)
                                    .font(.largeTitle)
                            }
                            
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
                            }
                        }
                    }
                    // you're gonna want to move the keyboard options down here. Don't do it! It slows down the toggle.
                    
                    Spacer()
                    
                    Button("Save") {
                        if maybeEnableButton() {
                            self.save()
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }
                }.navigationBarTitle("")
                .navigationBarHidden(true)
            }
        }
    }
    
    fileprivate func maybeEnableButton() -> Bool {
        if self.totalPrice == nil {
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
            service.fuel?.dpg = ((self.totalPrice!) / (Double(self.gallonsOfGas) ?? 0.00))
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
        
        service.cost = self.totalPrice!
        service.odometer = Int64(self.odometer)!
    }
    
}
