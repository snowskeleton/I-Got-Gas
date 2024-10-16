//
//  PrivacyPolicyView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 9/17/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            Text("Privacy Policy")
                .padding()
                .font(.largeTitle)
                .foregroundColor(colorScheme == .dark
                                    ? Color.white
                                    : Color.black)

            Spacer()
            
            Text("For now, this app does not collect any user data, or any other data of any kind. This is subject to change at any time.\n\nIf/when there is a change to our data collection practices, be assured that user privacy will have the utmost consideration.\n\nAny data collected in the future will be used soley for improvements in this app, and will never be sold to any third party.")
                .foregroundColor(colorScheme == .dark
                                    ? Color.white
                                    : Color.black)
                .fontWeight(.light)
                .padding(.leading)
                .padding(.trailing)
            
            Spacer()
        }
    }
}
