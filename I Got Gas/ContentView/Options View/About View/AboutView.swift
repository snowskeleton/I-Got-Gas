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
        NavigationView {
            List {
                Section(footer: AboutFooter()) {

                    NavigationLink(destination: PrivacyPolicyView()) {
                        Text("Privacy Policy")
                    }

                    NavigationLink(destination: ChangeLogView()) {
                        HStack {
                            Image(systemName: "hammer")
                            Text("Change Log")
                        }
                    }

                    Button(action: {
                        isShowingMailView.toggle()
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Feedback")
                        }
                        .foregroundColor(colorScheme == .dark
                                            ? Color.white
                                            : Color.black)
                    }
                    .disabled(!MFMailComposeViewController.canSendMail())
                    .sheet(isPresented: $isShowingMailView) {
                        MailView(result: self.$result)
                    }

                    HStack {
                        Text("Version:").fontWeight(.light)
                        Spacer()
                        Text("1.0.0").fontWeight(.light)
                    }
                    .foregroundColor(colorScheme == .dark
                                        ? Color.white
                                        : Color.black)

                }

            }
            .navigationBarTitle("About")
        }
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
