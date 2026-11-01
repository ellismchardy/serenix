import Foundation
import SerenixCore
import Testing

/// 1 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!

/// 2026-11-01T08:12:00Z, 08:12 local in London.
private let now = Date(timeIntervalSince1970: 1_793_520_720)

private let oct30 = Day(year: 2026, month: 10, day: 30)
private let oct31 = Day(year: 2026, month: 10, day: 31)
private let nov1 = Day(year: 2026, month: 11, day: 1)

/// A distinct Load on each Day, so a view can't show one Day's Load as another's.
private let dayLoads = [
    DayLoad(day: oct30, load: 9),
    DayLoad(day: oct31, load: 12),
    DayLoad(day: nov1, load: 5),
]

private func todayView(
    nights: [Night],
    dayLoads: [DayLoad] = dayLoads,
    showing day: Day,
    sync: SyncStatus = .connecting
) -> TodayView {
    TodayView(
        nights: nights,
        dayLoads: dayLoads,
        showing: day,
        now: now,
        timeZone: london,
        sync: sync
    )
}

/// Nights on the Days before 1 Nov, newest first: the first is on 31 Oct, the next on 30 Oct,
/// and so on. A nil (or absent) entry is a Night without that Nightly Metric.
private func nightsBeforeNov1(hrv: [Double?], restingHR: [Double?] = []) -> [Night] {
    (0..<max(hrv.count, restingHR.count)).map { index in
        Night(
            day: Day(year: 2026, month: 10, day: 31 - index),
            restingHR: index < restingHR.count ? restingHR[index] : nil,
            hrv: index < hrv.count ? hrv[index] : nil
        )
    }
}

/// Three earlier Nights with HRV and Resting HR, so Readiness on 1 Nov is past Calibrating.
private let calibratedNightsBeforeNov1 = nightsBeforeNov1(
    hrv: [60, 60, 60],
    restingHR: [50, 50, 50]
)

// MARK: Which Day is shown

@Test func arrowsStepByDayFromTodayBackToTheEarliestNight() {
    let nights = [Night(day: oct30), Night(day: nov1)]

    let today = todayView(nights: nights, showing: nov1)
    #expect(today.title == "Today")
    #expect(today.subtitle == "Sun 1 Nov")
    #expect(today.noNightMessage == nil)
    #expect(today.earlierDay == oct31)
    #expect(today.laterDay == nil)

    let oneEarlier = todayView(nights: nights, showing: oct31)
    #expect(oneEarlier.title == "Sat 31 Oct")
    #expect(oneEarlier.subtitle == "Night")
    #expect(oneEarlier.noNightMessage == "No Night recorded")
    #expect(oneEarlier.loadLabel == "Load")
    #expect(oneEarlier.loadText == "12")
    #expect(oneEarlier.earlierDay == oct30)
    #expect(oneEarlier.laterDay == nov1)

    let twoEarlier = todayView(nights: nights, showing: oct30)
    #expect(twoEarlier.title == "Fri 30 Oct")
    #expect(twoEarlier.noNightMessage == nil)
    #expect(twoEarlier.loadText == "9")
    #expect(twoEarlier.earlierDay == nil)
    #expect(twoEarlier.laterDay == oct31)
}

@Test func todayWithoutANightSaysNoNightYetAndShowsTodaysLoadSoFar() {
    let view = todayView(nights: [Night(day: oct31)], showing: nov1)

    #expect(view.title == "Today")
    #expect(view.noNightMessage == "No Night yet")
    #expect(view.loadLabel == "Load so far")
    #expect(view.loadText == "5")
    #expect(view.earlierDay == oct31)
    #expect(view.laterDay == nil)
}

@Test func withNoNightsBothArrowsAreDisabledOnToday() {
    let view = todayView(nights: [], showing: nov1)

    #expect(view.noNightMessage == "No Night yet")
    #expect(view.earlierDay == nil)
    #expect(view.laterDay == nil)
}

@Test func aMissingLoadShowsADash() {
    let nights = [Night(day: oct30)]

    let noDayLoad = todayView(nights: nights, dayLoads: [], showing: nov1)
    #expect(noDayLoad.loadText == "—")

    let nilLoad = todayView(
        nights: nights,
        dayLoads: [DayLoad(day: oct30, load: nil)],
        showing: oct30
    )
    #expect(nilLoad.loadText == "—")
}

// MARK: Today is the local calendar Day

