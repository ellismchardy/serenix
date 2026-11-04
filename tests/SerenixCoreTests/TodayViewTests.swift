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
    at time: Date = now,
    sync: SyncStatus = .idle,
    profileName: String? = nil
) -> TodayView {
    TodayView(
        nights: nights,
        dayLoads: dayLoads,
        showing: day,
        now: time,
        timeZone: london,
        sync: sync,
        profileName: profileName
    )
}

/// Nights on the Days before 1 Nov, newest first: the first is on 31 Oct, the next on 30 Oct,
/// and so on. A nil (or absent) entry is a Night without that Nightly Metric.
private func nightsBeforeNov1(
    hrv: [Double?] = [],
    sleepingHR: [Double?] = [],
    respiratoryRate: [Double?] = [],
    skinTemperature: [Double?] = [],
    spo2: [Double?] = []
) -> [Night] {
    let count = [hrv, sleepingHR, respiratoryRate, skinTemperature, spo2].map(\.count).max()!
    return (0..<count).map { index in
        Night(
            day: Day(year: 2026, month: 10, day: 31 - index),
            sleepingHR: index < sleepingHR.count ? sleepingHR[index] : nil,
            hrv: index < hrv.count ? hrv[index] : nil,
            respiratoryRate: index < respiratoryRate.count ? respiratoryRate[index] : nil,
            skinTemperature: index < skinTemperature.count ? skinTemperature[index] : nil,
            spo2: index < spo2.count ? spo2[index] : nil
        )
    }
}

/// Three earlier Nights with HRV and Sleeping HR, so Readiness on 1 Nov is past Calibrating.
private let calibratedNightsBeforeNov1 = nightsBeforeNov1(
    hrv: [60, 60, 60],
    sleepingHR: [50, 50, 50]
)

// MARK: Which Day is shown and the week strip

private let oct26 = Day(year: 2026, month: 10, day: 26)
private let oct27 = Day(year: 2026, month: 10, day: 27)
private let oct28 = Day(year: 2026, month: 10, day: 28)
private let oct29 = Day(year: 2026, month: 10, day: 29)

/// Two Nights with distinct Sleep Scores (spec 010), so showing the wrong one would fail. 30 Oct:
/// Time Asleep 5 h 40 m against Sleep Need 8 h, 70.83, so 71. 1 Nov: 30 Oct's 2 h 20 m short
/// raises its Sleep Need by a quarter, 35 min, to 8 h 35 m (spec 009); Time Asleep 7 h 13 m
/// (433 min) against 515 min is 84.08, so 84.
private let nightsOct30AndNov1 = [
    Night(day: oct30, timeAsleep: 20_400),
    Night(day: nov1, timeAsleep: 25_980),
]

@Test func todayShowsItsNightInAWeekStripEndingOnToday() {
    let nights = nightsOct30AndNov1
    let view = todayView(nights: nights, showing: nov1)

    #expect(view.noNightMessage == nil)
    #expect(view.sleepScoreText == "84")
    #expect(view.pickerRange == oct30...nov1)

    let strip = view.weekStrip
    #expect(strip.title == "November 2026")
    #expect(strip.days.map(\.day) == [oct26, oct27, oct28, oct29, oct30, oct31, nov1])
    #expect(strip.days.map(\.letter) == ["M", "T", "W", "T", "F", "S", "S"])
    #expect(strip.days.map(\.number) == [26, 27, 28, 29, 30, 31, 1])
    #expect(strip.days.map(\.isShown) == [false, false, false, false, false, false, true])
    #expect(strip.days.map(\.hasNight) == [false, false, false, false, true, false, true])
    #expect(strip.days.map(\.isInRange) == [false, false, false, false, true, true, true])
    #expect(strip.earlierDay == oct30)
    #expect(strip.laterDay == nil)
}

@Test func anEarlierDayWithoutANightSaysNoNightRecordedWithItsLoad() {
    let nights = nightsOct30AndNov1

    let oneEarlier = todayView(nights: nights, showing: oct31)
    #expect(oneEarlier.noNightMessage == "No Night recorded")
    #expect(oneEarlier.loadLabel == "Load")
    #expect(oneEarlier.loadText == "12")
    #expect(oneEarlier.pickerRange == oct30...nov1)
    #expect(
        oneEarlier.weekStrip.days.map(\.isShown) == [
            false, false, false, false, false, true, false,
        ]
    )

    let twoEarlier = todayView(nights: nights, showing: oct30)
    #expect(twoEarlier.noNightMessage == nil)
    #expect(twoEarlier.sleepScoreText == "71")
    #expect(twoEarlier.loadText == "9")
}

/// A Night on every Day from 1 Oct to 1 Nov.
private let nightsOct1ToNov1 =
    (1...31).map { Night(day: Day(year: 2026, month: 10, day: $0)) } + [Night(day: nov1)]

@Test func theWeekStripArrowsMoveAWeekAtATime() {
    let oct19 = Day(year: 2026, month: 10, day: 19)
    let oct20 = Day(year: 2026, month: 10, day: 20)
    let oct21 = Day(year: 2026, month: 10, day: 21)
    let oct22 = Day(year: 2026, month: 10, day: 22)
    let oct23 = Day(year: 2026, month: 10, day: 23)
    let oct24 = Day(year: 2026, month: 10, day: 24)
    let oct25 = Day(year: 2026, month: 10, day: 25)

    let onNov1 = todayView(nights: nightsOct1ToNov1, showing: nov1)
    #expect(onNov1.weekStrip.earlierDay == oct25)

    let onOct25 = todayView(nights: nightsOct1ToNov1, showing: oct25)
    #expect(onOct25.weekStrip.laterDay == nov1)
    #expect(onOct25.weekStrip.title == "October 2026")
    #expect(
        onOct25.weekStrip.days.map(\.day) == [oct19, oct20, oct21, oct22, oct23, oct24, oct25]
    )
    #expect(
        onOct25.weekStrip.days.map(\.isShown) == [false, false, false, false, false, false, true]
    )
}

@Test func todayWithoutANightSaysNoNightYetAndShowsTodaysLoad() {
    // Yesterday's Night has every value, so any of them leaking onto today would show. Its Time
    // Asleep, 7 h 40 m against 8 h, gives it a Sleep Score of 96 (spec 010).
    let yesterday = Night(
        day: oct31,
        sleepingHR: 50,
        hrv: 62,
        respiratoryRate: 14.1,
        skinTemperature: 34.0,
        spo2: 97,
        timeAsleep: 27_600
    )
    let view = todayView(nights: [yesterday], showing: nov1)

    #expect(view.noNightMessage == "No Night yet")
    #expect(view.loadLabel == "Load")
    #expect(view.loadText == "5")
    #expect(view.pickerRange == oct31...nov1)
    #expect(view.sleepScoreText == "—")
    #expect(view.readinessText == "—")
    #expect(view.readinessBand == nil)
    #expect(view.tiles.isEmpty)
    #expect(view.timeAsleepTile == nil)
    #expect(view.vsBaseline == nil)
}

@Test func withNoNightsTheDatePickerRunsFromTodayToTodayAndBothArrowsAreDisabled() {
    let view = todayView(nights: [], showing: nov1)

    #expect(view.noNightMessage == "No Night yet")
    #expect(view.pickerRange == nov1...nov1)
    #expect(view.weekStrip.earlierDay == nil)
    #expect(view.weekStrip.laterDay == nil)
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
        sync: .idle
    )
    #expect(newYorkToday.noNightMessage == "No Night yet")
    #expect(newYorkToday.weekStrip.days.last?.day == oct31)
    #expect(newYorkToday.weekStrip.laterDay == nil)
    #expect(newYorkToday.pickerRange == oct31...oct31)

    // 2026-10-24T23:30Z is 00:30 BST on 25 Oct in London.
    let oct25 = Day(year: 2026, month: 10, day: 25)
    let justAfterMidnightOct25InLondon = Date(timeIntervalSince1970: 1_792_884_600)
    let londonToday = TodayView(
        nights: [],
        dayLoads: [],
        showing: oct25,
        now: justAfterMidnightOct25InLondon,
        timeZone: london,
        sync: .idle
    )
    #expect(londonToday.noNightMessage == "No Night yet")
    #expect(londonToday.weekStrip.days.last?.day == oct25)
    #expect(londonToday.weekStrip.laterDay == nil)
    #expect(londonToday.pickerRange == oct25...oct25)
}

@Test func theDatePickerAndWeekStripRunBackAcrossTheNewYear() {
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
        sync: .idle
    )
    #expect(view.noNightMessage == "No Night yet")
    #expect(view.pickerRange == dec31...jan1)
    #expect(view.weekStrip.title == "January 2027")
    #expect(view.weekStrip.days.map(\.number) == [26, 27, 28, 29, 30, 31, 1])
}

// MARK: Sync pill

private let strapNotFound =
    "Couldn't find the Strap. Check it's nearby and charged, then try again."
private let badFrame = "A Frame from the Strap failed its CRC check."

@Test(
    arguments: [
        (.syncing, .syncing, "Syncing", nil, true),
        (.justFinished, .successful, "Sync successful", nil, false),
        (
            .failed(reason: strapNotFound, cause: .strapUnreachable), .paused, "Sync paused",
            strapNotFound + " Serenix will try again next time you open it.", false
        ),
        (.failed(reason: badFrame, cause: .other), .failed, "Sync failed", badFrame, false),
    ] as [(SyncStatus, SyncPillKind, String, String?, Bool)]
)
func syncPillShowsWhereTheHistorySyncHasGot(
    sync: SyncStatus,
    kind: SyncPillKind,
    text: String,
    detail: String?,
    showsProgress: Bool
) {
    let pill = todayView(nights: [], showing: nov1, sync: sync).syncPill

    #expect(pill?.kind == kind)
    #expect(pill?.text == text)
    #expect(pill != nil && pill?.detail == detail)
    #expect(pill?.showsProgress == showsProgress)
}

@Test func withNothingToSayNoSyncPillShows() {
    let view = todayView(nights: [], showing: nov1, sync: .idle)

    #expect(view.syncPill == nil)
}

@Test func aSyncTheUserCancelledShowsNoSyncPill() {
    let view = todayView(
        nights: [],
        showing: nov1,
        sync: .failed(reason: "Cancelled mid-sync.", cause: .cancelled)
    )

    #expect(view.syncPill == nil)
}

// MARK: Rings

/// HRV, Sleeping HR and Time Asleep (seconds) against Baselines of 60 ms and 50 bpm, and Sleep
/// Need 8 h (the earlier Nights carry no Time Asleep, spec 009). 100 needs every input at its
/// best; 1 is the lowest Readiness there is, every input 3 or more worse than usual (spec 008).
@Test(
    arguments: [
        (95, 42, 28_800, "100", ReadinessBand.ready, "Ready"),
        (59, 50, 28_800, "67", .ready, "Ready"),
        (60, 50, 27_000, "66", .steady, "Steady"),
        (49, 50, 28_800, "34", .steady, "Steady"),
        (51, 50, 25_200, "33", .takeItEasy, "Take it easy"),
        (38, 58, 18_000, "1", .takeItEasy, "Take it easy"),
    ] as [(Double, Double, TimeInterval, String, ReadinessBand, String)]
)
func readinessShowsItsNumberAndBand(
    hrv: Double,
    sleepingHR: Double,
    timeAsleep: TimeInterval,
    text: String,
    band: ReadinessBand,
    word: String
) {
    let shown = Night(day: nov1, sleepingHR: sleepingHR, hrv: hrv, timeAsleep: timeAsleep)
    let view = todayView(nights: calibratedNightsBeforeNov1 + [shown], showing: nov1)

    #expect(view.readinessText == text)
    #expect(view.readinessBand == band)
    #expect(view.readinessBand?.word == word)
}

@Test func sleepScoreShowsItsNumber() {
    // Time Asleep 6 h 43 m (403 min) against Sleep Need 8 h: 83.96, so 84 (spec 010).
    let view = todayView(nights: [Night(day: nov1, timeAsleep: 24_180)], showing: nov1)

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
    // 1 Nov has three earlier Nights, so it has a Readiness (60) that 31 Oct mustn't show. Sleep
    // Scores (spec 010): 30 Oct's Time Asleep 6 h 29 m against 8 h is 81.04, so 81; its 1 h 31 m
    // short raises 1 Nov's Sleep Need to 8 h 22 m 45 s (spec 009), and 1 Nov's Time Asleep
    // 7 h 2 m against it is 83.94, so 84. Readiness: 1 Nov is 1.35 h short of its Sleep Need, HRV
    // and Sleeping HR at Baseline, so (−1.35 × 0.15) ÷ 0.9 = −0.224 gives 59.7, so 60 (spec 008).
    let nights = [
        Night(day: oct28, sleepingHR: 50, hrv: 60),
        Night(day: oct29, sleepingHR: 50, hrv: 60),
        Night(day: oct30, sleepingHR: 50, hrv: 60, timeAsleep: 23_340),
        Night(day: nov1, sleepingHR: 50, hrv: 60, timeAsleep: 25_320),
    ]
    let view = todayView(nights: nights, showing: oct31)

    #expect(view.sleepScoreText == "—")
    #expect(view.readinessText == "—")
    #expect(view.readinessBand == nil)
}

/// 2026-10-31T21:16:00Z.
private let onsetOct31At2116 = Date(timeIntervalSince1970: 1_793_481_360)
/// 2026-11-01T07:00:00Z.
private let finalWakeNov1At0700 = Date(timeIntervalSince1970: 1_793_516_400)

