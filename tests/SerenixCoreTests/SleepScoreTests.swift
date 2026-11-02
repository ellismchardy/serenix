import Foundation
import SerenixCore
import Testing

// Sleep Score on the Today view's Sleep Score ring (spec 010, Behavior: Sleep Sufficiency,
// Sleep Efficiency, Sleep Consistency, Sleep Score, Missing and left out). Expected values are spec 010's success
// criteria, worked by hand from its rules.

/// 14–15 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!

/// 2026-11-15T08:12:00Z, 08:12 local in London.
private let now = Date(timeIntervalSince1970: 1_794_730_320)

private let nov15 = Day(year: 2026, month: 11, day: 15)

private let oneHour: TimeInterval = 3_600

private let oneMinute: TimeInterval = 60

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

/// `hour`:`minute` UTC (and so London local time) on `day` Nov 2026.
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(
        from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)
    )!
}

/// The Night shown, dated 15 Nov: by default Sleep Onset 23:00 on 14 Nov, Final Wake 07:00 and
/// Time Asleep 8 h (spec 010's default fixture).
private func nightOn15Nov(
    sleepOnset: Date? = at(14, 23),
    finalWake: Date? = at(15, 7),
    timeAsleep: TimeInterval? = 8 * oneHour
) -> Night {
    Night(
        day: nov15,
        sleepOnset: sleepOnset,
        finalWake: finalWake,
        timeAsleep: timeAsleep
    )
}

/// Earlier Nights dated 14 Nov, 13 Nov and so on back, with the given Time Asleep in that order
/// and no Sleep Onset or Final Wake.
private func earlierNights(_ timesAsleep: [TimeInterval]) -> [Night] {
    timesAsleep.enumerated().map { offset, timeAsleep in
        Night(day: Day(year: 2026, month: 11, day: 14 - offset), timeAsleep: timeAsleep)
    }
}

// MARK: Score and Sleep Sufficiency

@Test func theDefaultNightReads100WithTheRingFull() {
    let view = todayView(nights: [nightOn15Nov()])

    #expect(view.sleepScoreText == "100")
    #expect(view.sleepScoreFill == 1.0)
}

@Test func sixHoursAsleepAgainstASleepNeedOf8HoursReads81() {
    let view = todayView(nights: [nightOn15Nov(finalWake: at(15, 5, 18), timeAsleep: 6 * oneHour)])

    #expect(view.sleepScoreText == "81")
}

@Test func timeAsleep7Hours36Reads96AndTheRingFillsTo096() {
    let view = todayView(nights: [nightOn15Nov(timeAsleep: 7 * oneHour + 36 * oneMinute)])

    #expect(view.sleepScoreText == "96")
    #expect(view.sleepScoreFill == 0.96)
}

@Test func aSleepNeedRaisedTo9HoursLowersSleepSufficiency() {
    let view = todayView(
        nights: [nightOn15Nov()] + earlierNights(Array(repeating: 6 * oneHour, count: 4))
    )

    #expect(view.sleepScoreText == "92")
}

// MARK: Sleep Efficiency

@Test func eightHoursAsleepInANineHourSleepPeriodReads92() {
    let view = todayView(nights: [nightOn15Nov(sleepOnset: at(14, 22))])

    #expect(view.sleepScoreText == "92")
}

@Test func sleepEfficiencyBelow75PercentScoresZeroAndReads75() {
    let view = todayView(nights: [nightOn15Nov(sleepOnset: at(14, 20))])

    #expect(view.sleepScoreText == "75")
}

@Test func withNoSleepOnsetSleepEfficiencyIsLeftOutAndSleepSufficiencyAloneReads75() {
    let view = todayView(nights: [nightOn15Nov(sleepOnset: nil, timeAsleep: 6 * oneHour)])

    #expect(view.sleepScoreText == "75")
}

@Test func timeAsleepLongerThanTheSleepPeriodLeavesOutSleepEfficiencyAndReads100() {
    let view = todayView(nights: [nightOn15Nov(sleepOnset: at(14, 23, 30))])

    #expect(view.sleepScoreText == "100")
    #expect(part("Sleep Efficiency", of: view)?.scoreText == "\u{2014}")
    #expect(part("Sleep Efficiency", of: view)?.detailText == "\u{2014}")
}

// MARK: Sleep Consistency

/// An earlier Night dated `day` Nov for Sleep Consistency, carrying only a Sleep Onset and a
/// Final Wake (no Time Asleep, so Sleep Need stays 8 h).
private func nightOnNov(_ day: Int, onset: Date?, wake: Date?) -> Night {
    Night(day: Day(year: 2026, month: 11, day: day), sleepOnset: onset, finalWake: wake)
}

