import Foundation
import SerenixCore
import Testing

/// 1 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!
/// 2026-11-01T08:12:00Z, 08:12 local in London.
private let now = Date(timeIntervalSince1970: 1_793_520_720)
private let nov1 = Day(year: 2026, month: 11, day: 1)
/// 2026-10-31T23:18:00Z, 23:18 local in London.
private let onsetOct31At2318 = Date(timeIntervalSince1970: 1_793_488_680)
/// 2026-11-01T06:51:00Z, 06:51 local in London.
private let finalWakeNov1At0651 = Date(timeIntervalSince1970: 1_793_515_860)
/// Time Asleep of 7 h 12 m.
private let sevenHoursTwelve: TimeInterval = 25_920

private func storyForNov1() -> TodayStory {
    TodayView(
        nights: [
            Night(
                day: nov1,
                sleepOnset: onsetOct31At2318,
                finalWake: finalWakeNov1At0651,
                timeAsleep: sevenHoursTwelve
            )
        ],
        dayLoads: [],
        showing: nov1,
        now: now,
        timeZone: london,
        sync: .idle,
        profileName: nil
    ).story
}

@Test func aDayWithANightTellsItsStoryInFourStepsInOrder() {
    #expect(storyForNov1().steps.map(\.kind) == [.sleep, .overnight, .thisMorning, .todaySoFar])
}

@Test func theSleepStepRunsFromSleepOnsetToFinalWakeAndSaysHowLongYouSlept() {
    let sleep = storyForNov1().steps.first { $0.kind == .sleep }
    #expect(sleep?.timeLabel == "23:18 \u{2192} 06:51")
    #expect(sleep?.title == "You slept 7h 12m")
}

// MARK: Overnight step

private let oct29 = Day(year: 2026, month: 10, day: 29)

private let oct30 = Day(year: 2026, month: 10, day: 30)

private let oct31 = Day(year: 2026, month: 10, day: 31)

/// The Overnight step for 1 Nov's Night, after `earlier` Nights.
private func overnightStep(_ night: Night, earlier: [Night] = []) -> StoryStep? {
    TodayView(
        nights: earlier + [night],
        dayLoads: [],
        showing: nov1,
        now: now,
        timeZone: london,
        sync: .idle,
        profileName: nil
    ).story.steps.first { $0.kind == .overnight }
}

@Test func theOvernightStepIsLabelledOvernightAndTitledNightlyMetrics() {
    let overnight = overnightStep(Night(day: nov1, sleepingHR: 52))
    #expect(overnight?.timeLabel == "Overnight")
    #expect(overnight?.title == "Nightly Metrics")
}

@Test func theOvernightStepListsOnlyTheNightlyMetricsTheNightHas() {
    let overnight = overnightStep(Night(day: nov1, sleepingHR: 52, spo2: 97))
    #expect(overnight?.metrics.map(\.metric) == [.sleepingHR, .spo2])
}

@Test func otherStepsListNoNightlyMetrics() {
    let steps = storyForNov1().steps.filter { $0.kind != .overnight }
    #expect(steps.allSatisfy { $0.metrics.isEmpty })
}

@Test func eachOvernightMetricCarriesItsZone() {
    // Three earlier Nights at Sleeping HR 52 give a Baseline of 52 bpm; 52 is In range.
    // SpO2 97% is at or above 95%, its fixed In range level. 91% is below 92%, Out of range.
    let earlier = [oct29, oct30, oct31].map { Night(day: $0, sleepingHR: 52) }
    let overnight = overnightStep(Night(day: nov1, sleepingHR: 52, spo2: 97), earlier: earlier)
    #expect(overnight?.metrics.map(\.zone) == [.inRange, .inRange])

    let lowSpO2 = overnightStep(Night(day: nov1, spo2: 91))
    #expect(lowSpO2?.metrics.map(\.zone) == [.outOfRange])
}

// MARK: This morning step

/// The This morning step for 1 Nov's Night, after `earlier` Nights.
private func thisMorningStep(_ night: Night, earlier: [Night] = []) -> StoryStep? {
    TodayView(
        nights: earlier + [night],
        dayLoads: [],
        showing: nov1,
        now: now,
        timeZone: london,
        sync: .idle,
        profileName: nil
    ).story.steps.first { $0.kind == .thisMorning }
}

/// Three earlier Nights at HRV 60 ms and Sleeping HR 50 bpm: Baselines of 60 ms and 50 bpm.
private let threeCalibratedNightsBeforeNov1 = [oct29, oct30, oct31].map {
    Night(day: $0, sleepingHR: 50, hrv: 60)
}

@Test func theThisMorningStepIsLabelledThisMorning() {
    let step = thisMorningStep(Night(day: nov1, sleepingHR: 50, hrv: 60))
    #expect(step?.timeLabel == "This morning")
}

@Test func theThisMorningStepShowsReadinessWithItsBandAndAdvice() {
    // HRV 59 against 60 ms, Sleeping HR 50 against 50 bpm, Time Asleep 8 h against Sleep Need 8 h:
    // Readiness 67, Ready (pinned in TodayViewTests' readinessShowsItsNumberAndBand).
    let shown = Night(day: nov1, sleepingHR: 50, hrv: 59, timeAsleep: 28_800)
    let step = thisMorningStep(shown, earlier: threeCalibratedNightsBeforeNov1)
    #expect(step?.title == "Readiness 67 \u{2014} Ready")
    #expect(
        step?.advice
            == "You've recovered well. A good day to push: go for a harder session if you feel like it."
    )
}

