//
//  UpdateRequiredBanner.swift
//  I Got Gas
//
//  Shown when the selected vehicle is readable but not writable.
//
//  There are two ways to end up here and they have opposite remedies, so they
//  get separate messages rather than one vague warning:
//
//  - `.clientTooOld` — the vehicle was written by a newer build than this one.
//    A vehicle is stamped with the model version that last wrote it, and only
//    its owner can raise that stamp, so an owner who updates brings the people
//    they share with along. The reader updates to fix it.
//
//  - `.ownerTooOld` — a shared vehicle whose owner is still on 2.x. Their app
//    is authoritative for it until they update, so this device can read the
//    vehicle but must not write to it. Nothing the reader can do; telling them
//    to update would be actively wrong.
//
//  Either way the banner exists so that read-only looks like an explanation
//  rather than edits silently failing.
//

import SwiftUI

struct UpdateRequiredBanner: View {
    enum Reason {
        case clientTooOld
        case ownerTooOld
    }

    let reason: Reason

    private var title: String {
        switch reason {
        case .clientTooOld: return "Update Required"
        case .ownerTooOld: return "Read Only"
        }
    }

    private var message: String {
        switch reason {
        case .clientTooOld:
            return "This vehicle was updated on a newer version of I Got Gas. "
                 + "You can view it, but changes won't save until you update."
        case .ownerTooOld:
            return "The owner of this vehicle is on an older version of I Got Gas. "
                 + "You can view it, but changes won't save until they update."
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).bold()
                Text(message)
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