@Test func todayIsTheLocalCalendarDayOfTheCurrentTime() {
    let newYork = TimeZone(identifier: "America/New_York")!
    // 2026-11-01T03:30Z is 23:30 EDT on 31 Oct (EDT ends at 06:00Z that morning).
    let lateOnOct31InNewYork = Date(timeIntervalSince1970: 1_793_503_800)
    let newYorkToday = TodayView(
        nights: [],
        dayLoads: [],
        showing: oct31,
        now: lateOnOct31InNewYork,
        timeZone: newYork,
        sync: .connecting
    )
    #expect(newYorkToday.title == "Today")
    #expect(newYorkToday.subtitle == "Sat 31 Oct")

    // 2026-10-24T23:30Z is 00:30 BST on 25 Oct in London.
    let justAfterMidnightOct25InLondon = Date(timeIntervalSince1970: 1_792_884_600)
    let londonToday = TodayView(
        nights: [],
        dayLoads: [],
        showing: Day(year: 2026, month: 10, day: 25),
        now: justAfterMidnightOct25InLondon,
        timeZone: london,
        sync: .connecting
    )
    #expect(londonToday.title == "Today")
    #expect(londonToday.subtitle == "Sun 25 Oct")
}

@Test func theEarlierArrowStepsBackAcrossTheNewYear() {
    let dec31 = Day(year: 2026, month: 12, day: 31)
    let jan1 = Day(year: 2027, month: 1, day: 1)
    // 2027-01-01T12:00Z, midday in London (GMT).
    let middayJan1 = Date(timeIntervalSince1970: 1_798_804_800)

    let view = TodayView(
        nights: [Night(day: dec31)],
        dayLoads: [],
        showing: jan1,
        now: middayJan1,
        timeZone: london,
        sync: .connecting
    )
    #expect(view.title == "Today")
    #expect(view.subtitle == "Fri 1 Jan")
    #expect(view.earlierDay == dec31)
    #expect(view.laterDay == nil)
}

// MARK: Sync pill

@Test func syncPillNamesTheHistorySyncState() {
    let connecting = todayView(nights: [], showing: nov1, sync: .connecting).syncPill
    #expect(connecting.text == "Connecting…")
    #expect(connecting.failureReason == nil)
    #expect(!connecting.showsProgress)

    let syncing = todayView(nights: [], showing: nov1, sync: .syncing).syncPill
    #expect(syncing.text == "Syncing")
    #expect(syncing.failureReason == nil)
    #expect(syncing.showsProgress)

    // 2026-11-01T08:10:00Z, 08:10 local in London.
    let lastSync = Date(timeIntervalSince1970: 1_793_520_600)
    let upToDate = todayView(nights: [], showing: nov1, sync: .upToDate(lastSync: lastSync))
        .syncPill
    #expect(upToDate.text == "Synced 08:10")
    #expect(upToDate.failureReason == nil)
    #expect(!upToDate.showsProgress)

    let neverSynced = todayView(nights: [], showing: nov1, sync: .upToDate(lastSync: nil))
        .syncPill
    #expect(neverSynced.text == "Not synced")
    #expect(!neverSynced.showsProgress)

    let failed = todayView(
        nights: [],
        showing: nov1,
        sync: .failed(reason: "The Strap stopped responding.")
    ).syncPill
    #expect(failed.text == "Sync failed")
    #expect(failed.failureReason == "The Strap stopped responding.")
    #expect(!failed.showsProgress)
}

// MARK: Rings

@Test(arguments: [
    (100, "100", ReadinessBand.ready, "Ready"),
    (67, "67", .ready, "Ready"),
    (66, "66", .steady, "Steady"),
    (34, "34", .steady, "Steady"),
    (33, "33", .takeItEasy, "Take it easy"),
    (0, "0", .takeItEasy, "Take it easy"),
])
func readinessShowsItsNumberAndBand(
    readiness: Int,
    text: String,
    band: ReadinessBand,
    word: String
) {
    let view = todayView(
        nights: calibratedNightsBeforeNov1 + [Night(day: nov1, readiness: readiness)],
        showing: nov1
    )

    #expect(view.readinessText == text)
    #expect(view.readinessBand == band)
    #expect(view.readinessBand?.word == word)
}

@Test func sleepScoreShowsItsNumber() {
    let view = todayView(nights: [Night(day: nov1, sleepScore: 84)], showing: nov1)

    #expect(view.sleepScoreText == "84")
}

// MARK: Missing values

@Test func aNightWithoutScoresShowsDashesAndNoBand() {
    let view = todayView(nights: calibratedNightsBeforeNov1 + [Night(day: nov1)], showing: nov1)

    #expect(view.sleepScoreText == "—")
    #expect(view.readinessText == "—")
    #expect(view.readinessBand == nil)
}

