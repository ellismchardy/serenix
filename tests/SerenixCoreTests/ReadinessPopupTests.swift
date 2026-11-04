import Foundation
import SerenixCore
import Testing

// The Readiness popup's verdict and "Why" rows (spec 012, Success criteria: verdict, weights,
// points). Expected values are spec 012's literals.

/// 15 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!

/// 2026-11-15T08:12:00Z, 08:12 local in London.
private let now = Date(timeIntervalSince1970: 1_794_730_320)

private let nov14 = Day(year: 2026, month: 11, day: 14)
private let nov15 = Day(year: 2026, month: 11, day: 15)

private let oneHour: TimeInterval = 3_600

private func todayView(nights: [Night], dayLoads: [DayLoad] = []) -> TodayView {
    TodayView(
        nights: nights,
        dayLoads: dayLoads,
        showing: nov15,
        now: now,
        timeZone: london,
        sync: .idle,
        profileName: nil
    )
}

/// `count` earlier Nights before 15 Nov, each HRV 60 ms, Sleeping HR 52 bpm, Time Asleep 8 h:
/// Spreads HRV 0.15 (ln RMSSD) and Sleeping HR 2.5 bpm; Sleep Need 8 h.
private func usualNightsBefore15Nov(count: Int = 4) -> [Night] {
    (1...count).map { daysBefore in
        Night(
            day: Day(year: 2026, month: 11, day: 15 - daysBefore),
            sleepingHR: 52,
            hrv: 60,
            timeAsleep: 8 * oneHour
        )
    }
}

private func nightOn15Nov(
    hrv: Double? = 60,
    sleepingHR: Double? = 52,
    timeAsleep: TimeInterval = 8 * oneHour
) -> Night {
    Night(day: nov15, sleepingHR: sleepingHR, hrv: hrv, timeAsleep: timeAsleep)
}

private func readinessView(
    for night: Night,
    earlierNights: Int = 4,
    dayLoads: [DayLoad] = []
) -> TodayView {
    todayView(nights: usualNightsBefore15Nov(count: earlierNights) + [night], dayLoads: dayLoads)
}

/// `count` Days before 14 Nov at Load 45 (typical Load 45 with 4 of them).
private func daysBefore14NovAtLoad45(count: Int = 4) -> [DayLoad] {
    (1...count).map { daysBefore in
        DayLoad(day: Day(year: 2026, month: 11, day: 14 - daysBefore), load: 45)
    }
}

/// Four Days before 14 Nov at Load 45, and 14 Nov at `load`.
private func dayLoadsWith14NovAt(_ load: Int) -> [DayLoad] {
    daysBefore14NovAtLoad45() + [DayLoad(day: nov14, load: load)]
}

/// Parses "−23 pts", "+12 pts", "±0 pts" (U+2212 minus) into whole points.
private func points(_ text: String?) -> Int? {
    guard let text, text.hasSuffix(" pts") else { return nil }
    let number = text.dropLast(4)
    if number.hasPrefix("±") { return Int(number.dropFirst()) }
    if number.hasPrefix("\u{2212}") { return Int(number.dropFirst()).map { -$0 } }
    if number.hasPrefix("+") { return Int(number.dropFirst()) }
    return nil
}

private func row(_ name: String, in view: TodayView) -> ReadinessWhyRow? {
    view.readinessPopup?.whyRows.first { $0.name == name }
}

private func allFourOffView() -> TodayView {
    readinessView(
        for: nightOn15Nov(hrv: 50, sleepingHR: 57, timeAsleep: 5 * oneHour + 30 * 60),
        dayLoads: dayLoadsWith14NovAt(85)
    )
}

private func hrv72AndSixHoursView() -> TodayView {
    readinessView(for: nightOn15Nov(hrv: 72, timeAsleep: 6 * oneHour))
}

// MARK: Usual Night

@Test func aUsualNightReadsRecoveredWithEveryInputAtZeroPoints() {
    let view = readinessView(for: nightOn15Nov())
    let popup = view.readinessPopup

    #expect(popup?.verdictText == "Your body looks recovered.")
    #expect(row("HRV", in: view)?.pointsText == "±0 pts")
    #expect(row("Sleeping HR", in: view)?.pointsText == "±0 pts")
    #expect(row("Time Asleep", in: view)?.pointsText == "±0 pts")
    #expect(row("HRV", in: view)?.weightText == "56%")
    #expect(row("Sleeping HR", in: view)?.weightText == "28%")
    #expect(row("Time Asleep", in: view)?.weightText == "17%")
}

