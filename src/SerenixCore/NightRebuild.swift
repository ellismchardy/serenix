import Foundation

/// One date whose Night is worked out again after a sync, and the History Records to read for it.
public struct NightRebuild: Equatable, Codable, Sendable {
    public let day: Day
    /// The two night windows that can give a Night dated `day`: local noon the Day before `day`
    /// to local noon the Day after.
    public let records: DateInterval

    public init(day: Day, records: DateInterval) {
        self.day = day
        self.records = records
    }

    /// The rebuild of the Night dated `day`: its two night windows, local noon the Day before
    /// to local noon the Day after, in `timeZone`.
    init(day: Day, in timeZone: TimeZone) {
        self.init(
            day: day,
            records: DateInterval(
                start: day.adding(days: -1).midday(in: timeZone),
                end: day.adding(days: 1).midday(in: timeZone)
            )
        )
    }

    /// Whether to work this date out at `now`: not once its History Records start more than
    /// `historyRecordRetention` before `now` (they may be pruned, and such a Night stays as it
    /// is), nor while they start after `now` (a Strap clock that's wrong). Checked again when a
    /// waiting rebuild is resumed.
    public func isDue(at now: Date) -> Bool {
        isWithinRetention(start: records.start, now: now)
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
        let candidates = [
            NightRebuild(day: Day(containing: window.start, in: timeZone), in: timeZone),
            NightRebuild(day: Day(containing: window.end, in: timeZone), in: timeZone),
        ]
        for rebuild in candidates
        where rebuild.isDue(at: now) && !rebuilds.contains(where: { $0.day == rebuild.day }) {
            rebuilds.append(rebuild)
        }
    }
    return rebuilds
}

/// The dates whose stored Night has no Heart Rate Trace (built before spec 011) and whose History
/// Records are still due at `now` (`NightRebuild.isDue(at:)`), oldest first, each reading the
/// same two night windows a sync's rebuild would. The shell queues them once (spec 011).
public func traceRebuilds(for nights: [Night], now: Date, in timeZone: TimeZone)
    -> [NightRebuild]
{
    nights
        .filter { $0.heartRateTrace == nil }
        .map(\.day)
        .sorted()
        .map { NightRebuild(day: $0, in: timeZone) }
        .filter { $0.isDue(at: now) }
}
