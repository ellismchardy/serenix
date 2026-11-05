import Foundation
import SerenixCore
import Testing

// The Body tab's view (spec 014). Expected values are spec 014's success criteria under
// "Weigh-ins and Trend Weight", worked by hand from its rules.

/// 1–5 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!

private let nov1 = Day(year: 2026, month: 11, day: 1)

private let nov2 = Day(year: 2026, month: 11, day: 2)

private let nov4 = Day(year: 2026, month: 11, day: 4)

/// `hour`:`minute` UTC (and so London local time) on `month`/`day` 2026 (November by default).
private func at(month: Int = 11, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(
        from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
    )!
}

/// 5 Nov 2026 09:00 in London, after every Weigh-in here.
private let now = at(5, 9)

private func bodyView(weighIns: [WeighIn]) -> BodyView {
    BodyView(weighIns: weighIns, now: now, timeZone: london)
}

/// Whether `actual` is within 1e-9 kg of `expected`.
private func isClose(_ actual: Double?, _ expected: Double) -> Bool {
    guard let actual else { return false }
    return abs(actual - expected) < 1e-9
}

@Test func weighInsOnConsecutiveDaysGiveTrendWeightOneTenthOfTheWayToTheNewWeighIn() {
    let view = bodyView(weighIns: [
        WeighIn(time: at(1, 7), kilograms: 80.0),
        WeighIn(time: at(2, 7), kilograms: 79.0),
    ])

    #expect(view.trend.map(\.day) == [nov1, nov2])
    #expect(isClose(view.trend.first?.trendWeight, 80.0))
    #expect(isClose(view.trend.last?.trendWeight, 79.9))
    #expect(isClose(view.trendWeight, 79.9))
    #expect(view.lastWeighIn == WeighIn(time: at(2, 7), kilograms: 79.0))
}

@Test func aWeighInThreeDaysAfterThePreviousMovesTrendWeightFurther() {
    // α = 1 − 0.9^3 = 0.271, so 80.0 + 0.271 × (79.0 − 80.0) = 79.729.
    let view = bodyView(weighIns: [
        WeighIn(time: at(1, 7), kilograms: 80.0),
        WeighIn(time: at(4, 7), kilograms: 79.0),
    ])

    #expect(isClose(view.trend.last?.trendWeight, 79.729))
    #expect(isClose(view.trendWeight, 79.729))
}

@Test func onlyTheLowestWeighInOnADayMovesTrendWeightButEveryWeighInIsListed() {
    // On 2 Nov the lower Weigh-in (79.0) is the later one and comes first in the input, so
    // neither the first nor the last by time nor by input order would pick it by accident.
    let morning = WeighIn(time: at(2, 7), kilograms: 79.6)
    let evening = WeighIn(time: at(2, 20), kilograms: 79.0)
    let first = WeighIn(time: at(1, 7), kilograms: 80.0)
    let view = bodyView(weighIns: [evening, first, morning])

    #expect(view.trend.map(\.day) == [nov1, nov2])
    #expect(isClose(view.trend.last?.weighIn, 79.0))
    #expect(isClose(view.trend.last?.trendWeight, 79.9))
    #expect(view.weighIns == [evening, morning, first])
}

@Test func daysWithoutAWeighInHaveNoTrendWeightPoint() {
    let view = bodyView(weighIns: [
        WeighIn(time: at(1, 7), kilograms: 80.0),
        WeighIn(time: at(4, 7), kilograms: 79.0),
    ])

    #expect(view.trend.map(\.day) == [nov1, nov4])
}

@Test func aWeighInFifteenDaysAfterThePreviousRestartsTrendWeightAndBreaksTheLine() {
    // 19 Oct to 3 Nov is 15 Days, more than 14, so Trend Weight restarts at 79.0.
    let view = bodyView(weighIns: [
        WeighIn(time: at(month: 10, 19, 7), kilograms: 80.0),
        WeighIn(time: at(3, 7), kilograms: 79.0),
    ])

    #expect(view.trend.map(\.startsNewLine) == [true, true])
    #expect(isClose(view.trend.last?.trendWeight, 79.0))
    #expect(isClose(view.trendWeight, 79.0))
}

@Test func aWeighInFourteenDaysAfterThePreviousCarriesTrendWeightOnWithoutABreak() {
    // 20 Oct to 3 Nov is 14 Days. α = 1 − 0.9^14 = 1 − 0.2287679245496101 = 0.7712320754503899,
    // so 80.0 + 0.7712320754503899 × (79.0 − 80.0) = 79.2287679245496101.
    let view = bodyView(weighIns: [
        WeighIn(time: at(month: 10, 20, 7), kilograms: 80.0),
        WeighIn(time: at(3, 7), kilograms: 79.0),
    ])

    #expect(view.trend.map(\.startsNewLine) == [true, false])
    #expect(isClose(view.trend.last?.trendWeight, 79.2287679245496101))
    #expect(isClose(view.trendWeight, 79.2287679245496101))
}

@Test func aWeighInUnderTwentyKilogramsIsRefusedWithAMessage() {
    let refusal = WeighIn(time: at(4, 7), kilograms: 19.9).refusal(now: now)

    #expect(refusal == .tooLight)
    #expect(refusal?.message == "A Weigh-in can't be under 20 kg.")
}

@Test func aWeighInOverThreeHundredFiftyKilogramsIsRefusedWithAMessage() {
    let refusal = WeighIn(time: at(4, 7), kilograms: 350.1).refusal(now: now)

    #expect(refusal == .tooHeavy)
    #expect(refusal?.message == "A Weigh-in can't be over 350 kg.")
}

@Test func aWeighInInTheFutureIsRefusedWithAMessage() {
    let refusal = WeighIn(time: at(5, 10), kilograms: 80.0).refusal(now: now)

    #expect(refusal == .inTheFuture)
    #expect(refusal?.message == "A Weigh-in can't be in the future.")
}

@Test func weighInsOfExactlyTwentyAndThreeHundredFiftyKilogramsAreAllowed() {
    #expect(WeighIn(time: at(4, 7), kilograms: 20.0).refusal(now: now) == nil)
    #expect(WeighIn(time: at(4, 7), kilograms: 350.0).refusal(now: now) == nil)
}
