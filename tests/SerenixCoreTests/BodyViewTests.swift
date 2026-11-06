import Foundation
import SerenixCore
import Testing

// The Body tab's view (spec 015). Expected values are spec 015's success criteria under
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

// The chart (spec 015, Screen: chart ranges, empty and early states). Range first Days are
// today (5 Nov 2026) minus 6, 29, 90 and 181 Days, counted by hand on the calendar.

private let oct20 = Day(year: 2026, month: 10, day: 20)

private let nov5 = Day(year: 2026, month: 11, day: 5)

@Test func eachChartRangeRunsFromItsFirstDayToToday() {
    let view = bodyView(weighIns: [WeighIn(time: at(4, 7), kilograms: 80.0)])

    #expect(view.chart(.week)?.firstDay == Day(year: 2026, month: 10, day: 30))
    #expect(view.chart(.month)?.firstDay == Day(year: 2026, month: 10, day: 7))
    #expect(view.chart(.threeMonths)?.firstDay == Day(year: 2026, month: 8, day: 7))
    #expect(view.chart(.sixMonths)?.firstDay == Day(year: 2026, month: 5, day: 8))
    for range in ChartRange.allCases {
        #expect(view.chart(range)?.lastDay == nov5)
    }
}

@Test func theWeekChartHoldsOnlyTrendWeightPointsFromTheLastSevenDays() {
    let view = bodyView(weighIns: [
        WeighIn(time: at(month: 10, 20, 7), kilograms: 81.0),
        WeighIn(time: at(1, 7), kilograms: 80.0),
        WeighIn(time: at(4, 7), kilograms: 79.0),
    ])

    #expect(view.chart(.week)?.points.map(\.day) == [nov1, nov4])
}

@Test func theAllChartStartsAtTheFirstCountedWeighInAndHoldsEveryPoint() {
    let view = bodyView(weighIns: [
        WeighIn(time: at(month: 10, 20, 7), kilograms: 81.0),
        WeighIn(time: at(1, 7), kilograms: 80.0),
        WeighIn(time: at(4, 7), kilograms: 79.0),
    ])

    let chart = view.chart(.all)
    #expect(chart?.firstDay == oct20)
    #expect(chart?.lastDay == nov5)
    #expect(chart?.points.map(\.day) == [oct20, nov1, nov4])
}

@Test func withNoWeighInsThereIsNoChartInAnyRange() {
    let view = bodyView(weighIns: [])

    for range in ChartRange.allCases {
        #expect(view.chart(range) == nil)
    }
}

@Test func oneWeighInGivesOneDotAndNoLine() {
    let view = bodyView(weighIns: [WeighIn(time: at(4, 7), kilograms: 80.0)])

    let chart = view.chart(.week)
    #expect(chart?.points.map(\.day) == [nov4])
    #expect(chart?.showsLine == false)
}

@Test func twoCountedWeighInsInRangeDrawTheLine() {
    let view = bodyView(weighIns: [
        WeighIn(time: at(1, 7), kilograms: 80.0),
        WeighIn(time: at(4, 7), kilograms: 79.0),
    ])

    let chart = view.chart(.week)
    #expect(chart?.points.count == 2)
    #expect(chart?.showsLine == true)
}

@Test func aRestartInsideTheRangeBreaksTheChartsLine() {
    // 20 Oct to 4 Nov is 15 Days, so Trend Weight restarts on 4 Nov (spec 015, Trend Weight).
    let view = bodyView(weighIns: [
        WeighIn(time: at(month: 10, 20, 7), kilograms: 80.0),
        WeighIn(time: at(4, 7), kilograms: 79.0),
        WeighIn(time: at(5, 7), kilograms: 78.0),
    ])

    #expect(view.chart(.month)?.points.map(\.startsNewLine) == [true, true, false])
}

@Test func chartRangesAreLabelledOneWeekToAll() {
    #expect(ChartRange.allCases.map(\.label) == ["1W", "1M", "3M", "6M", "All"])
}

// Units (spec 015, Units and Profile): weights show to one decimal in the chosen units, from kg
// stored. 82.4 kg = 181.66 lb (1 lb = 0.45359237 kg), and 181.7 lb = 12 st 13.7 lb.

@Test(arguments: [
    (WeightUnits.kilograms, "82.4 kg"),
    (WeightUnits.pounds, "181.7 lb"),
    (WeightUnits.stonesAndPounds, "12 st 13.7 lb"),
])
func aWeightShowsToOneDecimalInTheChosenUnits(units: WeightUnits, text: String) {
    let view = BodyView(weighIns: [], units: units, now: now, timeZone: london)

    #expect(view.text(82.4) == text)
}