@Test func aDroppedYesterdaysLoadIsListedLastWithNoPoints() {
    let view = readinessView(for: nightOn15Nov())
    let last = view.readinessPopup?.whyRows.last

    #expect(last?.name == "Yesterday's Load")
    #expect(last?.weightText == "dropped")
    #expect(last?.pointsText == nil)
}

// MARK: One input off

@Test func anHRVBelowBaselineIsListedFirstAndPulledItDownMost() {
    let view = readinessView(for: nightOn15Nov(hrv: 50))
    let popup = view.readinessPopup

    #expect(popup?.whyRows.first?.name == "HRV")
    #expect(popup?.whyRows.first?.pointsText == "\u{2212}32 pts")
    #expect(popup?.verdictText == "HRV pulled it down most.")
}

// MARK: All four off

@Test func allFourInputsOffAreListedByPointsWithTheirWeights() {
    let popup = allFourOffView().readinessPopup
    let rows = popup?.whyRows ?? []

    #expect(rows.map(\.name) == ["HRV", "Sleeping HR", "Time Asleep", "Yesterday's Load"])
    #expect(
        rows.map(\.pointsText) == [
            "\u{2212}23 pts", "\u{2212}19 pts", "\u{2212}14 pts", "\u{2212}7 pts",
        ]
    )
    #expect(rows.map(\.weightText) == ["50%", "25%", "15%", "10%"])
}

// MARK: Mixed

@Test func aRaisingHRVAndAShortNightAreListedFromMostNegative() {
    let view = hrv72AndSixHoursView()
    let popup = view.readinessPopup

    #expect(view.readinessText == "82")
    #expect(row("HRV", in: view)?.pointsText == "+24 pts")
    #expect(row("Time Asleep", in: view)?.pointsText == "\u{2212}12 pts")
    #expect(row("Sleeping HR", in: view)?.pointsText == "±0 pts")
    #expect(
        popup?.whyRows.prefix(3).map(\.name) == ["Time Asleep", "Sleeping HR", "HRV"]
    )
    #expect(popup?.verdictText == "Time Asleep pulled it down most.")
}

@Test func cancellingInputsShowTheirOwnPointsAndRead70() {
    // HRV score exactly +1: ln(HRV) one Spread (0.15) above ln(60).
    let hrvOneSpreadAbove = 60 * exp(0.15)
    let view = readinessView(for: nightOn15Nov(hrv: hrvOneSpreadAbove, sleepingHR: 57))

    #expect(view.readinessText == "70")
    #expect(row("HRV", in: view)?.pointsText == "+23 pts")
    #expect(row("Sleeping HR", in: view)?.pointsText == "\u{2212}23 pts")
}

// MARK: Points add up

@Test(arguments: ["allFourOff", "hrv72AndSixHours"])
func pointsAddUpToReadinessLess70(_ scenario: String) throws {
    let view = scenario == "allFourOff" ? allFourOffView() : hrv72AndSixHoursView()
    let rows = try #require(view.readinessPopup?.whyRows)
    let readiness = try #require(Int(view.readinessText))

    let sum = rows.compactMap { points($0.pointsText) }.reduce(0, +)
    #expect(sum == readiness - 70)
}

// MARK: Reasons and gauge (spec 012, Reasons; gauge in Why)

private func expectGauge(_ position: Double?, isAbout expected: Double) {
    guard let position else {
        Issue.record("gaugePosition is nil, expected \(expected)")
        return
    }
    #expect(abs(position - expected) < 0.00005)
}

@Test func anHRVBelowBaselineGivesItsPercentAgainstUsualAndAGaugeLeftOfCentre() {
    let hrv = row("HRV", in: readinessView(for: nightOn15Nov(hrv: 50)))

    #expect(hrv?.reasonText == "\u{2212}17% against your usual 60 ms.")
    expectGauge(hrv?.gaugePosition, isAbout: 0.2974)
}

