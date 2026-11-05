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

// A Pace by date (spec 014, "Weight Goal" → "By date"): the Pace is what reaches Goal Weight from
// the current Trend Weight by that Day, |Trend Weight − Goal Weight| / (Days from today / 7) kg a
// week. The earliest allowed Day is the one a 1%-of-Trend-Weight-a-week Pace reaches Goal Weight
// by, rounded up to a whole Day; the quick picks are the same for 0.5% and 0.75% a week. Trend
// Weight is 80.0 kg throughout, today 5 Nov 2026.

private let nov23 = Day(year: 2026, month: 11, day: 23)
private let nov29 = Day(year: 2026, month: 11, day: 29)
private let dec10 = Day(year: 2026, month: 12, day: 10)

@Test func goalDatesToLoseTwoKilogramsAreTheOnePercentHalfAndThreeQuarterPercentDays() {
    // 2 kg to lose. 1% = 0.8 kg a week → 2.5 weeks = 17.5 Days → 18 → 23 Nov.
    // 0.5% = 0.4 kg a week → 5 weeks = 35 Days → 10 Dec.
    // 0.75% = 0.6 kg a week → 3.33 weeks = 23.33 Days → 24 → 29 Nov.
    let dates = bodyView().goalDates(goalWeight: 78.0)

    #expect(dates?.earliest == nov23)
    #expect(dates?.halfPercent == dec10)
    #expect(dates?.threeQuarterPercent == nov29)
}

@Test func goalDatesToGainTwoKilogramsMatchThoseToLoseTwo() {
    // Same 2 kg gap the other way, so the same Days as losing to 78.
    let dates = bodyView().goalDates(goalWeight: 82.0)

    #expect(dates?.earliest == nov23)
    #expect(dates?.halfPercent == dec10)
    #expect(dates?.threeQuarterPercent == nov29)
}

@Test func thereAreNoGoalDatesWhenGoalWeightIsTrendWeight() {
    #expect(bodyView().goalDates(goalWeight: 80.0) == nil)
}

@Test func thereAreNoGoalDatesWithoutWeighIns() {
    #expect(bodyView(weighIns: []).goalDates(goalWeight: 78.0) == nil)
}

/// A goal from 80.0 to 78.0 kg starting today, reaching Goal Weight by `day`.
private func dateGoal(by day: Day) -> WeightGoal {
    WeightGoal(startWeight: 80.0, startDay: nov5, goalWeight: 78.0, pace: .date(day))
}

@Test func aDatePaceFiveWeeksOutIsSustainable() {
    // 2 kg over 35 Days = 5 weeks → 0.4 kg a week = 0.5% of 80.0.
    let card = bodyView(goal: dateGoal(by: dec10)).goalCard

    #expect(isClose(card?.paceKilogramsPerWeek, 0.4))
    #expect(isClose(card?.pacePercentOfTrendWeight, 0.5))
    #expect(card?.paceBand == .sustainable)
}

@Test func aDatePaceByTheEarliestDayIsAggressive() {
    // 2 kg over 18 Days → 2 / (18/7) = 0.7777777777777778 kg a week = 0.9722222222222222% of 80.0.
    let card = bodyView(goal: dateGoal(by: nov23)).goalCard

    #expect(isClose(card?.paceKilogramsPerWeek, 0.7777777777777778))
    #expect(isClose(card?.pacePercentOfTrendWeight, 0.9722222222222222))
    #expect(card?.paceBand == .aggressive)
}

// A date Pace can't be earlier than the 1%-a-week Day (spec 014, Weight Goal → By date).

@Test func aDatePaceBeforeTheEarliestDayIsRefused() {
    // Earliest for 80 → 78 kg is 23 Nov (see above); 22 Nov needs over 1% a week.
    let view = bodyView()
    let refusal = view.goalRefusal(dateGoal(by: Day(year: 2026, month: 11, day: 22)))
    #expect(refusal == .dateTooEarly)
    #expect(refusal?.message == "Pick a date no earlier than a 1%-a-week Pace allows.")
}

@Test func aDatePaceOfTodayIsRefused() {
    #expect(bodyView().goalRefusal(dateGoal(by: nov5)) == .dateTooEarly)
}

@Test func aDatePaceOnTheEarliestDayCanBeSaved() {
    #expect(bodyView().goalRefusal(dateGoal(by: nov23)) == nil)
}

@Test func aRateGoalsRefusalIsTheSameThroughTheBodyView() {
    let goal = WeightGoal(
        startWeight: 80.0,
        startDay: nov5,
        goalWeight: 78.0,
        pace: .rate(kilogramsPerWeek: 0.3)
    )
    #expect(bodyView().goalRefusal(goal) == .rateNotOffered)
}

