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
    @State var showAboutView = false

    @AppStorage("isAnalyticsDisabled") var disableAnalytics = false

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    
                    Button("Drop all tables", role: .destructive) { try? ModelContainer().deleteAllData() }

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
                }
            }
            .navigationBarTitle(Text("Options"))
        }
    }
}