@Test func eachRingFillsToItsScoreOutOf100() {
    let view = todayView(
        // HRV 59 against 60 with Time Asleep 8 h, its Sleep Need: Readiness 67. Sleep Score
        // (spec 010): Sleep Sufficiency 100; 8 h asleep in a 9 h 44 m Sleep Period (21:16 to
        // 07:00) is 82.19%, so Sleep Efficiency 35.96; 0.75 × 100 + 0.25 × 35.96 = 83.99, so 84.
        nights: calibratedNightsBeforeNov1 + [
            Night(
                day: nov1,
                sleepingHR: 50,
                hrv: 59,
                sleepOnset: onsetOct31At2116,
                finalWake: finalWakeNov1At0700,
                timeAsleep: 28_800
            )
        ],
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
    // HRV 64 against 60, Sleeping HR at its Baseline: Readiness 80 once it's past Calibrating.
    let shown = Night(day: nov1, sleepingHR: 50, hrv: 64)

    let twoEarlier = todayView(
        nights: nightsBeforeNov1(hrv: [60, 60], sleepingHR: [50, 50]) + [shown],
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
        nights: [Night(day: nov1, sleepingHR: 50, hrv: 60)],
        showing: nov1
    )

    #expect(view.readinessText == "1/4")
    #expect(view.readinessBand == nil)
    #expect(view.readinessFill == 0)
}

@Test func calibratingCountsNightsByTheMetricWithFewestEarlierValues() {
    let nights =
        nightsBeforeNov1(hrv: [60, 60, 60], sleepingHR: [50])
        + [Night(day: nov1, sleepingHR: 50, hrv: 60)]
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

// MARK: Zones

/// Three earlier Nights at the same values, so 1 Nov's Baselines are exactly Sleeping HR 52 bpm,
/// HRV 60 ms, respiratory rate 14.0 br/min and skin temperature 34.0 °C.
private let exactBaselinesBeforeNov1 = nightsBeforeNov1(
    hrv: [60, 60, 60],
    sleepingHR: [52, 52, 52],
    respiratoryRate: [14.0, 14.0, 14.0],
    skinTemperature: [34.0, 34.0, 34.0]
)

private func nov1Tile(_ metric: NightlyMetric, of night: Night) -> MetricTile? {
    todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1).tile(metric)
}

// Values from spec 004. With 3 earlier Nights (under the 7 a measured Spread needs), the typical
// HRV Spread applies, so z = (ln v − ln 60) / 0.15: z = −1.5 at ≈47.91 and −2.5 at ≈41.24, so
// 48/47.9 and 41.3/41.2 sit either side of the Watch and Out of range edges; z = +2.5 at ≈87.30, so
// 87.2 is In range and 87.4 is Watch. A high HRV is never Out of range, however high (200).
@Test(
    arguments: [
        (48, .inRange), (47.9, .watch), (41.3, .watch), (41.2, .outOfRange),
        (87.2, .inRange), (87.4, .watch), (200, .watch),
    ] as [(Double, Zone)]
)
func hrvZoneAgainstABaselineOf60(hrv: Double, zone: Zone) {
    let tile = nov1Tile(.hrv, of: Night(day: nov1, hrv: hrv))

    #expect(tile?.baseline == 60)
    #expect(tile?.zone == zone)
}

// Values from spec 004. Sleeping HR uses a fixed gap, not a Spread, and only upward: with
// d = v − 52, In range while d < 3, Watch while 3 ≤ d < 5, Out of range from d ≥ 5. So 54.9 is
// In range, 55 and 56.9 are Watch, and 57 is Out of range. A lower Sleeping HR is never a warning,
// however low (40).
@Test(
    arguments: [
        (54.9, .inRange), (55, .watch), (56.9, .watch), (57, .outOfRange), (40, .inRange),
    ] as [(Double, Zone)]
)
func sleepingHRZoneAgainstABaselineOf52(sleepingHR: Double, zone: Zone) {
    let tile = nov1Tile(.sleepingHR, of: Night(day: nov1, sleepingHR: sleepingHR))

    #expect(tile?.baseline == 52)
    #expect(tile?.zone == zone)
}

// Values from spec 004. With 3 earlier Nights (under the 7 a measured Spread needs), the typical
// respiratory rate Spread applies, so z = (v − 14.0) / 0.5: In range while |z| ≤ 1.5 (14.0 ± 0.75),
// Watch while |z| ≤ 2.5 (14.0 ± 1.25), Out of range beyond. So 14.7 and 13.3 are In range, 14.8 and
// 15.25 are Watch, and 15.3 and 12.7 are Out of range.
@Test(
    arguments: [
        (14.7, .inRange), (13.3, .inRange), (14.8, .watch), (15.25, .watch),
        (15.3, .outOfRange), (12.7, .outOfRange),
    ] as [(Double, Zone)]
)
func respiratoryRateZoneAgainstABaselineOf14(respiratoryRate: Double, zone: Zone) {
    let tile = nov1Tile(.respiratoryRate, of: Night(day: nov1, respiratoryRate: respiratoryRate))

    #expect(tile?.baseline == 14.0)
    #expect(tile?.zone == zone)
}

@Test(arguments: [(34.3, .inRange), (33.6, .watch), (34.7, .outOfRange)] as [(Double, Zone)])
func skinTemperatureZoneAgainstABaselineOf34(skinTemperature: Double, zone: Zone) {
    let tile = nov1Tile(.skinTemperature, of: Night(day: nov1, skinTemperature: skinTemperature))

    #expect(tile?.baseline == 34.0)
    #expect(tile?.zone == zone)
}

@Test(
    arguments: [(95, .inRange), (94, .watch), (92, .watch), (91, .outOfRange)] as [(Double, Zone)]
)
func spo2ZoneIsSetByFixedLevelsFromTheFirstNight(spo2: Double, zone: Zone) {
    let firstNight = todayView(nights: [Night(day: nov1, spo2: spo2)], showing: nov1).tile(.spo2)
    #expect(firstNight?.baseline == nil)
    #expect(firstNight?.zone == zone)

    // Earlier Nights well above 95% change nothing: SpO2 has no Baseline.
    let afterOthers = todayView(
        nights: nightsBeforeNov1(spo2: [99, 99, 99]) + [Night(day: nov1, spo2: spo2)],
        showing: nov1
    ).tile(.spo2)
    #expect(afterOthers?.baseline == nil)
    #expect(afterOthers?.zone == zone)
}

@Test func changingTheNightsOwnHRVChangesItsZoneButNotItsBaseline() {
    let inRange = nov1Tile(.hrv, of: Night(day: nov1, hrv: 60))
    let outOfRange = nov1Tile(.hrv, of: Night(day: nov1, hrv: 40))

    #expect(inRange?.zone == .inRange)
    #expect(outOfRange?.zone == .outOfRange)
    #expect(inRange?.baseline == 60)
    #expect(outOfRange?.baseline == 60)
}

// MARK: Spread (through the Zone)

/// The Zone of 1 Nov's respiratory rate against the given earlier Nights (newest first).
private func respiratoryRateZone(_ value: Double, after earlier: [Double?]) -> Zone? {
    todayView(
        nights: nightsBeforeNov1(respiratoryRate: earlier)
            + [Night(day: nov1, respiratoryRate: value)],
        showing: nov1
    ).tile(.respiratoryRate)?.zone
}

/// The Zone of 1 Nov's HRV against the given earlier Nights (newest first).
private func hrvZone(_ value: Double, after earlier: [Double?]) -> Zone? {
    todayView(
        nights: nightsBeforeNov1(hrv: earlier) + [Night(day: nov1, hrv: value)],
        showing: nov1
    ).tile(.hrv)?.zone
}

// Values from spec 004. Six earlier Nights of 14.0: the typical Spread 0.5 applies, so
// z = 0.8 / 0.5 = 1.6, Watch. Seven: the scaled MAD is 0, floored to 0.3, so z = 0.8 / 0.3 = 2.67,
// Out of range.
@Test func respiratoryRateUsesTheTypicalSpreadUntilSevenEarlierNightsThenItsFloor() {
    #expect(respiratoryRateZone(14.8, after: Array(repeating: 14.0, count: 6)) == .watch)
    #expect(respiratoryRateZone(14.8, after: Array(repeating: 14.0, count: 7)) == .outOfRange)
}

// Values from spec 004. Earlier Nights 14.0, 14.4, 13.6, 14.8, 13.2, 14.0, 14.0: median 14.0;
// |value − 14.0| sorted is 0, 0, 0, 0.4, 0.4, 0.8, 0.8, median 0.4, so Spread = 1.4826 × 0.4 =
// 0.59304. In range while |d| ≤ 1.5 × 0.59304 = 0.88956 (13.11044 to 14.88956), Watch while
// |d| ≤ 2.5 × 0.59304 = 1.4826 (12.5174 to 15.4826), Out of range beyond.
@Test(
    arguments: [
        (14.88, .inRange), (13.12, .inRange), (14.9, .watch), (13.11, .watch),
        (15.48, .watch), (15.49, .outOfRange), (12.5, .outOfRange),
    ] as [(Double, Zone)]
)
func respiratoryRateZoneIsScaledByTheMADOfSevenEarlierNights(
    respiratoryRate: Double,
    zone: Zone
) {
    let earlier: [Double?] = [14.0, 14.4, 13.6, 14.8, 13.2, 14.0, 14.0]
    let tile = todayView(
        nights: nightsBeforeNov1(respiratoryRate: earlier)
            + [Night(day: nov1, respiratoryRate: respiratoryRate)],
        showing: nov1
    ).tile(.respiratoryRate)

    #expect(tile?.baseline == 14.0)
    #expect(tile?.zone == zone)
}

// Values from spec 004, the same seven earlier Nights: Spread = 1.4826 × 0.4 = 0.59304, so the
// In range band is 14.0 ∓ 1.5 × 0.59304 = 13.11044 to 14.88956, shown to one decimal place in the
// popup's Your Zones (spec 011).
@Test func respiratoryRateInRangeRowIsScaledByTheMADOfSevenEarlierNights() {
    let earlier: [Double?] = [14.0, 14.4, 13.6, 14.8, 13.2, 14.0, 14.0]
    let popup = todayView(
        nights: nightsBeforeNov1(respiratoryRate: earlier)
            + [Night(day: nov1, respiratoryRate: 14.0)],
        showing: nov1
    ).metricPopup(.respiratoryRate)

    #expect(popup?.baselineText == "14.0 br/min")
    #expect(popup?.zoneRows.first?.rangeText == "13.1–14.9 br/min")
}

// Values from spec 004. ln(50 / 60) = −0.18232. Seven earlier Nights of 60: the MAD is 0, floored
// to 0.10, so z = −1.82, Watch. Three: the typical 0.15 applies, so z = −1.22, In range.
// 54 against seven: ln(54 / 60) / 0.10 = −1.05, In range.
@Test func hrvSpreadIsFlooredAt010OnceSevenEarlierNightsHaveIt() {
    #expect(hrvZone(50, after: Array(repeating: 60, count: 7)) == .watch)
    #expect(hrvZone(50, after: Array(repeating: 60, count: 3)) == .inRange)
    #expect(hrvZone(54, after: Array(repeating: 60, count: 7)) == .inRange)
}

// Values from spec 004. Earlier Nights 40, 50, 60, 60, 60, 72, 90: median 60; |ln(v / 60)| sorted
// is 0, 0, 0, ln 1.2, ln 1.2, ln 1.5, ln 1.5, median ln 1.2 = 0.18232, so Spread = 1.4826 × ln 1.2 =
// 0.27031. The low In range edge is exp(ln 60 − 1.5 × 0.27031) ≈ 40.00 ms: 40.1 gives z = −1.49,
// In range; 39.9 gives z = −1.51, Watch. (On raw ms, or with the typical 0.15, both would be
// Out of range.)
// The popup's In range row is 60 × e^(−1.5 × 0.27031) = 40.00 to 60 × e^(2.5 × 0.27031) =
// 117.93 ms, shown in whole ms (spec 011, Your Zones).
@Test func hrvSpreadIsTheScaledMADOfLnRMSSD() {
    let earlier: [Double?] = [40, 50, 60, 60, 60, 72, 90]
    let tile = { (hrv: Double) in
        todayView(
            nights: nightsBeforeNov1(hrv: earlier) + [Night(day: nov1, hrv: hrv)],
            showing: nov1
        ).tile(.hrv)
    }

    #expect(tile(40.1)?.baseline == 60)
    #expect(tile(40.1)?.zone == .inRange)
    #expect(tile(39.9)?.zone == .watch)

    let popup = todayView(
        nights: nightsBeforeNov1(hrv: earlier) + [Night(day: nov1, hrv: 60)],
        showing: nov1
    ).metricPopup(.hrv)
    #expect(popup?.zoneRows.first?.rangeText == "40–118 ms")
}

// Spec 004: the Spread uses the same up-to-14 Nights as the median. The 14 newest earlier Nights
// are eight of 14.0, three of 13.0 and three of 15.0: median 14.0; deviations eight 0 and six 1.0,
// median 0, so the Spread is floored to 0.3. 14.2 gives z = 0.67 (In range), 14.5 gives 1.67
// (Watch), 14.8 gives 2.67 (Out of range).
// The six oldest are three of 12.0 and three of 16.0. Over all 20 the median is still 14.0 but the
// deviations become eight 0, six 1.0, six 2.0, median 1.0, so the Spread would be 1.4826 and all
// three values would be In range. Adding them must change no Zone.
// The gauge (0.5 + z / 5) uses the same Spread 0.3: 14.2 gives 0.5 + 0.6667 / 5 = 19/30 ≈ 0.6333,
// 14.5 gives 0.5 + 1.6667 / 5 = 5/6 ≈ 0.8333, and 14.8 gives 1.0333, clamped to 1. With the
// 20-Night Spread 1.4826 they would be ≈ 0.527, ≈ 0.567 and ≈ 0.608, so adding them must change
// no gauge either.
// The popup's Zone scale (spec 011: 0.5 + z / 7.5) also uses Spread 0.3: 14.2 gives
// 0.5 + 0.6667 / 7.5 = 0.5889, 14.5 gives 0.5 + 1.6667 / 7.5 = 0.7222, and 14.8 gives
// 0.5 + 2.6667 / 7.5 = 0.8556. With the 20-Night Spread 1.4826 they would be ≈ 0.518, ≈ 0.545 and
// ≈ 0.572.
@Test(
    arguments: [
        (14.2, .inRange, 19.0 / 30.0, 0.5889), (14.5, .watch, 5.0 / 6.0, 0.7222),
        (14.8, .outOfRange, 1, 0.8556),
    ] as [(Double, Zone, Double, Double)]
)
func respiratoryRateSpreadUsesOnlyTheFourteenMostRecentEarlierNights(
    respiratoryRate: Double,
    zone: Zone,
    gauge: Double,
    scalePosition: Double
) {
    let fourteenNewest: [Double?] = [
        14.0, 13.0, 15.0, 14.0, 13.0, 15.0, 14.0, 13.0, 15.0, 14.0, 14.0, 14.0, 14.0, 14.0,
    ]
    let sixOldest: [Double?] = [12.0, 16.0, 12.0, 16.0, 12.0, 16.0]

    for earlier in [fourteenNewest, fourteenNewest + sixOldest] {
        let view = todayView(
            nights: nightsBeforeNov1(respiratoryRate: earlier)
                + [Night(day: nov1, respiratoryRate: respiratoryRate)],
            showing: nov1
        )
        let tile = view.tile(.respiratoryRate)
        let popup = view.metricPopup(.respiratoryRate)

        #expect(tile?.zone == zone, "\(earlier.count) earlier Nights")
        #expect(
            isClose(tile?.gauge, to: gauge),
            "\(earlier.count) earlier Nights: gauge \(String(describing: tile?.gauge))"
        )
        #expect(
            isClose(popup?.scale?.valuePosition, to: scalePosition, within: 0.000_05),
            "\(earlier.count) earlier Nights: scale \(String(describing: popup?.scale))"
        )
    }
}

