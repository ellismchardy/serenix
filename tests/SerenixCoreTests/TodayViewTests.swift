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
    restingHR: [Double?] = [],
    respiratoryRate: [Double?] = [],
    skinTemperature: [Double?] = [],
    spo2: [Double?] = []
) -> [Night] {
    let count = [hrv, restingHR, respiratoryRate, skinTemperature, spo2].map(\.count).max()!
    return (0..<count).map { index in
        Night(
            day: Day(year: 2026, month: 10, day: 31 - index),
            restingHR: index < restingHR.count ? restingHR[index] : nil,
            hrv: index < hrv.count ? hrv[index] : nil,
            respiratoryRate: index < respiratoryRate.count ? respiratoryRate[index] : nil,
            skinTemperature: index < skinTemperature.count ? skinTemperature[index] : nil,
            spo2: index < spo2.count ? spo2[index] : nil
        )
    }
}

/// Three earlier Nights with HRV and Resting HR, so Readiness on 1 Nov is past Calibrating.
private let calibratedNightsBeforeNov1 = nightsBeforeNov1(
    hrv: [60, 60, 60],
    restingHR: [50, 50, 50]
)

// MARK: Which Day is shown and the week strip

private let oct26 = Day(year: 2026, month: 10, day: 26)
private let oct27 = Day(year: 2026, month: 10, day: 27)
private let oct28 = Day(year: 2026, month: 10, day: 28)
private let oct29 = Day(year: 2026, month: 10, day: 29)

