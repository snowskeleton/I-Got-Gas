//
//  UpdateRequiredBanner.swift
//  I Got Gas
//
//  Shown when this build is too old to write to the selected vehicle.
//
//  A vehicle is stamped with the model version that last wrote it, and only
//  its owner can raise that stamp. So someone who never updates keeps working
//  on their own vehicles indefinitely; an owner who does update brings the
//  people they share with along. The banner exists so that being brought along
//  looks like a prompt rather than edits silently failing.
//

import SwiftUI

struct UpdateRequiredBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Update Required")
                    .font(.subheadline).bold()
                Text("This vehicle was updated on a newer version of I Got Gas. You can view it, but changes won't save until you update.")
                    .font(.caption)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange)
    }
}