/// Earlier Nights dated 14, 13 and 12 Nov, each 23:00 the evening before to 07:00.
private let usualEarlierNights = [14, 13, 12].map { day in
    nightOnNov(day, onset: at(day - 1, 23), wake: at(day, 7))
}

@Test func sleepingAtTheUsualTimesReads100() {
    let view = todayView(nights: [nightOn15Nov()] + usualEarlierNights)

    #expect(view.sleepScoreText == "100")
}

@Test func sleepOnset30AndFinalWake40MinutesLaterThanUsualIs35MinutesOffAndReads94() {
    // Onset +30 min, wake +40 min: 35 min off, Sleep Consistency 70.8; 8 h asleep in 8 h 10 m
    // (98%) keeps Sleep Efficiency 100. 60 + 20 + 14.17 = 94.17.
    let view = todayView(
        nights: [nightOn15Nov(sleepOnset: at(14, 23, 30), finalWake: at(15, 7, 40))]
            + usualEarlierNights
    )

    #expect(view.sleepScoreText == "94")
}

@Test func twoHoursOffTheUsualTimesScoresSleepConsistencyZeroAndReads80() {
    let view = todayView(
        nights: [nightOn15Nov(sleepOnset: at(15, 1), finalWake: at(15, 9))] + usualEarlierNights
    )

    #expect(view.sleepScoreText == "80")
}

@Test func sleepOnsetsAroundMidnightAreComparedTheShortestWayRoundTheClock() {
    // Tonight 00:10 against 23:50, 23:40 and 00:20 is +20, +30 and -10 min (median 20); Final
    // Wake 08:10 each time is 0 off. 10 min off: Sleep Consistency 91.7. 60 + 20 + 18.33 = 98.33.
    let earlier = [
        nightOnNov(14, onset: at(13, 23, 50), wake: at(14, 8, 10)),
        nightOnNov(13, onset: at(12, 23, 40), wake: at(13, 8, 10)),
        nightOnNov(12, onset: at(12, 0, 20), wake: at(12, 8, 10)),
    ]
    let view = todayView(
        nights: [nightOn15Nov(sleepOnset: at(15, 0, 10), finalWake: at(15, 8, 10))] + earlier
    )

    #expect(view.sleepScoreText == "98")
}

@Test func withOnlyTwoEarlierNightsSleepConsistencyIsLeftOutAndTheNightReads100() {
    let view = todayView(
        nights: [
            nightOn15Nov(),
            nightOnNov(14, onset: at(14, 1), wake: at(14, 9)),
            nightOnNov(13, onset: at(13, 1), wake: at(13, 9)),
        ]
    )

    #expect(view.sleepScoreText == "100")
}

@Test func anEarlierNightWithNoFinalWakeDoesNotCountForSleepConsistency() {
    let view = todayView(
        nights: [
            nightOn15Nov(),
            nightOnNov(14, onset: at(14, 1), wake: at(14, 9)),
            nightOnNov(13, onset: at(13, 1), wake: at(13, 9)),
            nightOnNov(12, onset: at(12, 1), wake: nil),
        ]
    )

    #expect(view.sleepScoreText == "100")
    #expect(part("Sleep Consistency", of: view)?.scoreText == "\u{2014}")
    #expect(part("Sleep Consistency", of: view)?.detailText == "Needs 3 Nights")
}

@Test func anEarlierNightDated8NovCountsForSleepConsistency() {
    // 01:00 to 09:00 on 13, 12 and 8 Nov against tonight's 23:00 to 07:00: 2 h off, Sleep
    // Consistency 0.
    let view = todayView(
        nights: [
            nightOn15Nov(),
            nightOnNov(13, onset: at(13, 1), wake: at(13, 9)),
            nightOnNov(12, onset: at(12, 1), wake: at(12, 9)),
            nightOnNov(8, onset: at(8, 1), wake: at(8, 9)),
        ]
    )

    #expect(view.sleepScoreText == "80")
    #expect(part("Sleep Consistency", of: view)?.scoreText == "0")
}

@Test func anEarlierNightDated7NovDoesNotCountForSleepConsistency() {
    let view = todayView(
        nights: [
            nightOn15Nov(),
            nightOnNov(13, onset: at(13, 1), wake: at(13, 9)),
            nightOnNov(12, onset: at(12, 1), wake: at(12, 9)),
            nightOnNov(7, onset: at(7, 1), wake: at(7, 9)),
        ]
    )

    #expect(view.sleepScoreText == "100")
    #expect(part("Sleep Consistency", of: view)?.scoreText == "\u{2014}")
}

