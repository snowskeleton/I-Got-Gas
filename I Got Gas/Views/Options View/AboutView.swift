//
//  AboutView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 9/17/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import MessageUI

struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State var showPrivacyPolicy = false
    @State var showChangeLog = false

    @State var result: Result<MFMailComposeResult, Error>? = nil
    @State var isShowingMailView = false
    
    var body: some View {
        List {
            Section(footer: AboutFooter()) {
                
                NavigationLink(destination: PrivacyPolicyView()) {
                    HStack {
                        Image(systemName: "lock.doc")
                            .font(.system(size: 30))
                        Text("Privacy Policy")
                            .fontWeight(.medium)
                    }
                }
                
                Button(action: {
                    isShowingMailView.toggle()
                }) {
                    HStack {
                        Image(systemName: "envelope")
                            .font(.system(size: 28))
                        Text("Feedback")
                            .fontWeight(.medium)
                    }
                }
                .disabled(!MFMailComposeViewController.canSendMail())
                .sheet(isPresented: $isShowingMailView) {
                    MailView(result: self.$result)
                }
                
                Link(destination: URL(string: "https://www.github.com/snowskeleton/I-Got-Gas")!) {
                    HStack {
                        Image(colorScheme == .dark ? "GitHub.dark" : "GitHub")
                        Text("View this project on Github")
                            .fontWeight(.medium)
                    }
                    
                }
                
                HStack {
                    Text("Version: \(Bundle.main.appVersionLong) (\(Bundle.main.appBuild))")
                        .fontWeight(.light)
                }
            }
            .foregroundColor(colorScheme == .dark
                             ? Color.white
                             : Color.black)
            
        }
        .navigationBarTitle("About")
    }
}

struct AboutFooter: View {
    var body: some View {
        HStack {
            Spacer()
            VStack {
                Text("By John Isaac Lyons")
                Text("2020 Blizzard Skeleton, LLC")
                Text("Made in Georgia")
            }
            Spacer()
        }
    }
}

struct ListLabelWithArrow: View {
    var text: String
    var body: some View {
        HStack {
            Text("\(text)")
            Spacer()
            Image(systemName: "chevron.right")
        }
    }
}
