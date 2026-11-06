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

@Test func zoneRowsRunFromHRZone5To1WithTheirLabels() throws {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: 57, heartRate: heartRate())])
    let popup = try #require(view.loadPopup)

    #expect(popup.zoneRows.map(\.zone) == [.five, .four, .three, .two, .one])
    #expect(
        popup.zoneRows.map(\.label) == [
            "Zone 5 · 90–100%",
            "Zone 4 · 80–90%",
            "Zone 3 · 70–80%",
            "Zone 2 · 60–70%",
            "Zone 1 · 50–60%",
        ]
    )
}

@Test func zoneTimesAreWholeMinutesWithHoursFromAnHour() throws {
    // Zones 1 to 5: 42 min, 65 min, none, 10 min, 30 s (rounds up to a minute), and 29 s rounds
    // down. Rows run Zone 5 first.
    let seconds: [HRZone: Int] = [.one: 2_520, .two: 3_900, .three: 0, .four: 600, .five: 30]
    let view = todayView(
        dayLoads: [DayLoad(day: nov1, load: 57, heartRate: heartRate(zoneSeconds: seconds))]
    )
    let popup = try #require(view.loadPopup)

    #expect(popup.zoneRows.map(\.timeText) == ["1m", "10m", "0m", "1h 05m", "42m"])

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
    #expect(underHalf.loadPopup?.zoneRows.last?.timeText == "0m")
}

@Test func eachZoneBarIsItsShareOfTheDaysTimeInHRZones() throws {
    // Zones 1 to 5: 30 min, 1 h, none, 30 min, none: 2 h in HR Zones. Rows run Zone 5 first.
    let seconds: [HRZone: Int] = [.one: 1_800, .two: 3_600, .three: 0, .four: 1_800, .five: 0]
    let view = todayView(
        dayLoads: [DayLoad(day: nov1, load: 57, heartRate: heartRate(zoneSeconds: seconds))]
    )
    let popup = try #require(view.loadPopup)

    #expect(popup.zoneRows.map(\.share) == [0, 0.25, 0, 0.5, 0.25])
    #expect(popup.zoneRows.map(\.timeText) == ["0m", "30m", "0m", "1h 00m", "30m"])
}

@Test func aDayWithNoTimeInHRZonesHasEmptyBars() throws {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: 0, heartRate: heartRate())])
    let popup = try #require(view.loadPopup)

    #expect(popup.zoneRows.map(\.share) == [0, 0, 0, 0, 0])
    #expect(popup.zoneRows.map(\.timeText) == ["0m", "0m", "0m", "0m", "0m"])
}

// MARK: HR Zone mix

@Test func theMixIsEachHRZonesShareOfTheDaysTimeInHRZonesFromZone1To5() throws {
    // Spec 006: 30 min in HR Zone 2 and 90 min in HR Zone 4, none in the others.
    let seconds: [HRZone: Int] = [.one: 0, .two: 1_800, .three: 0, .four: 5_400, .five: 0]
    let view = todayView(
        dayLoads: [DayLoad(day: nov1, load: 57, heartRate: heartRate(zoneSeconds: seconds))]
    )
    let popup = try #require(view.loadPopup)

    #expect(popup.zoneMix.map(\.zone) == [.two, .four])
    #expect(popup.zoneMix.map(\.share) == [0.25, 0.75])
}

@Test func aDayWithNoTimeInHRZonesHasNoMix() throws {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: 0, heartRate: heartRate())])
    let popup = try #require(view.loadPopup)

    #expect(popup.zoneMix.isEmpty)
}

