import Foundation
import SerenixCore
import Testing

// Weight Goals and their Pace (spec 014, "Weight Goal": Pace by rate and the Pace bands).
// Expected values are worked by hand from the spec's rules: a Pace's band is its share of the
// current Trend Weight per week, ≤ 0.5% sustainable, > 0.5% to 1% aggressive, > 1% too fast.

/// 1–5 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!

private let nov5 = Day(year: 2026, month: 11, day: 5)

/// `hour`:`minute` UTC (and so London local time) on `day` November 2026.
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(
        from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)
    )!
}

/// 5 Nov 2026 09:00 in London, after every Weigh-in here.
private let now = at(5, 9)

/// One Weigh-in of 80.0 kg this morning, so Trend Weight is exactly 80.0 kg.
private let eightyToday = [WeighIn(time: at(5, 7), kilograms: 80.0)]

private func bodyView(
    weighIns: [WeighIn] = eightyToday,
    units: WeightUnits = .kilograms,
    goal: WeightGoal? = nil
) -> BodyView {
    BodyView(weighIns: weighIns, units: units, goal: goal, now: now, timeZone: london)
}

/// Whether `actual` is within 1e-9 of `expected`.
private func isClose(_ actual: Double?, _ expected: Double) -> Bool {
    guard let actual else { return false }
    return abs(actual - expected) < 1e-9
}

/// Whether `options` are exactly `expected` (kg a week, % of Trend Weight, band), in order.
private func matches(
    _ options: [RateOption],
    _ expected: [(kilogramsPerWeek: Double, percent: Double, band: PaceBand)]
) -> Bool {
    guard options.count == expected.count else { return false }
    return zip(options, expected).allSatisfy { option, want in
        isClose(option.kilogramsPerWeek, want.kilogramsPerWeek)
            && isClose(option.percentOfTrendWeight, want.percent)
            && option.band == want.band
    }
}

@Test func loseRateOptionsInKilogramsAreBandedByShareOfTrendWeight() {
    let options = bodyView().rateOptions(for: .lose)

    #expect(
        matches(
            options,
            [
                (0.25, 0.3125, .sustainable),
                (0.5, 0.625, .aggressive),
                (0.75, 0.9375, .aggressive),
                (1.0, 1.25, .tooFast),
            ]
        )
    )
}

@Test func gainRateOptionsInKilogramsAreBandedByShareOfTrendWeight() {
    let options = bodyView().rateOptions(for: .gain)

    #expect(
        matches(
            options,
            [
                (0.1, 0.125, .sustainable),
                (0.25, 0.3125, .sustainable),
                (0.5, 0.625, .aggressive),
            ]
        )
    )
}

@Test func aGainGoalOfOneKilogramAWeekIsTooFast() {
    let goal = WeightGoal(
        startWeight: 80.0,
        startDay: nov5,
        goalWeight: 90.0,
        pace: .rate(kilogramsPerWeek: 1.0)
    )
    let card = bodyView(goal: goal).goalCard

    #expect(card?.direction == .gain)
    #expect(isClose(card?.paceKilogramsPerWeek, 1.0))
    #expect(isClose(card?.pacePercentOfTrendWeight, 1.25))
    #expect(card?.paceBand == .tooFast)
}

@Test(arguments: [WeightUnits.pounds, .stonesAndPounds])
func loseRateOptionsInPoundsAreHalfPoundStepsStoredAsKilograms(units: WeightUnits) {
    // 0.5, 1, 1.5 and 2 lb at 0.45359237 kg per lb.
    let options = bodyView(units: units).rateOptions(for: .lose)
    let kilograms = options.map(\.kilogramsPerWeek)

    #expect(kilograms.count == 4)
    #expect(
        zip(kilograms, [0.226796185, 0.45359237, 0.680388555, 0.90718474])
            .allSatisfy { isClose($0, $1) }
    )
}

@Test func aGoalBelowItsStartWeightLosesAndOneAboveGains() {
    let lose = WeightGoal(startWeight: 88.0, startDay: nov5, goalWeight: 78.0, pace: nil)
    let gain = WeightGoal(startWeight: 70.0, startDay: nov5, goalWeight: 75.0, pace: nil)

    #expect(lose.direction == .lose)
    #expect(gain.direction == .gain)
}

@Test func aTooFastLoseGoalIsStillAGoal() {
    // Aggressive and Too fast Paces can still be saved: nothing refuses them.
    let goal = WeightGoal(
        startWeight: 80.0,
        startDay: nov5,
        goalWeight: 70.0,
        pace: .rate(kilogramsPerWeek: 1.0)
    )
    let card = bodyView(goal: goal).goalCard

    #expect(card != nil)
    #expect(card?.goal == goal)
    #expect(card?.direction == .lose)
    #expect(isClose(card?.pacePercentOfTrendWeight, 1.25))
    #expect(card?.paceBand == .tooFast)
}

