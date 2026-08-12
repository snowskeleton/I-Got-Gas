//
//  NotificationReconciler.swift
//  I Got Gas
//
//  Keeps iOS's pending notification set in step with the schedules.
//
//  The old approach scheduled a notification as a side effect of saving an
//  expense and stored the resulting request UUID on the model. It never
//  cancelled the request it replaced, so every reschedule leaked a duplicate,
//  and a synced device regenerated the UUID without scheduling anything.
//
//  This reconciles instead: work out what *should* be pending, diff it against
//  what *is* pending, and apply only the difference. Identifiers are derived
//  from the schedule ID, so there's no state to store and no state to drift.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
enum NotificationReconciler {

    private static let prefix = "sched-"

    /// Deterministic identifier for a schedule's reminder.
    private static func identifier(for schedule: SDScheduledService) -> String {
        prefix + schedule.id
    }

    /// What the pending set should look like right now.
    private struct Desired {
        let identifier: String
        let title: String
        let body: String
        let fireDate: Date
    }

    /// Recomputes and applies. Safe to call as often as you like — it's a
    /// diff, so a no-op costs one query and no notification churn.
    static func reconcile(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
            return
        }

        let desired = (try? desiredNotifications(context: context)) ?? []
        // `SDScheduledService.id` isn't enforced unique by the store, so two
        // rows can carry the same ID and collide here. One reminder per ID is
        // all iOS can hold anyway; keep the soonest so nothing is pushed out.
        let desiredByID = Dictionary(
            desired.map { ($0.identifier, $0) },
            uniquingKeysWith: { $0.fireDate <= $1.fireDate ? $0 : $1 }
        )

        let pending = await center.pendingNotificationRequests()
        let ours = pending.filter { $0.identifier.hasPrefix(prefix) }
        let pendingByID = Dictionary(uniqueKeysWithValues: ours.map { ($0.identifier, $0) })

        // Cancel anything that shouldn't be there, or whose fire date moved.
        var stale: [String] = []
        for request in ours {
            guard let want = desiredByID[request.identifier] else {
                stale.append(request.identifier)
                continue
            }
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let scheduled = trigger.nextTriggerDate(),
               abs(scheduled.timeIntervalSince(want.fireDate)) > 60 {
                stale.append(request.identifier)
            }
        }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        // Add anything missing.
        for want in desiredByID.values {
            let alreadyPending = pendingByID[want.identifier] != nil
                && !stale.contains(want.identifier)
            guard !alreadyPending else { continue }

            let content = UNMutableNotificationContent()
            content.title = want.title
            content.body = want.body
            content.sound = .default

            var components = Calendar.current.dateComponents(
                [.year, .month, .day], from: want.fireDate
            )
            components.hour = 8
            components.minute = 15

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: want.identifier, content: content, trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// Cancels everything this reconciler owns. Used on sign-out.
    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    // MARK: - What should be pending

    private static func desiredNotifications(context: ModelContext) throws -> [Desired] {
        let descriptor = FetchDescriptor<SDScheduledService>(
            predicate: #Predicate { $0.deleted == false && $0.completedAt == nil }
        )
        let schedules = try context.fetch(descriptor)

        return schedules.compactMap { schedule -> Desired? in
            guard let car = schedule.car, !car.deleted, !car.archived else { return nil }

            // Only time-based schedules can be turned into a calendar trigger.
            // Mileage-based ones can't be predicted — they surface in the app
            // when the odometer passes them.
            guard var fireDate = schedule.nextDueDate else { return nil }

            if let snoozed = schedule.snoozedUntil, snoozed > fireDate {
                fireDate = snoozed
            }

            // A schedule that came due in the past — from a backfilled entry,
            // say — fires as soon as iOS will allow, rather than being dropped.
            if fireDate < Date() {
                fireDate = Date().addingTimeInterval(60)
            }

            return Desired(
                identifier: identifier(for: schedule),
                title: schedule.name.isEmpty ? car.visualName : schedule.name,
                body: "Your \(car.visualName) \(schedule.name) is due.",
                fireDate: fireDate
            )
        }
    }
}