@Test func aWeightThatRoundsUpToAWholeStoneShowsNoPoundsNotFourteen() {
    // 88.89 kg = 195.9689 lb, which rounds to 196.0 lb = 14 st exactly.
    let view = BodyView(weighIns: [], units: .stonesAndPounds, now: now, timeZone: london)

    #expect(view.text(88.89) == "14 st 0.0 lb")
}

// Weekly Rate (spec 015, Weekly Rate): the latest Trend Weight minus the Trend Weight at the last
// counted Weigh-in on or before 7 Days earlier, per week. Today is 5 Nov, so 7 Days earlier is
// 29 Oct. 0.9^7 = 0.4782969 and 0.9^9 = 0.387420489 exactly.

@Test func weeklyRateIsTheChangeInTrendWeightOverSevenDays() {
    // 29 Oct to 5 Nov is 7 Days: α = 1 − 0.9^7 = 0.5217031, so Trend Weight goes 80.0 →
    // 80.0 − 0.5217031 = 79.4782969, a change of −0.5217031 kg over exactly one week.
    let view = bodyView(weighIns: [
        WeighIn(time: at(month: 10, 29, 7), kilograms: 80.0),
        WeighIn(time: at(5, 7), kilograms: 79.0),
    ])

    #expect(isClose(view.weeklyRate, -0.5217031))
}

@Test func trendWeightFallingHalfAKilogramOverSevenDaysIsAWeeklyRateOfMinusHalf() {
    // The spec's own number. With α = 0.5217031 over 29 Oct → 5 Nov, a Weigh-in of
    // 79.04160048119323 kg (80 − 0.5 / 0.5217031) takes Trend Weight from 80.0 to 79.5.
    let view = bodyView(weighIns: [
        WeighIn(time: at(month: 10, 29, 7), kilograms: 80.0),
        WeighIn(time: at(5, 7), kilograms: 79.04160048119323),
    ])

    #expect(isClose(view.trendWeight, 79.5))
    #expect(isClose(view.weeklyRate, -0.5))
}

@Test func weeklyRateOverMoreThanSevenDaysIsScaledToPerWeek() {
    // 27 Oct to 5 Nov is 9 Days: α = 1 − 0.9^9 = 0.612579511, so the change is −0.612579511 kg,
    // and per week −0.612579511 × 7 / 9 = −4.288056577 / 9 = −0.476450730777…
    let view = bodyView(weighIns: [
        WeighIn(time: at(month: 10, 27, 7), kilograms: 80.0),
        WeighIn(time: at(5, 7), kilograms: 79.0),
    ])

    #expect(isClose(view.weeklyRate, -0.47645073077777778))
}

@Test func weeklyRateCountsFromTheLastWeighInOnOrBeforeSevenDaysEarlier() {
    // 28 and 29 Oct both qualify; 29 Oct (Trend Weight 80.0) is the last, 7 Days before 5 Nov,
    // so Weekly Rate is (79.4782969 − 80.0) × 7 / 7 = −0.5217031. Counting from 28 Oct would
    // give × 7 / 8 instead.
    let view = bodyView(weighIns: [
        WeighIn(time: at(month: 10, 28, 7), kilograms: 80.0),
        WeighIn(time: at(month: 10, 29, 7), kilograms: 80.0),
        WeighIn(time: at(5, 7), kilograms: 79.0),
    ])

    #expect(isClose(view.weeklyRate, -0.5217031))
}

@Test func thereIsNoWeeklyRateWhenCountedWeighInsSpanUnderSevenDays() {
    // 30 Oct to 5 Nov is 6 Days, so no Weigh-in is on or before 29 Oct.
    let view = bodyView(weighIns: [
        WeighIn(time: at(month: 10, 30, 7), kilograms: 80.0),
        WeighIn(time: at(5, 7), kilograms: 79.0),
    ])

    #expect(view.weeklyRate == nil)
}

@Test func thereIsNoWeeklyRateWhenTrendWeightRestartedSinceTheEarlierPoint() {
    // 10 Oct is the last Weigh-in on or before 29 Oct, but 10 Oct to 1 Nov is 22 Days, more
    // than 14, so Trend Weight restarts on 1 Nov, between that point and 5 Nov.
    let view = bodyView(weighIns: [
        WeighIn(time: at(month: 10, 10, 7), kilograms: 80.0),
        WeighIn(time: at(1, 7), kilograms: 79.0),
        WeighIn(time: at(5, 7), kilograms: 78.5),
    ])

    #expect(view.weeklyRate == nil)
}

@Test func thereIsNoWeeklyRateWithoutWeighIns() {
    #expect(bodyView(weighIns: []).weeklyRate == nil)
}
