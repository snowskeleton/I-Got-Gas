//
//  Labels.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/7/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI


struct ExpenseLable: View {
    var body: some View {
        HStack {
            Image(systemName: "dollarsign.square")
            Text("Expenses")
        }
    }
}

struct MaintainanceLable: View {
    var body: some View {
        HStack {
            Image(systemName: "wrench")
            Text("Maintainence")
        }
    }
}
