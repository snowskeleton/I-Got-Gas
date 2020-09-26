//
//  CollapsableWheelPicker.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 9/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftUI

struct CollapsableWheelPicker<Label, Item, Content>: View
where Content: View, Item: Hashable, Label: View
{
    @Binding var showsPicker: Bool
    var picker: Picker<Label, Item, Content>
    init<S: StringProtocol>(_ title: S,
                            showsPicker: Binding<Bool>,
                            selection: Binding<Item>,
                            @ViewBuilder content: ()->Content)
    where Label == Text
    {
        self._showsPicker = showsPicker
        self.picker = Picker(title, selection: selection, content: content)
    }
    var body: some View {
        Group {
            if showsPicker {
                VStack {
                    HStack {
                        Spacer()
                        Button("dismiss") {
                            self.showsPicker = false
                        }
                    }
                    picker
                }
                .pickerStyle(WheelPickerStyle())
            }
        }
    }
}
