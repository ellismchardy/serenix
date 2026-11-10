import Foundation
import SerenixCore
import Testing

// Expenditure's starting estimate (spec 017, "Starting estimate"), through the Food view: the
// Mifflin-St Jeor resting rate from the Profile and today's Trend Weight, times the Activity
// Level's factor. Expected values are spec 017's success criteria, worked by hand.

/// 1–5 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC then.
private let london = TimeZone(identifier: "Europe/London")!

private let nov5 = Day(year: 2026, month: 11, day: 5)

/// `hour`:`minute` UTC on `day` November 2026, when it is also London local time.
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(
        from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)
    )!
}

/// 5 Nov 2026 09:00 in London: today, for Trend Weight and age.
private let now = at(5, 9)

/// One Weigh-in this morning, so today's Trend Weight is exactly `kilograms`.
private func weighInToday(_ kilograms: Double) -> [WeighIn] {
    [WeighIn(time: at(5, 7), kilograms: kilograms)]
}

/// Whether `actual` is within 1e-9 of `expected`.
private func isClose(_ actual: Double?, _ expected: Double) -> Bool {
    guard let actual else { return false }
    return abs(actual - expected) < 1e-9
}

/// The Food view for 5 Nov: by default Trend Weight 80 kg, 180 cm, born 1996 (age 30), male,
/// Light.
private func expenditureView(
    foodEntries: [FoodEntry] = [],
    completeDays: Set<Day> = [],
    weighIns: [WeighIn] = weighInToday(80.0),
    weightGoal: WeightGoal? = nil,
    heightCentimetres: Double? = 180,
    birthYear: Int? = 1996,
    sex: Sex? = .male,
    activityLevel: ActivityLevel? = .light,
    calorieTarget: Double? = nil,
    adaptsCalorieTarget: Bool? = nil,
    day: Day = nov5,
    now today: Date = now
) -> FoodView {
    FoodView(
        foodEntries: foodEntries,
        completeDays: completeDays,
        foodTargets: FoodTargets(
            calorieTarget: calorieTarget,
            activityLevel: activityLevel,
            adaptsCalorieTarget: adaptsCalorieTarget
        ),
        weighIns: weighIns,
        weightGoal: weightGoal,
        heightCentimetres: heightCentimetres,
        birthYear: birthYear,
        sex: sex,
        day: day,
        now: today,
        timeZone: london
    )
}

@Test func maleLightStartingEstimateComesFromTheProfile() {
    let view = expenditureView(sex: .male)
    #expect(isClose(view.restingRate, 1780))
    #expect(isClose(view.expenditure, 2447.5))
    #expect(view.expenditureSource == .profile)
    #expect(view.missingForExpenditure == [])
}

@Test func femaleLightStartingEstimate() {
    let view = expenditureView(sex: .female)
    #expect(isClose(view.restingRate, 1614))
    #expect(isClose(view.expenditure, 2219.25))
    #expect(view.expenditureSource == .profile)
}

@Test func preferNotToSayStartingEstimateSitsBetweenMaleAndFemale() {
    let view = expenditureView(sex: .preferNotToSay)
    #expect(isClose(view.restingRate, 1697))
    #expect(isClose(view.expenditure, 2333.375))
}

@Test func noSexReadsAsPreferNotToSay() {
    let view = expenditureView(sex: nil)
    #expect(isClose(view.restingRate, 1697))
    #expect(isClose(view.expenditure, 2333.375))
}

@Test func noActivityLevelReadsAsLight() {
    let view = expenditureView(activityLevel: nil)
    #expect(isClose(view.expenditure, 2447.5))
}

@Test(arguments: [
    (ActivityLevel.mostlySitting, 2136.0),  // 1,780 × 1.2
    (ActivityLevel.moderate, 2759.0),  // 1,780 × 1.55
    (ActivityLevel.veryActive, 3070.5),  // 1,780 × 1.725
])
func activityLevelScalesTheRestingRate(level: ActivityLevel, expected: Double) {
    let view = expenditureView(activityLevel: level)
    #expect(isClose(view.restingRate, 1780))
    #expect(isClose(view.expenditure, expected))
}

@Test func noHeightMeansNoExpenditureAndNamesHeight() {
    let view = expenditureView(heightCentimetres: nil)
    #expect(view.expenditure == nil)
    #expect(view.restingRate == nil)
    #expect(view.missingForExpenditure == [.height])
}

