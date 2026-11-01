import Foundation

/// One local calendar Day, midnight to midnight (GLOSSARY).
public struct Day: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let dayOfMonth: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.dayOfMonth = day
    }

    /// The Day `time` falls on in `timeZone`.
    public init(containing time: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: time)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.dayOfMonth) < (rhs.year, rhs.month, rhs.dayOfMonth)
    }

    /// The Day `count` Days later (earlier when negative).
    func adding(days count: Int) -> Day {
        let calendar = Self.utcCalendar
        let midnight = calendar.date(
            from: DateComponents(year: year, month: month, day: dayOfMonth)
        )!
        return Day(containing: calendar.date(byAdding: .day, value: count, to: midnight)!, in: .gmt)
    }

    /// How the Day reads in the Today screen's header, e.g. "Sun 1 Nov".
    var text: String {
        let calendar = Self.utcCalendar
        let midnight = calendar.date(
            from: DateComponents(year: year, month: month, day: dayOfMonth)
        )!
        let weekday = calendar.component(.weekday, from: midnight)
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
