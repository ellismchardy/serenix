import Foundation

/// How much Time Asleep the user needs on a Night, and the Sleep Debt behind it (spec 009). Every
/// constant is an assumption from issue #34 and docs/research/sleep-need-and-debt.md: tune with
/// real Nights.
struct SleepNeed: Equatable, Sendable {
    /// Usual Need for an adult, seconds (spec 009: 8 h; Garmin's figure under 65, within the
    /// NSF's 7–9 h).
    static let adultUsualNeed: TimeInterval = 8 * 60 * 60
    /// Usual Need from `olderAge`, seconds (spec 009: 7.5 h; Garmin's figure over 65, within the
    /// NSF's 7–8 h for 65 and over).
    static let olderUsualNeed: TimeInterval = 7.5 * 60 * 60
    /// The age in years from which Usual Need is `olderUsualNeed` (spec 009: 65).
    static let olderAge = 65
    /// How many Days before the Night's own Sleep Debt looks back (spec 009: the Nights dated
    /// D − 7 to D − 1).
    static let debtWindowDays = 7
    /// The share of Sleep Debt added to Usual Need (spec 009: ¼; Kitamura 2016, 1 h of shortfall
    /// took about 4 days to clear). Unitless.
    static let debtShare = 0.25
    /// The most Sleep Need may exceed Usual Need, seconds (spec 009: 1 h, holding an 8 h Usual
    /// Need at the NSF's 9 h ceiling).
    static let maxExtraNeed: TimeInterval = 60 * 60

    /// The Time Asleep the user needs with no Sleep Debt to repay, seconds.
    let usualNeed: TimeInterval
    /// The net shortfall against Usual Need over the Nights before, seconds.
    let sleepDebt: TimeInterval
    /// Usual Need plus part of Sleep Debt, seconds.
    let sleepNeed: TimeInterval
    /// How many Nights counted toward Sleep Debt.
    let nightsCounted: Int

    /// The Sleep Need of the Night dated `day`, from the Nights before it. Age is `day`'s year
    /// minus `birthYear`; with no birth year, Usual Need is the adult one.
    /// The Days of the week before the Night dated `day`, D − 7 to D − 1, the Night itself left
    /// out: Sleep Debt's look-back (spec 009), also Sleep Consistency's (spec 010).
    static func window(before day: Day) -> ClosedRange<Day> {
        day.adding(days: -debtWindowDays)...day.adding(days: -1)
    }

    init(for day: Day, among nights: [Night], birthYear: Int?) {
        let isOlder = birthYear.map { day.year - $0 >= Self.olderAge } ?? false
        let usualNeed = isOlder ? Self.olderUsualNeed : Self.adultUsualNeed
        self.usualNeed = usualNeed
        // The Nights in the week before, the Night itself left out. One with no plausible Time
        // Asleep is skipped, as if the Strap wasn't worn.
        let window = Self.window(before: day)
        let timesAsleep =
            nights
            .filter { window.contains($0.day) }
            .compactMap(\.plausibleTimeAsleep)
        // Long Nights pay short ones back; no sleep is banked ahead.
        let shortfall = timesAsleep.reduce(0) { $0 + usualNeed - $1 }
        sleepDebt = max(shortfall, 0)
        sleepNeed = usualNeed + min(Self.debtShare * sleepDebt, Self.maxExtraNeed)
        nightsCounted = timesAsleep.count
    }
}
