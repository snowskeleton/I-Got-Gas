//
//  IGGSchemaV3.swift
//  I Got Gas
//
//  The current shape. Unlike V2 this points at the live model types rather
//  than frozen copies — V3 is what the app compiles against, so it moves
//  with the app until a V4 exists to freeze it.
//

import Foundation
import SwiftData

enum IGGSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SDCar.self,
            SDService.self,
            SDScheduledService.self,
            SDCarSettings.self,
            SDUserPreferences.self,
            SDPart.self,
            SDCatalogPart.self,
            SDAttachment.self,
            // Local-only: the outbox never leaves the device.
            SDPendingOp.self,
        ]
    }
}
