//
//  SwiftDataManager.swift
//  I Got Gas
//
//  Created by snow on 8/24/24.
//

import Foundation
import SwiftData

public class SwiftDataManager {

    public static let shared = SwiftDataManager()

    /// Set when the store could not be opened. The UI surfaces this instead of
    /// the app dying on launch — a failed migration must never brick the app,
    /// because the user's data is still on disk and still recoverable.
    public private(set) var loadFailure: Error?

    public let container: ModelContainer

    private init() {
        let schema = Schema(IGGSchemaV3.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: IGGMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            NSLog("SwiftData: failed to open persistent store: \(error)")
            loadFailure = error

            // Fall back to an in-memory store so the app can launch and show
            // the user what went wrong. Nothing on disk is touched or deleted.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Could not create even an in-memory ModelContainer: \(error)")
            }
        }
    }
}