// MARK: Tile text

@Test func sleepingHRDifferenceIsInWholeSignedBpm() {
    let down = nov1Tile(.sleepingHR, of: Night(day: nov1, sleepingHR: 49))
    #expect(down?.differenceText == "\u{2212}3 bpm")

    let up = nov1Tile(.sleepingHR, of: Night(day: nov1, sleepingHR: 54))
    #expect(up?.differenceText == "+2 bpm")

    let none = nov1Tile(.sleepingHR, of: Night(day: nov1, sleepingHR: 51.6))
    #expect(none?.differenceText == "0 bpm")
}

@Test func hrvDifferenceIsAWholeSignedPercentageAgainstAnExactBaseline() {
    #expect(nov1Tile(.hrv, of: Night(day: nov1, hrv: 68.4))?.differenceText == "+14%")
    #expect(nov1Tile(.hrv, of: Night(day: nov1, hrv: 59.8))?.differenceText == "0%")
}

@Test func respiratoryRateDifferenceIsSignedToOneDecimalWithoutAUnit() {
    let up = nov1Tile(.respiratoryRate, of: Night(day: nov1, respiratoryRate: 14.4))
    #expect(up?.differenceText == "+0.4")

    let down = nov1Tile(.respiratoryRate, of: Night(day: nov1, respiratoryRate: 13.7))
    #expect(down?.differenceText == "\u{2212}0.3")

    let none = nov1Tile(.respiratoryRate, of: Night(day: nov1, respiratoryRate: 13.98))
    #expect(none?.differenceText == "0.0")
}

@Test func skinTemperatureDifferenceIsSignedToOneDecimalWithoutAUnit() {
    let up = nov1Tile(.skinTemperature, of: Night(day: nov1, skinTemperature: 34.4))
    #expect(up?.differenceText == "+0.4")

    let down = nov1Tile(.skinTemperature, of: Night(day: nov1, skinTemperature: 33.7))
    #expect(down?.differenceText == "\u{2212}0.3")

    let none = nov1Tile(.skinTemperature, of: Night(day: nov1, skinTemperature: 34.02))
    #expect(none?.differenceText == "0.0")
}

@Test(
    arguments: [
        (96, "95% or above"), (95, "95% or above"), (94, "Below 95%"), (92, "Below 95%"),
        (91, "Below 92%"),
    ] as [(Double, String)]
)
func spo2LineIsItsZoneLevelInWords(spo2: Double, line: String) {
    let tile = todayView(nights: [Night(day: nov1, spo2: spo2)], showing: nov1).tile(.spo2)

    #expect(tile?.differenceText == line)
}

@Test func eachMetricsValueShowsWithItsUnit() {
    let night = Night(
        day: nov1,
        sleepingHR: 52,
        hrv: 62,
        respiratoryRate: 14.2,
        skinTemperature: 34.1,
        spo2: 96
    )
    let view = todayView(nights: [night], showing: nov1)

    #expect(view.tile(.sleepingHR)?.valueText == "52 bpm")
    #expect(view.tile(.hrv)?.valueText == "62 ms")
    #expect(view.tile(.respiratoryRate)?.valueText == "14.2 br/min")
    #expect(view.tile(.skinTemperature)?.valueText == "34.1 °C")
    #expect(view.tile(.spo2)?.valueText == "96%")
}

@Test func valuesRoundToWholeNumbersOrOneDecimal() {
    let night = Night(
        day: nov1,
        sleepingHR: 51.6,
        respiratoryRate: 14.0,
        skinTemperature: 34.06,
        spo2: 95.6
    )
    let view = todayView(nights: [night], showing: nov1)

    #expect(view.tile(.sleepingHR)?.valueText == "52 bpm")
    #expect(view.tile(.respiratoryRate)?.valueText == "14.0 br/min")
    #expect(view.tile(.skinTemperature)?.valueText == "34.1 °C")
    #expect(view.tile(.spo2)?.valueText == "96%")
}

// MARK: Calibrating and missing tiles

@Test func aCalibratingMetricHasNoZoneButSpO2HasOne() {
    let earlier = nightsBeforeNov1(
        hrv: [60, 60],
        sleepingHR: [52, 52],
        respiratoryRate: [14.0, 14.0],
        skinTemperature: [34.0, 34.0],
        spo2: [97, 97]
    )
    let night = Night(
        day: nov1,
        sleepingHR: 60,
        hrv: 40,
        respiratoryRate: 16.0,
        skinTemperature: 35.0,
        spo2: 96
    )
    let view = todayView(nights: earlier + [night], showing: nov1)

    for metric in [NightlyMetric.sleepingHR, .hrv, .respiratoryRate, .skinTemperature] {
        #expect(view.tile(metric)?.baseline == nil, "\(metric)")
        #expect(view.tile(metric)?.zone == nil, "\(metric)")
        #expect(view.tile(metric)?.differenceText == "Calibrating", "\(metric)")
    }
    #expect(view.tile(.spo2)?.zone == .inRange)
    #expect(view.tile(.spo2)?.differenceText == "95% or above")
}

@Test func aNightMissingEveryNightlyMetricShowsDashesWithNoZone() {
    let earlier = nightsBeforeNov1(
        hrv: [60, 60, 60],
        sleepingHR: [52, 52, 52],
        respiratoryRate: [14.0, 14.0, 14.0],
        skinTemperature: [34.0, 34.0, 34.0],
        spo2: [97, 97, 97]
    )
    let view = todayView(nights: earlier + [Night(day: nov1)], showing: nov1)

    #expect(view.tiles.count == 5)
    for tile in view.tiles {
        #expect(tile.valueText == "—", "\(tile.metric)")
        #expect(tile.differenceText == "—", "\(tile.metric)")
        #expect(tile.zone == nil, "\(tile.metric)")
    }
}

@Test func aNightWithoutSpO2ShowsADashWhileItsOtherMetricsShow() {
    let view = todayView(nights: [Night(day: nov1, sleepingHR: 52)], showing: nov1)

    #expect(view.tile(.spo2)?.valueText == "—")
    #expect(view.tile(.spo2)?.differenceText == "—")
    #expect(view.tile(.spo2)?.zone == nil)
    #expect(view.tile(.sleepingHR)?.valueText == "52 bpm")
}

// MARK: Tile order and names

@Test func tilesRunSleepingHRHRVRespiratoryRateSkinTemperatureSpO2() {
    let view = todayView(nights: [Night(day: nov1)], showing: nov1)

    #expect(
        view.tiles.map(\.metric) == [.sleepingHR, .hrv, .respiratoryRate, .skinTemperature, .spo2]
    )
    #expect(
        view.tiles.map(\.metric.name) == [
            "Sleeping HR", "HRV", "Respiratory rate", "Skin temperature", "SpO2",
        ]
    )
}

// MARK: Resting HR tile (spec 007)

/// The name a grid tile shows: a Nightly Metric's name, or the Resting HR tile's.
private func gridTileName(_ tile: TodayTile) -> String {
    switch tile {
    case .metric(let metricTile): metricTile.metric.name
    case .restingHR(let restingHRTile): restingHRTile.name
    }
}

@Test func gridTilesRunSleepingHRThenRestingHRThenTheOtherMetricsAfterTimeAsleep() {
    let view = todayView(
        nights: [Night(day: nov1, timeAsleep: 27_600)],
        dayLoads: [DayLoad(day: nov1, load: 5, restingHR: 61.6)],
        showing: nov1
    )

    #expect(view.timeAsleepTile != nil)
    #expect(
        view.gridTiles.map(gridTileName) == [
            "Sleeping HR", "Resting HR", "HRV", "Respiratory rate", "Skin temperature", "SpO2",
        ]
    )
}

@Test func todaysRestingHRTileReadsWholeBpmSoFarTodayWithNoZoneAndAnEmptyGauge() {
    let view = todayView(
        nights: [Night(day: nov1)],
        dayLoads: [DayLoad(day: nov1, load: 5, restingHR: 61.6)],
        showing: nov1
    )

    #expect(view.restingHRTile?.name == "Resting HR")
    #expect(view.restingHRTile?.valueText == "62 bpm")
    #expect(view.restingHRTile?.statusText == "So far today")
    #expect(view.restingHRTile?.zone == nil)
    #expect(view.restingHRTile?.gauge == nil)
    // Tapping this tile opens the Resting HR popup (spec 011), tested under "Resting HR popup
    // (spec 011)" below; that the tap opens it is checked by hand on the phone.
}

@Test func anEarlierDaysRestingHRTileHasNoStatus() {
    let view = todayView(
        nights: [Night(day: oct31), Night(day: nov1)],
        dayLoads: [DayLoad(day: oct31, load: 12, restingHR: 58), DayLoad(day: nov1, load: 5)],
        showing: oct31
    )

    #expect(view.restingHRTile?.valueText == "58 bpm")
    #expect(view.restingHRTile?.statusText == nil)
}

@Test func aDayWithoutRestingHRShowsADashWithAnEmptyGauge() {
    let withoutRestingHR = todayView(
        nights: [Night(day: nov1)],
        dayLoads: [DayLoad(day: nov1, load: 5)],
        showing: nov1
    )
    let withoutDayLoad = todayView(nights: [Night(day: nov1)], dayLoads: [], showing: nov1)

    #expect(withoutRestingHR.restingHRTile?.valueText == "—")
    #expect(withoutRestingHR.restingHRTile?.name == "Resting HR")
    #expect(withoutRestingHR.restingHRTile?.gauge == nil)
    #expect(withoutDayLoad.restingHRTile?.valueText == "—")
    #expect(withoutDayLoad.restingHRTile?.gauge == nil)
}

/// Spec 002, "No Night for the Day": Resting HR comes from the Day, not the Night, so its tile
/// still shows on today without a Night.
@Test func todayWithoutANightStillShowsItsRestingHRTileSoFarTodayWithNoGrid() {
    let view = todayView(
        nights: [Night(day: oct31)],
        dayLoads: [DayLoad(day: nov1, load: 5, restingHR: 58)],
        showing: nov1
    )

    #expect(view.restingHRTile?.valueText == "58 bpm")
    #expect(view.restingHRTile?.statusText == "So far today")
    #expect(view.restingHRPopup != nil)
    #expect(view.gridTiles.isEmpty)
}

/// Spec 002, "No Night for the Day": an earlier Day without a Night shows its Resting HR tile
/// with no status.
@Test func anEarlierDayWithoutANightStillShowsItsRestingHRTileWithNoStatus() {
    let view = todayView(
        nights: [Night(day: Day(year: 2026, month: 10, day: 30)), Night(day: nov1)],
        dayLoads: [DayLoad(day: oct31, load: 12, restingHR: 58), DayLoad(day: nov1, load: 5)],
        showing: oct31
    )

    #expect(view.restingHRTile?.valueText == "58 bpm")
    #expect(view.restingHRTile?.statusText == nil)
    #expect(view.restingHRPopup != nil)
}

/// Spec 002, "No Night for the Day": with neither a Night nor a Resting HR there is no tile.
@Test func aDayWithoutANightOrRestingHRHasNoRestingHRTileOrPopup() {
    let withoutRestingHR = todayView(
        nights: [Night(day: oct31)],
        dayLoads: [DayLoad(day: nov1, load: 5)],
        showing: nov1
    )
    let withoutDayLoad = todayView(nights: [Night(day: oct31)], dayLoads: [], showing: nov1)

    #expect(withoutRestingHR.restingHRTile == nil)
    #expect(withoutRestingHR.restingHRPopup == nil)
    #expect(withoutDayLoad.restingHRTile == nil)
    #expect(withoutDayLoad.restingHRPopup == nil)
}

// MARK: Status words and gauges

// Values from spec 004, against Baselines HRV 60, Sleeping HR 52, respiratory rate 14.0 and skin
// temperature 34.0 with typical Spreads (HRV 0.15 on ln, respiratory rate 0.5).
// HRV: z = ln(v / 60) / 0.15, so 70 → +1.03 (In range, "Normal"), 90 → +2.70 (Watch, "High"),
// 41 → −2.54 (Out of range, "Low").
// Sleeping HR: 45 is below the Baseline, always In range ("Normal"); 55 is +3 (Watch, "High").
// Respiratory rate: 15.0 → z = +2 ("High"), 13.0 → z = −2 ("Low").
// Skin temperature: 34.5 is +0.5 ("High"), 33.5 is −0.5 ("Low").
// SpO2 keeps its fixed level words.
@Test(
    arguments: [
        (.hrv, Night(day: nov1, hrv: 70), "Normal"),
        (.hrv, Night(day: nov1, hrv: 90), "High"),
        (.hrv, Night(day: nov1, hrv: 41), "Low"),
        (.sleepingHR, Night(day: nov1, sleepingHR: 45), "Normal"),
        (.sleepingHR, Night(day: nov1, sleepingHR: 55), "High"),
        (.respiratoryRate, Night(day: nov1, respiratoryRate: 15.0), "High"),
        (.respiratoryRate, Night(day: nov1, respiratoryRate: 13.0), "Low"),
        (.skinTemperature, Night(day: nov1, skinTemperature: 34.5), "High"),
        (.skinTemperature, Night(day: nov1, skinTemperature: 33.5), "Low"),
        (.spo2, Night(day: nov1, spo2: 97), "95% or above"),
        (.spo2, Night(day: nov1, spo2: 93), "Below 95%"),
        (.spo2, Night(day: nov1, spo2: 90), "Below 92%"),
    ] as [(NightlyMetric, Night, String)]
)
func tileStatusWordAgainstExactBaselines(metric: NightlyMetric, night: Night, word: String) {
    #expect(nov1Tile(metric, of: night)?.statusText == word)
}

