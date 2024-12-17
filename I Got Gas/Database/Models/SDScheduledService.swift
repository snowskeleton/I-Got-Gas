//
//  SDScheduledService.swift
//  I Got Gas
//
//  Created by snow on 10/4/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftData
import UserNotifications

@Model
class SDScheduledService: Identifiable {
    @Attribute(originalName: "localId")
    var id: String = UUID().uuidString

    @available(*, deprecated, message: "Use `pastDue` instead")
    var important: Bool { return pastDue }
    var pastDue: Bool {
        if let nextDueDate = Calendar.current.date(byAdding: frequencyTimeInterval.calendarComponent, value: frequencyTime, to: frequencyTimeStart) {
            return Date() > nextDueDate
        }
        return false
    }
    
    var name: String = ""
    var fullDescription: String = ""
    var notificationUUID: String = UUID().uuidString
    var repeating: Bool = false
    
    var odometerFirstOccurance: Int = 0
    
    var frequencyMiles: Int = 0
    var frequencyTime: Int = 0
    var frequencyTimeInterval: FrequencyTimeInterval = FrequencyTimeInterval.month
    var frequencyTimeStart: Date = Date()

    var car: SDCar?
    
    init() { }
    
    func scheduleNotification(now: Bool? = false) {
        //        if futureService.date == nil { return }
        
        let content = UNMutableNotificationContent()
        content.title = "\(self.name)"
        content.body = "Your \(car!.make) \(car!.model) \(name) is due."
        content.badge = 0
        content.sound = UNNotificationSound.default
        
        if now! {
            // this sets a 30 second delay because IGG doesn't handle notificaions in the foreground.
            // Can't we just handle those?
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            notificationUUID = request.identifier
            UNUserNotificationCenter.current().add(request)
            return
        }
        
        if frequencyTime > 0 {
            let futureDate = Calendar.current.date(byAdding: frequencyTimeInterval.calendarComponent, value: frequencyTime, to: Date())!
            
            var triggerDate = Calendar.current.dateComponents([.year, .month, .day], from: futureDate)
            triggerDate.hour = 8
            triggerDate.minute = 15
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            notificationUUID = request.identifier
            
            UNUserNotificationCenter.current().add(request)
        }
    }
}

enum UrgencyLevel {
    case low
    case medium
    case high
}

enum FrequencyTimeInterval: CaseIterable, Codable {
    case day
    case month
    case year
    
    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return Calendar.Component.day
        case .month: return Calendar.Component.month
        case .year: return Calendar.Component.year
        }
    }
    
    var description: String {
        switch self {
        case .day: return "Days"
        case .month: return "Months"
        case .year: return "Years"
        }
    }
}
