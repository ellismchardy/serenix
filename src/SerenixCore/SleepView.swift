import Foundation

/// Everything the Sleep tab shows for the Day shown (spec 011), worked out from the stored Nights
/// each time, never stored. The shell draws it.
public struct SleepView: Equatable, Sendable {
    /// The same week strip as the Today tab's for the same Day (spec 002, Week strip).
    public let weekStrip: WeekStrip
    /// About the Night dated the Day shown; nil when that Day has no Night.
    public let lastNight: SleepLastNight?
    /// "No Night yet" for today, "No Night recorded" for an earlier Day, in place of Last night;
    /// nil when there's a Night (spec 002, as on the Today tab).
    public let noNightMessage: String?

    /// `birthYear` is the Profile's, for Sleep Need (spec 009).
    public init(
        nights: [Night],
        showing day: Day,
        now: Date,
        timeZone: TimeZone,
        birthYear: Int? = nil
    ) {
        let today = Day(containing: now, in: timeZone)
        let isToday = day == today
        weekStrip = WeekStrip(
            showing: day,
            today: today,
            earliest: WeekStrip.earliest(among: nights, today: today),
            nights: Set(nights.map(\.day))
        )
        let night = nights.first { $0.day == day }
        lastNight = night.map {
            SleepLastNight($0, title: isToday ? "Last night" : day.text, timeZone: timeZone)
        }
        noNightMessage = night != nil ? nil : TodayView.noNightMessage(isToday: isToday)
    }
}

/// The Sleep tab's Last night section, about one Night (spec 011, Last night).
public struct SleepLastNight: Equatable, Sendable {
    /// "Last night" when the Day shown is today, else the Day, e.g. "Sun 1 Nov".
    public let title: String
    /// e.g. "7h 45m asleep"; "— asleep" without a Time Asleep.
    public let timeAsleepText: String
    /// e.g. "In bed 22:50 · Up 07:10", from Time in Bed; nil without it.
    public let inBedText: String?

    init(_ night: Night, title: String, timeZone: TimeZone) {
        self.title = title
        timeAsleepText = "\(night.plausibleTimeAsleep.map(durationText) ?? missingText) asleep"
        inBedText = night.timeInBedStart.flatMap { start in
            night.timeInBedEnd.map { end in
                "In bed \(clockText(start, in: timeZone)) \u{00B7} Up \(clockText(end, in: timeZone))"
            }
        }
    }
}
