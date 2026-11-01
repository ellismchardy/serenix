import Foundation

/// One date whose Night is worked out again after a sync, and the History Records to read for it.
public struct NightRebuild: Equatable, Sendable {
    public let day: Day
    /// The two night windows that can give a Night dated `day`: local noon the Day before `day`
    /// to local noon the Day after.
    public let records: DateInterval

    public init(day: Day, records: DateInterval) {
        self.day = day
        self.records = records
    }

    /// Whether to work this date out at `now`: not once its History Records start more than
    /// `historyRecordRetention` before `now` (they may be pruned, and such a Night stays as it
    /// is), nor while they start after `now` (a Strap clock that's wrong). Checked again when a
    /// waiting rebuild is resumed.
    public func isDue(at now: Date) -> Bool {
        records.start >= now.addingTimeInterval(-historyRecordRetention) && records.start <= now
    }
}

/// The dates to work out again after a sync stored History Records at `recordTimes`, oldest
/// first (spec 003, When). A night window from noon on Day k−1 to noon on Day k gives a Night
/// dated k−1 or k, so both dates of every window a record falls in are rebuilt, except dates not
/// due at `now` (`NightRebuild.isDue(at:)`).
public func nightRebuilds(after recordTimes: [Date], now: Date, in timeZone: TimeZone)
    -> [NightRebuild]
{
    var windows: [DateInterval] = []
    // Sorted, so one comparison skips every other record in the window just found.
    for time in recordTimes.sorted() where windows.last.map({ !$0.contains(time) }) ?? true {
        windows.append(nightWindow(containing: time, in: timeZone))
    }
    var rebuilds: [NightRebuild] = []
    for window in windows {
        let before = nightWindow(containing: window.start.addingTimeInterval(-1), in: timeZone)
        let after = nightWindow(containing: window.end, in: timeZone)
        let candidates = [
            NightRebuild(
                day: Day(containing: window.start, in: timeZone),
                records: DateInterval(start: before.start, end: window.end)
            ),
            NightRebuild(
                day: Day(containing: window.end, in: timeZone),
                records: DateInterval(start: window.start, end: after.end)
            ),
        ]
        for rebuild in candidates
        where rebuild.isDue(at: now) && !rebuilds.contains(where: { $0.day == rebuild.day }) {
            rebuilds.append(rebuild)
        }
    }
    return rebuilds
}

/// Seconds History Records are kept on the phone before they're pruned: 30 days
/// (docs/architecture.md, Data model).
private let historyRecordRetention: TimeInterval = 30 * 24 * 60 * 60