@Test func todayShowsItsNightInAWeekStripEndingOnToday() {
    // A distinct Sleep Score on each Night, so showing the wrong one would fail.
    let nights = [Night(day: oct30, sleepScore: 71), Night(day: nov1, sleepScore: 84)]
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
    let nights = [Night(day: oct30, sleepScore: 71), Night(day: nov1, sleepScore: 84)]

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

@Test func todayWithoutANightSaysNoNightYetAndShowsTodaysLoadSoFar() {
    // Yesterday's Night has every value, so any of them leaking onto today would show.
    let yesterday = Night(
        day: oct31,
        sleepScore: 84,
        readiness: 80,
        restingHR: 50,
        hrv: 62,
        respiratoryRate: 14.1,
        skinTemperature: 34.0,
        spo2: 97,
        timeAsleep: 27_600
    )
    let view = todayView(nights: [yesterday], showing: nov1)

    #expect(view.noNightMessage == "No Night yet")
    #expect(view.loadLabel == "Load so far")
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

// MARK: Zones

/// Three earlier Nights at the same values, so 1 Nov's Baselines are exactly Resting HR 52 bpm,
/// HRV 60 ms, respiratory rate 14.0 br/min and skin temperature 34.0 °C.
private let exactBaselinesBeforeNov1 = nightsBeforeNov1(
    hrv: [60, 60, 60],
    restingHR: [52, 52, 52],
    respiratoryRate: [14.0, 14.0, 14.0],
    skinTemperature: [34.0, 34.0, 34.0]
)

private func nov1Tile(_ metric: NightlyMetric, of night: Night) -> MetricTile? {
    todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1).tile(metric)
}

// 57 is −5% and 51 is −15% of 60, the boundaries themselves.
@Test(
    arguments: [(57, .inRange), (56.9, .watch), (51, .watch), (50.9, .outOfRange), (90, .inRange)]
        as [(Double, Zone)]
)
func hrvZoneAgainstABaselineOf60(hrv: Double, zone: Zone) {
    let tile = nov1Tile(.hrv, of: Night(day: nov1, hrv: hrv))

    #expect(tile?.baseline == 60)
    #expect(tile?.zone == zone)
}

@Test(
    arguments: [(53, .inRange), (53.1, .watch), (56, .watch), (56.1, .outOfRange), (45, .inRange)]
        as [(Double, Zone)]
)
func restingHRZoneAgainstABaselineOf52(restingHR: Double, zone: Zone) {
    let tile = nov1Tile(.restingHR, of: Night(day: nov1, restingHR: restingHR))

    #expect(tile?.baseline == 52)
    #expect(tile?.zone == zone)
}

@Test(
    arguments: [
        (14.5, .inRange), (13.5, .inRange), (15.0, .watch), (15.1, .outOfRange),
        (12.9, .outOfRange),
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

// MARK: Tile text

@Test func restingHRDifferenceIsInWholeSignedBpm() {
    let down = nov1Tile(.restingHR, of: Night(day: nov1, restingHR: 49))
    #expect(down?.differenceText == "\u{2212}3 bpm")

    let up = nov1Tile(.restingHR, of: Night(day: nov1, restingHR: 54))
    #expect(up?.differenceText == "+2 bpm")

    let none = nov1Tile(.restingHR, of: Night(day: nov1, restingHR: 51.6))
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
        restingHR: 52,
        hrv: 62,
        respiratoryRate: 14.2,
        skinTemperature: 34.1,
        spo2: 96
    )
    let view = todayView(nights: [night], showing: nov1)

    #expect(view.tile(.restingHR)?.valueText == "52 bpm")
    #expect(view.tile(.hrv)?.valueText == "62 ms")
    #expect(view.tile(.respiratoryRate)?.valueText == "14.2 br/min")
    #expect(view.tile(.skinTemperature)?.valueText == "34.1 °C")
    #expect(view.tile(.spo2)?.valueText == "96%")
}

@Test func valuesRoundToWholeNumbersOrOneDecimal() {
    let night = Night(
        day: nov1,
        restingHR: 51.6,
        respiratoryRate: 14.0,
        skinTemperature: 34.06,
        spo2: 95.6
    )
    let view = todayView(nights: [night], showing: nov1)

    #expect(view.tile(.restingHR)?.valueText == "52 bpm")
    #expect(view.tile(.respiratoryRate)?.valueText == "14.0 br/min")
    #expect(view.tile(.skinTemperature)?.valueText == "34.1 °C")
    #expect(view.tile(.spo2)?.valueText == "96%")
}

// MARK: Calibrating and missing tiles

@Test func aCalibratingMetricHasNoZoneButSpO2HasOne() {
    let earlier = nightsBeforeNov1(
        hrv: [60, 60],
        restingHR: [52, 52],
        respiratoryRate: [14.0, 14.0],
        skinTemperature: [34.0, 34.0],
        spo2: [97, 97]
    )
    let night = Night(
        day: nov1,
        restingHR: 60,
        hrv: 40,
        respiratoryRate: 16.0,
        skinTemperature: 35.0,
        spo2: 96
    )
    let view = todayView(nights: earlier + [night], showing: nov1)

    for metric in [NightlyMetric.restingHR, .hrv, .respiratoryRate, .skinTemperature] {
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
        restingHR: [52, 52, 52],
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
    let view = todayView(nights: [Night(day: nov1, restingHR: 52)], showing: nov1)

    #expect(view.tile(.spo2)?.valueText == "—")
    #expect(view.tile(.spo2)?.differenceText == "—")
    #expect(view.tile(.spo2)?.zone == nil)
    #expect(view.tile(.restingHR)?.valueText == "52 bpm")
}

// MARK: Tile order and names

@Test func tilesRunRestingHRHRVRespiratoryRateSkinTemperatureSpO2() {
    let view = todayView(nights: [Night(day: nov1)], showing: nov1)

    #expect(
        view.tiles.map(\.metric) == [.restingHR, .hrv, .respiratoryRate, .skinTemperature, .spo2]
    )
    #expect(
        view.tiles.map(\.metric.name) == [
            "Resting HR", "HRV", "Respiratory rate", "Skin temperature", "SpO2",
        ]
    )
}

// MARK: Status words and gauges

@Test(
    arguments: [
        (.hrv, Night(day: nov1, hrv: 57), "Normal"),
        (.hrv, Night(day: nov1, hrv: 54), "Low"),
        (.restingHR, Night(day: nov1, restingHR: 53), "Normal"),
        (.restingHR, Night(day: nov1, restingHR: 55), "High"),
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

@Test(
    arguments: [
        (.hrv, Night(day: nov1, hrv: 60), 0.5),
        (.hrv, Night(day: nov1, hrv: 55.5), 0.25),
        (.hrv, Night(day: nov1, hrv: 51), 0),
        (.hrv, Night(day: nov1, hrv: 75), 1),
        (.restingHR, Night(day: nov1, restingHR: 54), 0.75),
        (.restingHR, Night(day: nov1, restingHR: 48), 0),
        (.respiratoryRate, Night(day: nov1, respiratoryRate: 14.5), 0.75),
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
        restingHR: [52, 52],
        respiratoryRate: [14.0, 14.0],
        skinTemperature: [34.0, 34.0],
        spo2: [97, 97]
    )
    let night = Night(
        day: nov1,
        restingHR: 55,
        hrv: 54,
        respiratoryRate: 15.0,
        skinTemperature: 34.5,
        spo2: 97
    )
    let view = todayView(nights: earlier + [night], showing: nov1)

    for metric in [NightlyMetric.restingHR, .hrv, .respiratoryRate, .skinTemperature] {
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
        restingHR: [52, 52, 52],
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

/// vs your Baseline's HRV and Resting HR comparisons; nil when it's Calibrating or absent.
private func baselineComparisons(_ view: TodayView) -> [BaselineComparison]? {
    guard case .comparisons(let comparisons) = view.vsBaseline else { return nil }
    return comparisons
}

@Test func hrvUp14PercentAndRestingHRDown3BpmAreBothMarkedTheGoodWay() {
    let view = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, restingHR: 49, hrv: 68.4)],
        showing: nov1
    )
    let comparisons = baselineComparisons(view)

    #expect(comparisons?.map(\.metric) == [.hrv, .restingHR])

    let hrv = comparisons?.first
    #expect(hrv?.valueText == "68 ms")
    #expect(hrv?.differenceText == "+14%")
    #expect(hrv?.direction == .up)
    #expect(hrv?.movedTheGoodWay == true)

    let restingHR = comparisons?.last
    #expect(restingHR?.valueText == "49 bpm")
    #expect(restingHR?.differenceText == "\u{2212}3 bpm")
    #expect(restingHR?.direction == .down)
    #expect(restingHR?.movedTheGoodWay == true)
}

@Test func hrvDownAndRestingHRUpAreBothMarkedTheBadWay() {
    let view = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, restingHR: 55, hrv: 54)],
        showing: nov1
    )
    let comparisons = baselineComparisons(view)

    let hrv = comparisons?.first
    #expect(hrv?.metric == .hrv)
    #expect(hrv?.differenceText == "\u{2212}10%")
    #expect(hrv?.direction == .down)
    #expect(hrv?.movedTheGoodWay == false)

    let restingHR = comparisons?.last
    #expect(restingHR?.metric == .restingHR)
    #expect(restingHR?.differenceText == "+3 bpm")
    #expect(restingHR?.direction == .up)
    #expect(restingHR?.movedTheGoodWay == false)
}

