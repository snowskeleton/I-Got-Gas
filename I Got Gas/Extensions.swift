//
//  Extensions.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/30/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftUI

extension DateFormatter {
    static let taskDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

extension NumberFormatter {
    static var decimal: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }
    static var currency: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }
}

extension Formatter {
    static let withSeparator: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ""
        return formatter
    }()
    static let withCommaSeparator: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()
}

extension Numeric {
    var formattedWithoutSeparator: String { Formatter.withSeparator.string(for: self) ?? "" }
}
//extension Numeric {
//    var formattedWithCommaSeparator: String { Formatter.withSeparator.string(for: self) ?? "," }
//}


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


struct DetailBoxStyle<V: View>: GroupBoxStyle {
    var destination: V
    
    @ScaledMetric var size: CGFloat = 1
    
    func makeBody(configuration: Configuration) -> some View {
        NavigationLink(destination: destination) {
            GroupBox(label: HStack {
                configuration.label
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Color(.systemGray4)).imageScale(.small)
            }) {
                configuration.content.padding(.top)
            }
        }.buttonStyle(PlainButtonStyle())
    }
}

struct CheckMarkToggleStyle: ToggleStyle {
    var label: String
    var color = Color.primary
    
    func makeBody(configuration: Self.Configuration) -> some View {
        HStack {
            Text(label)
            Spacer()
            Button(action: { configuration.isOn.toggle() } )
            {
                Image(systemName: configuration.isOn
                    ? "checkmark.square.fill"
                    : "square.fill")
                    .foregroundColor(color)
            }
        }
        .font(.title)
        .padding(.horizontal)
    }
}

func yearsPlusTwo() -> [String] {
    var list: [Int] = []
    
    var upperRange: Int {
        let date = Date()
        let format = DateFormatter()
        format.dateFormat = "yyyy"
        let formattedDate = format.string(from: date)
        let plusTwo = Int(formattedDate)! + 2
        return plusTwo
    }
    
    for i in 1885...upperRange {
        list.insert(i, at: 0)
    }
    
    let returnlist = list.map { String($0) }
    return returnlist
}
