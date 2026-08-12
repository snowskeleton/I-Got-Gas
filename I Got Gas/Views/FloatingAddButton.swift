//
//  FloatingAddButton.swift
//  I Got Gas
//
//  Created by snow on 8/12/26.
//  Copyright © 2026 Blizzard Skeleton. All rights reserved.
//
//  The circular "add" button that floats over the bottom-trailing corner of
//  the Fuel, Maintenance and Schedule lists, where the toolbar plus used to be.
//

import SwiftUI

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .shadow(radius: 6, y: 3)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .accessibilityLabel("Add")
    }
}

extension View {
    /// Overlays a floating add button without letting it eat taps on the rest
    /// of the list.
    func floatingAddButton(action: @escaping () -> Void) -> some View {
        // The extra content margin lets the last row scroll clear of the
        // button instead of coming to rest underneath it.
        contentMargins(.bottom, 76, for: .scrollContent)
            .overlay(alignment: .bottomTrailing) {
                FloatingAddButton(action: action)
            }
    }
}
