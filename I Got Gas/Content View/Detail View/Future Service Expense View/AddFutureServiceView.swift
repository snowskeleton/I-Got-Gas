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
    
    @State private var monthOrWeek: Int
    @State private var date: Date
    @State private var name: String
    @State private var repeating: Bool
    @State private var frequency: String
    @State private var miles: String
    @Binding var car: Car
    @State private var futureService: FutureService?
    
    init(car: Binding<Car>) {
        _car = car
        _monthOrWeek = State<Int>(initialValue: 0)
        _date = State<Date>(initialValue: Date())
        _name = State<String>(initialValue: "")
        _repeating = State<Bool>(initialValue: true)
        _frequency = State<String>(initialValue: "")
        _miles = State<String>(initialValue: "")
    }

    init(car: Binding<Car>, futureService: Binding<FutureService>) {
        self.init(car: car)
        _futureService = State(initialValue: futureService.wrappedValue)
        _monthOrWeek = State<Int>(initialValue: (Int(futureService.monthsOrWeeks.wrappedValue)))
        _name = State<String>(initialValue: futureService.name.wrappedValue!)
        _repeating = State<Bool>(initialValue: futureService.repeating.wrappedValue)
        _frequency = State<String>(initialValue: "\(futureService.frequency.wrappedValue)")
        _miles = State<String>(initialValue: "\(futureService.everyXMiles.wrappedValue)")
    }
    
    var body: some View {
        VStack {
            NavigationView {
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
                            .font(.largeTitle)
                        
                        Section(header: Text("Every...")) {
                            ZStack(alignment: .leading) {
                                HStack {
                                    Spacer()
                                    Text(monthOrWeek == 0 ? "months" : "weeks")
                                        .foregroundColor(.gray)
                                }
                                TextField("3, 6, 12....", text: self.$frequency)
                                    .font(.largeTitle)
                                    .keyboardType(.numberPad)
                            }

                            Picker(selection: self.$monthOrWeek, label: Text("Interval")) {
                                Text("Months").tag(0)
                                Text("Weeks").tag(1)
                            }.pickerStyle(SegmentedPickerStyle())
                        }
                        
                        Section(header: Text("Or...")) {
                            ZStack(alignment: .leading) {
                                HStack {
                                    Spacer()
                                    Text("miles")
                                        .foregroundColor(.gray)
                                }
                                TextField("3,000, 15,000...", text: self.$miles)
                                    .font(.largeTitle)
                                    .keyboardType(.numberPad)
                            }
                        }
                        
                        Section(header: Text("Starting...")) {
                            HStack {
                                Spacer()
                                DatePicker("Date",
                                           selection: self.$date,
                                           displayedComponents: .date)

                                    .labelsHidden()
                                Spacer()
                            }
                        }
                        
                        VStack {
                            Button(action: {
                                self.save()
                                self.presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Save")
                                    Spacer()
                                }
                            }
                        }
                        
                    }
                }.navigationBarTitle("")
                .navigationBarHidden(true)
            }
        }
    }
    
    public func upDate(_ futureService: FutureService, _ date: Date) {
        if self.frequency != "" {
            futureService.date = Calendar.current.date(
                byAdding:
                    (monthOrWeek == 0
                      ? .month
                      : .day),
                value: ( monthOrWeek == 0
                         ? Int(self.frequency)!
                         : (Int(self.frequency)!) * 7 ),
                to: date)!
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


        let futureService = ( self.futureService == nil
                                ? FutureService(context: self.moc)
                                : self.futureService
        )

        futureService!.vehicle = car
        
        futureService!.name = self.name
        futureService!.repeating = repeating
        futureService!.everyXMiles = Int64(self.miles) ?? 0
        
        futureService!.frequency = Int64(self.frequency) ?? 0
        futureService!.targetOdometer = (car.odometer + (Int64(self.miles) ?? 0))
        
        upDate(futureService!, date)
        setFutureServiceNotification(futureService!)
        
        try? self.moc.save()
    }
    
    public func removeFutureServiceNotification(_ futureServices: FetchedResults<FutureService>.Element) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: ["\(String(describing: futureServices.notificationUUID))"])
    }
    
    public func setFutureServiceNotification(_ futureService: FetchedResults<FutureService>.Element, now: Bool? = false) {
        if futureService.date == nil { return }
        
        removeFutureServiceNotification(futureService)
        
        let content = UNMutableNotificationContent()
        content.title = "\(self.name)"
        content.body = "You're \(futureService.vehicle!.make!) \(futureService.vehicle!.model!) \(self.name) is due."
        content.badge = 0
        content.sound = UNNotificationSound.default
        
        if now! {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            futureService.notificationUUID = request.identifier
            UNUserNotificationCenter.current().add(request)
            return
        }
        
        let date = futureService.date
        var triggerDate = Calendar.current.dateComponents([.year, .month, .day,], from: date!)
        triggerDate.hour = 8
        triggerDate.minute = 15
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        futureService.notificationUUID = request.identifier
        
        UNUserNotificationCenter.current().add(request)
    }
}