// Values from spec 004, against the same Baselines and typical Spreads. Each side ends where
// Watch turns into Out of range.
// HRV, 0.5 + z / (2 × 2.5) with z = ln(v / 60) / 0.15: 60 → 0.5; 30 → z = −4.62, 0.5 − 0.92,
// clamped to 0; 120 → z = +4.62, clamped to 1; 70 → z = ln(70 / 60) / 0.15 = 1.0277, 0.70553
// (unclamped, so it pins the ln and Spread scale).
// Respiratory rate, 0.5 + z / 5 with z = (v − 14.0) / 0.5: 15.0 → z = 2, 0.9; 13.5 → z = −1, 0.3;
// 16 → z = 4, 1.3, clamped to 1.
// Sleeping HR, 0.5 + d / (2 × 5): 54.5 → d = 2.5, 0.75; 47 → d = −5, 0.
// Skin temperature, 0.5 + d / (2 × 0.6): 33.7 → d = −0.3, 0.25.
// SpO2, fixed 88–100: 97 → 9 / 12 = 0.75; 85 → below 88, clamped to 0.
@Test(
    arguments: [
        (.hrv, Night(day: nov1, hrv: 60), 0.5),
        (.hrv, Night(day: nov1, hrv: 30), 0),
        (.hrv, Night(day: nov1, hrv: 120), 1),
        (.hrv, Night(day: nov1, hrv: 70), 0.705534239769678),
        (.respiratoryRate, Night(day: nov1, respiratoryRate: 15.0), 0.9),
        (.respiratoryRate, Night(day: nov1, respiratoryRate: 13.5), 0.3),
        (.respiratoryRate, Night(day: nov1, respiratoryRate: 16), 1),
        (.sleepingHR, Night(day: nov1, sleepingHR: 54.5), 0.75),
        (.sleepingHR, Night(day: nov1, sleepingHR: 47), 0),
        (.skinTemperature, Night(day: nov1, skinTemperature: 33.7), 0.25),
        (.spo2, Night(day: nov1, spo2: 97), 0.75),
        (.spo2, Night(day: nov1, spo2: 85), 0),
    ] as [(NightlyMetric, Night, Double)]
)
func tileGaugePositionAgainstExactBaselines(metric: NightlyMetric, night: Night, gauge: Double) {
    let tile = nov1Tile(metric, of: night)

    #expect(isClose(tile?.gauge, to: gauge), "gauge \(String(describing: tile?.gauge))")
}

@Test func aCalibratingMetricSaysCalibratingAndHasNoGaugeButSpO2Has() throws {
    let earlier = nightsBeforeNov1(
        hrv: [60, 60],
        sleepingHR: [52, 52],
        respiratoryRate: [14.0, 14.0],
        skinTemperature: [34.0, 34.0],
        spo2: [97, 97]
    )
    let night = Night(
        day: nov1,
        sleepingHR: 55,
        hrv: 54,
        respiratoryRate: 15.0,
        skinTemperature: 34.5,
        spo2: 97
    )
    let view = todayView(nights: earlier + [night], showing: nov1)

    for metric in [NightlyMetric.sleepingHR, .hrv, .respiratoryRate, .skinTemperature] {
        let tile = try #require(view.tile(metric), "\(metric)")
        #expect(tile.statusText == "Calibrating", "\(metric)")
        #expect(tile.gauge == nil, "\(metric)")
    }
    let spo2 = try #require(view.tile(.spo2))
    #expect(spo2.statusText == "95% or above")
    #expect(isClose(spo2.gauge, to: 0.75))
}

@Test func aMissingNightlyMetricHasADashForItsStatusWordAndNoGauge() {
    let earlier = nightsBeforeNov1(
        hrv: [60, 60, 60],
        sleepingHR: [52, 52, 52],
        respiratoryRate: [14.0, 14.0, 14.0],
        skinTemperature: [34.0, 34.0, 34.0],
        spo2: [97, 97, 97]
    )
    let view = todayView(nights: earlier + [Night(day: nov1)], showing: nov1)

    #expect(view.tiles.count == 5)
    for tile in view.tiles {
        #expect(tile.statusText == "—", "\(tile.metric)")
        #expect(tile.gauge == nil, "\(tile.metric)")
    }
}

// MARK: Time Asleep tile

/// 2026-10-31T22:45:00Z.
private let onsetOct31At2245 = Date(timeIntervalSince1970: 1_793_486_700)
/// 2026-11-01T06:57:00Z.
private let finalWakeNov1At0657 = Date(timeIntervalSince1970: 1_793_516_220)

@Test func timeAsleepShowsHoursAndMinutesAndTheSleepOnsetToFinalWakeSpan() {
    let night = Night(
        day: nov1,
        sleepOnset: onsetOct31At2245,
        finalWake: finalWakeNov1At0657,
        timeAsleep: 27_600
    )
    let tile = todayView(nights: [night], showing: nov1).timeAsleepTile

    #expect(tile?.valueText == "7h 40m")
    #expect(tile?.spanText == "22:45 → 06:57")
}

@Test(
    arguments: [(27_571, "7h 40m"), (27_629, "7h 40m"), (27_631, "7h 41m")]
        as [(TimeInterval, String)]
)
func timeAsleepRoundsToTheNearestMinute(timeAsleep: TimeInterval, text: String) {
    let tile = todayView(nights: [Night(day: nov1, timeAsleep: timeAsleep)], showing: nov1)
        .timeAsleepTile

    #expect(tile?.valueText == text)
}

@Test func theSleepOnsetToFinalWakeSpanIsInLocalTime() {
    let newYork = TimeZone(identifier: "America/New_York")!
    // 22:45Z on 31 Oct is 18:45 EDT; 06:57Z on 1 Nov is 01:57 EST (EDT ends at 06:00Z).
    let view = TodayView(
        nights: [Night(day: nov1, sleepOnset: onsetOct31At2245, finalWake: finalWakeNov1At0657)],
        dayLoads: [],
        showing: nov1,
        now: now,
        timeZone: newYork,
        sync: .idle
    )

    #expect(view.timeAsleepTile?.spanText == "18:45 → 01:57")
}

@Test func aNightWithoutTimeAsleepShowsADash() {
    let night = Night(day: nov1, sleepOnset: onsetOct31At2245, finalWake: finalWakeNov1At0657)
    let tile = todayView(nights: [night], showing: nov1).timeAsleepTile

    #expect(tile?.valueText == "—")
    #expect(tile?.spanText == "22:45 → 06:57")
}

@Test func theSpanIsADashWithoutSleepOnsetOrFinalWake() {
    let noOnset = Night(day: nov1, finalWake: finalWakeNov1At0657, timeAsleep: 27_600)
    #expect(todayView(nights: [noOnset], showing: nov1).timeAsleepTile?.spanText == "—")

    let noFinalWake = Night(day: nov1, sleepOnset: onsetOct31At2245, timeAsleep: 27_600)
    #expect(todayView(nights: [noFinalWake], showing: nov1).timeAsleepTile?.spanText == "—")
}

// MARK: Tiles heading

@Test func tilesAreHeadedLastNightOnTodayAndByDateOnEarlierDays() {
    let nights = [Night(day: oct31), Night(day: nov1)]

    #expect(todayView(nights: nights, showing: nov1).tilesHeading == "Last night")
    #expect(todayView(nights: nights, showing: oct31).tilesHeading == "Sat 31 Oct")
}

@Test func aDayWithoutANightHasNoTimeAsleepTile() {
    let view = todayView(nights: [Night(day: oct31, timeAsleep: 27_600)], showing: nov1)

    #expect(view.timeAsleepTile == nil)
    #expect(view.tiles.isEmpty)
}

// MARK: Bad values

@Test func skinTemperature06AboveBaselineIsWatchNotOutOfRange() {
    // 34.6 − 34.0 is 0.6000000000000014 in floating point; the spec's 0.6 is still Watch.
    #expect(nov1Tile(.skinTemperature, of: Night(day: nov1, skinTemperature: 34.6))?.zone == .watch)
    #expect(nov1Tile(.skinTemperature, of: Night(day: nov1, skinTemperature: 33.4))?.zone == .watch)
}

@Test func aValueTooLargeToShowCountsAsMissingRatherThanACrash() {
    let tile = nov1Tile(.hrv, of: Night(day: nov1, hrv: 1e300))

    #expect(tile?.valueText == "—")
    #expect(tile?.differenceText == "—")
    #expect(tile?.zone == nil)
}

@Test func aNegativeTimeAsleepCountsAsMissing() {
    let view = todayView(nights: [Night(day: nov1, timeAsleep: -300)], showing: nov1)

    #expect(view.timeAsleepTile?.valueText == "—")
}

// MARK: vs your Baseline

/// vs your Baseline's HRV and Sleeping HR comparisons; nil when it's Calibrating or absent.
private func baselineComparisons(_ view: TodayView) -> [BaselineComparison]? {
    guard case .comparisons(let comparisons) = view.vsBaseline else { return nil }
    return comparisons
}

@Test func hrvUp14PercentAndSleepingHRDown3BpmAreBothMarkedTheGoodWay() {
    let view = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, sleepingHR: 49, hrv: 68.4)],
        showing: nov1
    )
    let comparisons = baselineComparisons(view)

    #expect(comparisons?.map(\.metric) == [.hrv, .sleepingHR])

    let hrv = comparisons?.first
    #expect(hrv?.valueText == "68 ms")
    #expect(hrv?.differenceText == "+14%")
    #expect(hrv?.direction == .up)
    #expect(hrv?.movedTheGoodWay == true)

    let sleepingHR = comparisons?.last
    #expect(sleepingHR?.valueText == "49 bpm")
    #expect(sleepingHR?.differenceText == "\u{2212}3 bpm")
    #expect(sleepingHR?.direction == .down)
    #expect(sleepingHR?.movedTheGoodWay == true)
}

@Test func hrvDownAndSleepingHRUpAreBothMarkedTheBadWay() {
    let view = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, sleepingHR: 55, hrv: 54)],
        showing: nov1
    )
    let comparisons = baselineComparisons(view)

    let hrv = comparisons?.first
    #expect(hrv?.metric == .hrv)
    #expect(hrv?.differenceText == "\u{2212}10%")
    #expect(hrv?.direction == .down)
    #expect(hrv?.movedTheGoodWay == false)

    let sleepingHR = comparisons?.last
    #expect(sleepingHR?.metric == .sleepingHR)
    #expect(sleepingHR?.differenceText == "+3 bpm")
    #expect(sleepingHR?.direction == .up)
    #expect(sleepingHR?.movedTheGoodWay == false)
}

@Test func aDifferenceThatRoundsToZeroHasNoDirection() {
    let view = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, sleepingHR: 52.2, hrv: 60.1)],
        showing: nov1
    )
    let comparisons = baselineComparisons(view)

    let hrv = comparisons?.first
    #expect(hrv?.differenceText == "0%")
    #expect(hrv?.direction == nil)
    #expect(hrv?.movedTheGoodWay == nil)

    let sleepingHR = comparisons?.last
    #expect(sleepingHR?.differenceText == "0 bpm")
    #expect(sleepingHR?.direction == nil)
    #expect(sleepingHR?.movedTheGoodWay == nil)
}

@Test func aNightWithoutHRVComparesItAsDashesWithNoDirection() {
    let view = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, sleepingHR: 49)],
        showing: nov1
    )
    let comparisons = baselineComparisons(view)

    #expect(comparisons?.map(\.metric) == [.hrv, .sleepingHR])

    let hrv = comparisons?.first
    #expect(hrv?.valueText == "—")
    #expect(hrv?.differenceText == "—")
    #expect(hrv?.direction == nil)
    #expect(hrv?.movedTheGoodWay == nil)

    let sleepingHR = comparisons?.last
    #expect(sleepingHR?.differenceText == "\u{2212}3 bpm")
    #expect(sleepingHR?.movedTheGoodWay == true)
}

@Test func vsBaselineIsTheCalibratingLineWithTheNightsToGo() {
    let shown = Night(day: nov1, sleepingHR: 50, hrv: 60)

    let firstNight = todayView(nights: [shown], showing: nov1)
    #expect(firstNight.readinessText == "1/4")
    #expect(
        firstNight.vsBaseline
            == .calibrating(
                "Calibrating. Readiness starts once 4 Nights form your Baseline. 3 to go."
            )
    )

    let twoEarlier = todayView(
        nights: nightsBeforeNov1(hrv: [60, 60], sleepingHR: [50, 50]) + [shown],
        showing: nov1
    )
    #expect(twoEarlier.readinessText == "3/4")
    #expect(
        twoEarlier.vsBaseline
            == .calibrating(
                "Calibrating. Readiness starts once 4 Nights form your Baseline. 1 to go."
            )
    )
}

@Test func vsBaselineIsCalibratingWhileEitherBaselineIs() {
    let nights =
        nightsBeforeNov1(hrv: [60, 60, 60], sleepingHR: [50])
        + [Night(day: nov1, sleepingHR: 50, hrv: 60)]
    let view = todayView(nights: nights, showing: nov1)

    #expect(view.readinessText == "2/4")
    #expect(
        view.vsBaseline
            == .calibrating(
                "Calibrating. Readiness starts once 4 Nights form your Baseline. 2 to go."
            )
    )
}

@Test func aDayWithoutANightHasNoVsBaseline() {
    let view = todayView(nights: calibratedNightsBeforeNov1, showing: nov1)

    #expect(view.noNightMessage == "No Night yet")
    #expect(view.vsBaseline == nil)
}

// MARK: Readiness popup

