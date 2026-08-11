//
//  ScheduleLinkMatcher.swift
//  I Got Gas
//
//  Guesses which historical maintenance entries fulfilled which schedules,
//  by name, so upgrading users get service history rather than an empty one.
//
//  Deliberately conservative: it links only when exactly one schedule on the
//  same car matches, and it never overwrites a link the user made. Everything
//  it does is marked `linkedManually = false` so the review screen can show
//  the user what was guessed and they can undo it in bulk.
//

import Foundation
import SwiftData

enum ScheduleLinkMatcher {

    /// Normalizes a name for comparison: case- and whitespace-insensitive.
    static func matchKey(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Links unlinked maintenance entries to schedules on the same car whose
    /// names match exactly one candidate. Returns how many links it made.
    @discardableResult
    static func linkExistingHistory(in context: ModelContext) throws -> Int {
        let cars = try context.fetch(FetchDescriptor<SDCar>())
        var linkCount = 0

        for car in cars {
            let schedules = (car.scheduledServices ?? []).filter { !$0.deleted }
            guard !schedules.isEmpty else { continue }

            // Group by name so ambiguous names can be skipped wholesale.
            var byName: [String: [SDScheduledService]] = [:]
            for schedule in schedules {
                let key = matchKey(for: schedule.name)
                guard !key.isEmpty else { continue }
                byName[key, default: []].append(schedule)
            }

            let candidates = byName.filter { $0.value.count == 1 }

            for service in (car.services ?? []) {
                guard !service.deleted,
                      service.kind == .maintenance,
                      service.scheduledService == nil else { continue }

                let key = matchKey(for: service.name)
                guard !key.isEmpty, let match = candidates[key]?.first else { continue }

                service.scheduledService = match
                service.linkedManually = false
                linkCount += 1
            }
        }

        return linkCount
    }

    /// Everything the matcher guessed, for the one-time review screen.
    static func autoLinkedEntries(in context: ModelContext) throws -> [SDService] {
        let descriptor = FetchDescriptor<SDService>(
            predicate: #Predicate { $0.deleted == false && $0.linkedManually == false },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor).filter { $0.scheduledService != nil }
    }
}
