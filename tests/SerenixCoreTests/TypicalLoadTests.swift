import SerenixCore
import Testing

// Spec 006, Behavior 3 and success criterion "Typical Load": the median Load of the 28 Days
// before the Day, not counting the Day; missing Loads skipped, a Load of 0 counted; an even count
// takes the mean of the middle two, halves rounded up; fewer than 4 such Days is calibrating.

/// 15 Nov 2026, the Day every test asks for.
private let fifteenthOfNovember = Day(year: 2026, month: 11, day: 15)

/// A Day of November 2026 with a Load, or missing (no records) when `load` is nil.
private func november(_ dayOfMonth: Int, load: Int?) -> DayLoad {
    DayLoad(
        day: Day(year: 2026, month: 11, day: dayOfMonth),
        load: load,
        missingReason: load == nil ? .noRecords : nil
    )
}

/// A Day of October 2026 with a Load.
private func october(_ dayOfMonth: Int, load: Int) -> DayLoad {
    DayLoad(day: Day(year: 2026, month: 10, day: dayOfMonth), load: load)
}

@Test func typicalLoadIsTheMedianOfTheDaysBeforeNotCountingTheDay() {
    let dayLoads = [
        november(11, load: 30), november(12, load: 40), november(13, load: 50),
        november(14, load: 60), november(15, load: 90),
    ]

    #expect(typicalLoad(for: fifteenthOfNovember, among: dayLoads) == .value(45))
}

@Test func anEvenCountTakesTheMeanOfTheMiddleTwoWithHalvesRoundedUp() {
    let dayLoads = [
        november(11, load: 30), november(12, load: 40), november(13, load: 51),
        november(14, load: 60),
    ]

    #expect(typicalLoad(for: fifteenthOfNovember, among: dayLoads) == .value(46))
}

@Test func aMissingLoadIsSkipped() {
    let dayLoads = [
        november(10, load: 30), november(11, load: 40), november(12, load: nil),
        november(13, load: 50), november(14, load: 60),
    ]

    #expect(typicalLoad(for: fifteenthOfNovember, among: dayLoads) == .value(45))
}

@Test func aLoadOfZeroCounts() {
    let dayLoads = [
        november(10, load: 0), november(11, load: 0), november(12, load: 40),
        november(13, load: 50), november(14, load: 60),
    ]

    #expect(typicalLoad(for: fifteenthOfNovember, among: dayLoads) == .value(40))
}

@Test func aDay29DaysBeforeIsNotCounted() {
    let dayLoads = [
        october(17, load: 100), november(12, load: 30), november(13, load: 40),
        november(14, load: 50),
    ]

    #expect(typicalLoad(for: fifteenthOfNovember, among: dayLoads) == .calibrating(soFar: 3))
}

@Test func aDay28DaysBeforeIsCounted() {
    let dayLoads = [
        october(18, load: 100), november(12, load: 30), november(13, load: 40),
        november(14, load: 50),
    ]

    #expect(typicalLoad(for: fifteenthOfNovember, among: dayLoads) == .value(45))
}

@Test func threeDaysIsCalibratingWithThreeSoFar() {
    let dayLoads = [november(12, load: 30), november(13, load: 40), november(14, load: 50)]

    #expect(typicalLoad(for: fifteenthOfNovember, among: dayLoads) == .calibrating(soFar: 3))
}

@Test func noDaysIsCalibratingWithNoneSoFar() {
    #expect(typicalLoad(for: fifteenthOfNovember, among: []) == .calibrating(soFar: 0))
}

@Test func daysAfterTheDayAreNotCounted() {
    let dayLoads = [
        november(12, load: 30), november(13, load: 40), november(14, load: 50),
        november(16, load: 60), november(17, load: 70),
    ]

    #expect(typicalLoad(for: fifteenthOfNovember, among: dayLoads) == .calibrating(soFar: 3))
}

@Test func theOrderOfTheDaysDoesNotMatter() {
    let dayLoads = [
        november(14, load: 60), november(11, load: 30), november(15, load: 90),
        november(13, load: 50), november(12, load: 40),
    ]

    #expect(typicalLoad(for: fifteenthOfNovember, among: dayLoads) == .value(45))
}
