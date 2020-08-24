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
    @State var formatSelection: Int
    var formatList: [String]
    
    init() {
        formatList = ["%.3f", "%.2f"]
        let priceFormat = UserDefaults.standard.string(forKey: "priceFormat")
        if priceFormat == nil {
            _formatSelection = State<Int>(initialValue: 0)
        } else {
            _formatSelection = State<Int>(initialValue: formatList.firstIndex(of: priceFormat!)!)
        }
    }


    var body: some View {
        VStack {
            Form {
                Picker(selection: $formatSelection, label: Text("Fuel Price Decimal Length"), content:
                        {
                            ForEach(0 ..< formatList.count) {
                                Text(self.formatList[$0])
                            }
                        }).pickerStyle(SegmentedPickerStyle())
                
            }
            Text("Hello, World!")
            Button("Save") {
                UserDefaults.standard.set(formatList[formatSelection], forKey: "priceFormat")
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

