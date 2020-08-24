//
//  OptionsView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/23/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct OptionsView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        
        VStack {
        
            Text("Hello, World!")
            Button("Cancel") {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct OptionsView_Previews: PreviewProvider {
    static var previews: some View {
        OptionsView()
    }
}
