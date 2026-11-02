import Foundation
import SerenixCore
import Testing

// The Load popup on the Today view (spec 006, Behavior: Opening and Contents).

/// 1 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!

/// 2026-11-01T08:12:00Z, 08:12 local in London.
private let now = Date(timeIntervalSince1970: 1_793_520_720)

/// 2026-11-02T08:12:00Z, a day after `now`, so 1 Nov is an earlier Day.
private let nextMorning = Date(timeIntervalSince1970: 1_793_607_120)

/// 2026-11-01T18:40:00Z, 18:40 local in London.
private let nov1At1840 = Date(timeIntervalSince1970: 1_793_558_400)

private let oct28 = Day(year: 2026, month: 10, day: 28)
private let oct29 = Day(year: 2026, month: 10, day: 29)
private let oct30 = Day(year: 2026, month: 10, day: 30)
private let oct31 = Day(year: 2026, month: 10, day: 31)
private let nov1 = Day(year: 2026, month: 11, day: 1)

private let noZoneSeconds: [HRZone: Int] = [.one: 0, .two: 0, .three: 0, .four: 0, .five: 0]

private func heartRate(
    zoneSeconds: [HRZone: Int] = noZoneSeconds,
    hourlyZoneSeconds: [[HRZone: Int]] = Array(repeating: noZoneSeconds, count: 24),
    highestHR: HighestHR? = HighestHR(bpm: 172, time: nov1At1840),
    maxHRUsed: MaxHRUsed = MaxHRUsed(bpm: 190, source: .entered)
) -> DayHeartRate {
    DayHeartRate(
        zoneSeconds: zoneSeconds,
        hourlyZoneSeconds: hourlyZoneSeconds,
        highestHR: highestHR,
        maxHRUsed: maxHRUsed
    )
}

private func todayView(
    dayLoads: [DayLoad],
    showing day: Day = nov1,
    at time: Date = now,
    lastSyncEnded: Date? = nil
) -> TodayView {
    TodayView(
        nights: [],
        dayLoads: dayLoads,
        showing: day,
        now: time,
        timeZone: london,
        sync: .idle,
        profileName: nil,
        lastSyncEnded: lastSyncEnded
    )
}

/// Loads 30, 40, 50 and 60 on the 4 Days before 1 Nov: typical Load 45 on 1 Nov.
private let fourDaysBeforeNov1 = [
    DayLoad(day: oct28, load: 30, heartRate: heartRate()),
    DayLoad(day: oct29, load: 40, heartRate: heartRate()),
    DayLoad(day: oct30, load: 50, heartRate: heartRate()),
    DayLoad(day: oct31, load: 60, heartRate: heartRate()),
]

// MARK: Opening

@Test func aDayWithALoadOpensTheLoadPopup() {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: 57, heartRate: heartRate())])

    #expect(view.loadPopup != nil)
    #expect(!view.loadOpensProfileMenu)
}

@Test func aDayWithNoRecordsStillOpensTheLoadPopup() {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: nil, missingReason: .noRecords)])

    #expect(view.loadPopup != nil)
    #expect(!view.loadOpensProfileMenu)
}

@Test func aDayWithNoMaxHROpensTheProfileMenuInsteadOfTheLoadPopup() {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: nil, missingReason: .noMaxHR)])

    #expect(view.loadPopup == nil)
    #expect(view.loadOpensProfileMenu)
}

@Test func aDayWithNoLoadWorkedOutOpensTheLoadPopupSayingNoHeartRateWasRecorded() {
    let view = todayView(dayLoads: [])

    #expect(view.loadPopup?.note == "No heart rate recorded this Day")
    #expect(view.loadPopup?.loadText == "—")
}

// MARK: The Day and Load

@Test func todaysPopupHasTheLiveHRPillAndTheTimeOfTheLastSync() throws {
    let view = todayView(
        dayLoads: [DayLoad(day: nov1, load: 57, heartRate: heartRate())],
        lastSyncEnded: now
    )
    let popup = try #require(view.loadPopup)

    #expect(popup.dateText == "Sun 1 Nov")
    #expect(popup.loadText == "57")
    #expect(popup.showsLiveHR)
    #expect(popup.lastSyncText == "As of your last sync at 08:12")
}

@Test func anEarlierDaysPopupHasNeitherTheLiveHRPillNorTheLastSync() throws {
    let view = todayView(
        dayLoads: [DayLoad(day: oct31, load: 57, heartRate: heartRate())],
        showing: oct31,
        lastSyncEnded: now
    )
    let popup = try #require(view.loadPopup)

    #expect(popup.dateText == "Sat 31 Oct")
    #expect(!popup.showsLiveHR)
    #expect(popup.lastSyncText == nil)
}

