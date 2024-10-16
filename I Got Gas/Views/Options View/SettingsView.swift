//
//  SettingsView.swift
//  I Got Gas
//
//  Created by snow on 10/16/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI


struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @AppStorage("showDeveloperMenu") var showDeveloperMenu = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack {
                            Image(systemName: "list.clipboard")
                            Text("About")
                        }
                    }
                }
                
                Section {
                    Link(destination: URL(string: "https://discord.gg/SGrHWdYNWN")!) {
                        HStack {
                            Image(colorScheme == .dark ? "discord-white" : "discord-black")
                                .resizable()
                                .frame(width: 25, height: 20)
                            Text("Discord")
                        }
                    }
                    
                    HStack {
                        Image(systemName: "envelope.fill")
                        Link(destination: supportEmailURL()) {
                            Text("Support")
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/snowskeleton/I-Got-Gas")!) {
                        HStack {
                            HStack {
                                Image(colorScheme == .dark ? "github-mark-white" : "github-mark")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                
                                Text("GitHub")
                            }
                        }
                    }
                }
                
                Section {
                    NavigationLink {
                        AnalyticsView()
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar")
                            Text("Analytics")
                        }
                    }
                }
                
                if Config.appConfiguration != .AppStore {
                    Section {
                        NavigationLink {
                            DeveloperMenuView()
                        } label: {
                            HStack {
                                Image(systemName: "hammer")
                                Text("Developer")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            Analytics.track(.openedSettingsView)
        }
    }
    
    func supportEmailURL() -> URL {
        let recipient = "i_got_gas_support@snowskeleton.net"
        let subject = "I Got Gas Support Request"
        let body = """
        Describe the problem you're having:
        
        
        Describe when it happens:
        
        
        Anything else you think is relevant:
        
        
        
        —————————————————————————————————————————————————————
        Please don't edit anything below this line
        
        - App Version: \(Bundle.main.appVersionLong)
        - Build Number: \(Bundle.main.appBuild)
        """
        
        // URL encode the subject and body
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "mailto:\(recipient)?subject=\(encodedSubject)&body=\(encodedBody)"
        return URL(string: urlString)!
    }
    
    
}
