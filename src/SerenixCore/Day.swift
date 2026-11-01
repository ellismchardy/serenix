import Foundation

/// One local calendar Day, midnight to midnight (GLOSSARY).
public struct Day: Hashable, Comparable, Sendable {
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

    /// How the Day reads in the Today screen's title, e.g. "Sun 1 Nov".
    var text: String {
        let calendar = Self.utcCalendar
        let midnight = calendar.date(
            from: DateComponents(year: year, month: month, day: dayOfMonth)
        )!
        let weekday = calendar.component(.weekday, from: midnight)
        // The init keeps month and weekday in range; the guards make that hold here too.
        guard Self.weekdayNames.indices.contains(weekday - 1),
            Self.monthNames.indices.contains(month - 1)
        else { return missingText }
        return "\(Self.weekdayNames[weekday - 1]) \(dayOfMonth) \(Self.monthNames[month - 1])"
    }

    /// Day arithmetic needs no time zone: a Day is only a date.
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    private static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]
}

/// A Day's Load, missing until the Load spec computes it.
public struct DayLoad: Equatable, Sendable {
    public var day: Day
    public var load: Int?

    public init(day: Day, load: Int?) {
        self.day = day
        self.load = load
    }
}