@Test func todaysPopupWithNoSyncYetHasNoLastSyncLine() throws {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: 57, heartRate: heartRate())])
    let popup = try #require(view.loadPopup)

    #expect(popup.showsLiveHR)
    #expect(popup.lastSyncText == nil)
}

// MARK: No records and not available

@Test func aDayWithNoRecordsSaysSoInPlaceOfZonesHighestHRAndMaxHR() throws {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: nil, missingReason: .noRecords)])
    let popup = try #require(view.loadPopup)

    #expect(popup.loadText == "—")
    #expect(popup.note == "No heart rate recorded this Day")
    #expect(popup.zoneRows.isEmpty)
    #expect(popup.hourlyZoneSeconds.isEmpty)
    #expect(popup.highestHRText == nil)
    #expect(popup.maxHRText == nil)
}

@Test func aDayWithALoadButNoStoredHRZonesSaysTheyAreNotAvailable() throws {
    let view = todayView(dayLoads: [DayLoad(day: oct31, load: 40)], showing: oct31)
    let popup = try #require(view.loadPopup)

    #expect(popup.loadText == "40")
    #expect(popup.note == "Heart rate zones aren't available for this Day")
    #expect(popup.zoneRows.isEmpty)
    #expect(popup.hourlyZoneSeconds.isEmpty)
    #expect(popup.highestHRText == nil)
    #expect(popup.maxHRText == nil)
}

@Test func aDayWithStoredHRZonesHasNoNote() throws {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: 57, heartRate: heartRate())])
    let popup = try #require(view.loadPopup)

    #expect(popup.note == nil)
}

// MARK: Heart rate zones

@Test func zoneRowsRunFromHRZone1To5WithTheirLabels() throws {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: 57, heartRate: heartRate())])
    let popup = try #require(view.loadPopup)

    #expect(popup.zoneRows.map(\.zone) == [.one, .two, .three, .four, .five])
    #expect(
        popup.zoneRows.map(\.label) == [
            "Zone 1 · 50–60%",
            "Zone 2 · 60–70%",
            "Zone 3 · 70–80%",
            "Zone 4 · 80–90%",
            "Zone 5 · 90–100%",
        ]
    )
}

@Test func zoneTimesAreWholeMinutesWithHoursFromAnHour() throws {
    // 42 min, 65 min, none, 10 min, 30 s (rounds up to a minute), and 29 s rounds down.
    let seconds: [HRZone: Int] = [.one: 2_520, .two: 3_900, .three: 0, .four: 600, .five: 30]
    let view = todayView(
        dayLoads: [DayLoad(day: nov1, load: 57, heartRate: heartRate(zoneSeconds: seconds))]
    )
    let popup = try #require(view.loadPopup)

    #expect(popup.zoneRows.map(\.timeText) == ["42m", "1h 05m", "0m", "10m", "1m"])

    let underHalf = todayView(
        dayLoads: [
            DayLoad(
                day: nov1,
                load: 57,
                heartRate: heartRate(zoneSeconds: [
                    .one: 29, .two: 0, .three: 0, .four: 0, .five: 0,
                ])
            )
        ]
    )
    #expect(underHalf.loadPopup?.zoneRows.first?.timeText == "0m")
}

@Test func eachZoneBarIsItsShareOfTheDaysTimeInHRZones() throws {
    // 30 min, 1 h, none, 30 min, none: 2 h in HR Zones.
    let seconds: [HRZone: Int] = [.one: 1_800, .two: 3_600, .three: 0, .four: 1_800, .five: 0]
    let view = todayView(
        dayLoads: [DayLoad(day: nov1, load: 57, heartRate: heartRate(zoneSeconds: seconds))]
    )
    let popup = try #require(view.loadPopup)

    #expect(popup.zoneRows.map(\.share) == [0.25, 0.5, 0, 0.25, 0])
    #expect(popup.zoneRows.map(\.timeText) == ["30m", "1h 00m", "0m", "30m", "0m"])
}

@Test func aDayWithNoTimeInHRZonesHasEmptyBars() throws {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: 0, heartRate: heartRate())])
    let popup = try #require(view.loadPopup)

    #expect(popup.zoneRows.map(\.share) == [0, 0, 0, 0, 0])
    #expect(popup.zoneRows.map(\.timeText) == ["0m", "0m", "0m", "0m", "0m"])
}

// MARK: Hourly bars

@Test func hourlyBarsAreTheDaysStoredHourlyHRZoneSeconds() throws {
    var hourly = Array(repeating: noZoneSeconds, count: 24)
    hourly[7] = [.one: 600, .two: 120, .three: 0, .four: 0, .five: 0]
    hourly[18] = [.one: 300, .two: 900, .three: 1_200, .four: 480, .five: 60]
    let view = todayView(
        dayLoads: [
            DayLoad(day: nov1, load: 57, heartRate: heartRate(hourlyZoneSeconds: hourly))
        ]
    )
    let popup = try #require(view.loadPopup)

    #expect(popup.hourlyZoneSeconds == hourly)
}

