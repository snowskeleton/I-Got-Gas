//
//  DefaultFiltersView.swift
//  I Got Gas
//
//  Created by snow on 11/12/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct DefaultFiltersView: View {
    @AppStorage("defaultFilterSelectedTab") var selectedTab = "MPG"
    @AppStorage("defaultFilterRange") var range: Int = 90
    @AppStorage("defaultFilterIncludeFuel") var includeFuel: Bool = true
    @AppStorage("defaultFilterIncludeMaintenance") var includeMaintenance: Bool = true
    @AppStorage("defaultFilterIncludeCompleted") var includeCompleted: Bool = true
    @AppStorage("defaultFilterIncludePending") var includePending: Bool = false
    
    var body: some View {
        List {
            Picker("Date Range", selection: $range) {
                Text("3 months").tag(90)
                Text("6 months").tag(180)
                Text("1 year").tag(365)
                Text("3 year").tag(730)
                Text("All time").tag(0)
            }
            Toggle("Fuel", isOn: $includeFuel)
            Toggle("Maintenance", isOn: $includeMaintenance)
            Toggle("Completed", isOn: $includeCompleted)
            Toggle("Pending", isOn: $includePending)
        }
    }
}
