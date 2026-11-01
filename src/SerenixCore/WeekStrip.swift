import Foundation

/// The week strip under the Today screen's top bar (spec 002, Week strip): seven Days holding the
/// Day shown, counted back from today in sevens, with where ‹ and › go.
public struct WeekStrip: Equatable, Sendable {
    /// The month and year of the strip's last Day, e.g. "November 2026".
    public let title: String
    /// Seven Days, oldest first.
    public let days: [WeekStripDay]
    /// Where ‹ goes: a week earlier, never before the earliest Night's Day; nil when disabled.
    public let earlierDay: Day?
    /// Where › goes: a week later, never after today; nil on today.
    public let laterDay: Day?

    /// How many Days the strip holds and ‹ › move by.
    static let length = 7

    /// `earliest` is the earliest Night's Day, or today with no Nights.
    init(showing shown: Day, today: Day, earliest: Day, nights: Set<Day>) {
        // Weeks count back from today: page 0 ends on today, page 1 on the Day a week before.
        let page = max(0, shown.days(until: today)) / Self.length
        let last = today.adding(days: -Self.length * page)
        days = (0..<Self.length).reversed().map { back in
            let day = last.adding(days: -back)
            return WeekStripDay(
                day: day,
                letter: day.weekdayLetter,
                number: day.dayOfMonth,
                isShown: day == shown,
                hasNight: nights.contains(day),
                isInRange: day >= earliest
            )
        }
        title = last.monthTitle
        earlierDay = shown > earliest ? max(shown.adding(days: -Self.length), earliest) : nil
        laterDay = shown < today ? min(shown.adding(days: Self.length), today) : nil
    }
}

/// One Day in the week strip.
public struct WeekStripDay: Equatable, Sendable {
    public let day: Day
    /// Its weekday's letter, e.g. "M".
    public let letter: String
    public let number: Int
    public let isShown: Bool
    /// False for a Day without a Night, which the strip dims.
    public let hasNight: Bool
    /// False for a Day before the earliest Night's Day, which can't be shown.
    public let isInRange: Bool
}
