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
}

extension Numeric {
    var formattedWithoutSeparator: String { Formatter.withSeparator.string(for: self) ?? "" }
}

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
    var color: Color
    var destination: V
    var date: Date?
    
    @ScaledMetric var size: CGFloat = 1
    
    func makeBody(configuration: Configuration) -> some View {
        NavigationLink(destination: destination) {
            GroupBox(label: HStack {
                configuration.label.foregroundColor(color)
                Spacer()
                if date != nil {
                    Text("\(date!)").font(.footnote).foregroundColor(.secondary).padding(.trailing, 4)
                }
                Image(systemName: "chevron.right").foregroundColor(Color(.systemGray4)).imageScale(.small)
            }) {
                configuration.content.padding(.top)
            }
        }.buttonStyle(PlainButtonStyle())
    }
}


struct BackgroundView : UIViewRepresentable {
    
    var color: UIColor = .systemBackground
    
    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }
    
    func updateUIView(_ view: UIView, context: Context) {
        view.backgroundColor = color
    }
    
}
