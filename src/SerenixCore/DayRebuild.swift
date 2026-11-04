import Foundation

/// One Day whose Load is worked out again, and the History Records to read for it (spec 005,
/// When).
public struct DayRebuild: Equatable, Codable, Sendable {
    public let day: Day
    /// The Day's local midnight to the next (23 or 25 hours across a clock change). A record at
    /// `end` belongs to the next Day: read `start..<end`, never `DateInterval.contains`.
    public let records: DateInterval

    public init(day: Day, records: DateInterval) {
        self.day = day
        self.records = records
    }

    /// Whether to work this Day out at `now` (`isWithinRetention`); a Day no longer due keeps the
    /// Load it has.
    public func isDue(at now: Date) -> Bool {
        isWithinRetention(start: records.start, now: now)
    }
}

/// The Days to work out again after a sync stored History Records at `recordTimes`: every Day a
/// record falls on, oldest first, except Days not due at `now` (`DayRebuild.isDue(at:)`).
public func dayRebuilds(after recordTimes: [Date], now: Date, in timeZone: TimeZone)
    -> [DayRebuild]
{
    Set(recordTimes.map { Day(containing: $0, in: timeZone) })
        .sorted()
        .map { DayRebuild(day: $0, records: $0.span(in: timeZone)) }
        .filter { $0.isDue(at: now) }
}

/// The rebuilds to queue for the stored `days` whose values weren't kept (`DayLoad.valuesKept`:
/// stored before HR Zones or Resting HR existed, or dropped since by another build of Serenix)
/// and that are still due at `now` (`DayRebuild.isDue(at:)`), oldest first; any already in
/// `alreadyQueued` are left out. The shell asks on every rebuild pass (spec 007, Days missing
/// their values), so a Day is never queued twice.
public func dayRebuilds(
    missingValuesIn days: [DayLoad],
    alreadyQueued: [DayRebuild],
    now: Date,
    in timeZone: TimeZone
) -> [DayRebuild] {
    Set(days.filter { !$0.valuesKept }.map(\.day))
        .sorted()
        .map { DayRebuild(day: $0, records: $0.span(in: timeZone)) }
        .filter { $0.isDue(at: now) && !alreadyQueued.contains($0) }
}

/// Every Day still due at `now`, oldest first: the Days whose History Records may still be on the
/// phone, for working out Load again after a Profile change (spec 005, Profile changes).
public func dayRebuildsDue(now: Date, in timeZone: TimeZone) -> [DayRebuild] {
    let today = Day(containing: now, in: timeZone)
    let oldest = Day(containing: now.addingTimeInterval(-historyRecordRetention), in: timeZone)
    return (0...max(0, oldest.days(until: today)))
        .map { oldest.adding(days: $0) }
        .map { DayRebuild(day: $0, records: $0.span(in: timeZone)) }
        .filter { $0.isDue(at: now) }
}