@Test func readinessPopupShowsEachInputWithItsReason() {
    // Time Asleep 5 h, 3 h short of Sleep Need 8 h, the most it can cost: Readiness 81.
    // The previous Day, 31 Oct, has Load 12, but only 30 Oct comes before it, so typical Load
    // is calibrating. Sleep Score (spec 010): Time Asleep 5 h against Sleep Need 8 h, with no
    // Sleep Onset or Final Wake, is Sleep Sufficiency alone, 62.5, so 63 (halves up).
    let night = Night(
        day: nov1,
        sleepingHR: 49,
        hrv: 68.4,
        timeAsleep: 18_000
    )
    let popup = todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1)
        .readinessPopup
    func row(_ name: String) -> ReadinessWhyRow? { popup?.whyRows.first { $0.name == name } }

    #expect(popup?.readinessText == "81")
    #expect(popup?.band == .ready)
    #expect(
        Set(popup?.whyRows.map(\.name) ?? [])
            == ["HRV", "Sleeping HR", "Time Asleep", "Yesterday's Load"]
    )
    #expect(row("HRV")?.valueText == "68 ms")
    #expect(row("Sleeping HR")?.valueText == "49 bpm")
    #expect(row("Time Asleep")?.valueText == "5h 0m")
    #expect(row("Yesterday's Load")?.valueText == "12")
    #expect(row("HRV")?.reasonText == "+14% against your usual 60 ms.")
    #expect(row("Sleeping HR")?.reasonText == "\u{2212}3 bpm against your usual 52 bpm.")
    // A whole-hour shortfall keeps its minutes, as the Time Asleep tile does ("7h 0m").
    #expect(row("Time Asleep")?.reasonText == "3h 0m short of your Sleep Need.")
    #expect(
        row("Yesterday's Load")?.reasonText
            == "Typical Load is still calibrating, so it's left out."
    )
    #expect(popup?.sleepScoreText == "63")
}

/// Spec 007: vs your Baseline and the Readiness popup name the Night's metric "Sleeping HR".
@Test func vsBaselineAndTheReadinessPopupNameSleepingHR() {
    let night = Night(day: nov1, sleepingHR: 49, hrv: 68.4)
    let view = todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1)

    #expect(baselineComparisons(view)?.map(\.metric.name) == ["HRV", "Sleeping HR"])
    let rows = view.readinessPopup?.whyRows ?? []
    func row(_ name: String) -> ReadinessWhyRow? { rows.first { $0.name == name } }
    #expect(Set(rows.map(\.name)) == ["HRV", "Sleeping HR", "Time Asleep", "Yesterday's Load"])
    // This Night has no Time Asleep, so its row reads "—". The previous Day, 31 Oct, has Load 12
    // with typical Load calibrating.
    #expect(row("HRV")?.valueText == "68 ms")
    #expect(row("Sleeping HR")?.valueText == "49 bpm")
    #expect(row("Time Asleep")?.valueText == "\u{2014}")
    #expect(row("Yesterday's Load")?.valueText == "12")
    #expect(row("HRV")?.reasonText == "+14% against your usual 60 ms.")
    #expect(row("Sleeping HR")?.reasonText == "\u{2212}3 bpm against your usual 52 bpm.")
    #expect(
        row("Yesterday's Load")?.reasonText
            == "Typical Load is still calibrating, so it's left out."
    )
}

@Test func readinessPopupExplainsCalibratingWithTheNightsSoFar() {
    // Time Asleep 6 h 43 m against Sleep Need 8 h gives a Sleep Score, 84 (spec 010), which the
    // popup shows as usual while Calibrating (spec 012 supersedes spec 002 here).
    let night = Night(day: nov1, sleepingHR: 50, hrv: 60, timeAsleep: 24_180)
    let popup = todayView(
        nights: nightsBeforeNov1(hrv: [60, 60], sleepingHR: [50, 50]) + [night],
        showing: nov1
    ).readinessPopup

    #expect(popup?.readinessText == "3/4")
    #expect(popup?.band == nil)
    #expect(
        popup?.verdictText
            == "Readiness needs 4 Nights to form your Baseline. You have 3 so far."
    )
    // Spec 012, Calibrating: no Why list.
    #expect(popup?.whyRows == [])
    // Spec 012: the Sleep Score shows as usual while Calibrating.
    #expect(popup?.sleepScoreText == "84")
}

// MARK: Sleep popup

/// 2026-10-31T22:30:00Z.
private let timeInBedStartOct31At2230 = Date(timeIntervalSince1970: 1_793_485_800)
/// 2026-11-01T07:05:00Z.
private let timeInBedEndNov1At0705 = Date(timeIntervalSince1970: 1_793_516_700)

@Test func sleepPopupMinutesAwakeAreFinalWakeMinusSleepOnsetMinusTimeAsleep() {
    // 22:45 to 06:57 is 492 min; Time Asleep 27 600 s is 460 min; so 32 min awake. Sleep Score
    // (spec 010): Sleep Sufficiency 460 ÷ 480 = 95.83; 93.50% asleep is Sleep Efficiency 92.48;
    // 0.75 × 95.83 + 0.25 × 92.48 = 94.99, so 95.
    let night = Night(
        day: nov1,
        sleepOnset: onsetOct31At2245,
        finalWake: finalWakeNov1At0657,
        timeAsleep: 27_600,
        timeInBedStart: timeInBedStartOct31At2230,
        timeInBedEnd: timeInBedEndNov1At0705
    )
    let popup = todayView(nights: [night], showing: nov1).sleepPopup

    #expect(popup?.sleepScoreText == "95")
    #expect(popup?.timeInBedText == "22:30\u{2013}07:05")
    #expect(popup?.timeInBedDurationText == "8h 35m")
    #expect(popup?.sleepOnsetText == "22:45")
    #expect(popup?.finalWakeText == "06:57")
    #expect(popup?.timeAsleepText == "7h 40m")
    #expect(popup?.minutesAwakeText == "32 min")
}

@Test func sleepPopupMinutesAwakeIsADashWithoutTimeAsleep() {
    let night = Night(day: nov1, sleepOnset: onsetOct31At2245, finalWake: finalWakeNov1At0657)
    let popup = todayView(nights: [night], showing: nov1).sleepPopup

    #expect(popup?.timeAsleepText == "—")
    #expect(popup?.minutesAwakeText == "—")
}

@Test func sleepPopupMinutesAwakeIsADashWhenTimeAsleepIsLongerThanTheSleepPeriod() {
    // 30 000 s is 500 min, more than the 492 min from Sleep Onset to Final Wake.
    let night = Night(
        day: nov1,
        sleepOnset: onsetOct31At2245,
        finalWake: finalWakeNov1At0657,
        timeAsleep: 30_000
    )

    #expect(todayView(nights: [night], showing: nov1).sleepPopup?.minutesAwakeText == "—")
}

@Test func sleepPopupTimeInBedIsADashWithoutItsEnd() {
    let night = Night(
        day: nov1,
        sleepOnset: onsetOct31At2245,
        finalWake: finalWakeNov1At0657,
        timeAsleep: 27_600,
        timeInBedStart: timeInBedStartOct31At2230
    )
    let popup = todayView(nights: [night], showing: nov1).sleepPopup

    #expect(popup?.timeInBedText == "—")
    #expect(popup?.timeInBedDurationText == "—")
    #expect(popup?.minutesAwakeText == "32 min")
}

@Test func sleepPopupTimeInBedIsADashWhenItEndsBeforeItStarts() {
    let night = Night(
        day: nov1,
        timeInBedStart: timeInBedEndNov1At0705,
        timeInBedEnd: timeInBedStartOct31At2230
    )
    let popup = todayView(nights: [night], showing: nov1).sleepPopup

    #expect(popup?.timeInBedDurationText == "—")
}

// MARK: Nightly Metric popup

/// One Night a Day from 13 Oct to 1 Nov, HRV 40 ms on 13 Oct rising by 1 ms a Day to 59 ms on
/// 1 Nov; `hrvOnOct25` replaces 25 Oct's 52 ms.
private func nightsOct13ToNov1(hrvOnOct25: Double? = 52) -> [Night] {
    let october = (13...31).map { dayOfMonth in
        Night(
            day: Day(year: 2026, month: 10, day: dayOfMonth),
            hrv: dayOfMonth == 25 ? hrvOnOct25 : Double(27 + dayOfMonth)
        )
    }
    return october + [Night(day: nov1, hrv: 59)]
}

/// A Night after 1 Nov, which must never appear in 1 Nov's popup.
private let laterNightOnNov2 = Night(day: Day(year: 2026, month: 11, day: 2), hrv: 99)

/// Whether `value` is within `tolerance` of `expected`. By default that is floating-point error:
/// limits such as 34.0 − 0.3 needn't be exact in binary floating point. Values the spec quotes to
/// 2 dp pass a looser tolerance such as 0.005.
private func isClose(_ value: Double?, to expected: Double, within tolerance: Double = 1e-9) -> Bool
{
    value.map { abs($0 - expected) < tolerance } ?? false
}

// Values from spec 004, with typical Spreads (three earlier Nights). HRV: Spread 0.15 on ln(RMSSD),
// so the band is 60 × e^(−1.5 × 0.15) = 60 × e^−0.225 = 47.91097 to 60 × e^(2.5 × 0.15) =
// 60 × e^0.375 = 87.29948 ms. Respiratory rate: Spread 0.5, so 14.0 ∓ 1.5 × 0.5 = 13.25 to 14.75.
// Sleeping HR: no lower limit, upper 52 + 3 = 55. Skin temperature: 34.0 ± 0.3. Shown in the
// popup's Baseline fact and In range row, rounded as each metric's values are (spec 011).
@Test func metricPopupShowsTheBaselineFactAndItsInRangeRow() {
    let night = Night(
        day: nov1,
        sleepingHR: 52,
        hrv: 60,
        respiratoryRate: 14.0,
        skinTemperature: 34.0,
        spo2: 97
    )
    let view = todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1)

    let hrv = view.metricPopup(.hrv)
    #expect(hrv?.baselineText == "60 ms")
    #expect(hrv?.zoneRows.first?.rangeText == "48–87 ms")

    let sleepingHR = view.metricPopup(.sleepingHR)
    #expect(sleepingHR?.baselineText == "52 bpm")
    #expect(sleepingHR?.zoneRows.first?.rangeText == "under 55 bpm")

    let respiratoryRate = view.metricPopup(.respiratoryRate)
    #expect(respiratoryRate?.baselineText == "14.0 br/min")
    #expect(respiratoryRate?.zoneRows.first?.rangeText == "13.3–14.8 br/min")

    let skinTemperature = view.metricPopup(.skinTemperature)
    #expect(skinTemperature?.baselineText == "34.0 °C")
    #expect(skinTemperature?.zoneRows.first?.rangeText == "33.7 to 34.3 °C")

    let spo2 = view.metricPopup(.spo2)
    #expect(spo2 != nil && spo2?.baselineText == nil)
    #expect(spo2?.zoneRows.first?.rangeText == "95% and up")
}

@Test func spo2PopupShowsItsLevelWithNoBaselineFactAndZonesOnFixedLevels() {
    let night = Night(day: nov1, spo2: 97)
    let popup = todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1)
        .metricPopup(.spo2)

    #expect(popup?.valueText == "97%")
    #expect(popup?.verdictText == "A healthy level.")
    #expect(popup?.zone == .inRange)
    #expect(popup != nil && popup?.baselineText == nil)
    #expect(popup?.zonesHeading == "Zones")
}

@Test func aCalibratingMetricPopupReadsCalibratingWithNoZonesRows() {
    let nights = nightsBeforeNov1(hrv: [60, 60]) + [Night(day: nov1, hrv: 60)]
    let popup = todayView(nights: nights, showing: nov1).metricPopup(.hrv)

    #expect(
        popup?.verdictText
            == "Calibrating: Serenix needs 3 earlier Nights with HRV to know what's usual for you (2 so far)."
    )
    #expect(popup?.baselineText == "Calibrating")
    #expect(popup != nil && popup?.zoneRows.isEmpty == true)
}

// Spec 011: the popup's heading, pill and verdict.

@Test func metricPopupHeadingNamesTheEveningBeforeAndTheNightsDate() {
    let nov1Popup = todayView(nights: [Night(day: nov1, hrv: 60)], showing: nov1)
        .metricPopup(.hrv)
    #expect(nov1Popup?.nightText == "Night of 31 Oct–1 Nov")

    // 2026-11-02T08:12:00Z, 08:12 local in London, so 2 Nov is today.
    let nov2Now = Date(timeIntervalSince1970: 1_793_607_120)
    let nov2Popup = todayView(
        nights: [Night(day: nov1, hrv: 60), laterNightOnNov2],
        showing: Day(year: 2026, month: 11, day: 2),
        at: nov2Now
    ).metricPopup(.hrv)
    #expect(nov2Popup?.nightText == "Night of 1–2 Nov")
}

// HRV with a typical Spread (0.15) against a Baseline of 60: 48 is 48 / 60 = 0.8, so −20%, and
// z = ln 0.8 / 0.15 = −1.49, In range; 45 is −25%, z = ln 0.75 / 0.15 = −1.92, Watch.
// Sleeping HR 57 against a Baseline of 52 is +5 bpm, Out of range (spec 004).
@Test func metricPopupVerdictAgainstABaselineEndsWithItsZoneInWords() {
    let hrv48 = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, hrv: 48)],
        showing: nov1
    ).metricPopup(.hrv)
    #expect(hrv48?.statusText == "Normal")
    #expect(hrv48?.verdictText == "\u{2212}20% against your Baseline: about usual for you.")
    #expect(hrv48?.zone == .inRange)

    let hrv45 = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, hrv: 45)],
        showing: nov1
    ).metricPopup(.hrv)
    #expect(hrv45?.statusText == "Low")
    #expect(hrv45?.verdictText == "\u{2212}25% against your Baseline: unusual for you.")
    #expect(hrv45?.zone == .watch)

    let sleepingHR57 = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, sleepingHR: 57)],
        showing: nov1
    ).metricPopup(.sleepingHR)
    #expect(sleepingHR57?.statusText == "High")
    #expect(
        sleepingHR57?.verdictText == "+5 bpm against your Baseline: well outside your usual."
    )
    #expect(sleepingHR57?.zone == .outOfRange)
}

