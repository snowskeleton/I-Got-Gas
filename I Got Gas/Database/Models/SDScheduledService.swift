//
//  SDScheduledService.swift
//  I Got Gas
//
//  Created by snow on 10/4/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftData

@Model
class SDScheduledService: Identifiable {
    @Attribute(.unique)
    var localId: String = UUID().uuidString
    var icloudId: String = UUID().uuidString
    
    var important: Bool = false
    var name: String = ""
    var notes: String = ""
    var notificationUUID: String = UUID().uuidString
    var repeating: Bool = false
    var odometerFirstOccurance: Int = 0
    var frequencyMiles: Int = 0
    var frequencyTime: Int = 0
    var frequencyTimeInterval: FrequencyTimeInterval = FrequencyTimeInterval.month

    var car: SDCar?
    
//    var nextFireDate: Date? {
//        return Calendar.current.date(
//            byAdding: frequencyTimeInterval.calendarComponent,
//            value: frequencyTime,
//            to: Date())!
//    }
    
    init() {
        self.localId = localId
        self.icloudId = icloudId
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