@Test func noBirthYearMeansNoExpenditureAndNamesBirthYear() {
    let view = expenditureView(birthYear: nil)
    #expect(view.expenditure == nil)
    #expect(view.restingRate == nil)
    #expect(view.missingForExpenditure == [.birthYear])
}

@Test func noWeighInMeansNoExpenditureAndNamesWeighIn() {
    let view = expenditureView(weighIns: [])
    #expect(view.expenditure == nil)
    #expect(view.restingRate == nil)
    #expect(view.missingForExpenditure == [.weighIn])
}

@Test func missingEverythingNamesHeightBirthYearAndWeighInInOrder() {
    let view = expenditureView(weighIns: [], heightCentimetres: nil, birthYear: nil)
    #expect(view.expenditure == nil)
    #expect(view.expenditureSource == nil)
    #expect(view.missingForExpenditure == [.height, .birthYear, .weighIn])
}

@Test func activityLevelFactors() {
    #expect(ActivityLevel.mostlySitting.factor == 1.2)
    #expect(ActivityLevel.light.factor == 1.375)
    #expect(ActivityLevel.moderate.factor == 1.55)
    #expect(ActivityLevel.veryActive.factor == 1.725)
}

// The window's figure (spec 017, "Expenditure from logged data"): the mean Intake of the Complete
// Days among the 21 Days ending on the shown Day, plus the Trend Weight drop from the window's
// first Weigh-in Day to its last × 7,700 ÷ the Days between them; nil without enough data.
// The shown Day is 30 Nov 2026, so its window is 10–30 Nov (all GMT in London).

private let nov30 = Day(year: 2026, month: 11, day: 30)

/// 30 Nov 2026 21:00 in London, after every entry and Weigh-in below.
private let lateNov30 = at(30, 21)

/// One Food Entry of `kilocalories` at 12:00 on each of `days` of November 2026.
private func meals(_ kilocalories: Double, on days: ClosedRange<Int>) -> [FoodEntry] {
    days.map { FoodEntry(time: at($0, 12), kilocalories: kilocalories) }
}

/// `days` of November 2026 as Days, to mark complete.
private func november(_ days: ClosedRange<Int>) -> Set<Day> {
    Set(days.map { Day(year: 2026, month: 11, day: $0) })
}

/// One Weigh-in of `kilograms` at 07:00 on each of `days` of November 2026.
private func weighIns(_ kilograms: Double, on days: [Int]) -> [WeighIn] {
    days.map { WeighIn(time: at($0, 7), kilograms: kilograms) }
}

/// The Food view for 30 Nov 2026 with these entries, Complete Days and Weigh-ins.
private func windowView(
    foodEntries: [FoodEntry],
    completeDays: Set<Day>,
    weighIns: [WeighIn]
) -> FoodView {
    expenditureView(
        foodEntries: foodEntries,
        completeDays: completeDays,
        weighIns: weighIns,
        day: nov30,
        now: lateNov30
    )
}