@Test(
    arguments: [
        (97, "95% or above", "A healthy level.", .inRange),
        (93, "Below 95%", "A little low.", .watch),
        (90, "Below 92%", "Low.", .outOfRange),
    ] as [(Double, String, String, Zone)]
)
func spo2PopupVerdictSaysItsLevelInWords(spo2: Double, status: String, verdict: String, zone: Zone)
{
    let popup = todayView(nights: [Night(day: nov1, spo2: spo2)], showing: nov1)
        .metricPopup(.spo2)

    #expect(popup?.statusText == status)
    #expect(popup?.verdictText == verdict)
    #expect(popup?.zone == zone)
}

@Test func aCalibratingMetricPopupSaysHowManyEarlierNightsItHasWithNoZone() {
    let nights = nightsBeforeNov1(hrv: [60, 60]) + [Night(day: nov1, hrv: 60)]
    let popup = todayView(nights: nights, showing: nov1).metricPopup(.hrv)

    #expect(popup?.statusText == "Calibrating")
    #expect(
        popup?.verdictText
            == "Calibrating: Serenix needs 3 earlier Nights with HRV to know what's usual for you "
            + "(2 so far)."
    )
    #expect(popup != nil && popup?.zone == nil)
}

@Test func aMetricPopupForANightMissingTheValueSaysSoWithNoZone() {
    let view = todayView(nights: exactBaselinesBeforeNov1 + [Night(day: nov1)], showing: nov1)

    let hrv = view.metricPopup(.hrv)
    #expect(hrv?.valueText == "—")
    #expect(hrv?.statusText == "—")
    #expect(hrv?.verdictText == "No HRV for this Night.")
    #expect(hrv != nil && hrv?.zone == nil)

    let sleepingHR = view.metricPopup(.sleepingHR)
    #expect(sleepingHR?.verdictText == "No Sleeping HR for this Night.")
    #expect(sleepingHR != nil && sleepingHR?.zone == nil)
}

// Spec 011: the Zone scale. Positions are quoted to 4 dp in the spec, so they're compared within
// 0.00005.

/// Whether `segments` are, left to right, the `expected` Zones with their from–to positions to
/// 4 dp.
private func segmentsMatch(
    _ segments: [MetricPopupScaleSegment]?,
    _ expected: [(Zone, Double, Double)]
) -> Bool {
    guard let segments, segments.count == expected.count else { return false }
    return zip(segments, expected).allSatisfy { segment, expected in
        segment.zone == expected.0
            && isClose(segment.from, to: expected.1, within: 0.000_05)
            && isClose(segment.to, to: expected.2, within: 0.000_05)
    }
}

// HRV 48 against a Baseline of 60 with a typical Spread (0.15): z = ln 0.8 / 0.15 = −1.4876, so
// 0.5 + z / 7.5 = 0.3017.
@Test func metricPopupScalePlacesTheValueAndTheBaselineOnTheBar() {
    let popup = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, hrv: 48)],
        showing: nov1
    ).metricPopup(.hrv)
    let scale = popup?.scale

    #expect(popup?.zone == .inRange)
    #expect(isClose(scale?.valuePosition, to: 0.30, within: 0.005))
    #expect(isClose(scale?.baselinePosition, to: 0.5))
    // Spec 011: the tick is labelled "Baseline 62", the Baseline as values are shown, no unit.
    #expect(scale?.baselineLabel == "Baseline 60")
}

// HRV 200 against 60: z = ln(200 / 60) / 0.15 = 8.03, far past the bar's right end, and Watch
// (spec 004: above the In range band is Watch).
@Test func aValuePastTheEndOfTheScaleSitsAtTheEnd() {
    let hrv200 = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, hrv: 200)],
        showing: nov1
    ).metricPopup(.hrv)
    #expect(hrv200?.zone == .watch)
    #expect(isClose(hrv200?.scale?.valuePosition, to: 1))
    #expect(hrv200?.verdictText.hasSuffix("against your Baseline: unusual for you.") == true)

    // Sleeping HR 40 against 52: 0.5 − 12 / 15 = −0.3, so the left end.
    let sleepingHR40 = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, sleepingHR: 40)],
        showing: nov1
    ).metricPopup(.sleepingHR)
    #expect(sleepingHR40?.zone == .inRange)
    #expect(isClose(sleepingHR40?.scale?.valuePosition, to: 0))
}

// Sleeping HR 57 against 52: 0.5 + 5 / 15 = 0.8333.
@Test func sleepingHRScalePositionIsItsDifferenceInBpm() {
    let scale = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, sleepingHR: 57)],
        showing: nov1
    ).metricPopup(.sleepingHR)?.scale

    #expect(isClose(scale?.valuePosition, to: 0.8333, within: 0.000_05))
    #expect(isClose(scale?.baselinePosition, to: 0.5))
}

// Skin temperature 34.3 against a Baseline of 33.8: +0.5 °C, Watch, at 0.5 + 0.5 / 1.8 = 0.7778.
@Test func skinTemperatureScalePositionIsItsDifferenceInDegrees() {
    let nights =
        nightsBeforeNov1(skinTemperature: [33.8, 33.8, 33.8])
        + [Night(day: nov1, skinTemperature: 34.3)]
    let popup = todayView(nights: nights, showing: nov1).metricPopup(.skinTemperature)

    #expect(popup?.zone == .watch)
    #expect(isClose(popup?.scale?.valuePosition, to: 0.7778, within: 0.000_05))
    #expect(isClose(popup?.scale?.baselinePosition, to: 0.5))
    #expect(popup?.scale?.baselineLabel == "Baseline 33.8")
}

// SpO2 93: (93 − 88) / 12 = 0.4167, and no Baseline tick.
@Test func spo2ScaleIsOnFixedLevelsWithNoBaselineTick() {
    let popup = todayView(nights: [Night(day: nov1, spo2: 93)], showing: nov1).metricPopup(.spo2)
    let scale = popup?.scale

    #expect(popup?.zone == .watch)
    #expect(isClose(scale?.valuePosition, to: 0.4167, within: 0.000_05))
    #expect(scale != nil && scale?.baselinePosition == nil)
    #expect(scale != nil && scale?.baselineLabel == nil)
}

@Test func metricPopupScaleSegmentsAreFixedPerMetric() {
    let night = Night(
        day: nov1,
        sleepingHR: 52,
        hrv: 60,
        respiratoryRate: 14.0,
        skinTemperature: 34.0,
        spo2: 97
    )
    let view = todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1)

    #expect(
        segmentsMatch(
            view.metricPopup(.hrv)?.scale?.segments,
            [
                (.outOfRange, 0, 0.1667), (.watch, 0.1667, 0.3), (.inRange, 0.3, 0.8333),
                (.watch, 0.8333, 1),
            ]
        )
    )
    #expect(
        segmentsMatch(
            view.metricPopup(.respiratoryRate)?.scale?.segments,
            [
                (.outOfRange, 0, 0.1667), (.watch, 0.1667, 0.3), (.inRange, 0.3, 0.7),
                (.watch, 0.7, 0.8333), (.outOfRange, 0.8333, 1),
            ]
        )
    )
    #expect(
        segmentsMatch(
            view.metricPopup(.sleepingHR)?.scale?.segments,
            [(.inRange, 0, 0.7), (.watch, 0.7, 0.8333), (.outOfRange, 0.8333, 1)]
        )
    )
    #expect(
        segmentsMatch(
            view.metricPopup(.skinTemperature)?.scale?.segments,
            [
                (.outOfRange, 0, 0.1667), (.watch, 0.1667, 0.3333), (.inRange, 0.3333, 0.6667),
                (.watch, 0.6667, 0.8333), (.outOfRange, 0.8333, 1),
            ]
        )
    )
    #expect(
        segmentsMatch(
            view.metricPopup(.spo2)?.scale?.segments,
            [(.outOfRange, 0, 0.3333), (.watch, 0.3333, 0.5833), (.inRange, 0.5833, 1)]
        )
    )
}

@Test func metricPopupScaleSegmentsDoNotDependOnTheNight() {
    let low = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, hrv: 40, spo2: 90)],
        showing: nov1
    )
    let high = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, hrv: 90, spo2: 99)],
        showing: nov1
    )

    let lowHRV = low.metricPopup(.hrv)?.scale?.segments
    #expect(lowHRV != nil && lowHRV == high.metricPopup(.hrv)?.scale?.segments)
    let lowSpO2 = low.metricPopup(.spo2)?.scale?.segments
    #expect(lowSpO2 != nil && lowSpO2 == high.metricPopup(.spo2)?.scale?.segments)
}

@Test func aMetricPopupWithoutAZoneHasNoScale() {
    let calibrating = todayView(
        nights: nightsBeforeNov1(hrv: [60, 60]) + [Night(day: nov1, hrv: 60)],
        showing: nov1
    ).metricPopup(.hrv)
    #expect(calibrating != nil && calibrating?.scale == nil)

    let missing = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, sleepingHR: 52)],
        showing: nov1
    ).metricPopup(.hrv)
    #expect(missing != nil && missing?.scale == nil)
}

// Spec 011: Your Zones. Range texts are the spec's success criteria, word for word ("–" is an en
// dash).

/// The Zones rows' Zones, top to bottom: always In range, Watch, Out of range.
private let zoneRowOrder: [Zone] = [.inRange, .watch, .outOfRange]

// HRV against 60 with the typical Spread (0.15): spec 004's In range band is 47.9 to 87.3, and
// W = exp(ln 60 − 2.5 × 0.15) = 41.2. 48 is In range.
@Test func hrvZonesRowsAreItsBandAroundTheBaselineWithTheNightsRowMarked() {
    let popup = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, hrv: 48)],
        showing: nov1
    ).metricPopup(.hrv)

    #expect(popup?.zonesHeading == "Your Zones · Baseline 60 ms")
    #expect(popup?.zoneRows.map(\.zone) == zoneRowOrder)
    #expect(
        popup?.zoneRows.map(\.rangeText) == ["48–87 ms", "41–48 ms, or above 87 ms", "under 41 ms"]
    )
    #expect(popup?.zoneRows.map(\.isThisNight) == [true, false, false])
    #expect(
        popup?.zoneRows.map(\.nameText) == ["In range ← this Night", "Watch", "Out of range"]
    )
}

// Sleeping HR 57 against 52: +5 bpm, Out of range (spec 004's cut-offs B+3 and B+5).
@Test func sleepingHRZonesRowsAreFixedGapsAboveTheBaseline() {
    let popup = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, sleepingHR: 57)],
        showing: nov1
    ).metricPopup(.sleepingHR)

    #expect(popup?.zonesHeading == "Your Zones · Baseline 52 bpm")
    #expect(popup?.zoneRows.map(\.zone) == zoneRowOrder)
    #expect(popup?.zoneRows.map(\.rangeText) == ["under 55 bpm", "55 to 57 bpm", "57 bpm and up"])
    #expect(popup?.zoneRows.map(\.isThisNight) == [false, false, true])
}

// Spec 004's seven earlier Nights: Baseline 14.0, Spread 0.59304, so In range 13.11 to 14.89 and
// Watch out to 12.52 and 15.48. 14.0 is In range.
@Test func respiratoryRateZonesRowsAreScaledByItsSpread() {
    let earlier: [Double?] = [14.0, 14.4, 13.6, 14.8, 13.2, 14.0, 14.0]
    let popup = todayView(
        nights: nightsBeforeNov1(respiratoryRate: earlier)
            + [Night(day: nov1, respiratoryRate: 14.0)],
        showing: nov1
    ).metricPopup(.respiratoryRate)

    #expect(popup?.zonesHeading == "Your Zones · Baseline 14.0 br/min")
    #expect(popup?.zoneRows.map(\.zone) == zoneRowOrder)
    #expect(
        popup?.zoneRows.map(\.rangeText) == [
            "13.1–14.9 br/min", "12.5–13.1 or 14.9–15.5 br/min", "under 12.5 or above 15.5 br/min",
        ]
    )
    #expect(popup?.zoneRows.map(\.isThisNight) == [true, false, false])
}

// Skin temperature 34.3 against 33.8: +0.5 °C, Watch (spec 004's cut-offs ±0.3 and ±0.6).
@Test func skinTemperatureZonesRowsAreFixedGapsEitherSideOfTheBaseline() {
    let popup = todayView(
        nights: nightsBeforeNov1(skinTemperature: [33.8, 33.8, 33.8])
            + [Night(day: nov1, skinTemperature: 34.3)],
        showing: nov1
    ).metricPopup(.skinTemperature)

    #expect(popup?.zonesHeading == "Your Zones · Baseline 33.8 °C")
    #expect(popup?.zoneRows.map(\.zone) == zoneRowOrder)
    #expect(
        popup?.zoneRows.map(\.rangeText) == [
            "33.5 to 34.1 °C", "33.2 to 33.5 or 34.1 to 34.4 °C", "under 33.2 or above 34.4 °C",
        ]
    )
    #expect(popup?.zoneRows.map(\.isThisNight) == [false, true, false])
}

// SpO2 has no Baseline: its Zones are fixed levels, from the first Night. 93 is Watch.
@Test func spo2ZonesAreFixedLevelsHeadedZones() {
    let popup = todayView(nights: [Night(day: nov1, spo2: 93)], showing: nov1).metricPopup(.spo2)

    #expect(popup?.zonesHeading == "Zones")
    #expect(popup?.zoneRows.map(\.zone) == zoneRowOrder)
    #expect(popup?.zoneRows.map(\.rangeText) == ["95% and up", "92% to 95%", "under 92%"])
    #expect(popup?.zoneRows.map(\.isThisNight) == [false, true, false])
}

@Test func aNightMissingTheValueHasZonesRowsWithNoneMarked() {
    let popup = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, sleepingHR: 52)],
        showing: nov1
    ).metricPopup(.hrv)

    #expect(popup?.zonesHeading == "Your Zones · Baseline 60 ms")
    #expect(popup?.zoneRows.map(\.zone) == zoneRowOrder)
    #expect(popup?.zoneRows.map(\.isThisNight) == [false, false, false])
    #expect(popup?.zoneRows.map(\.nameText) == ["In range", "Watch", "Out of range"])
}

@Test func aCalibratingMetricPopupHasNoZonesRows() {
    let popup = todayView(
        nights: nightsBeforeNov1(hrv: [60, 60]) + [Night(day: nov1, hrv: 60)],
        showing: nov1
    ).metricPopup(.hrv)

    #expect(popup != nil && popup?.zoneRows.isEmpty == true)
    #expect(popup != nil && popup?.zonesHeading == nil)
}