@Test func withNoSleepOnsetTonightSleepConsistencyIsLeftOutAndSleepSufficiencyAloneReads100() {
    // The earlier Nights are 2 h off tonight's Final Wake, so a Sleep Consistency wrongly worked
    // out from Final Wake alone would pull the score below 100.
    let earlier = [14, 13, 12].map { day in nightOnNov(day, onset: at(day, 1), wake: at(day, 9)) }
    let view = todayView(nights: [nightOn15Nov(sleepOnset: nil)] + earlier)

    #expect(view.sleepScoreText == "100")
}

// MARK: Missing and where it shows

@Test func aNightWithNoTimeAsleepHasNoSleepScoreAndAnEmptyRing() {
    let view = todayView(nights: [nightOn15Nov(timeAsleep: nil)])

    #expect(view.sleepScoreText == "\u{2014}")
    #expect(view.sleepScoreFill == 0)
}

@Test func theReadinessPopupsSleepScoreRowShowsTheNightsSleepScore() {
    // Spec 008's usual HRV 60 ms and Sleeping HR 52 bpm on four earlier Nights (14 to 11 Nov),
    // with no Time Asleep, Sleep Onset or Final Wake, so Readiness is past Calibrating and Sleep
    // Need stays 8 h. Time Asleep 7 h 36 m in 23:00 to 07:00 reads 96.
    let earlier = (11...14).map { day in
        Night(day: Day(year: 2026, month: 11, day: day), sleepingHR: 52, hrv: 60)
    }
    var shown = nightOn15Nov(timeAsleep: 7 * oneHour + 36 * oneMinute)
    shown.sleepingHR = 52
    shown.hrv = 60

    let popup = todayView(nights: earlier + [shown]).readinessPopup

    #expect(popup?.sleepScoreText == "96")
}

// MARK: Sleep popup

/// The Sleep popup's part called `name` ("Sleep Sufficiency", "Sleep Efficiency" or "Sleep
/// Consistency") on `view`.
private func part(_ name: String, of view: TodayView) -> SleepScorePart? {
    view.sleepPopup?.parts.first { $0.name == name }
}

@Test func theSleepPopupShowsSleepSufficiencySleepEfficiencyAndSleepConsistencyInOrder() {
    let popup = todayView(nights: [nightOn15Nov()]).sleepPopup

    #expect(
        popup?.parts.map(\.name) == ["Sleep Sufficiency", "Sleep Efficiency", "Sleep Consistency"]
    )
}

@Test func theDefaultNightsSleepPopupShowsEachPartAndWhatItCameFrom() {
    let view = todayView(nights: [nightOn15Nov()])

    let sufficiency = part("Sleep Sufficiency", of: view)
    #expect(sufficiency?.scoreText == "100")
    #expect(sufficiency?.fill == 1.0)
    #expect(sufficiency?.detailText == "8h 0m of 8h 0m")

    let efficiency = part("Sleep Efficiency", of: view)
    #expect(efficiency?.scoreText == "100")
    #expect(efficiency?.fill == 1.0)
    #expect(efficiency?.detailText == "100% asleep")

    let consistency = part("Sleep Consistency", of: view)
    #expect(consistency?.scoreText == "\u{2014}")
    #expect(consistency?.fill == 0)
    #expect(consistency?.detailText == "Needs 3 Nights")
}

@Test func sixHoursAsleepShowsSleepSufficiency75Of8Hours() {
    let view = todayView(nights: [nightOn15Nov(finalWake: at(15, 5, 18), timeAsleep: 6 * oneHour)])

    let sufficiency = part("Sleep Sufficiency", of: view)
    #expect(sufficiency?.scoreText == "75")
    #expect(sufficiency?.fill == 0.75)
    #expect(sufficiency?.detailText == "6h 0m of 8h 0m")
    #expect(part("Sleep Efficiency", of: view)?.scoreText == "100")
}

@Test func aSleepNeedOf9HoursShowsSleepSufficiency89() {
    let view = todayView(
        nights: [nightOn15Nov()] + earlierNights(Array(repeating: 6 * oneHour, count: 4))
    )

    let sufficiency = part("Sleep Sufficiency", of: view)
    #expect(sufficiency?.scoreText == "89")
    #expect(sufficiency?.fill == 0.89)
    #expect(sufficiency?.detailText == "8h 0m of 9h 0m")
}

@Test func eightHoursAsleepInNineShowsSleepEfficiency69And89PercentAsleep() {
    let view = todayView(nights: [nightOn15Nov(sleepOnset: at(14, 22))])

    let efficiency = part("Sleep Efficiency", of: view)
    #expect(efficiency?.scoreText == "69")
    #expect(efficiency?.fill == 0.69)
    #expect(efficiency?.detailText == "89% asleep")
}

