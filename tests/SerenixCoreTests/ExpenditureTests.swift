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
    weighIns: [WeighIn] = weighInToday(80.0),
    heightCentimetres: Double? = 180,
    birthYear: Int? = 1996,
    sex: Sex? = .male,
    activityLevel: ActivityLevel? = .light
) -> FoodView {
    FoodView(
        foodEntries: [],
        foodTargets: FoodTargets(activityLevel: activityLevel),
        weighIns: weighIns,
        heightCentimetres: heightCentimetres,
        birthYear: birthYear,
        sex: sex,
        day: nov5,
        now: now,
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
