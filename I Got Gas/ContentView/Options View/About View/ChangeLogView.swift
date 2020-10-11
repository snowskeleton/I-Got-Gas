//
//  ChangeLogView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 9/17/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct ChangeLogView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Form {

            Section(header: Text("Version 1.0.2")) {
                Text("- The price field in the Add Expense page now automatically adds a decimal point for you.\n\n- Centered a label that should have been centered.\n\n- Added an arrow to the Repeating/One Time toggle in the Futre Expense scheduler. Hopefully this makes it obvious that it's a toggle\n\n- You can now edit expenses! Didn't get the price quite right? Want to add a note? Now you can!")
                    .fontWeight(.light)
            }

            Section(header: Text("Version 1.0.1")) {
                Text("- Added a Support button that will let you send me an email.\n\n- Made the change log pretty (can you tell?).\n\n- Prevented random elements from turning blue for no reason.\n\n- Gave all the boxes a shadow to help them stand out. Also added some spacing to give them room to breathe.")
                    .fontWeight(.light)
            }

            Section(header: Text("Version 1.0.0")) {
                Text("First public release! More changes to come.\n\nI Got Gas, in its current form, is designed to let you keep track of how much your vehicle is costing you mile by mile. Future releases will make it even more granular and add new features.")
                    .fontWeight(.light)
            }
        }
        
        .foregroundColor(colorScheme == .dark
                            ? Color.white
                            : Color.black)
    }
}