@Test func aDatePaceHasNoPaceOnceTrendWeightHasPassedGoalWeight() {
    // Trend Weight 77.0 is already below the 78.0 Goal Weight, so nothing is left to lose.
    let view = bodyView(
        weighIns: [WeighIn(time: at(5, 7), kilograms: 77.0)],
        goal: dateGoal(by: dec10)
    )
    #expect(view.goalCard?.paceKilogramsPerWeek == nil)
}

// The Pace badge (spec 014, "Pace badge (lose and gain)"): Weekly Rate in the goal's direction as
// a share of Pace. On pace at 90% or more; a bit behind from 60% to under 90%; off pace under 60%,
// at zero, the wrong way or with no Weekly Rate; too fast over 125% of Pace and over 0.5% of Trend
// Weight a week, checked first.

@Test(arguments: [
    (-0.45, PaceBadge.onPace),  // 90% of 0.5
    (-0.44, .behind),  // 88%
    (-0.29, .offPace),  // 58%
    (0.1, .offPace),  // the wrong way
    (-0.30, .behind),  // exactly 60%
    (-0.625, .onPace),  // exactly 125% is not over it, so not Too fast
])
func aLoseGoalsBadgeIsWeeklyRateAsAShareOfPace(weeklyRate: Double, badge: PaceBadge) {
    #expect(
        PaceBadge(
            weeklyRate: weeklyRate,
            paceKilogramsPerWeek: 0.5,
            direction: .lose,
            trendWeight: 80
        )
            == badge
    )
}

@Test func aGoalWithNoWeeklyRateIsOffPace() {
    #expect(
        PaceBadge(weeklyRate: nil, paceKilogramsPerWeek: 0.5, direction: .lose, trendWeight: 80)
            == .offPace
    )
}

@Test func losingOverAQuarterFasterThanPaceAndOverHalfAPercentAWeekIsTooFast() {
    // 0.63 is 126% of 0.5, and over 0.5% of 80 kg (0.4) a week.
    #expect(
        PaceBadge(weeklyRate: -0.63, paceKilogramsPerWeek: 0.5, direction: .lose, trendWeight: 80)
            == .tooFast
    )
}

@Test func losingFasterThanPaceButUnderHalfAPercentOfAHeavierTrendWeightIsOnPace() {
    // 0.65 is 130% of 0.5, but under 0.5% of 140 kg (0.7) a week.
    #expect(
        PaceBadge(weeklyRate: -0.65, paceKilogramsPerWeek: 0.5, direction: .lose, trendWeight: 140)
            == .onPace
    )
}

@Test(arguments: [(0.25, PaceBadge.onPace), (-0.1, .offPace)])
func aGainGoalsBadgeCountsWeeklyRateUpward(weeklyRate: Double, badge: PaceBadge) {
    #expect(
        PaceBadge(
            weeklyRate: weeklyRate,
            paceKilogramsPerWeek: 0.25,
            direction: .gain,
            trendWeight: 80
        )
            == badge
    )
}

// Settling in (spec 014): while the Weight Goal is under 14 Days old or the counted Weigh-ins span
// under 14 Days, the cards say "Settling in, day N of 14", N being the younger of the two.

/// A Weigh-in of 80.0 kg at 07:00 UTC on each Day from `first` to 5 Nov 2026.
private func flatEighties(from first: Day) -> [WeighIn] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    var weighIns: [WeighIn] = []
    var time = calendar.date(
        from: DateComponents(year: first.year, month: first.month, day: first.dayOfMonth, hour: 7)
    )!
    while time <= at(5, 7) {
        weighIns.append(WeighIn(time: time, kilograms: 80.0))
        time = calendar.date(byAdding: .day, value: 1, to: time)!
    }
    return weighIns
}

/// A goal to lose from 80 to 75 kg at 0.5 kg a week, starting on `startDay`.
private func loseHalfAKilogramAWeek(from startDay: Day) -> WeightGoal {
    WeightGoal(
        startWeight: 80.0,
        startDay: startDay,
        goalWeight: 75.0,
        pace: .rate(kilogramsPerWeek: 0.5)
    )
}

private let oct16 = Day(year: 2026, month: 10, day: 16)
private let oct22 = Day(year: 2026, month: 10, day: 22)
private let oct23 = Day(year: 2026, month: 10, day: 23)
private let oct31 = Day(year: 2026, month: 10, day: 31)

