//MIT License
//
//Copyright (c) 2020 youjinp
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.
//
//  adaptToKeyboard.swift
//  SwiftUIKitExampleApp
//
//  Created by Youjin Phea on 17/06/20.
//  Copyright © 2020 youjinp. All rights reserved.
//

import SwiftUI
import Combine

public extension View {
    func adaptToKeyboard() -> some View {
        modifier(AdaptToSoftwareKeyboard())
    }
}

// See https://gist.github.com/scottmatthewman/722987c9ad40f852e2b6a185f390f88d
public struct AdaptToSoftwareKeyboard: ViewModifier {
    @State var currentHeight: CGFloat = 0
    
    public func body(content: Content) -> some View {
        content
            .padding(.bottom, currentHeight)
            .edgesIgnoringSafeArea(.bottom)
            .animation(.spring())
            .onAppear(perform: subscribeToKeyboardEvents)
    }
    
    private func subscribeToKeyboardEvents() {
        NotificationCenter.Publisher(
            center: NotificationCenter.default,
            name: UIResponder.keyboardWillShowNotification
        )
            .compactMap { $0.userInfo?["UIKeyboardFrameEndUserInfoKey"] as? CGRect }
            .map { $0.height }
            .subscribe(Subscribers.Assign(object: self, keyPath: \.currentHeight))
        
        /* use these to figure out duration and animation curve (.25 & 7)
        NotificationCenter.Publisher(
            center: NotificationCenter.default,
            name: UIResponder.keyboardWillShowNotification
        )
            .compactMap { $0.userInfo?["UIKeyboardAnimationDurationUserInfoKey"] as? NSNumber }
            .subscribe(Subscribers.Sink(receiveCompletion: {_ in }, receiveValue: {print("Received: \($0)")}))
        
        
        NotificationCenter.Publisher(
            center: NotificationCenter.default,
            name: UIResponder.keyboardWillShowNotification
        )
            .compactMap { $0.userInfo?["UIKeyboardAnimationCurveUserInfoKey"] }
            .subscribe(Subscribers.Sink(receiveCompletion: {_ in }, receiveValue: {print("Received: \($0)")}))
        */
        
        NotificationCenter.Publisher(
            center: NotificationCenter.default,
            name: UIResponder.keyboardWillHideNotification
        )
            .compactMap { _ in CGFloat.zero }
            .subscribe(Subscribers.Assign(object: self, keyPath: \.currentHeight))
    }
}