@Test func allFourInputsOffGiveTheirReasons() {
    let view = allFourOffView()

    #expect(row("Time Asleep", in: view)?.reasonText == "2h 30m short of your Sleep Need.")
    #expect(row("Yesterday's Load", in: view)?.reasonText == "Above your typical 45.")
    #expect(row("Sleeping HR", in: view)?.reasonText == "+5 bpm against your usual 52 bpm.")
    expectGauge(row("Sleeping HR", in: view)?.gaugePosition, isAbout: 0.1667)
}

@Test func anHRVScoreClampedAtMinusThreeSitsAtTheGaugesLeftEnd() {
    let hrv = row("HRV", in: readinessView(for: nightOn15Nov(hrv: 20)))

    #expect(hrv?.gaugePosition == 0)
}

@Test func aUsualNightWithNoDaysLeavesOutYesterdaysLoadWithNoGauge() {
    let view = readinessView(for: nightOn15Nov())
    let load = row("Yesterday's Load", in: view)

    #expect(load?.reasonText == "No Load for yesterday, so it's left out.")
    #expect(load != nil && load?.gaugePosition == nil)
    expectGauge(row("HRV", in: view)?.gaugePosition, isAbout: 0.5)
}

@Test func aNightWithNoSleepingHRLeavesItOutWithNoGauge() {
    let shr = row("Sleeping HR", in: readinessView(for: nightOn15Nov(sleepingHR: nil)))

    #expect(shr?.reasonText == "No Sleeping HR for this Night, so it's left out.")
    #expect(shr != nil && shr?.gaugePosition == nil)
}

@Test func aCalibratingTypicalLoadLeavesOutYesterdaysLoad() {
    let dayLoads = daysBefore14NovAtLoad45(count: 3) + [DayLoad(day: nov14, load: 85)]
    let view = readinessView(for: nightOn15Nov(), dayLoads: dayLoads)

    #expect(
        row("Yesterday's Load", in: view)?.reasonText
            == "Typical Load is still calibrating, so it's left out."
    )
}

@Test func aLongNightIsEnoughForTheSleepNeed() {
    let view = readinessView(for: nightOn15Nov(timeAsleep: 10 * oneHour))

    #expect(row("Time Asleep", in: view)?.reasonText == "Enough for your Sleep Need.")
}

@Test func aLoadAtOrBelowTypicalSaysNoMoreThanTypical() {
    let view = readinessView(for: nightOn15Nov(), dayLoads: dayLoadsWith14NovAt(40))

    #expect(row("Yesterday's Load", in: view)?.reasonText == "No more than your typical 45.")
}

// MARK: Calibrating and missing

@Test func whileCalibratingTheVerdictExplainsHowManyNightsSoFarAndSleepScoreStillShows() {
    // One earlier Night plus the Night shown: 2 Nights so far.
    let popup = readinessView(for: nightOn15Nov(), earlierNights: 1).readinessPopup

    #expect(popup?.readinessText == "2/4")
    #expect(popup?.band == nil)
    #expect(popup?.whyRows == [])
    #expect(
        popup?.verdictText
            == "Readiness needs 4 Nights to form your Baseline. You have 2 so far."
    )
    #expect(popup != nil && popup?.sleepScoreText != nil)
}

@Test func aNightWithNoHRVSaysThereIsNoReadinessAndSleepScoreStillShows() {
    let popup = readinessView(for: nightOn15Nov(hrv: nil)).readinessPopup

    #expect(popup?.readinessText == "\u{2014}")
    #expect(popup?.band == nil)
    #expect(popup?.whyRows == [])
    #expect(popup?.verdictText == "No HRV for this Night, so there's no Readiness.")
    #expect(popup != nil && popup?.sleepScoreText != nil)
}

// MARK: Band scale

private func expectScale(_ popup: ReadinessPopup?) {
    let segments = popup?.scaleSegments ?? []
    #expect(segments.map(\.band) == [.takeItEasy, .steady, .ready])
    #expect(segments.map(\.from) == [0, 0.34, 0.67])
    #expect(segments.map(\.to) == [0.34, 0.67, 1])
}

private func expectMarker(_ marker: Double?, isAbout expected: Double) {
    guard let marker else {
        Issue.record("expected a marker at \(expected), got nil")
        return
    }
    #expect(abs(marker - expected) < 0.0001)
}

@Test func theBandScaleHasTheSameThreeSegmentsWhateverTheNight() {
    expectScale(readinessView(for: nightOn15Nov()).readinessPopup)
    expectScale(readinessView(for: nightOn15Nov(), earlierNights: 1).readinessPopup)
    expectScale(readinessView(for: nightOn15Nov(hrv: nil)).readinessPopup)
}