@Test func aGoalThirteenDaysOldIsSettlingInOnDayThirteen() {
    // Goal from 23 Oct: 13 Days old on 5 Nov. Weigh-ins 22 Oct to 5 Nov span 14 Days.
    let view = bodyView(
        weighIns: flatEighties(from: oct22),
        goal: loseHalfAKilogramAWeek(from: oct23)
    )

    #expect(view.goalCard?.status == .settlingIn(day: 13))
}

@Test func aGoalFourteenDaysOldWithFourteenDaysOfWeighInsShowsItsBadge() {
    // Goal from 22 Oct: 14 Days old on 5 Nov, Weigh-ins span 14 Days. Flat 80s: Weekly Rate 0.
    let view = bodyView(
        weighIns: flatEighties(from: oct22),
        goal: loseHalfAKilogramAWeek(from: oct22)
    )

    #expect(view.goalCard?.status == .badge(.offPace))
}

@Test func anOlderGoalWithFiveDaysOfWeighInsIsSettlingInOnDayFive() {
    // Goal from 16 Oct: 20 Days old. Weigh-ins 31 Oct to 5 Nov span 5 Days.
    let view = bodyView(
        weighIns: flatEighties(from: oct31),
        goal: loseHalfAKilogramAWeek(from: oct16)
    )

    #expect(view.goalCard?.status == .settlingIn(day: 5))
}

@Test func aGoalIsSettlingInAgainAfterTrendWeightRestarts() {
    // Weigh-ins 1–10 Oct, then none until 31 Oct (21 Days: Trend Weight restarts), then daily
    // to 5 Nov. The span since the restart is 31 Oct → 5 Nov = 5 Days, so it settles again
    // although the goal (from 1 Oct) is 35 Days old.
    let eleventhOctober = flatEighties(from: Day(year: 2026, month: 10, day: 11))[0].time
    let before = flatEighties(from: Day(year: 2026, month: 10, day: 1)).filter {
        $0.time < eleventhOctober
    }
    let after = flatEighties(from: Day(year: 2026, month: 10, day: 31))
    let view = bodyView(
        weighIns: before + after,
        goal: loseHalfAKilogramAWeek(from: Day(year: 2026, month: 10, day: 1))
    )
    #expect(view.goalCard?.status == .settlingIn(day: 5))
}

// Ease the goal (spec 014, "Pace badge" → "Ease the goal"): after the badge has been Off pace or
// Too fast on each of the last 7 Days, the Rate card offers the next slower rate option (Off
// pace), the rate option nearest Weekly Rate (Too fast), or for a date Pace the projected Day:
// today plus the Days Trend Weight needs at Weekly Rate, rounded up.

/// Whether `ease` is a rate within 1e-9 of `expected` kg a week.
private func isRate(_ ease: GoalEase?, _ expected: Double) -> Bool {
    guard case .rate(let kilogramsPerWeek) = ease else { return false }
    return isClose(kilogramsPerWeek, expected)
}

@Test func anOffPaceRateGoalIsOfferedTheNextSlowerRate() {
    // Lose rates in kg: 0.25, 0.5, 0.75, 1.0. The next slower than 0.5 is 0.25.
    let ease = GoalEase.offer(
        goal: rateGoal(80.0, 75.0, rate: 0.5),
        badge: .offPace,
        weeklyRate: 0,
        trendWeight: 80.0,
        today: nov5,
        units: .kilograms
    )
    #expect(isRate(ease, 0.25))
}

@Test func anOffPaceRateGoalAtTheSlowestRateIsOfferedNothing() {
    let ease = GoalEase.offer(
        goal: rateGoal(80.0, 75.0, rate: 0.25),
        badge: .offPace,
        weeklyRate: 0,
        trendWeight: 80.0,
        today: nov5,
        units: .kilograms
    )
    #expect(ease == nil)
}

@Test func aTooFastRateGoalIsOfferedTheRateNearestWeeklyRate() {
    // Losing 0.9 kg a week: of 0.25, 0.5, 0.75 and 1.0, 1.0 is nearest (0.1 away; 0.75 is 0.15).
    let ease = GoalEase.offer(
        goal: rateGoal(80.0, 75.0, rate: 0.5),
        badge: .tooFast,
        weeklyRate: -0.9,
        trendWeight: 80.0,
        today: nov5,
        units: .kilograms
    )
    #expect(isRate(ease, 1.0))
}

@Test func anOffPaceRateGoalInPoundsIsOfferedTheNextSlowerPoundRate() {
    // 1 lb a week (0.45359237 kg) eases to 0.5 lb (0.226796185 kg).
    let ease = GoalEase.offer(
        goal: rateGoal(80.0, 75.0, rate: 0.45359237),
        badge: .offPace,
        weeklyRate: 0,
        trendWeight: 80.0,
        today: nov5,
        units: .pounds
    )
    #expect(isRate(ease, 0.226796185))
}