@Test func eightHoursAsleepInElevenShowsSleepEfficiency0And73PercentAsleep() {
    // 8 h of 11 h is 72.7%, which rounds to 73%.
    let view = todayView(nights: [nightOn15Nov(sleepOnset: at(14, 20))])

    let efficiency = part("Sleep Efficiency", of: view)
    #expect(efficiency?.scoreText == "0")
    #expect(efficiency?.fill == 0)
    #expect(efficiency?.detailText == "73% asleep")
}

@Test func withNoSleepOnsetTheSleepPopupShowsSleepEfficiencyLeftOut() {
    let view = todayView(nights: [nightOn15Nov(sleepOnset: nil, timeAsleep: 6 * oneHour)])

    let efficiency = part("Sleep Efficiency", of: view)
    #expect(efficiency?.scoreText == "\u{2014}")
    #expect(efficiency?.fill == 0)
    #expect(efficiency?.detailText == "\u{2014}")
}

@Test func sleepingAtTheUsualTimesShowsSleepConsistency100And0MinutesOff() {
    let view = todayView(nights: [nightOn15Nov()] + usualEarlierNights)

    let consistency = part("Sleep Consistency", of: view)
    #expect(consistency?.scoreText == "100")
    #expect(consistency?.fill == 1.0)
    #expect(consistency?.detailText == "0m off your usual")
}

@Test func thirtyFiveMinutesOffShowsSleepConsistency71() {
    let view = todayView(
        nights: [nightOn15Nov(sleepOnset: at(14, 23, 30), finalWake: at(15, 7, 40))]
            + usualEarlierNights
    )

    let consistency = part("Sleep Consistency", of: view)
    #expect(consistency?.scoreText == "71")
    #expect(consistency?.fill == 0.71)
    #expect(consistency?.detailText == "35m off your usual")
}

@Test func twoHoursOffShowsSleepConsistency0And2HoursOff() {
    let view = todayView(
        nights: [nightOn15Nov(sleepOnset: at(15, 1), finalWake: at(15, 9))] + usualEarlierNights
    )

    let consistency = part("Sleep Consistency", of: view)
    #expect(consistency?.scoreText == "0")
    #expect(consistency?.fill == 0)
    #expect(consistency?.detailText == "2h 0m off your usual")
}

@Test func sleepOnsetsAroundMidnightShowSleepConsistency92And10MinutesOff() {
    let earlier = [
        nightOnNov(14, onset: at(13, 23, 50), wake: at(14, 8, 10)),
        nightOnNov(13, onset: at(12, 23, 40), wake: at(13, 8, 10)),
        nightOnNov(12, onset: at(12, 0, 20), wake: at(12, 8, 10)),
    ]
    let view = todayView(
        nights: [nightOn15Nov(sleepOnset: at(15, 0, 10), finalWake: at(15, 8, 10))] + earlier
    )

    let consistency = part("Sleep Consistency", of: view)
    #expect(consistency?.scoreText == "92")
    #expect(consistency?.fill == 0.92)
    #expect(consistency?.detailText == "10m off your usual")
}

@Test func withOnlyTwoEarlierNightsTheSleepPopupShowsSleepConsistencyNeeds3Nights() {
    let view = todayView(
        nights: [
            nightOn15Nov(),
            nightOnNov(14, onset: at(14, 1), wake: at(14, 9)),
            nightOnNov(13, onset: at(13, 1), wake: at(13, 9)),
        ]
    )

    let consistency = part("Sleep Consistency", of: view)
    #expect(consistency?.scoreText == "\u{2014}")
    #expect(consistency?.fill == 0)
    #expect(consistency?.detailText == "Needs 3 Nights")
}

@Test func withNoTimeAsleepTheSleepPopupsThreeRingsReadDashAndAreEmpty() {
    let popup = todayView(nights: [nightOn15Nov(timeAsleep: nil)]).sleepPopup

    #expect(popup?.parts.count == 3)
    #expect(popup?.parts.map(\.scoreText) == ["\u{2014}", "\u{2014}", "\u{2014}"])
    #expect(popup?.parts.map(\.fill) == [0, 0, 0])
    #expect(popup?.parts.map(\.detailText) == ["\u{2014}", "\u{2014}", "\u{2014}"])
}

@Test func anHourAndTenMinutesOffShowsSleepConsistency42() {
    // Tonight 00:10 to 08:10 against 23:00 to 07:00: 70 minutes off both, Sleep Consistency
    // 100 × (1 − 70/120) = 41.7; 60 + 20 + 8.33 = 88.3 reads 88.
    let view = todayView(
        nights: [nightOn15Nov(sleepOnset: at(15, 0, 10), finalWake: at(15, 8, 10))]
            + usualEarlierNights
    )

    #expect(view.sleepScoreText == "88")
    #expect(part("Sleep Consistency", of: view)?.scoreText == "42")
    #expect(part("Sleep Consistency", of: view)?.detailText == "1h 10m off your usual")
}