// Spec 011: Last 14 Nights blocks and the facts.

/// The positions (0 = oldest) of the blocks with no value.
private func noValuePositions(_ popup: MetricPopup?) -> [Int]? {
    popup?.blocks.enumerated().filter { $0.element.state == .noValue }.map(\.offset)
}

// 1 Nov 2026 is a Sunday, so its 14 dates run Monday 19 Oct to Sunday 1 Nov.
@Test func metricPopupBlocksAreTheNightShownsDateAndThe13BeforeItOldestFirst() {
    let nights = [laterNightOnNov2] + nightsOct13ToNov1().reversed()
    let popup = todayView(nights: nights, showing: nov1).metricPopup(.hrv)

    #expect(
        popup?.blocks.map(\.weekdayLetter)
            == ["M", "T", "W", "T", "F", "S", "S", "M", "T", "W", "T", "F", "S", "S"]
    )
    #expect(popup?.blocks.map(\.isNightShown) == Array(repeating: false, count: 13) + [true])
}

@Test func datesWithoutANightAreBlocksWithNoValue() {
    // Nights on 12 of the 14 dates: none on Thu 22 Oct (position 3) or Tue 27 Oct (position 8).
    let missingDays = [Day(year: 2026, month: 10, day: 22), Day(year: 2026, month: 10, day: 27)]
    let nights = nightsOct13ToNov1().filter { !missingDays.contains($0.day) }
    let popup = todayView(nights: nights, showing: nov1).metricPopup(.hrv)

    #expect(popup?.blocks.count == 14)
    #expect(noValuePositions(popup) == [3, 8])
}

@Test func aNightWithoutTheValueIsABlockWithNoValue() {
    // 25 Oct (position 6) has a Night, but without HRV.
    let popup = todayView(nights: nightsOct13ToNov1(hrvOnOct25: nil), showing: nov1)
        .metricPopup(.hrv)

    #expect(noValuePositions(popup) == [6])
}

// HRV 60 on 29, 30 and 31 Oct, and 1 Nov: 29 Oct has no earlier Night, 30 Oct one and 31 Oct two,
// so all three are Calibrating; 1 Nov has three and is In range against 60. 19 to 28 Oct have no
// Night.
@Test func aCalibratingNightIsABlockWithNoZone() {
    let nights = nightsBeforeNov1(hrv: [60, 60, 60]) + [Night(day: nov1, hrv: 60)]
    let popup = todayView(nights: nights, showing: nov1).metricPopup(.hrv)

    let expected: [MetricPopupBlockState] =
        Array(repeating: .noValue, count: 10) + [.noZone, .noZone, .noZone, .zone(.inRange)]
    #expect(popup?.blocks.map(\.state) == expected)
}

// Sleeping HR, oldest first: 52 on 19, 20 and 21 Oct; 55 on 22 Oct; 56 on 23 to 31 Oct and 1 Nov.
// 22 Oct's own Baseline is the median of 52, 52, 52 = 52, so d = 55 − 52 = +3: Watch (spec 004:
// 3 ≤ d < 5). 1 Nov's Baseline is the median of its 13 earlier Nights (52 ×3, 55, 56 ×9), the 7th
// value, 56; against that 55 would be d = −1, In range. The block keeps 22 Oct's own Watch.
@Test func anEarlierNightsBlockIsItsZoneAgainstItsOwnBaseline() {
    let oldestFirst: [Double?] = [52, 52, 52, 55] + Array(repeating: 56, count: 9)
    let nights =
        nightsBeforeNov1(sleepingHR: Array(oldestFirst.reversed()))
        + [Night(day: nov1, sleepingHR: 56)]
    let popup = todayView(nights: nights, showing: nov1).metricPopup(.sleepingHR)

    #expect(popup?.baselineText == "56 bpm")
    // 22 Oct is position 3 (19 Oct is position 0).
    #expect(popup?.blocks.count == 14)
    #expect(popup?.blocks.dropFirst(3).first?.state == .zone(.watch))
}

// The 14 dates hold HRV 46 to 59, with 41.4 on 25 Oct. Older Nights (40 to 45 ms on 13 to 18 Oct,
// 200 ms on 12 Oct) and the later 2 Nov Night (99 ms) are outside them.
@Test func lowestAndHighestAreOverTheFourteenBlocksOnlyFormattedAsOnTheTile() {
    let nights =
        [Night(day: Day(year: 2026, month: 10, day: 12), hrv: 200)]
        + nightsOct13ToNov1(hrvOnOct25: 41.4) + [laterNightOnNov2]
    let popup = todayView(nights: nights, showing: nov1).metricPopup(.hrv)

    #expect(popup?.lowestText == "41 ms")
    #expect(popup?.highestText == "59 ms")
}

@Test func lowestAndHighestAreDashesWhenNoBlockHasAValue() {
    // Only 12 Oct, older than the 14 dates, has a Sleeping HR.
    let nights =
        [Night(day: Day(year: 2026, month: 10, day: 12), sleepingHR: 50)] + nightsOct13ToNov1()
    let popup = todayView(nights: nights, showing: nov1).metricPopup(.sleepingHR)

    #expect(popup?.lowestText == "—")
    #expect(popup?.highestText == "—")
}

@Test func baselineFactIsTheBaselineWithItsUnitOrCalibratingAndSpO2HasNone() {
    let calibrated = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, hrv: 48, spo2: 97)],
        showing: nov1
    )
    #expect(calibrated.metricPopup(.hrv)?.baselineText == "60 ms")

    let spo2 = calibrated.metricPopup(.spo2)
    #expect(spo2 != nil && spo2?.baselineText == nil)

    let calibrating = todayView(
        nights: nightsBeforeNov1(hrv: [60, 60]) + [Night(day: nov1, hrv: 60)],
        showing: nov1
    ).metricPopup(.hrv)
    #expect(calibrating?.baselineText == "Calibrating")
}

/// Spec 011's Text table, word for word: What it is, then What moves it split on " · ".
private func specText(of metric: NightlyMetric) -> (whatItIs: String, whatMovesIt: [String]) {
    switch metric {
    case .sleepingHR:
        let whatItIs: String =
            "Your lowest sustained heart rate while asleep. Lower than usual is fine; a rise of a "
            + "few bpm over your Baseline often comes with a late meal, alcohol, illness or hard "
            + "training."
        return (
            whatItIs,
            [
                "Alcohol", "A late, heavy meal", "Illness coming on",
                "Hard training the day before", "A warm bedroom",
            ]
        )
    case .hrv:
        let whatItIs: String =
            "How much the time between your heartbeats varies while you sleep, as RMSSD. It's "
            + "personal, so compare it only with your own Baseline. Higher than usual is "
            + "generally a good sign; a drop well below it is worth noticing."
        return (
            whatItIs,
            ["Alcohol", "Short or broken sleep", "Illness", "Hard training", "Stress"]
        )
    case .respiratoryRate:
        let whatItIs: String =
            "Breaths per minute while you sleep. It barely changes from Night to Night, so even a "
            + "small rise above your Baseline stands out."
        return (
            whatItIs,
            ["Illness, especially of the chest or airways", "Being at altitude", "Alcohol"]
        )
    case .skinTemperature:
        let whatItIs: String =
            "The temperature of the skin under the Strap while you sleep. Only the change from "
            + "your Baseline matters: the number itself depends on the room, your bedding and "
            + "how the Strap sits."
        return (
            whatItIs,
            [
                "Fever or illness", "The menstrual cycle", "Room temperature and bedding",
                "How tightly the Strap is worn",
            ]
        )
    case .spo2:
        let whatItIs: String =
            "How much oxygen your blood is carrying, measured in short SpO2 Windows while you "
            + "sleep. It's judged against fixed levels, not a Baseline."
        return (
            whatItIs,
            ["Being at altitude", "Pauses in breathing during sleep", "A loose Strap"]
        )
    }
}

@Test(arguments: [NightlyMetric.sleepingHR, .hrv, .respiratoryRate, .skinTemperature, .spo2])
func metricPopupExplainsWhatTheMetricIsAndWhatMovesIt(metric: NightlyMetric) {
    let night = Night(
        day: nov1,
        sleepingHR: 52,
        hrv: 60,
        respiratoryRate: 14,
        skinTemperature: 34,
        spo2: 97
    )
    let popup = todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1)
        .metricPopup(metric)

    #expect(popup?.whatItIsText == specText(of: metric).whatItIs)
    #expect(popup?.whatMovesItTexts == specText(of: metric).whatMovesIt)
}

@Test func metricPopupTextsAreTheSameWhetherCalibratingOrMissingTheValue() {
    let inRange = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, hrv: 60)],
        showing: nov1
    ).metricPopup(.hrv)
    let calibrating = todayView(
        nights: nightsBeforeNov1(hrv: [60, 60]) + [Night(day: nov1, hrv: 60)],
        showing: nov1
    ).metricPopup(.hrv)
    let missing = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1)],
        showing: nov1
    ).metricPopup(.hrv)

    for popup in [inRange, calibrating, missing] {
        #expect(popup?.whatItIsText == specText(of: .hrv).whatItIs)
        #expect(popup?.whatMovesItTexts == specText(of: .hrv).whatMovesIt)
    }
}

// MARK: Resting HR popup (spec 011)

@Test func todaysRestingHRPopupReadsTodayItsValueAndSoFarToday() {
    let popup = todayView(
        nights: [Night(day: nov1)],
        dayLoads: [DayLoad(day: nov1, load: 5, restingHR: 57)],
        showing: nov1
    ).restingHRPopup

    #expect(popup?.dateText == "Today")
    #expect(popup?.valueText == "57 bpm")
    #expect(
        popup?.sentenceText == "So far today. A stiller moment later today can still lower it."
    )
}

@Test func anEarlierDaysRestingHRPopupHasItsDateAndNoSentence() {
    let popup = todayView(
        nights: [Night(day: oct31), Night(day: nov1)],
        dayLoads: [DayLoad(day: oct31, load: 12, restingHR: 58), DayLoad(day: nov1, load: 5)],
        showing: oct31
    ).restingHRPopup

    #expect(popup?.dateText == "Sat 31 Oct")
    #expect(popup?.valueText == "58 bpm")
    #expect(popup != nil && popup?.sentenceText == nil)
}

@Test func aRestingHRPopupWithoutRestingHRShowsADashAndSaysSoTodayOrEarlier() {
    let today = todayView(
        nights: [Night(day: nov1)],
        dayLoads: [DayLoad(day: nov1, load: 5)],
        showing: nov1
    ).restingHRPopup
    let earlier = todayView(
        nights: [Night(day: oct31), Night(day: nov1)],
        dayLoads: [DayLoad(day: nov1, load: 5, restingHR: 57)],
        showing: oct31
    ).restingHRPopup

    #expect(today?.valueText == "—")
    #expect(today?.sentenceText == "No Resting HR for this Day.")
    #expect(earlier?.dateText == "Sat 31 Oct")
    #expect(earlier?.valueText == "—")
    #expect(earlier?.sentenceText == "No Resting HR for this Day.")
}

/// Resting HR on each Day from 19 Oct (position 0) to 1 Nov (position 13): 58 bpm, except 55.4
/// on 25 Oct (position 6) and 63.6 on 30 Oct (position 11). 22 Oct (position 3) has no DayLoad
/// and 27 Oct (position 8) a DayLoad without Resting HR. Older Days, outside the 14, hold 40 on
/// 18 Oct and 90 on 5 Oct.
private let restingHRDayLoadsOct5ToNov1: [DayLoad] =
    [
        DayLoad(day: Day(year: 2026, month: 10, day: 5), load: 10, restingHR: 90),
        DayLoad(day: Day(year: 2026, month: 10, day: 18), load: 10, restingHR: 40),
    ]
    + (19...31).compactMap { date -> DayLoad? in
        let day = Day(year: 2026, month: 10, day: date)
        switch date {
        case 22: return nil
        case 25: return DayLoad(day: day, load: 10, restingHR: 55.4)
        case 27: return DayLoad(day: day, load: 10)
        case 30: return DayLoad(day: day, load: 10, restingHR: 63.6)
        default: return DayLoad(day: day, load: 10, restingHR: 58)
        }
    }
    + [DayLoad(day: nov1, load: 5, restingHR: 58)]

// 1 Nov 2026 is a Sunday, so its 14 Days run Monday 19 Oct to Sunday 1 Nov.
@Test func restingHRPopupBlocksAreTheDayShownAndThe13BeforeItOldestFirst() {
    let popup = todayView(
        nights: [Night(day: nov1)],
        dayLoads: restingHRDayLoadsOct5ToNov1,
        showing: nov1
    ).restingHRPopup

    #expect(
        popup?.blocks.map(\.weekdayLetter)
            == ["M", "T", "W", "T", "F", "S", "S", "M", "T", "W", "T", "F", "S", "S"]
    )
    #expect(popup?.blocks.map(\.isDayShown) == Array(repeating: false, count: 13) + [true])
}

@Test func daysWithoutRestingHRAreRestingHRPopupBlocksWithNoValue() {
    let popup = todayView(
        nights: [Night(day: nov1)],
        dayLoads: restingHRDayLoadsOct5ToNov1,
        showing: nov1
    ).restingHRPopup

    #expect(popup?.blocks.count == 14)
    #expect(
        popup?.blocks.enumerated().filter { !$0.element.hasValue }.map(\.offset) == [3, 8]
    )
}

@Test func restingHRPopupLowestAndHighestAreOverTheFourteenDaysOnlyInWholeBpm() {
    let popup = todayView(
        nights: [Night(day: nov1)],
        dayLoads: restingHRDayLoadsOct5ToNov1,
        showing: nov1
    ).restingHRPopup

    #expect(popup?.lowestText == "55 bpm")
    #expect(popup?.highestText == "64 bpm")
}

@Test func restingHRPopupLowestAndHighestAreDashesWhenNoDayHasRestingHR() {
    // Only 18 Oct, older than the 14 Days, has a Resting HR.
    let popup = todayView(
        nights: [Night(day: nov1)],
        dayLoads: [
            DayLoad(day: Day(year: 2026, month: 10, day: 18), load: 10, restingHR: 40),
            DayLoad(day: nov1, load: 5),
        ],
        showing: nov1
    ).restingHRPopup

    #expect(popup?.lowestText == "—")
    #expect(popup?.highestText == "—")
}

