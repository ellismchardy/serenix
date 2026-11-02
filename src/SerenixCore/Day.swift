import Foundation

/// One local calendar Day, midnight to midnight (GLOSSARY).
public struct Day: Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let month: Int
    public let dayOfMonth: Int

    /// A date outside the calendar rolls over the way the calendar does: month 13 of 2026 is
    /// January 2027, so a Day is always a real date and never crashes when shown.
    public init(year: Int, month: Int, day: Int) {
        let calendar = Self.utcCalendar
        let parts = calendar.date(from: DateComponents(year: year, month: month, day: day))
            .map { calendar.dateComponents([.year, .month, .day], from: $0) }
        self.year = parts?.year ?? year
        self.month = parts?.month ?? month
        self.dayOfMonth = parts?.day ?? day
    }

    /// The Day `time` falls on in `timeZone`.
    public init(containing time: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: time)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.dayOfMonth) < (rhs.year, rhs.month, rhs.dayOfMonth)
    }

    /// Midday on this Day in `timeZone`, on the Gregorian calendar whatever the phone's own
    /// calendar is, so no daylight-saving change can move it onto a neighbouring Day.
    func midday(in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: year, month: month, day: dayOfMonth, hour: 12)
        // Only a Day far outside any real date has none; it falls back to the start of time
        // rather than crashing (docs/architecture.md, Errors).
        return calendar.date(from: components) ?? .distantPast
    }

    /// The Day's local midnight in `timeZone` up to the next (23 or 25 hours across a clock
    /// change), on the Gregorian calendar whatever the phone's own calendar is. A time at `end`
    /// belongs to the next Day, so callers must not use `DateInterval.contains`, which includes it.
    func span(in timeZone: TimeZone) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: midday(in: timeZone))
        let end = calendar.startOfDay(for: adding(days: 1).midday(in: timeZone))
        return DateInterval(start: start, end: end)
    }

    /// The Day `count` Days later (earlier when negative).
    /// A Day is always a real date (see `init`), so the fallback to `self` never happens in practice.
    func adding(days count: Int) -> Day {
        let calendar = Self.utcCalendar
        guard let midnight = calendar.date(from: components),
            let moved = calendar.date(byAdding: .day, value: count, to: midnight)
        else { return self }
        return Day(containing: moved, in: .gmt)
    }

    /// How many Days from this Day to `other`; negative when `other` is earlier.
    func days(until other: Day) -> Int {
        let calendar = Self.utcCalendar
        guard let from = calendar.date(from: components),
            let to = calendar.date(from: other.components)
        else { return 0 }
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// The weekday's letter for the week strip, e.g. "M".
    var weekdayLetter: String {
        weekdayIndex.map { Self.weekdayLetters[$0] } ?? missingText
    }

    /// The month and year, e.g. "November 2026".
    var monthTitle: String {
        Self.monthTitles.indices.contains(month - 1)
            ? "\(Self.monthTitles[month - 1]) \(year)" : missingText
    }

    private var components: DateComponents {
        DateComponents(year: year, month: month, day: dayOfMonth)
    }

    /// How the Day reads, e.g. "Sun 1 Nov".
    var text: String {
        guard let weekday = weekdayIndex, Self.monthNames.indices.contains(month - 1) else {
            return missingText
        }
        return "\(Self.weekdayNames[weekday]) \(dayOfMonth) \(Self.monthNames[month - 1])"
    }

    /// The weekday, 0 for Sunday to 6 for Saturday; nil for a Day with no real date.
    private var weekdayIndex: Int? {
        guard let midnight = Self.utcCalendar.date(from: components) else { return nil }
        let index = Self.utcCalendar.component(.weekday, from: midnight) - 1
        return Self.weekdayNames.indices.contains(index) ? index : nil
    }

    /// Day arithmetic needs no time zone: a Day is only a date.
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    private static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let weekdayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private static let monthTitles = [
        "January", "February", "March", "April", "May", "June", "July", "August", "September",
        "October", "November", "December",
    ]
    private static let monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]
}

/// Why a Day's Load is missing (spec 005, Missing vs 0).
public enum LoadMissing: String, Codable, Sendable {
    /// The Day has no History Records.
    case noRecords
    /// No Max HR was entered and there's no birth year to estimate one from.
    case noMaxHR
    /// Max HR is at or below Resting HR, so there's no heart-rate reserve.
    case maxHRNotAboveRestingHR
}

/// A Day's Load (spec 005): 0–100, or missing with why.
public struct DayLoad: Equatable, Codable, Sendable {
    public var day: Day
    public var load: Int?
    /// Nil when `load` is there.
    public var missingReason: LoadMissing?
    /// The Day's HR Zones and the Max HR used (spec 006). Nil with no History Records or no Max
    /// HR, and for a Day worked out before spec 006 whose records are gone. There even when Load
    /// is missing because Max HR isn't above Resting HR: HR Zones need only Max HR.
    public var heartRate: DayHeartRate?

    public init(
        day: Day,
        load: Int?,
        missingReason: LoadMissing? = nil,
        heartRate: DayHeartRate? = nil
    ) {
        self.day = day
        self.load = load
        self.missingReason = missingReason
        self.heartRate = heartRate
    }
}