// MARK: Highest HR and Max HR used

@Test func highestHRReadsItsBpmAndLocalTime() throws {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: 57, heartRate: heartRate())])
    let popup = try #require(view.loadPopup)

    #expect(popup.highestHRText == "Highest HR 172 bpm at 18:40")
}

@Test func highestHRReadsADashWithNoHeartRateOverZero() throws {
    let view = todayView(
        dayLoads: [DayLoad(day: nov1, load: 0, heartRate: heartRate(highestHR: nil))]
    )
    let popup = try #require(view.loadPopup)

    #expect(popup.highestHRText == "Highest HR —")
}

@Test func maxHRUsedSaysItWasEntered() {
    let view = todayView(
        dayLoads: [
            DayLoad(
                day: nov1,
                load: 57,
                heartRate: heartRate(maxHRUsed: MaxHRUsed(bpm: 190, source: .entered))
            )
        ]
    )

    #expect(view.loadPopup?.maxHRText == "Using Max HR 190 (entered)")
}

@Test func maxHRUsedSaysItWasEstimatedFromAge() {
    let view = todayView(
        dayLoads: [
            DayLoad(
                day: nov1,
                load: 57,
                heartRate: heartRate(maxHRUsed: MaxHRUsed(bpm: 180, source: .estimated))
            )
        ]
    )

    #expect(view.loadPopup?.maxHRText == "Using Max HR 180 (estimated from your age)")
}

// MARK: Typical Load

@Test func todayAboveTypicalLoadReadsAPlusDifference() {
    let view = todayView(
        dayLoads: fourDaysBeforeNov1 + [DayLoad(day: nov1, load: 57, heartRate: heartRate())]
    )

    #expect(view.loadPopup?.typicalText == "Typical: 45 · today +12")
}

@Test func theSpecsTypicalLoadExampleReadsPlus45() {
    // Spec 006: Loads 30, 40, 50 and 60 on the 4 Days before, and 90 on the Day.
    let view = todayView(
        dayLoads: fourDaysBeforeNov1 + [DayLoad(day: nov1, load: 90, heartRate: heartRate())]
    )

    #expect(view.loadPopup?.typicalText == "Typical: 45 · today +45")
}

@Test func anEarlierDayReadsThatDay() {
    let view = todayView(
        dayLoads: fourDaysBeforeNov1 + [DayLoad(day: nov1, load: 57, heartRate: heartRate())],
        at: nextMorning
    )

    #expect(view.loadPopup?.typicalText == "Typical: 45 · that Day +12")
}

@Test func belowTypicalLoadReadsAMinusDifference() {
    let view = todayView(
        dayLoads: fourDaysBeforeNov1 + [DayLoad(day: nov1, load: 40, heartRate: heartRate())]
    )

    #expect(view.loadPopup?.typicalText == "Typical: 45 · today −5")
}

@Test func equalToTypicalLoadReadsPlusMinusZero() {
    let view = todayView(
        dayLoads: fourDaysBeforeNov1 + [DayLoad(day: nov1, load: 45, heartRate: heartRate())]
    )

    #expect(view.loadPopup?.typicalText == "Typical: 45 · today ±0")
}

@Test func aDayWithItsLoadMissingReadsOnlyTheTypicalLoad() {
    let view = todayView(
        dayLoads: fourDaysBeforeNov1 + [
            DayLoad(day: nov1, load: nil, missingReason: .noRecords)
        ]
    )

    #expect(view.loadPopup?.typicalText == "Typical: 45")
}

@Test func withFewerThan4DaysTheTypicalLineCountsTheDaysSoFar() {
    let view = todayView(
        dayLoads: Array(fourDaysBeforeNov1.dropFirst()) + [
            DayLoad(day: nov1, load: 57, heartRate: heartRate())
        ]
    )

    #expect(view.loadPopup?.typicalText == "Typical Load after 4 Days (3 so far)")
}

@Test func aDayWithMaxHRNotAboveRestingHRShowsItsHRZonesWithNoLoad() {
    let view = todayView(
        dayLoads: [
            DayLoad(
                day: nov1,
                load: nil,
                missingReason: .maxHRNotAboveRestingHR,
                heartRate: heartRate()
            )
        ]
    )

    let popup = view.loadPopup
    #expect(popup?.loadText == "—")
    #expect(popup?.note == nil)
    #expect(popup?.zoneRows.count == 5)
    #expect(popup?.maxHRText == "Using Max HR 190 (entered)")
}