@Test func aDifferenceThatRoundsToZeroHasNoDirection() {
    let view = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, restingHR: 52.2, hrv: 60.1)],
        showing: nov1
    )
    let comparisons = baselineComparisons(view)

    let hrv = comparisons?.first
    #expect(hrv?.differenceText == "0%")
    #expect(hrv?.direction == nil)
    #expect(hrv?.movedTheGoodWay == nil)

    let restingHR = comparisons?.last
    #expect(restingHR?.differenceText == "0 bpm")
    #expect(restingHR?.direction == nil)
    #expect(restingHR?.movedTheGoodWay == nil)
}

@Test func aNightWithoutHRVComparesItAsDashesWithNoDirection() {
    let view = todayView(
        nights: exactBaselinesBeforeNov1 + [Night(day: nov1, restingHR: 49)],
        showing: nov1
    )
    let comparisons = baselineComparisons(view)

    #expect(comparisons?.map(\.metric) == [.hrv, .restingHR])

    let hrv = comparisons?.first
    #expect(hrv?.valueText == "—")
    #expect(hrv?.differenceText == "—")
    #expect(hrv?.direction == nil)
    #expect(hrv?.movedTheGoodWay == nil)

    let restingHR = comparisons?.last
    #expect(restingHR?.differenceText == "\u{2212}3 bpm")
    #expect(restingHR?.movedTheGoodWay == true)
}

@Test func vsBaselineIsTheCalibratingLineWithTheNightsToGo() {
    let shown = Night(day: nov1, readiness: 80, restingHR: 50, hrv: 60)

    let firstNight = todayView(nights: [shown], showing: nov1)
    #expect(firstNight.readinessText == "1/4")
    #expect(
        firstNight.vsBaseline
            == .calibrating(
                "Calibrating. Readiness starts once 4 Nights form your Baseline. 3 to go."
            )
    )

    let twoEarlier = todayView(
        nights: nightsBeforeNov1(hrv: [60, 60], restingHR: [50, 50]) + [shown],
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
        nightsBeforeNov1(hrv: [60, 60, 60], restingHR: [50])
        + [Night(day: nov1, readiness: 80, restingHR: 50, hrv: 60)]
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

@Test func readinessPopupShowsHRVAndRestingHRAgainstTheirBaselinesAndHowManyNightsFormThem() {
    let night = Night(day: nov1, sleepScore: 84, readiness: 80, restingHR: 49, hrv: 68.4)
    let popup = todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1)
        .readinessPopup

    #expect(popup?.readinessText == "80")
    #expect(popup?.band == .ready)
    #expect(popup?.rows.map(\.metric) == [.hrv, .restingHR])
    #expect(popup?.rows.map(\.valueText) == ["68 ms", "49 bpm"])
    #expect(popup?.rows.map(\.baselineText) == ["60 ms", "52 bpm"])
    #expect(popup?.rows.map(\.differenceText) == ["+14%", "\u{2212}3 bpm"])
    #expect(popup?.sleepScoreText == "84")
    #expect(popup?.baselineNote == "Baseline: your last 3 Nights")
    #expect(popup?.calibratingText == nil)
}