@Test func aDayWithNoRecordsHasNoMix() throws {
    let view = todayView(dayLoads: [DayLoad(day: nov1, load: nil, missingReason: .noRecords)])
    let popup = try #require(view.loadPopup)

    #expect(popup.zoneMix.isEmpty)
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

// MARK: The sentence

/// The same Load on each of the 4 Days before 1 Nov, so it is the typical Load on 1 Nov.
private func typicalLoadBeforeNov1(_ load: Int) -> [DayLoad] {
    [oct28, oct29, oct30, oct31].map { DayLoad(day: $0, load: load, heartRate: heartRate()) }
}

@Test(
    "Against typical Load 50, the sentence names the Day's band",
    arguments: [
        (39, "An easier Day than usual"),
        (40, "About your usual Day"),
        (59, "About your usual Day"),
        (60, "A harder Day than usual"),
        (74, "A harder Day than usual"),
        (75, "A much harder Day than usual"),
    ]
)
func theSentenceComparesTheDaysLoadToTypicalLoad(load: Int, sentence: String) {
    let view = todayView(
        dayLoads: typicalLoadBeforeNov1(50) + [
            DayLoad(day: nov1, load: load, heartRate: heartRate())
        ]
    )

    #expect(view.loadPopup?.comparisonText == sentence)
}

@Test func withFewerThan4DaysTheSentenceSaysItIsLearningTypicalLoad() {
    let view = todayView(
        dayLoads: Array(typicalLoadBeforeNov1(50).dropFirst()) + [
            DayLoad(day: nov1, load: 57, heartRate: heartRate())
        ]
    )

    #expect(view.loadPopup?.comparisonText == "Learning your typical Load")
}

@Test func aDayWithItsLoadMissingSaysNoLoadThisDay() {
    let view = todayView(
        dayLoads: typicalLoadBeforeNov1(50) + [
            DayLoad(day: nov1, load: nil, missingReason: .noRecords)
        ]
    )

    #expect(view.loadPopup?.comparisonText == "No Load this Day")
}

@Test(
    "Against typical Load 0, Load 0 is usual and any other Load much harder",
    arguments: [
        (0, "About your usual Day"),
        (5, "A much harder Day than usual"),
    ]
)
func theSentenceAgainstTypicalLoadZero(load: Int, sentence: String) {
    let view = todayView(
        dayLoads: typicalLoadBeforeNov1(0) + [
            DayLoad(day: nov1, load: load, heartRate: heartRate())
        ]
    )

    #expect(view.loadPopup?.comparisonText == sentence)
}

// MARK: The Load bar

@Test(
    "Against typical Load 50, the Load bar fills to Load over twice typical, full from 100",
    arguments: [
        (25, 0.25),
        (100, 1.0),
        (130, 1.0),
    ]
)
func theLoadBarFillsToTheDaysLoadOverTwiceTypicalLoad(load: Int, fill: Double) {
    let view = todayView(
        dayLoads: typicalLoadBeforeNov1(50) + [
            DayLoad(day: nov1, load: load, heartRate: heartRate())
        ]
    )

    #expect(view.loadPopup?.loadBarFill == fill)
}

@Test func aDayWithItsLoadMissingHasAnEmptyLoadBar() {
    let view = todayView(
        dayLoads: typicalLoadBeforeNov1(50) + [
            DayLoad(day: nov1, load: nil, missingReason: .noRecords)
        ]
    )

    #expect(view.loadPopup?.loadBarFill == 0)
}

@Test func withFewerThan4DaysThereIsNoLoadBar() throws {
    let view = todayView(
        dayLoads: Array(typicalLoadBeforeNov1(50).dropFirst()) + [
            DayLoad(day: nov1, load: 57, heartRate: heartRate())
        ]
    )
    let popup = try #require(view.loadPopup)

    #expect(popup.loadBarFill == nil)
}

@Test(
    "Against typical Load 0, Load 0 leaves the Load bar empty and any other Load fills it",
    arguments: [
        (0, 0.0),
        (5, 1.0),
    ]
)
func theLoadBarAgainstTypicalLoadZero(load: Int, fill: Double) {
    let view = todayView(
        dayLoads: typicalLoadBeforeNov1(0) + [
            DayLoad(day: nov1, load: load, heartRate: heartRate())
        ]
    )

    #expect(view.loadPopup?.loadBarFill == fill)
}

@Test func aDayWithNoRecordsStillHasTheSentenceTypicalLineAndLoadBar() throws {
    let view = todayView(
        dayLoads: typicalLoadBeforeNov1(50) + [
            DayLoad(day: nov1, load: nil, missingReason: .noRecords)
        ]
    )
    let popup = try #require(view.loadPopup)

    #expect(popup.note == "No heart rate recorded this Day")
    #expect(popup.comparisonText == "No Load this Day")
    #expect(popup.typicalText == "Typical: 50")
    #expect(popup.loadBarFill == 0)
}

@Test func aDayWithHRZonesNotAvailableStillHasTheSentenceTypicalLineAndLoadBar() throws {
    // Load 40 against typical Load 50: 0.8 of typical, and 40 of the bar's 100.
    let view = todayView(dayLoads: typicalLoadBeforeNov1(50) + [DayLoad(day: nov1, load: 40)])
    let popup = try #require(view.loadPopup)

    #expect(popup.note == "Heart rate zones aren't available for this Day")
    #expect(popup.comparisonText == "About your usual Day")
    #expect(popup.typicalText == "Typical: 50 · today −10")
    #expect(popup.loadBarFill == 0.4)
}

// MARK: The Day's Load while typical Load is learned

@Test func withFewerThan4DaysTheDaysLoadShowsAsANumber() {
    let view = todayView(
        dayLoads: Array(typicalLoadBeforeNov1(50).dropFirst()) + [
            DayLoad(day: nov1, load: 40, heartRate: heartRate())
        ]
    )

    #expect(view.loadPopup?.learningLoadText == "Load 40")
}

@Test func withFewerThan4DaysAMissingLoadShowsADash() {
    let view = todayView(
        dayLoads: Array(typicalLoadBeforeNov1(50).dropFirst()) + [
            DayLoad(day: nov1, load: nil, missingReason: .noRecords)
        ]
    )

    #expect(view.loadPopup?.learningLoadText == "Load —")
}

@Test func withATypicalLoadTheDaysLoadDoesNotShowAsANumber() throws {
    let view = todayView(
        dayLoads: typicalLoadBeforeNov1(50) + [
            DayLoad(day: nov1, load: 40, heartRate: heartRate())
        ]
    )
    let popup = try #require(view.loadPopup)

    #expect(popup.learningLoadText == nil)
}