@Test func aDayWithoutANightShowsNoOtherDaysScores() {
    let nights = [
        Night(day: oct30, sleepScore: 81, readiness: 72),
        Night(day: nov1, sleepScore: 84, readiness: 67),
    ]
    let view = todayView(nights: nights, showing: oct31)

    #expect(view.sleepScoreText == "—")
    #expect(view.readinessText == "—")
    #expect(view.readinessBand == nil)
}

@Test func eachRingFillsToItsScoreOutOf100() {
    let view = todayView(
        nights: calibratedNightsBeforeNov1 + [Night(day: nov1, sleepScore: 84, readiness: 67)],
        showing: nov1
    )

    #expect(view.sleepScoreFill == 0.84)
    #expect(view.readinessFill == 0.67)
    #expect(view.loadFill == 0.05)
}

@Test func aRingWithAMissingScoreIsEmpty() {
    let view = todayView(nights: [Night(day: nov1)], dayLoads: [], showing: nov1)

    #expect(view.sleepScoreFill == 0)
    #expect(view.readinessFill == 0)
    #expect(view.loadFill == 0)
}

// MARK: Readiness Calibrating

@Test func readinessIsCalibratingUntilThreeEarlierNightsFormBothBaselines() {
    let shown = Night(day: nov1, readiness: 80, restingHR: 50, hrv: 60)

    let twoEarlier = todayView(
        nights: nightsBeforeNov1(hrv: [60, 60], restingHR: [50, 50]) + [shown],
        showing: nov1
    )
    #expect(twoEarlier.readinessText == "3/4")
    #expect(twoEarlier.readinessBand == nil)
    #expect(twoEarlier.readinessFill == 0)

    let threeEarlier = todayView(nights: calibratedNightsBeforeNov1 + [shown], showing: nov1)
    #expect(threeEarlier.readinessText == "80")
    #expect(threeEarlier.readinessBand == .ready)
}

@Test func theFirstNightIsOneOfFourNightsWhileReadinessIsCalibrating() {
    let view = todayView(
        nights: [Night(day: nov1, readiness: 80, restingHR: 50, hrv: 60)],
        showing: nov1
    )

    #expect(view.readinessText == "1/4")
    #expect(view.readinessBand == nil)
    #expect(view.readinessFill == 0)
}

@Test func calibratingCountsNightsByTheMetricWithFewestEarlierValues() {
    let nights =
        nightsBeforeNov1(hrv: [60, 60, 60], restingHR: [50])
        + [Night(day: nov1, readiness: 80, restingHR: 50, hrv: 60)]
    let view = todayView(nights: nights, showing: nov1)

    #expect(view.readinessText == "2/4")
    #expect(view.readinessBand == nil)
}

// MARK: Baseline (through the HRV tile)

@Test func hrvBaselineIsTheMedianOfEarlierNights() {
    let shown = Night(day: nov1, hrv: 60)

    let evenCount = todayView(
        nights: nightsBeforeNov1(hrv: [50, 70, 60, 58]) + [shown],
        showing: nov1
    )
    #expect(evenCount.tile(.hrv)?.baseline == 59)

    let oddCount = todayView(nights: nightsBeforeNov1(hrv: [50, 70, 60]) + [shown], showing: nov1)
    #expect(oddCount.tile(.hrv)?.baseline == 60)
}

@Test func hrvBaselineUsesAtMostTheFourteenMostRecentEarlierNights() {
    let shown = Night(day: nov1, hrv: 60)
    let fourteenNewest: [Double?] = [50, 52, 54, 56, 58, 60, 62, 64, 66, 68, 70, 72, 74, 76]
    // If these counted, the median of all 20 would be 69, not 63.
    let sixOldest: [Double?] = [200, 200, 200, 200, 200, 200]

    let fourteen = todayView(nights: nightsBeforeNov1(hrv: fourteenNewest) + [shown], showing: nov1)
    #expect(fourteen.tile(.hrv)?.baseline == 63)

    let twenty = todayView(
        nights: nightsBeforeNov1(hrv: fourteenNewest + sixOldest) + [shown],
        showing: nov1
    )
    #expect(twenty.tile(.hrv)?.baseline == 63)
}

@Test func theNightShownIsNotInItsOwnBaseline() {
    let earlier = nightsBeforeNov1(hrv: [50, 70, 60])

    let low = todayView(nights: earlier + [Night(day: nov1, hrv: 62)], showing: nov1).tile(.hrv)
    #expect(low?.baseline == 60)
    #expect(low?.valueText == "62 ms")
    #expect(low?.differenceText == "+3%")

    let high = todayView(nights: earlier + [Night(day: nov1, hrv: 90)], showing: nov1).tile(.hrv)
    #expect(high?.baseline == 60)
    #expect(high?.valueText == "90 ms")
    #expect(high?.differenceText == "+50%")
}