@Test func aUsualNightPutsTheMarkerAtTheUsualTick() {
    let popup = readinessView(for: nightOn15Nov()).readinessPopup

    expectMarker(popup?.scaleMarker, isAbout: 0.70)
    expectMarker(popup?.usualTick, isAbout: 0.70)
}

@Test func anHRVBelowBaselinePutsTheMarkerInSteady() {
    let popup = readinessView(for: nightOn15Nov(hrv: 50)).readinessPopup

    expectMarker(popup?.scaleMarker, isAbout: 0.38)
    #expect(popup?.band == .steady)
}

@Test func allFourInputsOffPutTheMarkerInTakeItEasy() {
    let popup = allFourOffView().readinessPopup

    expectMarker(popup?.scaleMarker, isAbout: 0.07)
    #expect(popup?.band == .takeItEasy)
}

@Test func whileCalibratingTheScaleHasNoMarkers() {
    let popup = readinessView(for: nightOn15Nov(), earlierNights: 1).readinessPopup

    #expect(popup != nil)
    #expect(popup?.scaleMarker == nil)
    #expect(popup?.usualTick == nil)
}

@Test func aNightWithNoHRVHasNoScaleMarkers() {
    let popup = readinessView(for: nightOn15Nov(hrv: nil)).readinessPopup

    #expect(popup != nil)
    #expect(popup?.scaleMarker == nil)
    #expect(popup?.usualTick == nil)
}

// MARK: Your week

/// A usual Night (HRV 60, Sleeping HR 52, 8 h) dated `day` November 2026.
private func usualNight(onNov day: Int) -> Night {
    Night(
        day: Day(year: 2026, month: 11, day: day),
        sleepingHR: 52,
        hrv: 60,
        timeAsleep: 8 * oneHour
    )
}

@Test func theWeekHoldsTheDayShownAndTheSixDaysBeforeOldestFirst() {
    let nights = (1...14).map { usualNight(onNov: $0) } + [nightOn15Nov(hrv: 50)]
    let week = todayView(nights: nights).readinessPopup?.week ?? []

    #expect(week.map(\.weekdayText) == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
    #expect(week.map(\.isDayShown) == [false, false, false, false, false, false, true])
}

@Test func eachWeekBarReadsItsDaysReadinessAgainstItsOwnBaselines() {
    // 9 Nov has HRV 50 against four usual earlier Nights (5–8 Nov, typical Spread): Readiness 38,
    // as in spec 008. 10–15 Nov are usual Nights at their Baseline's median of 60 ms: Readiness 70
    // whatever their Spread (spec 008).
    let nights =
        (5...8).map { usualNight(onNov: $0) }
        + [
            Night(
                day: Day(year: 2026, month: 11, day: 9),
                sleepingHR: 52,
                hrv: 50,
                timeAsleep: 8 * oneHour
            )
        ]
        + (10...14).map { usualNight(onNov: $0) } + [nightOn15Nov()]
    let week = todayView(nights: nights).readinessPopup?.week ?? []

    #expect(week.map(\.readinessText) == ["38", "70", "70", "70", "70", "70", "70"])
    #expect(week.map(\.band) == [.steady, .ready, .ready, .ready, .ready, .ready, .ready])
    // A bar's height is its Readiness out of 100, as the ring's fill.
    #expect(week.map(\.fill) == [0.38, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7])
}

@Test func aDayWithNoNightAndACalibratingDayHaveNoReadiness() throws {
    // Nights on 10, 11, 12, 14 and 15 Nov: 15 Nov has 4 earlier Nights, so it reads a number.
    // 9 and 13 Nov have no Night; 10–12 Nov have fewer than 3 earlier Nights (Calibrating).
    let nights = [10, 11, 12, 14].map { usualNight(onNov: $0) } + [nightOn15Nov()]
    let week = todayView(nights: nights).readinessPopup?.week ?? []

    try #require(week.count == 7)
    for index in [0, 1, 2, 3, 4] {
        #expect(week[index].readinessText == "—")
        #expect(week[index].band == nil)
        #expect(week[index].fill == 0)
    }
    #expect(week.last?.readinessText == "70")
    #expect(week.last?.band == .ready)
}
