//
//  SDScheduledService.swift
//  I Got Gas
//
//  Created by snow on 10/4/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftData

@Model
class SDScheduledService: Identifiable {
    var id: String = UUID().uuidString

    var name: String = ""
    var fullDescription: String = ""
    var repeating: Bool = false

    // MARK: - Definition
    //
    // These describe the schedule and never move. Next-due is derived from
    // the linked completions instead of being written back here, which is
    // what lets an entry be backfilled without corrupting the schedule.

    /// Interval between services, in whole metres. Zero = not mileage-based.
    var frequencyMeters: Int = 0

    /// Interval between services, in `frequencyTimeInterval` units. Zero = not time-based.
    var frequencyTime: Int = 0
    var frequencyTimeInterval: FrequencyTimeInterval = FrequencyTimeInterval.month

    /// Where the schedule starts counting when nothing has been completed yet.
    var anchorDate: Date = Date()
    var anchorOdometerMeters: Int = 0

    /// Set when a non-repeating schedule has been fulfilled. The row is kept
    /// rather than deleted so it can still anchor history.
    var completedAt: Date?

    /// Suppresses the due state until this date, without touching the schedule.
    var snoozedUntil: Date?

    var deleted: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var car: SDCar?

    /// Maintenance entries that fulfilled this schedule.
    @Relationship(deleteRule: .nullify, inverse: \SDService.scheduledService)
    var completions: [SDService]? = []

    init() { }

    // MARK: - Typed accessors

    var frequencyDistance: Distance {
        get { Distance(meters: frequencyMeters) }
        set { frequencyMeters = newValue.meters }
    }

    var anchorOdometer: Distance {
        get { Distance(meters: anchorOdometerMeters) }
        set { anchorOdometerMeters = newValue.meters }
    }

    var isMileageBased: Bool { frequencyMeters > 0 }
    var isTimeBased: Bool { frequencyTime > 0 }

    /// True once a non-repeating schedule has been fulfilled.
    var isCompleted: Bool { completedAt != nil }

    // MARK: - Derived next-due
    //
    // Everything below is a pure function of the completions. Add, delete, or
    // re-date a completion and the answer simply recomputes — there is no
    // cursor to get out of step.

    var liveCompletions: [SDService] {
        (completions ?? []).filter { !$0.deleted }
    }

    /// The most recent fulfilment, by date then odometer.
    var lastCompletion: SDService? {
        liveCompletions.max {
            ($0.date, $0.odometerMeters) < ($1.date, $1.odometerMeters)
        }
    }

    /// Nil when the schedule isn't time-based.
    var nextDueDate: Date? {
        guard isTimeBased else { return nil }
        let from = lastCompletion?.date ?? anchorDate
        return Calendar.current.date(
            byAdding: frequencyTimeInterval.calendarComponent,
            value: frequencyTime,
            to: from
        )
    }

    /// Nil when the schedule isn't mileage-based.
    var nextDueOdometer: Distance? {
        guard isMileageBased else { return nil }
        let from = lastCompletion?.odometerMeters ?? anchorOdometerMeters
        return Distance(meters: from + frequencyMeters)
    }

    /// Distance still to go. Negative means overdue.
    var distanceRemaining: Distance? {
        guard let due = nextDueOdometer, let current = car?.odometer else { return nil }
        return Distance(meters: due.meters - current.meters)
    }

    /// Whichever comes first — mileage or time. A schedule with both set goes
    /// due as soon as either threshold is crossed.
    var isDue: Bool {
        guard !isCompleted else { return false }
        if let snoozed = snoozedUntil, Date() < snoozed { return false }
        if let due = nextDueDate, Date() >= due { return true }
        if let due = nextDueOdometer, let current = car?.odometer, current.meters >= due.meters {
            return true
        }
        return false
    }

    @available(*, deprecated, renamed: "isDue")
    var pastDue: Bool { isDue }

    func touch() {
        updatedAt = Date()
    }

    /// Records a maintenance entry as fulfilling this schedule.
    /// Cross-car links are not allowed.
    func canBeFulfilled(by service: SDService) -> Bool {
        guard let scheduleCar = car, let serviceCar = service.car else { return false }
        return scheduleCar.id == serviceCar.id
    }
}

enum UrgencyLevel {
    case low
    case medium
    case high
}

enum FrequencyTimeInterval: CaseIterable, Codable {
    case day
    case month
    case year

    init(rawValue: String) {
        switch rawValue {
        case "Days": self = .day
        case "Months": self = .month
        case "Years": self = .year
        default: self = .month
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return Calendar.Component.day
        case .month: return Calendar.Component.month
        case .year: return Calendar.Component.year
        }
    }

    var description: String {
        switch self {
        case .day: return "Days"
        case .month: return "Months"
        case .year: return "Years"
        }
    }

    var rawValue: String { description }
}
