//
//  AboutView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 9/17/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State var showPrivacyPolicy = false
    @State var showChangeLog = false
    
    var body: some View {
        VStack {
            Text("About")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding(.bottom, -5.0)
            
            NavigationView {
                List {
                    Section(footer: AboutFooter()) {
                        
                        Button(action: { self.showPrivacyPolicy = true })
                            { ListLabelWithArrow(text: "Privacy Policy") }
                            .sheet(isPresented: $showPrivacyPolicy)
                                { PrivacyPolicyView() }
                        
                        Button(action: { self.showChangeLog = true })
                            { ListLabelWithArrow(text: "Change Log") }
                            .sheet(isPresented: $showChangeLog)
                                { ChangeLogView() }
                        
                        HStack {
                            Text("Version:").fontWeight(.light)
                            Spacer()
                            Text("1.5.0").fontWeight(.light)
                        }
                        .foregroundColor(colorScheme == .dark
                                            ? Color.white
                                            : Color.black)
                        
                    }
                    
                }
                .navigationBarHidden(true)
            }
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