@Test func windowOfCompleteDaysWithSteadyTrendWeightGivesTheirMeanIntake() {
    // 21 Complete Days of 2,000 kcal, 80.0 kg every Day: no Trend Weight change, so 2,000.
    let view = windowView(
        foodEntries: meals(2000, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(80.0, on: Array(10...30))
    )
    #expect(isClose(view.windowFigure, 2000))
}

@Test func daysThatArentCompleteAreLeftOutOfTheWindowFigure() {
    // 16 Complete Days of 2,000 kcal (10–25 Nov) and 5 Days of 500 kcal not marked complete
    // (26–30 Nov). Counting those would give (16 × 2,000 + 5 × 500) ÷ 21 ≈ 1,642.9; left out,
    // the figure is 2,000.
    let view = windowView(
        foodEntries: meals(2000, on: 10...25) + meals(500, on: 26...30),
        completeDays: november(10...25),
        weighIns: weighIns(80.0, on: Array(10...30))
    )
    #expect(isClose(view.windowFigure, 2000))
}

@Test func trendWeightDropOfPointSevenOverFourteenDaysAddsItsEnergy() {
    // Spec 017's criterion: Trend Weight 0.7 kg lower on the last Weigh-in Day than the first,
    // 14 Days apart. Weigh-ins of 80.0 on 10–17 Nov keep Trend Weight at exactly 80.0 (the
    // first Weigh-in Day's). The last Weigh-in, 7 Days later on 24 Nov, closes 1 − 0.9^7 of
    // the gap, so a Weigh-in of 80 − 0.7 ÷ (1 − 0.9^7) puts Trend Weight at 79.3.
    // 9 Weigh-in Days, 10 → 24 Nov is 14 Days, 21 Complete Days of 2,000 kcal:
    // 2,000 + 0.7 × 7,700 ÷ 14 = 2,000 + 385 = 2,385.
    let lastWeighIn = 80.0 - 0.7 / (1 - pow(0.9, 7))
    let view = windowView(
        foodEntries: meals(2000, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(80.0, on: Array(10...17)) + weighIns(lastWeighIn, on: [24])
    )
    #expect(isClose(view.windowFigure, 2385))
}

@Test func trendWeightDropWorkedByHandAddsItsEnergy() {
    // Weigh-ins of 80.0 on 10–17 Nov (Trend Weight 80.0), then 79.0 on 24 Nov, 7 Days on:
    // 0.9^7 = 0.4782969, so Trend Weight = 80 − (1 − 0.4782969) × 1.0 = 79.4782969, a drop of
    // 0.5217031 kg over 10 → 24 Nov, 14 Days.
    // 2,000 + 0.5217031 × 7,700 ÷ 14 = 2,000 + 0.5217031 × 550 = 2,000 + 286.936705
    // = 2,286.936705.
    let view = windowView(
        foodEntries: meals(2000, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(80.0, on: Array(10...17)) + weighIns(79.0, on: [24])
    )
    #expect(isClose(view.windowFigure, 2286.936705))
}

@Test func windowWithNineCompleteDaysLacksEnoughData() {
    // Complete Days 10–18 Nov: 9.
    let view = windowView(
        foodEntries: meals(2000, on: 10...18),
        completeDays: november(10...18),
        weighIns: weighIns(80.0, on: Array(10...30))
    )
    #expect(view.windowFigure == nil)
    // No earlier window has enough data either, so Expenditure stays the starting estimate.
    #expect(isClose(view.expenditure, 2447.5))
    #expect(view.expenditureSource == .profile)
}

@Test func windowWithTenCompleteDaysHasAFigure() {
    // Complete Days 10–19 Nov: 10.
    let view = windowView(
        foodEntries: meals(2000, on: 10...19),
        completeDays: november(10...19),
        weighIns: weighIns(80.0, on: Array(10...30))
    )
    #expect(isClose(view.windowFigure, 2000))
}

@Test func windowWithSevenWeighInDaysLacksEnoughData() {
    // Weigh-ins on 10, 12, 14, 16, 18, 20 and 24 Nov: 7 Days, 14 Days apart, no gap over 14
    // Days (so no restart), with 21 Complete Days.
    let view = windowView(
        foodEntries: meals(2000, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(80.0, on: [10, 12, 14, 16, 18, 20, 24])
    )
    #expect(view.windowFigure == nil)
    // No earlier window has enough data either, so Expenditure stays the starting estimate.
    #expect(isClose(view.expenditure, 2447.5))
    #expect(view.expenditureSource == .profile)
}

@Test func windowWithEightWeighInDaysHasAFigure() {
    // Weigh-ins on 10, 12, 14, 16, 18, 20, 22 and 24 Nov: 8 Days, 14 Days apart, no restart,
    // all 80.0, so 2,000.
    let view = windowView(
        foodEntries: meals(2000, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(80.0, on: [10, 12, 14, 16, 18, 20, 22, 24])
    )
    #expect(isClose(view.windowFigure, 2000))
}

@Test func windowWithFirstAndLastWeighInThirteenDaysApartLacksEnoughData() {
    // Weigh-ins every Day 10–23 Nov: 14 Days with a Weigh-in, but 10 → 23 Nov is 13 Days.
    let view = windowView(
        foodEntries: meals(2000, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(80.0, on: Array(10...23))
    )
    #expect(view.windowFigure == nil)
    // No earlier window has enough data either, so Expenditure stays the starting estimate.
    #expect(isClose(view.expenditure, 2447.5))
    #expect(view.expenditureSource == .profile)
}

@Test func windowWithFirstAndLastWeighInFourteenDaysApartHasAFigure() {
    // Weigh-ins every Day 10–24 Nov: 10 → 24 Nov is 14 Days, all 80.0, so 2,000.
    let view = windowView(
        foodEntries: meals(2000, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(80.0, on: Array(10...24))
    )
    #expect(isClose(view.windowFigure, 2000))
}

@Test func windowWhoseTrendWeightRestartsCountsOnlyTheLineAfterIt() {
    // Weigh-ins every Day 10–14 Nov, then none until 30 Nov: a 16-Day gap restarts Trend Weight
    // (spec 015), so only the new line counts, and it has one Weigh-in: not enough data.
    let view = windowView(
        foodEntries: meals(2000, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(80.0, on: Array(10...14) + [30])
    )
    #expect(view.windowFigure == nil)
}

@Test func windowAfterAnEarlyRestartTakesItsFigureFromTheNewLine() {
    // A Weigh-in of 90.0 on 1 Nov, then 80.0 every Day 16–30 Nov: the 15-Day gap restarts
    // Trend Weight at 80.0 on 16 Nov, and it stays 80.0 to 30 Nov (15 Days with a Weigh-in,
    // 14 Days apart). Without the restart it would still be easing down from 90.0. So the
    // figure is 2,000 + 0 = 2,000.
    let view = windowView(
        foodEntries: meals(2000, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(90.0, on: [1]) + weighIns(80.0, on: Array(16...30))
    )
    #expect(isClose(view.windowFigure, 2000))
}

/// `hour`:00 UTC on 1 December 2026, also London local time (GMT).
private func december1(_ hour: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: hour))!
}

@Test func completeDaysOutsideTheWindowAreLeftOut() {
    // Complete Days of 2,000 kcal on 10–30 Nov, and of 9,000 kcal on 9 Nov and 1 Dec, just
    // outside the 30 Nov window (10–30 Nov). Weigh-ins of 80.0 every Day 9 Nov–1 Dec. Only the
    // window's Days count: 2,000.
    let view = expenditureView(
        foodEntries: meals(2000, on: 10...30) + meals(9000, on: 9...9)
            + [FoodEntry(time: december1(12), kilocalories: 9000)],
        completeDays: november(9...30).union([Day(year: 2026, month: 12, day: 1)]),
        weighIns: weighIns(80.0, on: Array(9...30))
            + [WeighIn(time: december1(7), kilograms: 80.0)],
        day: nov30,
        now: december1(21)
    )
    #expect(isClose(view.windowFigure, 2000))
}

// Easing (spec 017, "Expenditure from logged data"): on the first Day whose window has enough
// data, Expenditure moves 10% of the way from the starting estimate to that Day's window figure;
// each later Day, 10% from the previous Day's Expenditure to that Day's figure; a Day without
// enough data leaves it where it was. Days after the shown Day don't count.
//
// Complete Days of 2,000 kcal and Weigh-ins of 80.0 every Day 10–30 Nov: the window first has
// enough data on 24 Nov (10 → 24 Nov is the first 14-Day Weigh-in span), with a figure of 2,000
// on every Day from then. The starting estimate is 2,447.5 throughout (Trend Weight 80.0).

private let nov23 = Day(year: 2026, month: 11, day: 23)
private let nov24 = Day(year: 2026, month: 11, day: 24)
private let nov25 = Day(year: 2026, month: 11, day: 25)
private let nov26 = Day(year: 2026, month: 11, day: 26)

/// The Food view for `day` with Complete Days of 2,000 kcal and Weigh-ins of 80.0 every Day
/// 10–30 Nov, seen late on 30 Nov.
private func dailyDataView(showing day: Day) -> FoodView {
    expenditureView(
        foodEntries: meals(2000, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(80.0, on: Array(10...30)),
        day: day,
        now: lateNov30
    )
}

@Test func dayBeforeEnoughDataKeepsTheStartingEstimate() {
    // 23 Nov: Weigh-ins 10 → 23 Nov are only 13 Days apart.
    let view = dailyDataView(showing: nov23)
    #expect(isClose(view.expenditure, 2447.5))
    #expect(view.expenditureSource == .profile)
}

@Test func firstDayWithEnoughDataMovesATenthOfTheWayToItsFigure() {
    // 2,447.5 + 0.1 × (2,000 − 2,447.5) = 2,447.5 − 44.75 = 2,402.75. Data after 24 Nov
    // doesn't count.
    let view = dailyDataView(showing: nov24)
    #expect(isClose(view.expenditure, 2402.75))
    #expect(view.expenditureSource == .loggedData)
}

@Test func nextDayMovesATenthOfTheWayFromThePreviousDaysExpenditure() {
    // 2,402.75 + 0.1 × (2,000 − 2,402.75) = 2,402.75 − 40.275 = 2,362.475.
    let view = dailyDataView(showing: nov25)
    #expect(isClose(view.expenditure, 2362.475))
    #expect(view.expenditureSource == .loggedData)
}

@Test func dayWithoutEnoughDataLeavesExpenditureWhereItWas() {
    // Complete Days of 2,000 kcal on 5 Nov and 16–24 Nov (10), Weigh-ins of 80.0 every Day
    // 10–30 Nov. 23 Nov's window (3–23 Nov) has 9 Complete Days; 24 Nov's (4–24) and 25 Nov's
    // (5–25) have 10, with Weigh-ins 14 Days apart, so 2,402.75 then 2,362.475 as above.
    // 26 Nov's window (6–26) loses 5 Nov: 9 Complete Days, so Expenditure holds at 2,362.475.
    let view = expenditureView(
        foodEntries: meals(2000, on: 5...5) + meals(2000, on: 16...24),
        completeDays: november(5...5).union(november(16...24)),
        weighIns: weighIns(80.0, on: Array(10...30)),
        day: nov26,
        now: lateNov30
    )
    #expect(view.windowFigure == nil)
    #expect(isClose(view.expenditure, 2362.475))
    #expect(view.expenditureSource == .loggedData)
}

@Test func easingIsSeededFromTheStartingEstimateOnTheFirstDayWithEnoughData() {
    // Complete Days of 2,000 kcal every Day 10–30 Nov; Weigh-ins of 80.0 on 10–28 Nov, then
    // 70.0 on 29–30 Nov, so Trend Weight is 80.0 through 28 Nov and falls after. Today's (30 Nov)
    // Trend Weight is lower, but 24 Nov's starting estimate is at 80.0: 2,447.5.
    let foodEntries = meals(2000, on: 10...30)
    let completeDays = november(10...30)
    let weighIns = weighIns(80.0, on: Array(10...28)) + weighIns(70.0, on: [29, 30])
    let nov24View = expenditureView(
        foodEntries: foodEntries,
        completeDays: completeDays,
        weighIns: weighIns,
        day: nov24,
        now: lateNov30
    )
    // 2,447.5 + 0.1 × (2,000 − 2,447.5) = 2,402.75.
    #expect(isClose(nov24View.expenditure, 2402.75))
    #expect(nov24View.expenditureSource == .loggedData)

    // 25–28 Nov: figure 2,000 (Trend Weight flat), so 2,362.475, 2,326.2275, 2,293.60475,
    // 2,264.244275. 29 Nov: a Weigh-in of 70.0 moves Trend Weight 10% of the way, to 79.0. The
    // window (9–29 Nov) runs from 10 Nov (80.0) to 29 Nov (79.0), 19 Days, so its figure is
    // 2,000 + 1.0 × 7,700 ÷ 19 = 2,405.263157894737, and Expenditure is
    // 2,264.244275 + 0.1 × (2,405.263157894737 − 2,264.244275) = 2,278.3461632894737.
    // (Seeded from a starting estimate at 79.0 kg, 2,433.75, it would differ.)
    let nov29View = expenditureView(
        foodEntries: foodEntries,
        completeDays: completeDays,
        weighIns: weighIns,
        day: Day(year: 2026, month: 11, day: 29),
        now: lateNov30
    )
    #expect(isClose(nov29View.windowFigure, 2405.263157894737))
    #expect(isClose(nov29View.expenditure, 2278.3461632894737))
    #expect(nov29View.expenditureSource == .loggedData)
}

@Test func withNoStartingEstimateEasingIsSeededFromTheFirstFigure() {
    // No height, so no starting estimate. Daily 2,000 kcal and 80.0 kg data: 24 Nov's figure
    // 2,000 seeds Expenditure, moved 10% toward itself: 2,000. 23 Nov lacks enough data: none.
    let nov24View = expenditureView(
        foodEntries: meals(2000, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(80.0, on: Array(10...30)),
        heightCentimetres: nil,
        day: nov24,
        now: lateNov30
    )
    #expect(isClose(nov24View.expenditure, 2000))
    #expect(nov24View.expenditureSource == .loggedData)

    let nov23View = expenditureView(
        foodEntries: meals(2000, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(80.0, on: Array(10...30)),
        heightCentimetres: nil,
        day: nov23,
        now: lateNov30
    )
    #expect(nov23View.expenditure == nil)
    #expect(nov23View.expenditureSource == nil)
}

@Test func pastDayBeforeEnoughDataUsesThatDaysStartingEstimate() {
    // Weigh-ins of 80.0 on 10–23 Nov and 70.0 from 24 Nov on, no Complete Days. On 23 Nov
    // Trend Weight is 80.0, so its starting estimate is the 80 kg one even seen on 30 Nov:
    // resting rate 1,780, Expenditure 2,447.5.
    let view = expenditureView(
        weighIns: weighIns(80.0, on: Array(10...23)) + weighIns(70.0, on: Array(24...30)),
        day: nov23,
        now: lateNov30
    )
    #expect(isClose(view.restingRate, 1780))
    #expect(isClose(view.expenditure, 2447.5))
    #expect(view.expenditureSource == .profile)
}

// The suggested Calorie Target (spec 017, "Suggested Calorie Target"): Expenditure ∓ the Pace ×
// 7,700 ÷ 7 kcal a Day (Expenditure itself when holding or with no Weight Goal), rounded to the
// nearest 10 kcal, never below the floor (1,200 kcal or the resting rate, whichever is higher; a
// floored suggestion rounds up to the next 10). Expected values are spec 017's criteria.
//
// With no height there is no starting estimate, so logged data seeds Expenditure from the window
// figure itself: Complete Days of N kcal and Weigh-ins of 80.0 every Day 10–30 Nov, shown on
// 24 Nov, give Expenditure exactly N, with no resting rate (so the floor is 1,200).

/// A Weight Goal from 80 kg on 1 Nov to `goalWeight` at `kilogramsPerWeek`: losing when
/// `goalWeight` is below 80, gaining when above.
private func goal(to goalWeight: Double, at kilogramsPerWeek: Double) -> WeightGoal {
    WeightGoal(
        startWeight: 80,
        startDay: Day(year: 2026, month: 11, day: 1),
        goalWeight: goalWeight,
        pace: .rate(kilogramsPerWeek: kilogramsPerWeek)
    )
}

/// The Food view for 24 Nov with Expenditure exactly `expenditure` from logged data, no resting
/// rate, and `weightGoal`; optionally a typed Calorie Target and the Adapt switch.
private func suggestionView(
    expenditure: Double,
    weightGoal: WeightGoal?,
    calorieTarget: Double? = nil,
    adaptsCalorieTarget: Bool? = nil
) -> FoodView {
    expenditureView(
        foodEntries: meals(expenditure, on: 10...30),
        completeDays: november(10...30),
        weighIns: weighIns(80.0, on: Array(10...30)),
        weightGoal: weightGoal,
        heightCentimetres: nil,
        calorieTarget: calorieTarget,
        adaptsCalorieTarget: adaptsCalorieTarget,
        day: nov24,
        now: lateNov30
    )
}

@Test func losingHalfAKiloAWeekSuggestsExpenditureLessItsEnergy() {
    // 2,400 − 0.5 × 7,700 ÷ 7 = 2,400 − 550 = 1,850, above the 1,200 floor.
    let view = suggestionView(expenditure: 2400, weightGoal: goal(to: 75, at: 0.5))
    #expect(isClose(view.expenditure, 2400))
    #expect(isClose(view.suggestedCalorieTarget, 1850))
    #expect(view.paceNotSafelyReachable == false)
}

@Test func gainingAQuarterKiloAWeekSuggestsExpenditurePlusItsEnergyRoundedToTen() {
    // 2,400 + 0.25 × 7,700 ÷ 7 = 2,400 + 275 = 2,675, rounded to the nearest 10: 2,680.
    let view = suggestionView(expenditure: 2400, weightGoal: goal(to: 85, at: 0.25))
    #expect(isClose(view.suggestedCalorieTarget, 2680))
    #expect(view.paceNotSafelyReachable == false)
}

@Test func holdingWeightSuggestsExpenditure() {
    let hold = WeightGoal.hold(at: 80, on: Day(year: 2026, month: 11, day: 1))
    let view = suggestionView(expenditure: 2400, weightGoal: hold)
    #expect(isClose(view.suggestedCalorieTarget, 2400))
    #expect(view.paceNotSafelyReachable == false)
}

@Test func noWeightGoalSuggestsExpenditure() {
    let view = suggestionView(expenditure: 2400, weightGoal: nil)
    #expect(isClose(view.suggestedCalorieTarget, 2400))
    #expect(view.paceNotSafelyReachable == false)
}

@Test func noExpenditureMeansNoSuggestion() {
    // No Weigh-ins and no height: no starting estimate and no logged data.
    let view = expenditureView(
        weighIns: [],
        weightGoal: goal(to: 75, at: 0.5),
        heightCentimetres: nil
    )
    #expect(view.expenditure == nil)
    #expect(view.suggestedCalorieTarget == nil)
    #expect(view.paceNotSafelyReachable == false)
}

@Test func paceBelowTheFloorWithNoRestingRateSuggestsTwelveHundredAndFlagsIt() {
    // 1,800 − 1 × 7,700 ÷ 7 = 1,800 − 1,100 = 700, below the 1,200 floor (no resting rate).
    let view = suggestionView(expenditure: 1800, weightGoal: goal(to: 70, at: 1.0))
    #expect(view.restingRate == nil)
    #expect(isClose(view.suggestedCalorieTarget, 1200))
    #expect(view.paceNotSafelyReachable == true)
}

@Test func paceBelowTheRestingRateSuggestsItRoundedUpAndFlagsIt() {
    // Spec 017's criterion uses Expenditure 1,800 with a female resting rate of 1,614, but with a
    // resting rate present Expenditure is the resting rate × an Activity Level factor (at least
    // 1.2), so 1,800 can't be produced exactly. Same floor rule at the nearest real case: female,
    // 180 cm, born 1996 (age 30), Trend Weight 80 kg, Mostly sitting: resting rate 1,614,
    // Expenditure 1,614 × 1.2 = 1,936.8. Losing at 1 kg a week: 1,936.8 − 1,100 = 836.8, below
    // the floor of 1,614 (higher than 1,200), which rounds up to 1,620.
    let view = expenditureView(
        weightGoal: goal(to: 70, at: 1.0),
        sex: .female,
        activityLevel: .mostlySitting
    )
    #expect(isClose(view.restingRate, 1614))
    #expect(isClose(view.expenditure, 1936.8))
    #expect(isClose(view.suggestedCalorieTarget, 1620))
    #expect(view.paceNotSafelyReachable == true)
}

@Test func suggestionJustAboveTheRestingRateRoundsUpNotBelowIt() {
    // Female, 180 cm, born 1996, 80 kg, Mostly sitting: resting rate 1,614, Expenditure 1,936.8.
    // Losing at 0.293 kg a week: 0.293 × 7,700 ÷ 7 = 322.3, so 1,936.8 − 322.3 = 1,614.5. That's
    // above the floor of 1,614, so the Pace is met, but the nearest 10 (1,610) is below the
    // floor: the suggestion rounds up to 1,620 instead, and isn't flagged.
    let view = expenditureView(
        weightGoal: goal(to: 70, at: 0.293),
        sex: .female,
        activityLevel: .mostlySitting
    )
    #expect(isClose(view.restingRate, 1614))
    #expect(isClose(view.expenditure, 1936.8))
    #expect(isClose(view.suggestedCalorieTarget, 1620))
    #expect(view.paceNotSafelyReachable == false)
}

@Test func expenditureBelowTheFloorWithNoWeightGoalSuggestsTheFloorUnflagged() {
    // Expenditure 1,000, no resting rate: the floor of 1,200. No Pace, so nothing to flag.
    let view = suggestionView(expenditure: 1000, weightGoal: nil)
    #expect(isClose(view.expenditure, 1000))
    #expect(isClose(view.suggestedCalorieTarget, 1200))
    #expect(view.paceNotSafelyReachable == false)
}

@Test func expenditureBelowTheFloorWhileHoldingSuggestsTheFloorUnflagged() {
    let hold = WeightGoal.hold(at: 80, on: Day(year: 2026, month: 11, day: 1))
    let view = suggestionView(expenditure: 1000, weightGoal: hold)
    #expect(isClose(view.suggestedCalorieTarget, 1200))
    #expect(view.paceNotSafelyReachable == false)
}

@Test func losingByDateUsesTheDatesKilogramsAWeek() {
    // Trend Weight 80.0 on the shown Day, 24 Nov; Goal Weight 78 by 22 Dec, 28 Days on: spec
    // 015's Pace is 2 kg ÷ 4 weeks = 0.5 kg a week. 2,400 − 0.5 × 7,700 ÷ 7 = 1,850.
    let byDate = WeightGoal(
        startWeight: 80,
        startDay: Day(year: 2026, month: 11, day: 1),
        goalWeight: 78,
        pace: .date(Day(year: 2026, month: 12, day: 22))
    )
    let view = suggestionView(expenditure: 2400, weightGoal: byDate)
    #expect(isClose(view.suggestedCalorieTarget, 1850))
    #expect(view.paceNotSafelyReachable == false)
}

// Adapt (spec 017, "Adapt"): with the switch on, the Calorie Target that applies, and so the
// Macro Targets and what's left or over, is the suggestion; with it off or unset, or with no
// suggestion, the typed one. The suggestion views below have Expenditure 2,400 and a Weight Goal
// losing 0.5 kg a week, so the suggestion is 1,850 (as above), and 24 Nov's Intake is 2,400 kcal.
// The typed Calorie Target is 2,000.

@Test func adaptOnAppliesTheSuggestedCalorieTarget() {
    let view = suggestionView(
        expenditure: 2400,
        weightGoal: goal(to: 75, at: 0.5),
        calorieTarget: 2000,
        adaptsCalorieTarget: true
    )
    #expect(isClose(view.calorieTarget, 1850))
    // Intake 2,400 against 1,850: 550 over.
    #expect(view.calorieBalance == .over(550))
}

@Test func adaptOnGivesTheMacroTargetsOfTheSuggestedCalorieTarget() {
    let adapted = suggestionView(
        expenditure: 2400,
        weightGoal: goal(to: 75, at: 0.5),
        calorieTarget: 2000,
        adaptsCalorieTarget: true
    )
    // The same inputs with 1,850 typed in and Adapt off: the Macro Targets of a 1,850 target.
    let typedAtSuggestion = suggestionView(
        expenditure: 2400,
        weightGoal: goal(to: 75, at: 0.5),
        calorieTarget: 1850,
        adaptsCalorieTarget: false
    )
    #expect(adapted.macroTargets != nil)
    #expect(adapted.macroTargets == typedAtSuggestion.macroTargets)
}

@Test func adaptOffAppliesTheTypedCalorieTargetEvenWithASuggestion() {
    let view = suggestionView(
        expenditure: 2400,
        weightGoal: goal(to: 75, at: 0.5),
        calorieTarget: 2000,
        adaptsCalorieTarget: false
    )
    #expect(isClose(view.suggestedCalorieTarget, 1850))
    #expect(isClose(view.calorieTarget, 2000))
    // Intake 2,400 against 2,000: 400 over.
    #expect(view.calorieBalance == .over(400))
}

@Test func adaptUnsetReadsAsOffAndAppliesTheTypedCalorieTarget() {
    let view = suggestionView(
        expenditure: 2400,
        weightGoal: goal(to: 75, at: 0.5),
        calorieTarget: 2000,
        adaptsCalorieTarget: nil
    )
    #expect(isClose(view.suggestedCalorieTarget, 1850))
    #expect(isClose(view.calorieTarget, 2000))
    #expect(view.calorieBalance == .over(400))
}

@Test func adaptOnWithNoTypedCalorieTargetAppliesTheSuggestion() {
    let view = suggestionView(
        expenditure: 2400,
        weightGoal: goal(to: 75, at: 0.5),
        calorieTarget: nil,
        adaptsCalorieTarget: true
    )
    #expect(isClose(view.calorieTarget, 1850))
    #expect(view.calorieBalance == .over(550))
}

@Test func adaptOnWithNoSuggestionAppliesTheTypedCalorieTarget() {
    // No Weigh-ins and no height: no Expenditure, so no suggestion. No Food Entries on 5 Nov.
    let view = expenditureView(
        weighIns: [],
        weightGoal: goal(to: 75, at: 0.5),
        heightCentimetres: nil,
        calorieTarget: 2000,
        adaptsCalorieTarget: true
    )
    #expect(view.suggestedCalorieTarget == nil)
    #expect(isClose(view.calorieTarget, 2000))
    #expect(view.calorieBalance == .left(2000))
}
