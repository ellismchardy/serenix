import Foundation

/// How much Time Asleep the user needs on a Night, and the Sleep Debt behind it (spec 009). Every
/// constant is an assumption from issue #34 and docs/research/sleep-need-and-debt.md: tune with
/// real Nights.
struct SleepNeed: Equatable, Sendable {
    /// Usual Need for an adult, seconds (spec 009: 8 h; Garmin's figure under 65, within the
    /// NSF's 7–9 h).
    static let adultUsualNeed: TimeInterval = 8 * 60 * 60

    /// The Time Asleep the user needs with no Sleep Debt to repay, seconds.
    let usualNeed: TimeInterval
    /// The net shortfall against Usual Need over the Nights before, seconds.
    let sleepDebt: TimeInterval
    /// Usual Need plus part of Sleep Debt, seconds.
    let sleepNeed: TimeInterval
    /// How many Nights counted toward Sleep Debt.
    let nightsCounted: Int

    /// The Sleep Need of the Night dated `day`, from the Nights before it.
    init(for day: Day, among nights: [Night]) {
        usualNeed = Self.adultUsualNeed
        sleepDebt = 0
        sleepNeed = usualNeed
        nightsCounted = 0
    }
}
