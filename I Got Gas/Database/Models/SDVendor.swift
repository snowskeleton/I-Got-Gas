//
//  SDVendor.swift
//  I Got Gas
//
//  Created by snow on 10/4/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftData

@Model
class SDVendor: Identifiable {
    @Attribute(.unique)
    var localId: String = UUID().uuidString
    var icloudId: String = UUID().uuidString
    var name: String = ""
    var longitude: Double = 0.0
    var latitude: Double = 0.0
    
    @Relationship
    var services: [SDService] = []
    
    init(
        name: String,
        longitude: Double = 0.0,
        latitude: Double = 0.0
    ) {
        self.localId = localId
        self.name = name
        self.longitude = longitude
        self.latitude = latitude
    }
}