@Test func anOffPaceDateGoalIsOfferedTheProjectedDay() {
    // 2 kg left at 0.2 kg a week = 10 weeks = 70 Days after 5 Nov 2026 → 14 Jan 2027.
    let ease = GoalEase.offer(
        goal: dateGoal(by: dec10),
        badge: .offPace,
        weeklyRate: -0.2,
        trendWeight: 80.0,
        today: nov5,
        units: .kilograms
    )
    #expect(ease == .date(Day(year: 2027, month: 1, day: 14)))
}

@Test(arguments: [0.1, nil] as [Double?])
func aDateGoalMovingAwayFromGoalWeightOrWithoutWeeklyRateIsOfferedNothing(weeklyRate: Double?) {
    let ease = GoalEase.offer(
        goal: dateGoal(by: dec10),
        badge: .offPace,
        weeklyRate: weeklyRate,
        trendWeight: 80.0,
        today: nov5,
        units: .kilograms
    )
    #expect(ease == nil)
}

@Test func anOnPaceGoalIsOfferedNothing() {
    let ease = GoalEase.offer(
        goal: rateGoal(80.0, 75.0, rate: 0.5),
        badge: .onPace,
        weeklyRate: -0.5,
        trendWeight: 80.0,
        today: nov5,
        units: .kilograms
    )
    #expect(ease == nil)
}

@Test func aGoalOffPaceOnEachOfTheLastSevenDaysIsOfferedEasing() {
    // Goal and daily flat 80.0 Weigh-ins from 16 Oct: settled from its 14th Day, 30 Oct, then
    // Off pace (Weekly Rate 0) on 30 Oct, 31 Oct and 1–5 Nov = 7 Days.
    let view = bodyView(
        weighIns: flatEighties(from: oct16),
        goal: loseHalfAKilogramAWeek(from: oct16)
    )
    #expect(isRate(view.goalCard?.ease, 0.25))
}

@Test func aGoalOffPaceOnOnlySixDaysIsNotOfferedEasing() {
    // Goal and Weigh-ins from 17 Oct: Settling in until 31 Oct, then Off pace on 31 Oct and
    // 1–5 Nov = 6 Days, one short.
    let oct17 = Day(year: 2026, month: 10, day: 17)
    let view = bodyView(
        weighIns: flatEighties(from: oct17),
        goal: loseHalfAKilogramAWeek(from: oct17)
    )
    #expect(view.goalCard != nil)
    #expect(view.goalCard?.ease == nil)
}

@Test func easingARateGoalKeepsItsStartAndGoalAndChangesThePace() {
    let goal = loseHalfAKilogramAWeek(from: nov5)
    #expect(
        goal.eased(by: .rate(kilogramsPerWeek: 0.25))
            == WeightGoal(
                startWeight: 80.0,
                startDay: nov5,
                goalWeight: 75.0,
                pace: .rate(kilogramsPerWeek: 0.25)
            )
    )
}

@Test func easingADateGoalMovesItsDate() {
    let eased = dateGoal(by: dec10).eased(by: .date(Day(year: 2027, month: 1, day: 14)))
    #expect(eased.pace == .date(Day(year: 2027, month: 1, day: 14)))
    #expect(eased.startWeight == 80.0 && eased.goalWeight == 78.0 && eased.startDay == nov5)
}

@Test func aTooFastRateGoalWhoseNearestRateIsItsOwnIsOfferedNothing() {
    // Pace 1.0 kg, Weekly Rate −1.3: the nearest option is 1.0, the goal's own Pace.
    let goal = WeightGoal(
        startWeight: 80.0,
        startDay: nov5,
        goalWeight: 75.0,
        pace: .rate(kilogramsPerWeek: 1.0)
    )
    let offer = GoalEase.offer(
        goal: goal,
        badge: .tooFast,
        weeklyRate: -1.3,
        trendWeight: 80.0,
        today: nov5,
        units: .kilograms
    )
    #expect(offer == nil)
}

@Test func aTooFastDateGoalIsOfferedNoEarlierThanTheOnePercentDay() {
    // 2 kg at 1.5 kg a week is 9.33 Days → 15 Nov, before the 1%-a-week Day, 23 Nov.
    let offer = GoalEase.offer(
        goal: dateGoal(by: dec10),
        badge: .tooFast,
        weeklyRate: -1.5,
        trendWeight: 80.0,
        today: nov5,
        units: .kilograms
    )
    #expect(offer == .date(nov23))
}