@Test func whileCalibratingTheThisMorningStepCountsNightsAndGivesNoAdvice() {
    let step = thisMorningStep(
        Night(day: nov1, sleepingHR: 50, hrv: 60),
        earlier: [Night(day: oct31, sleepingHR: 50, hrv: 60)]
    )
    #expect(step?.title == "Readiness calibrating \u{2014} 2/4")
    #expect(step?.advice == nil)
}

@Test func otherStepsGiveNoAdvice() {
    let steps = storyForNov1().steps.filter { $0.kind != .thisMorning }
    #expect(steps.allSatisfy { $0.advice == nil })
}

// MARK: Today so far step

/// Loads of 12 on 31 Oct and 5 on 1 Nov, shown as "12" and "5" (pinned in TodayViewTests).
private let loadsOct31AndNov1 = [DayLoad(day: oct31, load: 12), DayLoad(day: nov1, load: 5)]

private func story(nights: [Night], showing day: Day) -> TodayStory {
    TodayView(
        nights: nights,
        dayLoads: loadsOct31AndNov1,
        showing: day,
        now: now,
        timeZone: london,
        sync: .idle,
        profileName: nil
    ).story
}

@Test func todayWithoutANightSaysNoNightYetAndTellsOnlyTodaySoFar() {
    let story = story(nights: [Night(day: oct31)], showing: nov1)
    #expect(story.noNightMessage == "No Night yet")
    #expect(story.steps.map(\.kind) == [.todaySoFar])
    #expect(story.steps.first?.timeLabel == "Today so far")
    #expect(story.steps.first?.title == "Load 5")
}

@Test func anEarlierDayWithoutANightSaysNoNightRecordedAndLabelsItsLoadThatDay() {
    let story = story(nights: [Night(day: oct30), Night(day: nov1)], showing: oct31)
    #expect(story.noNightMessage == "No Night recorded")
    #expect(story.steps.map(\.kind) == [.todaySoFar])
    #expect(story.steps.first?.timeLabel == "That Day")
    #expect(story.steps.first?.title == "Load 12")
}

@Test func aDayWithANightHasNoNoNightMessageAndLabelsTodaySoFar() {
    let story = story(nights: [Night(day: nov1)], showing: nov1)
    #expect(story.noNightMessage == nil)
    let step = story.steps.first { $0.kind == .todaySoFar }
    #expect(step?.timeLabel == "Today so far")
    #expect(step?.title == "Load 5")
}

// MARK: Load against typical Load

private let oct28 = Day(year: 2026, month: 10, day: 28)

/// The Today so far step for 1 Nov's Night, with `dayLoads`.
private func todaySoFarStep(dayLoads: [DayLoad]) -> StoryStep? {
    TodayView(
        nights: [Night(day: nov1)],
        dayLoads: dayLoads,
        showing: nov1,
        now: now,
        timeZone: london,
        sync: .idle,
        profileName: nil
    ).story.steps.first { $0.kind == .todaySoFar }
}

/// Four earlier Days at Load 10: a typical Load of 10.
private let fourDaysAtLoad10 = [oct28, oct29, oct30, oct31].map { DayLoad(day: $0, load: 10) }

@Test func theLoadBarIsTheDaysLoadAgainstTypicalLoad() {
    let step = todaySoFarStep(dayLoads: fourDaysAtLoad10 + [DayLoad(day: nov1, load: 5)])
    #expect(step?.loadVsTypical == 0.5)
}

@Test func theLoadBarIsFullWhenLoadIsAboveTypical() {
    let step = todaySoFarStep(dayLoads: fourDaysAtLoad10 + [DayLoad(day: nov1, load: 15)])
    #expect(step?.loadVsTypical == 1)
}

@Test func thereIsNoLoadBarWhileTypicalLoadIsCalibrating() {
    let threeDays = [oct29, oct30, oct31].map { DayLoad(day: $0, load: 10) }
    let step = todaySoFarStep(dayLoads: threeDays + [DayLoad(day: nov1, load: 5)])
    #expect(step != nil)
    #expect(step?.loadVsTypical == nil)
}

@Test func thereIsNoLoadBarWhenTheDayHasNoLoad() {
    let step = todaySoFarStep(dayLoads: fourDaysAtLoad10)
    #expect(step != nil)
    #expect(step?.loadVsTypical == nil)
}

@Test func thereIsNoLoadBarWhenTypicalLoadIsZero() {
    // Four earlier Days at Load 0 give a typical Load of 0: nothing to compare against.
    let restDays = [oct28, oct29, oct30, oct31].map { DayLoad(day: $0, load: 0) }
    let step = todaySoFarStep(dayLoads: restDays + [DayLoad(day: nov1, load: 5)])
    #expect(step != nil)
    #expect(step?.loadVsTypical == nil)
}

@Test func otherStepsHaveNoLoadBar() {
    let steps = storyForNov1().steps.filter { $0.kind != .todaySoFar }
    #expect(steps.allSatisfy { $0.loadVsTypical == nil })
}

// MARK: Taps

@Test func eachStepNamesThePopupATapOpensAndOvernightIsTappedByItsRows() {
    #expect(storyForNov1().steps.map(\.tap) == [.sleep, nil, .readiness, .load])
}

@Test func eachOvernightRowNamesItsMetricsPopup() {
    let overnight = overnightStep(Night(day: nov1, sleepingHR: 52, spo2: 97))
    #expect(overnight?.rowTaps == [.metric(.sleepingHR), .metric(.spo2)])
}

@Test func withoutANightTheTodaySoFarStepOpensLoad() {
    let story = story(nights: [Night(day: oct31)], showing: nov1)
    #expect(story.steps.map(\.tap) == [.load])
}
