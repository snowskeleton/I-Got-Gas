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

    /// An optional second action reached by pressing and holding. Lists that
    /// don't supply one get exactly the button they had before.
    var longPressAction: LongPressAction?

    struct LongPressAction {
        let title: String
        let systemImage: String
        let perform: () -> Void
    }

    private var plus: some View {
        Image(systemName: "plus")
            .font(.title2.weight(.semibold))
            .frame(width: 42, height: 42)
    }

    var body: some View {
        Group {
            if let longPressAction {
                // A Menu with a primary action is the platform's own
                // press-and-hold affordance. Hanging a LongPressGesture off a
                // Button instead fires *both* handlers on release, which would
                // open the sheet twice.
                Menu {
                    Button {
                        longPressAction.perform()
                    } label: {
                        Label(longPressAction.title, systemImage: longPressAction.systemImage)
                    }
                } label: {
                    plus
                } primaryAction: {
                    action()
                }
            } else {
                Button(action: action) { plus }
            }
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
    func floatingAddButton(
        action: @escaping () -> Void,
        longPressAction: FloatingAddButton.LongPressAction? = nil
    ) -> some View {
        // The extra content margin lets the last row scroll clear of the
        // button instead of coming to rest underneath it.
        contentMargins(.bottom, 76, for: .scrollContent)
            .overlay(alignment: .bottomTrailing) {
                FloatingAddButton(action: action, longPressAction: longPressAction)
            }
    }
}
