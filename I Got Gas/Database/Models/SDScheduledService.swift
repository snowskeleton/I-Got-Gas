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
    
    var frequencyDays: Int = 0
    var frequencyWeeks: Int {
        return frequencyDays / 7
    }
    var frequencyMonths: Int {
        return frequencyWeeks / 4
    }
    var frequencyYears: Int {
        return frequencyMonths / 12
    }
    
    var car: SDCar?
    
    init(
        localId: String,
        icloudId: String,
        frequencyMiles: Int,
        frequencyDays: Int
    ) {
        self.localId = localId
        self.icloudId = icloudId
        self.frequencyMiles = frequencyMiles
        self.frequencyDays = frequencyDays
    }
}

enum UrgencyLevel {
    case low
    case medium
    case high
}
