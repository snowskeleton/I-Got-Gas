//
//  ChangeLogView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 9/17/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct ChangeLogView: View {
    var body: some View {
        Form {

            Section(header: Text("Version 1.0.1")) {
                Text("  - Added a Support button that will let you send me an email.\n\n    - Made the change log pretty (can you tell?).\n\n")
            }

            Section(header: Text("Version 1.0.0")) {
                Text("First public release! More changes to come.\n\nI Got Gas, in its current form, is designed to let you keep track of how much your vehicle is costing you mile by mile. Future releases will make it even more granular and add new features.")
            }
        }
    }
}

struct ChangeLogView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeLogView()
    }
}