@Test func readinessPopupBaselineNoteCountsAtMostFourteenNights() {
    let earlier = nightsBeforeNov1(
        hrv: Array(repeating: 60, count: 20),
        restingHR: Array(repeating: 52, count: 20)
    )
    let night = Night(day: nov1, readiness: 80, restingHR: 49, hrv: 68.4)
    let popup = todayView(nights: earlier + [night], showing: nov1).readinessPopup

    #expect(popup?.baselineNote == "Baseline: your last 14 Nights")
}

@Test func readinessPopupBaselineNoteCountsByTheMetricWithFewerEarlierNights() {
    let earlier = nightsBeforeNov1(hrv: [60, 60, 60, 60, 60], restingHR: [52, 52, 52, 52])
    let night = Night(day: nov1, readiness: 80, restingHR: 49, hrv: 68.4)
    let popup = todayView(nights: earlier + [night], showing: nov1).readinessPopup

    #expect(popup?.baselineNote == "Baseline: your last 4 Nights")
}

@Test func readinessPopupExplainsCalibratingWithTheNightsSoFar() {
    let night = Night(day: nov1, sleepScore: 84, readiness: 80, restingHR: 50, hrv: 60)
    let popup = todayView(
        nights: nightsBeforeNov1(hrv: [60, 60], restingHR: [50, 50]) + [night],
        showing: nov1
    ).readinessPopup

    #expect(popup?.readinessText == "3/4")
    #expect(popup?.band == nil)
    #expect(
        popup?.calibratingText
            == "Readiness needs 4 Nights to form your Baseline. You have 3 so far."
    )
    // Spec 002, Popups: while Calibrating it explains "instead", so no rows or Sleep Score.
    #expect(popup?.baselineNote == nil)
    #expect(popup?.rows == [])
    #expect(popup != nil && popup?.sleepScoreText == nil)
}

// MARK: Sleep popup

/// 2026-10-31T22:30:00Z.
private let timeInBedStartOct31At2230 = Date(timeIntervalSince1970: 1_793_485_800)
/// 2026-11-01T07:05:00Z.
private let timeInBedEndNov1At0705 = Date(timeIntervalSince1970: 1_793_516_700)

@Test func sleepPopupMinutesAwakeAreFinalWakeMinusSleepOnsetMinusTimeAsleep() {
    // 22:45 to 06:57 is 492 min; Time Asleep 27 600 s is 460 min; so 32 min awake.
    let night = Night(
        day: nov1,
        sleepScore: 84,
        sleepOnset: onsetOct31At2245,
        finalWake: finalWakeNov1At0657,
        timeAsleep: 27_600,
        timeInBedStart: timeInBedStartOct31At2230,
        timeInBedEnd: timeInBedEndNov1At0705
    )
    let popup = todayView(nights: [night], showing: nov1).sleepPopup

    #expect(popup?.sleepScoreText == "84")
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

@Test func metricPopupChartHoldsTheNightShownAndThirteenEarlierNightsOldestFirst() {
    // Given newest first, so the order of the input can't stand in for sorting.
    let nights = [laterNightOnNov2] + nightsOct13ToNov1().reversed()
    let popup = todayView(nights: nights, showing: nov1).metricPopup(.hrv)

    #expect(popup?.metric == .hrv)
    #expect(popup?.valueText == "59 ms")
    #expect(
        popup?.chart.map(\.day)
            == (19...31).map { Day(year: 2026, month: 10, day: $0) } + [nov1]
    )
    #expect(
        popup?.chart.map(\.value)
            == [46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59]
    )
}

@Test func metricPopupListsTheFiveMostRecentNightsNewestFirst() {
    let nights = nightsOct13ToNov1() + [laterNightOnNov2]
    let popup = todayView(nights: nights, showing: nov1).metricPopup(.hrv)

    #expect(
        popup?.recent.map(\.dayText)
            == ["Sun 1 Nov", "Sat 31 Oct", "Fri 30 Oct", "Thu 29 Oct", "Wed 28 Oct"]
    )
    #expect(popup?.recent.map(\.valueText) == ["59 ms", "58 ms", "57 ms", "56 ms", "55 ms"])
}

