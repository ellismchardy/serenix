import Foundation
import SerenixCore
import Testing

// Sleep Need and Sleep Debt in the Today view's Sleep popup (spec 009, Behavior: Usual Need,
// Sleep Debt, Sleep Need, Sleep popup).
// Expected values are spec 009's success criteria, worked by hand from its rules.

/// 15 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!

/// 2026-11-15T08:12:00Z, 08:12 local in London.
private let now = Date(timeIntervalSince1970: 1_794_730_320)

private let nov15 = Day(year: 2026, month: 11, day: 15)

private let oneHour: TimeInterval = 3_600

private func todayView(nights: [Night]) -> TodayView {
    TodayView(
        nights: nights,
        dayLoads: [],
        showing: nov15,
        now: now,
        timeZone: london,
        sync: .idle,
        profileName: nil
    )
}

/// The Night shown, dated 15 Nov, with Time Asleep `timeAsleep` (8 h by default).
private func nightOn15Nov(timeAsleep: TimeInterval? = 8 * oneHour) -> Night {
    Night(day: nov15, timeAsleep: timeAsleep)
}

// MARK: Usual Need and Sleep Need

@Test func withNoEarlierNightsSleepNeedIsUsualNeedAndSleepDebtIsZero() {
    let popup = todayView(nights: [nightOn15Nov()]).sleepPopup

    #expect(popup?.sleepNeedText == "8h 0m")
    #expect(popup?.sleepDebtText == "0h 0m")
    #expect(popup?.sleepDebtCaption == "No earlier Nights")
}
