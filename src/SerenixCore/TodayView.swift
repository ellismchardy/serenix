import Foundation

/// Everything the Today screen shows for one Day (spec 002). It decides; the shell draws.
public struct TodayView: Equatable, Sendable {
    /// "Today" on today, else the Day's date, e.g. "Sat 31 Oct".
    public let title: String
    /// The date on today, else "Night".
    public let subtitle: String
    /// Where ‹ goes; nil when it's disabled, on the Day of the earliest Night.
    public let earlierDay: Day?
    /// Where › goes; nil when it's disabled, on today.
    public let laterDay: Day?
    /// "No Night yet" on today or "No Night recorded" on an earlier Day; nil when the Day has a
    /// Night. Another Day's Night is never shown in its place.
    public let noNightMessage: String?
    public let loadLabel: String
    public let loadText: String
    public let syncPill: SyncPill

    public init(
        nights: [Night],
        dayLoads: [DayLoad],
        showing day: Day,
        now: Date,
        timeZone: TimeZone,
        sync: SyncStatus
    ) {
        let today = Day(containing: now, in: timeZone)
        let isToday = day == today
        title = isToday ? "Today" : day.text
        subtitle = isToday ? day.text : "Night"

        let earliestNight = nights.map(\.day).min()
        earlierDay = earliestNight.flatMap { $0 < day ? day.adding(days: -1) : nil }
        laterDay = day < today ? day.adding(days: 1) : nil

        let hasNight = nights.contains { $0.day == day }
        noNightMessage = hasNight ? nil : isToday ? "No Night yet" : "No Night recorded"

        loadLabel = isToday ? "Load so far" : "Load"
        let load = dayLoads.first { $0.day == day }?.load
        loadText = load.map(String.init) ?? missingText

        syncPill = SyncPill(sync, timeZone: timeZone)
    }
}

/// How a missing value reads (spec 002, Missing values).
let missingText = "—"