@Test func thereIsNoGoalCardWithoutAGoal() {
    #expect(bodyView().goalCard == nil)
}

@Test func aNewGoalStartsFromTodaysTrendWeight() {
    #expect(bodyView().newGoalStart == GoalStart(weight: 80.0, day: nov5))
}

@Test func thereIsNoNewGoalStartWithoutWeighIns() {
    #expect(bodyView(weighIns: []).newGoalStart == nil)
}

// Saving a Weight Goal (spec 014, "Weight Goal": Goal Weight must differ from Start Weight, weights
// are 20–350 kg, the Pace is one of the rates offered, and changing direction ends a goal).

@Test func aGoalWeightBelowStartLosesAboveGainsAndEqualHasNoDirection() {
    #expect(WeightGoal.direction(startWeight: 80.0, goalWeight: 78.0) == .lose)
    #expect(WeightGoal.direction(startWeight: 80.0, goalWeight: 82.0) == .gain)
    #expect(WeightGoal.direction(startWeight: 80.0, goalWeight: 80.0) == nil)
}

/// A goal from `start` to `goal` kg starting today at `rate` kg a week.
private func rateGoal(_ start: Double, _ goal: Double, rate: Double) -> WeightGoal {
    WeightGoal(
        startWeight: start,
        startDay: nov5,
        goalWeight: goal,
        pace: .rate(kilogramsPerWeek: rate)
    )
}

@Test func aGoalWeightEqualToStartWeightIsRefused() {
    let refusal = rateGoal(80.0, 80.0, rate: 0.5).refusal(units: .kilograms)

    #expect(refusal == .sameAsStart)
    #expect(refusal?.message == "Goal Weight must differ from Start Weight.")
}

@Test func aGoalWeightUnderTwentyKilogramsIsRefused() {
    let refusal = rateGoal(80.0, 10.0, rate: 0.5).refusal(units: .kilograms)

    #expect(refusal == .weightOutOfRange)
    #expect(refusal?.message == "Weights must be 20–350 kg.")
}

@Test func aStartWeightOverThreeHundredFiftyKilogramsIsRefused() {
    #expect(rateGoal(400.0, 80.0, rate: 0.5).refusal(units: .kilograms) == .weightOutOfRange)
}

@Test func aLoseRateThatIsNotOfferedIsRefused() {
    let refusal = rateGoal(80.0, 78.0, rate: 0.3).refusal(units: .kilograms)

    #expect(refusal == .rateNotOffered)
    #expect(refusal?.message == "Pick one of the Paces offered.")
}

@Test func anOfferedLoseRateInKilogramsCanBeSaved() {
    #expect(rateGoal(80.0, 78.0, rate: 0.5).refusal(units: .kilograms) == nil)
}

@Test func anOfferedLoseRateInPoundsCanBeSaved() {
    // 1 lb a week, stored as 0.45359237 kg.
    #expect(rateGoal(80.0, 78.0, rate: 0.45359237).refusal(units: .pounds) == nil)
}

@Test func aLoseOnlyRateOnAGainGoalIsRefused() {
    // Gain offers 0.1, 0.25 and 0.5 kg a week; 1.0 is a lose rate only.
    #expect(rateGoal(80.0, 85.0, rate: 1.0).refusal(units: .kilograms) == .rateNotOffered)
}

@Test func aGoalInTheSameDirectionEditsTheCurrentGoal() {
    let current = rateGoal(90.0, 80.0, rate: 0.5)
    let changed = rateGoal(88.0, 78.0, rate: 0.5)

    #expect(changed.edits(current))
}

@Test func aGoalInTheOtherDirectionDoesNotEditTheCurrentGoal() {
    let current = rateGoal(90.0, 80.0, rate: 0.5)
    let gain = rateGoal(80.0, 85.0, rate: 0.25)

    #expect(!gain.edits(current))
}

@Test func goalEndsAreStoredByName() {
    #expect(GoalEnd.reached.rawValue == "reached")
    #expect(GoalEnd.changed.rawValue == "changed")
    #expect(GoalEnd.removed.rawValue == "removed")
}

private let posix = Locale(identifier: "en_US_POSIX")

@Test func aPaceInKilogramsReadsUnsignedToOneOrTwoDecimals() {
    #expect(WeightUnits.kilograms.paceText(0.25, locale: posix) == "0.25 kg a week")
    #expect(WeightUnits.kilograms.paceText(0.5, locale: posix) == "0.5 kg a week")
    #expect(WeightUnits.kilograms.paceText(1.0, locale: posix) == "1.0 kg a week")
}

@Test(arguments: [WeightUnits.pounds, .stonesAndPounds])
func aPaceInPoundsOrStonesReadsInPounds(units: WeightUnits) {
    #expect(units.paceText(0.226796185, locale: posix) == "0.5 lb a week")
    #expect(units.paceText(0.113398093, locale: posix) == "0.25 lb a week")
}