@Test func aNightMissingTheValueIsLeftOutOfTheMetricPopupChart() {
    let popup = todayView(nights: nightsOct13ToNov1(hrvOnOct25: nil), showing: nov1)
        .metricPopup(.hrv)

    // 25 Oct's Night is one of the 14 but has no HRV; 18 Oct's Night doesn't take its place.
    #expect(
        popup?.chart.map(\.value)
            == [46, 47, 48, 49, 50, 51, 53, 54, 55, 56, 57, 58, 59]
    )
    #expect(popup?.chart.first?.day == Day(year: 2026, month: 10, day: 19))
}

/// Whether `value` is within floating-point error of `expected`: limits such as 34.0 − 0.3 or
/// 0.95 × 60 needn't be exact in binary floating point.
private func isClose(_ value: Double?, to expected: Double) -> Bool {
    value.map { abs($0 - expected) < 1e-9 } ?? false
}

@Test func metricPopupShowsTheBaselineAndItsInRangeLimits() {
    let night = Night(
        day: nov1,
        restingHR: 52,
        hrv: 60,
        respiratoryRate: 14.0,
        skinTemperature: 34.0,
        spo2: 97
    )
    let view = todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1)

    let hrv = view.metricPopup(.hrv)
    #expect(isClose(hrv?.baseline, to: 60))
    #expect(isClose(hrv?.inRangeLow, to: 57))
    #expect(hrv != nil && hrv?.inRangeHigh == nil)

    let restingHR = view.metricPopup(.restingHR)
    #expect(isClose(restingHR?.baseline, to: 52))
    #expect(restingHR != nil && restingHR?.inRangeLow == nil)
    #expect(isClose(restingHR?.inRangeHigh, to: 53))

    let respiratoryRate = view.metricPopup(.respiratoryRate)
    #expect(isClose(respiratoryRate?.baseline, to: 14.0))
    #expect(isClose(respiratoryRate?.inRangeLow, to: 13.5))
    #expect(isClose(respiratoryRate?.inRangeHigh, to: 14.5))

    let skinTemperature = view.metricPopup(.skinTemperature)
    #expect(isClose(skinTemperature?.baseline, to: 34.0))
    #expect(isClose(skinTemperature?.inRangeLow, to: 33.7))
    #expect(isClose(skinTemperature?.inRangeHigh, to: 34.3))
}

@Test func spo2PopupHasNoBaselineOrInRangeLimitsButShowsItsLevel() {
    let night = Night(day: nov1, spo2: 97)
    let popup = todayView(nights: exactBaselinesBeforeNov1 + [night], showing: nov1)
        .metricPopup(.spo2)

    #expect(popup?.valueText == "97%")
    #expect(popup?.differenceText == "95% or above")
    #expect(popup?.zone == .inRange)
    #expect(popup != nil && popup?.baseline == nil)
    #expect(popup != nil && popup?.inRangeLow == nil)
    #expect(popup != nil && popup?.inRangeHigh == nil)
}

@Test func aCalibratingMetricPopupHasNoBaselineOrInRangeLimits() {
    let nights = nightsBeforeNov1(hrv: [60, 60]) + [Night(day: nov1, hrv: 60)]
    let popup = todayView(nights: nights, showing: nov1).metricPopup(.hrv)

    #expect(popup?.differenceText == "Calibrating")
    #expect(popup != nil && popup?.baseline == nil)
    #expect(popup != nil && popup?.inRangeLow == nil)
    #expect(popup != nil && popup?.inRangeHigh == nil)
}

// MARK: Popups on a Day without a Night

@Test func aDayWithoutANightHasNoPopups() {
    let view = todayView(nights: calibratedNightsBeforeNov1, showing: nov1)

    #expect(view.readinessPopup == nil)
    #expect(view.sleepPopup == nil)
    for metric in [NightlyMetric.restingHR, .hrv, .respiratoryRate, .skinTemperature, .spo2] {
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

@Test func theLaterWeekArrowStopsAtToday() {
    let view = todayView(nights: nightsOct1ToNov1, showing: Day(year: 2026, month: 10, day: 28))

    #expect(view.weekStrip.laterDay == nov1)
}

@Test func theEarlierWeekArrowIsDisabledOnTheEarliestNightsDay() {
    let nights = [Night(day: oct30), Night(day: nov1)]

    #expect(todayView(nights: nights, showing: oct30).weekStrip.earlierDay == nil)
}
