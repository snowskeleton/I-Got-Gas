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
    //when done testing add placement, take out from here
    var topOrBottomList: [Bool]
    @State private var selectTopOrBottom: Int
    //to here
    
    init() {
        formatList = ["%.3f", "%.2f"]
        let priceFormat = UserDefaults.standard.string(forKey: "priceFormat")
        if priceFormat == nil {
            _formatSelection = State<Int>(initialValue: 0)
        } else {
            _formatSelection = State<Int>(initialValue: formatList.firstIndex(of: priceFormat!)!)
        }


        //when done testing add placement, take out from here
        topOrBottomList = [true, false]
        let adOnTop = UserDefaults.standard.bool(forKey: "isAdOnTop")
        if adOnTop == true {
            _selectTopOrBottom = State<Int>(initialValue: 0)
        } else {
            _selectTopOrBottom = State<Int>(initialValue: 1)
        }
        //to here
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Decimal Length")) {
                        
                        Picker(selection: $formatSelection,
                               label: Text("Fuel Price Decimal Length")) {
                            ForEach(0 ..< formatList.count) { Text(self.formatList[$0]) }
                        }.pickerStyle(SegmentedPickerStyle())
                        .onChange(of: formatSelection) { _ in
                            UserDefaults.standard.set(formatList[formatSelection],
                                                      forKey: "priceFormat")
                        }
                        //when done testing add placement, take out from here
                        Picker(selection: $selectTopOrBottom,
                               label: Text("Where is your ad?")) {
                            Text("Ad on Top").tag(0)
                            Text("Ad on Bottom").tag(1)
                            }
                        }.pickerStyle(SegmentedPickerStyle())
                        .onChange(of: selectTopOrBottom) { _ in
                            if selectTopOrBottom == 0 {
                                UserDefaults.standard.set(true,
                                                          forKey: "isAdOnTop")
                            } else {
                                UserDefaults.standard.set(false,
                                                          forKey: "isAdOnTop")
                            }
                            fatalError()
                        }
                        // to here
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
                    
                }
                
                
            }
            .navigationBarTitle(Text("Options"))
        }
    }

