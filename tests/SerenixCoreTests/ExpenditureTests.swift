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
    heightCentimetres: Double? = 180,
    birthYear: Int? = 1996,
    sex: Sex? = .male,
    activityLevel: ActivityLevel? = .light,
    day: Day = nov5,
    now today: Date = now
) -> FoodView {
    FoodView(
        foodEntries: foodEntries,
        completeDays: completeDays,
        foodTargets: FoodTargets(activityLevel: activityLevel),
        weighIns: weighIns,
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