@Test func restingHRPopupTextsAreSpecElevensRestingHRRowWordForWord() {
    let popup = todayView(
        nights: [Night(day: nov1)],
        dayLoads: [DayLoad(day: nov1, load: 5, restingHR: 57)],
        showing: nov1
    ).restingHRPopup

    #expect(
        popup?.whatItIsText
            == "Your lowest sustained heart rate on a Day while awake and still, outside your "
            + "Sleep Period. Load is worked out against it. It has no Baseline or Zone, so it "
            + "isn't coloured."
    )
    #expect(
        popup?.whatMovesItTexts
            == ["Caffeine", "Stress", "How still you were during the Day", "Fitness, over weeks"]
    )
}

// MARK: Popups on a Day without a Night

@Test func aDayWithoutANightHasNoPopups() {
    let view = todayView(nights: calibratedNightsBeforeNov1, showing: nov1)

    #expect(view.readinessPopup == nil)
    #expect(view.sleepPopup == nil)
    for metric in [NightlyMetric.sleepingHR, .hrv, .respiratoryRate, .skinTemperature, .spo2] {
        #expect(view.metricPopup(metric) == nil)
    }
}

@Test func aDayOutsideTheCalendarReadsAsTheDateItRollsOverToRatherThanCrashing() {
    // Month 13 of 2026 rolls over to January 2027; 1 Jan 2027 is a Friday.
    let view = todayView(nights: [], showing: Day(year: 2026, month: 13, day: 1))

    #expect(view.tilesHeading == "Fri 1 Jan")
}

@Test func theDatePickerGetsMiddayOfItsEndsAndOfTheDayShown() {
    let view = todayView(nights: [Night(day: oct30), Night(day: nov1)], showing: oct31)

    // Midday in London, which is GMT after 25 Oct: 30 Oct and 1 Nov 12:00Z, and 31 Oct 12:00Z.
    #expect(
        view.pickerDates
            == Date(
                timeIntervalSince1970: 1_793_361_600
            )...Date(timeIntervalSince1970: 1_793_534_400)
    )
    #expect(view.shownDate == Date(timeIntervalSince1970: 1_793_448_000))
}

@Test func aNightDatedAfterTodayDoesNotStretchTheDatePickerPastToday() {
    let view = todayView(nights: [Night(day: Day(year: 2026, month: 11, day: 2))], showing: nov1)

    #expect(view.pickerRange == nov1...nov1)
}

// MARK: Greeting and Profile

/// A time on 1 Nov 2026, London, where local time equals UTC.
private func onNov1(_ hour: Int, _ minute: Int) -> Date {
    // 2026-11-01T00:00:00Z.
    Date(timeIntervalSince1970: 1_793_491_200 + Double(hour * 3600 + minute * 60))
}

@Test(arguments: [
    (5, 0, "Good morning!"),
    (8, 12, "Good morning!"),
    (11, 59, "Good morning!"),
    (12, 0, "Good afternoon!"),
    (17, 59, "Good afternoon!"),
    (18, 0, "Good evening!"),
    (4, 59, "Good evening!"),
])
func theGreetingFitsTheLocalTimeOfDayWithTheProfileNameUnderIt(
    hour: Int,
    minute: Int,
    greeting: String
) {
    let view = todayView(
        nights: [],
        showing: nov1,
        at: onNov1(hour, minute),
        profileName: "Ellis"
    )

    #expect(view.greeting == greeting)
    #expect(view.greetingName == "Ellis")
}

@Test func anEarlierDayHasTheSameGreetingAndName() {
    let view = todayView(nights: [], showing: oct31, at: onNov1(8, 12), profileName: "Ellis")

    #expect(view.greeting == "Good morning!")
    #expect(view.greetingName == "Ellis")
}

@Test(arguments: [nil, "   "] as [String?])
func withoutAProfileNameTheGreetingStandsAlone(profileName: String?) {
    let view = todayView(nights: [], showing: nov1, at: onNov1(8, 12), profileName: profileName)

    #expect(view.greeting == "Good morning!")
    #expect(view.greetingName == nil)
}

@Test func theAvatarLetterIsTheProfileNamesFirstLetterUpperCased() {
    let view = todayView(nights: [], showing: nov1, profileName: "ellis")

    #expect(view.avatarLetter == "E")
}

@Test func theProfileNameIsTrimmedForTheAvatarLetterAndMenuName() {
    let view = todayView(nights: [], showing: nov1, profileName: "  Ellis ")

    #expect(view.avatarLetter == "E")
    #expect(view.menuName == "Ellis")
}

@Test(arguments: [nil, "   "] as [String?])
func withoutAProfileNameThereIsNoAvatarLetterAndTheMenuAsksForOne(profileName: String?) {
    let view = todayView(nights: [], showing: nov1, profileName: profileName)

    #expect(view.avatarLetter == nil)
    #expect(view.menuName == "Add your name")
}

@Test func syncNowOffersARetryOnlyAfterAPausedOrFailedSync() {
    func offersRetry(_ sync: SyncStatus) -> Bool {
        todayView(nights: [], showing: nov1, sync: sync).syncOffersRetry
    }

    #expect(offersRetry(.failed(reason: "Not found.", cause: .strapUnreachable)))
    #expect(offersRetry(.failed(reason: "Bad Frame.", cause: .other)))
    #expect(!offersRetry(.failed(reason: "Cancelled mid-sync.", cause: .cancelled)))
    #expect(!offersRetry(.idle))
    #expect(!offersRetry(.syncing))
    #expect(!offersRetry(.justFinished))
}

@Test func onlyPausedAndFailedSyncPillsCanBeSwipedAway() {
    func canBeDismissed(_ sync: SyncStatus) -> Bool? {
        todayView(nights: [], showing: nov1, sync: sync).syncPill?.canBeDismissed
    }

    #expect(canBeDismissed(.failed(reason: "Not found.", cause: .strapUnreachable)) == true)
    #expect(canBeDismissed(.failed(reason: "Bad Frame.", cause: .other)) == true)
    #expect(canBeDismissed(.syncing) == false)
    #expect(canBeDismissed(.justFinished) == false)
}

@Test func theWeekStripIsTitledWithTheMonthOfTheDayShown() {
    let oct28 = Day(year: 2026, month: 10, day: 28)
    let onOct28 = todayView(nights: nightsOct1ToNov1, showing: oct28)
    let onNov1 = todayView(nights: nightsOct1ToNov1, showing: nov1)

    // Both show the strip 26 Oct to 1 Nov; its title follows the Day shown, not the last Day.
    #expect(onOct28.weekStrip.days.map(\.number) == [26, 27, 28, 29, 30, 31, 1])
    #expect(onOct28.weekStrip.title == "October 2026")
    #expect(onNov1.weekStrip.days.map(\.number) == [26, 27, 28, 29, 30, 31, 1])
    #expect(onNov1.weekStrip.title == "November 2026")
}

@Test func theLaterWeekArrowStopsAtToday() {
    let view = todayView(nights: nightsOct1ToNov1, showing: Day(year: 2026, month: 10, day: 28))

    #expect(view.weekStrip.laterDay == nov1)
}

@Test func theEarlierWeekArrowIsDisabledOnTheEarliestNightsDay() {
    let nights = [Night(day: oct30), Night(day: nov1)]

    #expect(todayView(nights: nights, showing: oct30).weekStrip.earlierDay == nil)
}

// MARK: Readiness advice

@Test func readyAdviceSaysItsAGoodDayToPush() {
    // HRV and Sleeping HR at their Baselines: Readiness 70.
    let night = Night(day: nov1, sleepingHR: 52, hrv: 60)
    let view = todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1)

    #expect(
        view.readinessAdvice
            == "You've recovered well. A good day to push: go for a harder session if you feel like it."
    )
}

@Test func steadyAdviceWithNothingOffIsJustTheBandSentence() {
    // HRV and Sleeping HR at their Baselines, Time Asleep 7 h, 1 h short of Sleep Need 8 h:
    // Readiness 62.
    let night = Night(day: nov1, sleepingHR: 52, hrv: 60, timeAsleep: 25_200)
    let view = todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1)

    #expect(
        view.readinessAdvice
            == "You're part-way recovered. Train at a moderate pace and keep your Load under 50 today."
    )
}

@Test func takeItEasyAdviceSaysWhyFromTheNightsNumbers() {
    // HRV 14% below and Sleeping HR 4 bpm above their Baselines: Readiness 17.
    let night = Night(day: nov1, sleepingHR: 56, hrv: 51.6)
    let view = todayView(
        nights: exactBaselinesBeforeNov1 + [night],
        dayLoads: [DayLoad(day: oct31, load: 82)],
        showing: nov1
    )

    #expect(
        view.readinessAdvice
            == "Yesterday's Load was high (82), HRV is 14% below your Baseline and "
            + "Sleeping HR is up 4 bpm. Your body hasn't recovered yet. Rest, hydrate and get to bed early, and keep "
            + "your Load under 33 today."
    )
}

@Test func aLoadBelowTheHighMarkYesterdayIsNotMentioned() {
    // Take it easy needs HRV or Sleeping HR worse than usual, so the Night gives its reasons
    // too: Readiness 17.
    let night = Night(day: nov1, sleepingHR: 56, hrv: 51.6)
    let view = todayView(
        nights: exactBaselinesBeforeNov1 + [night],
        dayLoads: [DayLoad(day: oct31, load: 54)],
        showing: nov1
    )

    #expect(
        view.readinessAdvice
            == "HRV is 14% below your Baseline and Sleeping HR is up 4 bpm. Your body hasn't "
            + "recovered yet. Rest, hydrate and get to bed early, and keep your Load under 33 today."
    )
}

@Test func aLoadAtTheHighMarkYesterdayIsMentioned() {
    // Take it easy needs HRV or Sleeping HR worse than usual, so the Night gives its reasons
    // too: Readiness 17.
    let night = Night(day: nov1, sleepingHR: 56, hrv: 51.6)
    let view = todayView(
        nights: exactBaselinesBeforeNov1 + [night],
        dayLoads: [DayLoad(day: oct31, load: 55)],
        showing: nov1
    )

    #expect(
        view.readinessAdvice
            == "Yesterday's Load was high (55), HRV is 14% below your Baseline and Sleeping HR is "
            + "up 4 bpm. Your body hasn't recovered yet. Rest, hydrate and get to bed early, and "
            + "keep your Load under 33 today."
    )
}

@Test func thereIsNoAdviceWhileReadinessIsCalibrating() {
    // A Night with HRV and Sleeping HR, so only Calibrating keeps it from a Readiness.
    let view = todayView(nights: [Night(day: nov1, sleepingHR: 50, hrv: 60)], showing: nov1)

    #expect(view.readinessText == "1/4")
    #expect(view.readinessAdvice == nil)
}

// Against Baselines of HRV 60 and Sleeping HR 52, with no Time Asleep:
// - HRV 14% below, but Sleeping HR 8 bpm under lifts it: Readiness 82;
// - Sleeping HR up 4 bpm, but HRV 20% above lifts it: Readiness 80.
// Yesterday's high Load isn't given as a reason either.
@Test(arguments: [(51.6, 44.0), (72.0, 56.0)])
func readyAdviceGivesNoReasonsEvenWhenNumbersAreOff(hrv: Double, sleepingHR: Double) {
    let night = Night(day: nov1, sleepingHR: sleepingHR, hrv: hrv)
    let view = todayView(
        nights: exactBaselinesBeforeNov1 + [night],
        dayLoads: [DayLoad(day: oct31, load: 82)],
        showing: nov1
    )

    #expect(
        view.readinessAdvice
            == "You've recovered well. A good day to push: go for a harder session if you feel like it."
    )
}

@Test func twoReasonsAreJoinedWithAnd() {
    // HRV 58 against 60 and Sleeping HR 54 against 52, with no Time Asleep: Readiness 50.
    let night = Night(day: nov1, sleepingHR: 54, hrv: 58)
    let view = todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1)

    #expect(
        view.readinessAdvice
            == "HRV is 3% below your Baseline and Sleeping HR is up 2 bpm. You're part-way "
            + "recovered. Train at a moderate pace and keep your Load under 50 today."
    )
}

// MARK: Add your age (spec 005)

@Test func aLoadMissingForNoMaxHRAsksForTheAgeAndOpensTheProfileMenu() {
    let noMaxHR = [
        DayLoad(day: oct31, load: nil, missingReason: .noMaxHR),
        DayLoad(day: nov1, load: nil, missingReason: .noMaxHR),
    ]
    let today = todayView(nights: [Night(day: nov1)], dayLoads: noMaxHR, showing: nov1)
    let earlier = todayView(nights: [Night(day: oct31)], dayLoads: noMaxHR, showing: oct31)

    #expect(today.loadLabel == "Add your age")
    #expect(today.loadText == "—")
    #expect(today.loadOpensProfileMenu)
    #expect(earlier.loadLabel == "Add your age")
    #expect(earlier.loadOpensProfileMenu)
}

@Test(arguments: [LoadMissing.noRecords, .maxHRNotAboveRestingHR])
func aLoadMissingForAnotherReasonKeepsTheUsualLabelAndNoTap(reason: LoadMissing) {
    let missing = [
        DayLoad(day: oct31, load: nil, missingReason: reason),
        DayLoad(day: nov1, load: nil, missingReason: reason),
    ]
    let today = todayView(nights: [Night(day: nov1)], dayLoads: missing, showing: nov1)
    let earlier = todayView(nights: [Night(day: oct31)], dayLoads: missing, showing: oct31)

    #expect(today.loadLabel == "Load")
    #expect(!today.loadOpensProfileMenu)
    #expect(earlier.loadLabel == "Load")
    #expect(!earlier.loadOpensProfileMenu)
}

@Test func aLoadThatIsThereKeepsTheUsualLabelAndNoTap() {
    let view = todayView(
        nights: [Night(day: nov1)],
        dayLoads: [DayLoad(day: nov1, load: 40)],
        showing: nov1
    )

    #expect(view.loadText == "40")
    #expect(view.loadLabel == "Load")
    #expect(!view.loadOpensProfileMenu)
}
