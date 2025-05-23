//
//  OptionsView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/23/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData

struct OptionsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var formatSelection: Int
    @State var showAboutView = false
    var formatList: [String]
    
    @AppStorage("isAnalyticsDisabled") var disableAnalytics = false
    @AppStorage("migratedFrom1.0To2.0") var migrated: Bool = false

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
        NavigationStack {
            VStack {
                Form {
                    
                    Button("Drop all tables", role: .destructive) { try? ModelContainer().deleteAllData() }
                    Toggle("2.0 Migration Complete", isOn: $migrated)
                    Section(header: Text("Decimal Length")) {
                        Picker(selection: $formatSelection,
                               label: Text("Fuel Price Decimal Length")) {
                            ForEach(0..<formatList.count, id: \.self)
                            { Text(self.formatList[$0]) }
                        }.pickerStyle(SegmentedPickerStyle())
                            .onChange(of: formatSelection) { _, _ in
                                UserDefaults.standard.set(formatList[formatSelection],
                                                          forKey: "priceFormat")
                            }
                    }
                    
                    Section {
                        NavigationLink {
                            AboutView()
                        } label: {
                            Text("About")
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

