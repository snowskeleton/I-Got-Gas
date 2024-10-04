//
//  OptionsView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/23/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct OptionsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var formatSelection: Int
    @State var showAboutView = false
    var formatList: [String]
    
    @AppStorage("isAnalyticsDisabled") var disableAnalytics = false
    @AppStorage("useSwiftData") var useSwiftData: Bool = false

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
        NavigationView {
            VStack {
                Form {
                    
                    Toggle("SwiftData", isOn: $useSwiftData)
                    Section(header: Text("Decimal Length")) {
                        Picker(selection: $formatSelection,
                               label: Text("Fuel Price Decimal Length")) {
                            ForEach(0..<formatList.count, id: \.self)
                            { Text(self.formatList[$0]) }
                        }.pickerStyle(SegmentedPickerStyle())
                            .onChange(of: formatSelection) { _ in
                                UserDefaults.standard.set(formatList[formatSelection],
                                                          forKey: "priceFormat")
                            }
                    }
                    
                    Section {
                        Button(action: {
                            self.showAboutView = true
                        }) {
                            Text("About")
                                .foregroundColor(colorScheme == .dark
                                                 ? Color.white
                                                 : Color.black)
                                .fontWeight(.light)
                        }
                        .sheet(isPresented: $showAboutView) {
                            AboutView()
                        }
                    }
                    
                    Section {
                        Toggle("Enable Analytics", isOn: Binding(
                            get: { !disableAnalytics },
                            set: {
                                Analytics.track(!$0 ? .analyticsDisabled : .analyticsEnabled)
                                disableAnalytics  = !$0
                                Analytics.track(!$0 ? .analyticsDisabled : .analyticsEnabled)
                            }
                        ))
                    } header: {
                        Text("Analytics")
                    } footer: {
                        Text("\(disableAnalytics ? "No" : "Only") app usage is tracked. No personally identifible information is saved. No information is sold to or used by third parties.")
                    }
                
//                    Section {
//                        NavigationLink {
//                            ExportDataView()
//                        } label: {
//                            Text("Import/Export")
//                        }
//                    }
                }
            }
            .navigationBarTitle(Text("Options"))
        }   
    }
}