@Test func anEarlierNightsBaselineComesFromNightsBeforeItOnly() {
    let nights = [
        Night(day: Day(year: 2026, month: 10, day: 28), hrv: 50),
        Night(day: Day(year: 2026, month: 10, day: 29), hrv: 70),
        Night(day: oct30, hrv: 60),
        Night(day: oct31, hrv: 64),
    ]

    let before = todayView(nights: nights, showing: oct31).tile(.hrv)
    #expect(before?.baseline == 60)

    let after = todayView(nights: nights + [Night(day: nov1, hrv: 100)], showing: oct31)
        .tile(.hrv)
    #expect(after?.baseline == 60)
}

@Test func hrvIsCalibratingWithTwoEarlierNightsAndHasABaselineWithThree() {
    let shown = Night(day: nov1, hrv: 60)

    let two = todayView(nights: nightsBeforeNov1(hrv: [50, 70]) + [shown], showing: nov1)
        .tile(.hrv)
    #expect(two?.baseline == nil)
    #expect(two?.differenceText == "Calibrating")
    #expect(two?.valueText == "60 ms")

    let three = todayView(nights: nightsBeforeNov1(hrv: [50, 70, 60]) + [shown], showing: nov1)
        .tile(.hrv)
    #expect(three?.baseline == 60)
}

@Test func earlierNightsWithoutHRVAreSkippedForItsBaseline() {
    let shown = Night(day: nov1, hrv: 60)

    let twoOfFour = todayView(
        nights: nightsBeforeNov1(hrv: [50, nil, 70, nil]) + [shown],
        showing: nov1
    ).tile(.hrv)
    #expect(twoOfFour?.baseline == nil)
    #expect(twoOfFour?.differenceText == "Calibrating")

    // Counting the two missing values as 0 would make the median 50.
    let threeOfFive = todayView(
        nights: nightsBeforeNov1(hrv: [50, nil, 70, nil, 60]) + [shown],
        showing: nov1
    ).tile(.hrv)
    #expect(threeOfFive?.baseline == 60)
}

// MARK: HRV tile text

@Test func hrvDifferenceIsAWholeSignedPercentageFromBaseline() {
    let earlier = nightsBeforeNov1(hrv: [50, 70, 60])

    let up = todayView(nights: earlier + [Night(day: nov1, hrv: 68.4)], showing: nov1).tile(.hrv)
    #expect(up?.differenceText == "+14%")

    let down = todayView(nights: earlier + [Night(day: nov1, hrv: 58.2)], showing: nov1)
        .tile(.hrv)
    #expect(down?.differenceText == "\u{2212}3%")
}

@Test func hrvValueIsAWholeNumberOfMilliseconds() {
    let whole = todayView(nights: [Night(day: nov1, hrv: 62.0)], showing: nov1).tile(.hrv)
    #expect(whole?.valueText == "62 ms")

    let rounded = todayView(nights: [Night(day: nov1, hrv: 61.6)], showing: nov1).tile(.hrv)
    #expect(rounded?.valueText == "62 ms")
}

@Test func aNightWithoutHRVShowsDashes() {
    let view = todayView(
        nights: nightsBeforeNov1(hrv: [50, 70, 60]) + [Night(day: nov1)],
        showing: nov1
    )

    let tile = view.tile(.hrv)
    #expect(tile?.metric == .hrv)
    #expect(tile?.valueText == "—")
    #expect(tile?.differenceText == "—")
}

@Test func aDayWithoutANightHasNoHRVTile() {
    let view = todayView(nights: nightsBeforeNov1(hrv: [50, 70, 60]), showing: nov1)

    #expect(view.tile(.hrv) == nil)
}

@Test func aZeroHRVBaselineGivesNoDifferenceRatherThanACrash() {
    let shown = Night(day: nov1, hrv: 62)
    let view = todayView(nights: nightsBeforeNov1(hrv: [0, 0, 0]) + [shown], showing: nov1)

    #expect(view.tile(.hrv)?.valueText == "62 ms")
    #expect(view.tile(.hrv)?.differenceText == "—")
}

@Test func aNonFiniteHRVCountsAsMissing() {
    let shown = Night(day: nov1, hrv: .nan)
    let view = todayView(
        nights: nightsBeforeNov1(hrv: [.infinity, 50, 70, 60]) + [shown],
        showing: nov1
    )

    #expect(view.tile(.hrv)?.valueText == "—")
    #expect(view.tile(.hrv)?.differenceText == "—")
    #expect(view.tile(.hrv)?.baseline == 60)
}
