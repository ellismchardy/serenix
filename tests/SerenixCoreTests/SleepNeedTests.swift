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

private func todayView(nights: [Night], birthYear: Int? = nil) -> TodayView {
    TodayView(
        nights: nights,
        dayLoads: [],
        showing: nov15,
        now: now,
        timeZone: london,
        sync: .idle,
        profileName: nil,
        birthYear: birthYear
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

/// A Night dated `day` Nov 2026 with Time Asleep `timeAsleep`.
private func nightOnNov(_ day: Int, timeAsleep: TimeInterval?) -> Night {
    Night(day: Day(year: 2026, month: 11, day: day), timeAsleep: timeAsleep)
}

/// Earlier Nights dated 14 Nov, 13 Nov and so on back, with the given Time Asleep in that order.
private func earlierNights(_ timesAsleep: [TimeInterval?]) -> [Night] {
    timesAsleep.enumerated().map { offset, timeAsleep in
        nightOnNov(14 - offset, timeAsleep: timeAsleep)
    }
}

@Test func aLongNightPaysBackAShortOneAndSleepNeedAddsAQuarterOfSleepDebt() {
    let popup = todayView(nights: [nightOn15Nov()] + earlierNights([6 * oneHour, 9 * oneHour]))
        .sleepPopup

    #expect(popup?.sleepDebtText == "1h 0m")
    #expect(popup?.sleepNeedText == "8h 15m")
}

@Test func sleepNeedIsCappedAtOneHourOverUsualNeed() {
    let popup = todayView(
        nights: [nightOn15Nov()] + earlierNights(Array(repeating: 6 * oneHour, count: 4))
    )
    .sleepPopup

    #expect(popup?.sleepDebtText == "8h 0m")
    #expect(popup?.sleepNeedText == "9h 0m")
}

@Test func sleepDebtIsNeverBelowZero() {
    let popup = todayView(
        nights: [nightOn15Nov()] + earlierNights([9 * oneHour, 9 * oneHour, 9 * oneHour])
    )
    .sleepPopup

    #expect(popup?.sleepDebtText == "0h 0m")
    #expect(popup?.sleepNeedText == "8h 0m")
}

@Test func theNightShownWithNoTimeAsleepStillHasASleepNeed() {
    let popup = todayView(
        nights: [nightOn15Nov(timeAsleep: nil)] + earlierNights([6 * oneHour, 9 * oneHour])
    ).sleepPopup

    #expect(popup?.sleepNeedText == "8h 15m")
}

// MARK: Usual Need by age

@Test func aUserWhoIs65GetsAUsualNeedOf7Hours30() {
    let popup = todayView(nights: [nightOn15Nov()], birthYear: 1961).sleepPopup

    #expect(popup?.sleepNeedText == "7h 30m")
}

@Test func aUserWhoIs64KeepsAUsualNeedOf8Hours() {
    let popup = todayView(nights: [nightOn15Nov()], birthYear: 1962).sleepPopup

    #expect(popup?.sleepNeedText == "8h 0m")
}

@Test func sleepDebtForAUserWhoIs65IsMeasuredAgainst7Hours30() {
    let popup = todayView(
        nights: [nightOn15Nov()] + earlierNights([6 * oneHour + 30 * 60]),
        birthYear: 1961
    )
    .sleepPopup

    #expect(popup?.sleepDebtText == "1h 0m")
    #expect(popup?.sleepNeedText == "7h 45m")
}

// MARK: Window and skipping

@Test func aNightDated8NovIsInsideTheWindow() {
    let popup = todayView(nights: [nightOn15Nov(), nightOnNov(8, timeAsleep: 6 * oneHour)])
        .sleepPopup

    #expect(popup?.sleepDebtText == "2h 0m")
    #expect(popup?.sleepNeedText == "8h 30m")
    #expect(popup?.sleepDebtCaption == "Your last 1 Night")
}

@Test func aNightDated7NovIsOutsideTheWindow() {
    let popup = todayView(nights: [nightOn15Nov(), nightOnNov(7, timeAsleep: 4 * oneHour)])
        .sleepPopup

    #expect(popup?.sleepDebtText == "0h 0m")
    #expect(popup?.sleepNeedText == "8h 0m")
    #expect(popup?.sleepDebtCaption == "No earlier Nights")
}

@Test func theShownNightsOwnTimeAsleepDoesNotCount() {
    let popup = todayView(nights: [nightOn15Nov(timeAsleep: 4 * oneHour)]).sleepPopup

    #expect(popup?.sleepDebtText == "0h 0m")
    #expect(popup?.sleepNeedText == "8h 0m")
    #expect(popup?.sleepDebtCaption == "No earlier Nights")
}

@Test func anEarlierNightWithNoPlausibleTimeAsleepIsSkipped() {
    let popup = todayView(
        nights: [
            nightOn15Nov(),
            nightOnNov(14, timeAsleep: 6 * oneHour),
            nightOnNov(13, timeAsleep: nil),
            nightOnNov(12, timeAsleep: -oneHour),
            nightOnNov(11, timeAsleep: 6 * oneHour),
        ]
    ).sleepPopup

    #expect(popup?.sleepDebtText == "4h 0m")
    #expect(popup?.sleepNeedText == "9h 0m")
    #expect(popup?.sleepDebtCaption == "Your last 2 Nights")
}

@Test func oneEarlierNightReadsYourLast1Night() {
    let popup = todayView(nights: [nightOn15Nov()] + earlierNights([8 * oneHour])).sleepPopup

    #expect(popup?.sleepDebtCaption == "Your last 1 Night")
}

@Test func sevenEarlierNightsReadYourLast7Nights() {
    let popup = todayView(
        nights: [nightOn15Nov()] + earlierNights(Array(repeating: 8 * oneHour, count: 7))
    )
    .sleepPopup

    #expect(popup?.sleepDebtCaption == "Your last 7 Nights")
}

// MARK: Always current

@Test func anEarlierNightAddedBySyncRaisesSleepNeed() {
    let before = [nightOn15Nov()]
    let after = before + [nightOnNov(14, timeAsleep: 6 * oneHour)]

    #expect(todayView(nights: before).sleepPopup?.sleepNeedText == "8h 0m")
    #expect(todayView(nights: after).sleepPopup?.sleepNeedText == "8h 30m")
}

@Test func givingABirthYearChangesSleepNeedForTheSameNights() {
    let nights = [nightOn15Nov()]

    #expect(todayView(nights: nights).sleepPopup?.sleepNeedText == "8h 0m")
    #expect(todayView(nights: nights, birthYear: 1961).sleepPopup?.sleepNeedText == "7h 30m")
}

// MARK: Readiness against Sleep Need

/// Earlier Nights dated 14 Nov, 13 Nov and so on back, each with spec 008's usual HRV 60 ms and
/// Sleeping HR 52 bpm, and the given Time Asleep in that order.
private func usualEarlierNights(_ timesAsleep: [TimeInterval]) -> [Night] {
    timesAsleep.enumerated().map { offset, timeAsleep in
        Night(
            day: Day(year: 2026, month: 11, day: 14 - offset),
            sleepingHR: 52,
            hrv: 60,
            timeAsleep: timeAsleep
        )
    }
}

/// The Night shown, dated 15 Nov: spec 008's usual Night (HRV 60 ms, Sleeping HR 52 bpm) with
/// Time Asleep 8 h.
private let usualNightOn15Nov = Night(day: nov15, sleepingHR: 52, hrv: 60, timeAsleep: 8 * oneHour)

@Test func readinessJudgesTimeAsleepAgainstARaisedSleepNeed() {
    let view = todayView(
        nights: usualEarlierNights(Array(repeating: 6 * oneHour, count: 4)) + [usualNightOn15Nov]
    )
    let row = view.readinessPopup?.rows.first { $0.name == "Time Asleep" }

    #expect(view.readinessText == "62")
    #expect(row?.valueText == "8h 0m")
    #expect(row?.referenceText == "9h 0m")
    #expect(row?.differenceText == "\u{2212}1h 0m")
}

@Test func readinessAgainstSleepNeedOf8Hours30ReadsSteady() {
    let view = todayView(
        nights: usualEarlierNights([6 * oneHour, 8 * oneHour, 8 * oneHour, 8 * oneHour])
            + [usualNightOn15Nov]
    )

    #expect(view.readinessText == "66")
    #expect(view.readinessBand == .steady)
}
