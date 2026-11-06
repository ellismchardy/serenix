import Foundation
import SerenixCore
import Testing

// The Body data file (spec 015, "Backup and import"; Seams → "Body data file"): a lossless,
// versioned JSON backup of every Weigh-in and Weight Goal, and what importing one adds and skips.
// Expected values are literals built by hand from the spec's duplicate rule: a Weigh-in with the
// same time and weight, or the same Weight Goal, is skipped.

/// `hour`:`minute` UTC on `day` November 2026.
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(
        from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)
    )!
}

/// 6 Nov 2026 09:00 UTC, after everything here.
private let now = at(6, 9)

/// A Weigh-in time with a sub-second part, which the file must keep exactly.
private let subSecondTime = Date(timeIntervalSinceReferenceDate: 815_000_000.123456)

/// A lose goal with a rate Pace, ended when the user changed it.
private let endedRateGoal = GoalRecord(
    goal: WeightGoal(
        startWeight: 85.3,
        startDay: Day(year: 2026, month: 9, day: 1),
        goalWeight: 80.0,
        pace: .rate(kilogramsPerWeek: 0.5),
        changedDay: Day(year: 2026, month: 9, day: 20),
        milestoneStep: .small
    ),
    endedAt: at(1, 8, 15),
    endReason: .changed
)

/// A gain goal with a date Pace, Reached then reopened by Undo, then removed.
private let endedDateGoal = GoalRecord(
    goal: WeightGoal(
        startWeight: 70.0,
        startDay: Day(year: 2026, month: 6, day: 1),
        goalWeight: 72.5,
        pace: .date(Day(year: 2026, month: 8, day: 31)),
        changedDay: Day(year: 2026, month: 6, day: 10),
        milestoneStep: .large,
        reopenedDay: Day(year: 2026, month: 8, day: 2)
    ),
    endedAt: at(2, 12, 30),
    endReason: .removed
)

/// The current goal: holding 80.0 kg within 1.5 kg either side.
private let currentHoldGoal = GoalRecord(
    goal: WeightGoal(
        startWeight: 80.2,
        startDay: Day(year: 2026, month: 11, day: 1),
        goalWeight: 80.0,
        pace: nil,
        changedDay: Day(year: 2026, month: 11, day: 3),
        milestoneStep: .medium,
        holdBand: 1.5
    )
)

/// A different current goal: lose to 78.0 kg at 0.25 kg a week.
private let currentLoseGoal = GoalRecord(
    goal: WeightGoal(
        startWeight: 81.0,
        startDay: Day(year: 2026, month: 11, day: 2),
        goalWeight: 78.0,
        pace: .rate(kilogramsPerWeek: 0.25)
    )
)

private let fullData = BodyData(
    weighIns: [
        WeighIn(time: subSecondTime, kilograms: 80.4),
        WeighIn(time: at(4, 7, 5), kilograms: 80.15),
        WeighIn(time: at(5, 6, 59), kilograms: 79.95),
    ],
    goals: [endedRateGoal, endedDateGoal, currentHoldGoal]
)

private let empty = BodyData(weighIns: [], goals: [])

/// The fixtures' times are UTC, so their Days are UTC Days.
private let utc = TimeZone(identifier: "UTC")!

/// `object` as JSON bytes.
private func json(_ object: [String: Any]) -> Data {
    try! JSONSerialization.data(withJSONObject: object)
}

// MARK: - Round trip

@Test func exportThenImportGivesBackIdenticalBodyData() throws {
    let file = try BodyDataFile.encode(fullData)

    #expect(try BodyDataFile.decode(file) == fullData)
}

@Test func theFileSaysItIsVersionTwoOfTheSerenixBodyFormat() throws {
    let file = try BodyDataFile.encode(fullData)

    let top = try #require(try JSONSerialization.jsonObject(with: file) as? [String: Any])
    #expect(top["format"] as? String == "serenix-body")
    #expect(top["version"] as? Int == 2)
}

@Test func emptyBodyDataRoundTrips() throws {
    #expect(try BodyDataFile.decode(BodyDataFile.encode(empty)) == empty)
}

// MARK: - Import: add and skip

@Test func importingIntoEmptyBodyDataAddsEverything() {
    let result = BodyDataFile.importing(fullData, into: empty, now: now, timeZone: utc)

    #expect(result.weighInsToAdd == fullData.weighIns)
    #expect(result.goalsToAdd == fullData.goals)
    #expect(result.skipped == 0)
}

@Test func importingSkipsWhatIsAlreadyHereAndCountsIt() {
    let newWeighIn = WeighIn(time: at(5, 6, 59), kilograms: 79.95)
    let file = BodyData(
        weighIns: [
            WeighIn(time: subSecondTime, kilograms: 80.4),
            WeighIn(time: at(4, 7, 5), kilograms: 80.15),
            newWeighIn,
        ],
        goals: [endedRateGoal, endedDateGoal]
    )
    let current = BodyData(
        weighIns: [
            WeighIn(time: subSecondTime, kilograms: 80.4),
            WeighIn(time: at(4, 7, 5), kilograms: 80.15),
        ],
        goals: [endedRateGoal]
    )

    let result = BodyDataFile.importing(file, into: current, now: now, timeZone: utc)

    #expect(result.weighInsToAdd == [newWeighIn])
    #expect(result.goalsToAdd == [endedDateGoal])
    #expect(result.skipped == 3)
}

@Test func aWeighInAtTheSameTimeWithADifferentWeightIsAdded() {
    let here = WeighIn(time: at(4, 7, 5), kilograms: 80.15)
    let corrected = WeighIn(time: at(4, 7, 5), kilograms: 80.25)

    let result = BodyDataFile.importing(
        BodyData(weighIns: [corrected], goals: []),
        into: BodyData(weighIns: [here], goals: []),
        now: now,
        timeZone: utc
    )

    #expect(result.weighInsToAdd == [corrected])
    #expect(result.skipped == 0)
}

@Test func aWeightGoalAlreadyHereIsSkippedWhateverHowItEnded() {
    // The same goal is current in the file but ended here: still a duplicate.
    let endedHere = GoalRecord(goal: currentHoldGoal.goal, endedAt: at(5, 10), endReason: .removed)

    let result = BodyDataFile.importing(
        BodyData(weighIns: [], goals: [currentHoldGoal]),
        into: BodyData(weighIns: [], goals: [endedHere]),
        now: now,
        timeZone: utc
    )

    #expect(result.goalsToAdd == [])
    #expect(result.skipped == 1)
}

@Test func anExactDuplicateWithinTheFileIsAddedOnceAndSkippedOnce() {
    let weighIn = WeighIn(time: at(4, 7, 5), kilograms: 80.15)

    let result = BodyDataFile.importing(
        BodyData(weighIns: [weighIn, weighIn], goals: []),
        into: empty,
        now: now,
        timeZone: utc
    )

    #expect(result.weighInsToAdd == [weighIn])
    #expect(result.skipped == 1)
}

// MARK: - Import: never two current goals

@Test func aFilesCurrentGoalIsEndedAsChangedWhenACurrentGoalIsAlreadyHere() {
    let result = BodyDataFile.importing(
        BodyData(weighIns: [], goals: [currentHoldGoal]),
        into: BodyData(weighIns: [], goals: [currentLoseGoal]),
        now: now,
        timeZone: utc
    )

    #expect(
        result.goalsToAdd == [
            GoalRecord(goal: currentHoldGoal.goal, endedAt: now, endReason: .changed)
        ]
    )
    #expect(result.skipped == 0)
}

@Test func aFilesCurrentGoalStaysCurrentWhenNoCurrentGoalIsHere() {
    let result = BodyDataFile.importing(
        BodyData(weighIns: [], goals: [currentHoldGoal]),
        into: BodyData(weighIns: [], goals: [endedRateGoal]),
        now: now,
        timeZone: utc
    )

    #expect(result.goalsToAdd == [currentHoldGoal])
}

// MARK: - Unreadable files

@Test func aTruncatedFileIsUnreadable() throws {
    let file = try BodyDataFile.encode(fullData)
    let truncated = file.prefix(file.count / 2)

    #expect(throws: BodyDataFileError.unreadable) { try BodyDataFile.decode(Data(truncated)) }
}

@Test func anEmptyJSONObjectIsUnreadable() {
    #expect(throws: BodyDataFileError.unreadable) { try BodyDataFile.decode(Data("{}".utf8)) }
}

@Test func aFileOfAnotherFormatIsTheWrongFormat() {
    let file = json(["format": "other", "version": 1, "weighIns": [], "goals": []])

    #expect(throws: BodyDataFileError.wrongFormat) { try BodyDataFile.decode(file) }
}

@Test func aFileFromANewerVersionSaysWhichVersion() {
    let file = json(["format": "serenix-body", "version": 3, "weighIns": [], "goals": []])

    #expect(throws: BodyDataFileError.newerVersion(3)) { try BodyDataFile.decode(file) }
}

// MARK: - Entries Serenix would refuse

/// `goal` alone in a file, current.
private func fileWith(_ goal: WeightGoal) -> BodyData {
    BodyData(weighIns: [], goals: [GoalRecord(goal: goal)])
}

/// A lose goal from 85.0 kg to `goalWeight` with `pace`.
private func loseGoal(to goalWeight: Double = 80.0, pace: GoalPace?) -> WeightGoal {
    WeightGoal(
        startWeight: 85.0,
        startDay: Day(year: 2026, month: 11, day: 1),
        goalWeight: goalWeight,
        pace: pace
    )
}

@Test func aFileOfEntriesSerenixWouldSaveIsNotRefused() {
    #expect(BodyDataFile.refusal(fullData, now: now) == nil)
}

@Test func aFileWithAWeighInUnder20KilogramsIsRefused() {
    let file = BodyData(weighIns: [WeighIn(time: at(4, 7, 5), kilograms: 5)], goals: [])

    #expect(BodyDataFile.refusal(file, now: now) == .invalidEntry)
}

@Test func aFileWithAWeighInInTheFutureIsRefused() {
    let file = BodyData(weighIns: [WeighIn(time: at(6, 10), kilograms: 80.0)], goals: [])

    #expect(BodyDataFile.refusal(file, now: now) == .invalidEntry)
}

@Test func aFileWithAGoalAtARateNoUnitsOfferIsRefused() {
    let file = fileWith(loseGoal(pace: .rate(kilogramsPerWeek: 1e-300)))

    #expect(BodyDataFile.refusal(file, now: now) == .invalidEntry)
}

@Test func aFileWithAGoalAtARateOfferedOnlyInPoundsIsNotRefused() {
    // 1 lb a week, exactly 0.45359237 kg: offered in lb and st units, not in kg.
    let file = fileWith(loseGoal(pace: .rate(kilogramsPerWeek: 0.45359237)))

    #expect(BodyDataFile.refusal(file, now: now) == nil)
}

@Test func aFileWithAGoalWeightOver350KilogramsIsRefused() {
    let goal = WeightGoal(
        startWeight: 85.0,
        startDay: Day(year: 2026, month: 11, day: 1),
        goalWeight: 500.0,
        pace: .date(Day(year: 2027, month: 6, day: 1))
    )

    #expect(BodyDataFile.refusal(fileWith(goal), now: now) == .invalidEntry)
}

// MARK: - Version 2: food (spec 016, Backup)

/// A Food Entry with every field set.
private let fullEntry = FoodEntry(
    time: at(4, 12, 30),
    kilocalories: 650,
    protein: 42.5,
    fat: 21,
    carbs: 70.25,
    name: "Chicken wrap"
)

/// A Food Entry with only its calories.
private let kcalOnlyEntry = FoodEntry(time: at(5, 8, 15), kilocalories: 320)

private let fullDataWithFood = BodyData(
    weighIns: fullData.weighIns,
    goals: fullData.goals,
    foodEntries: [fullEntry, kcalOnlyEntry],
    completeDays: [Day(year: 2026, month: 11, day: 4)],
    foodTargets: FoodTargets(calorieTarget: 2000, proteinOverride: 150, fatOverride: 70)
)

@Test func aVersionTwoFileRoundTripsFoodEntriesCompleteDaysAndTargets() throws {
    let file = try BodyDataFile.encode(fullDataWithFood)

    #expect(try BodyDataFile.decode(file) == fullDataWithFood)
    let top = try #require(try JSONSerialization.jsonObject(with: file) as? [String: Any])
    #expect(top["version"] as? Int == 2)
}

/// A version 1 file's layout, as spec 015's Serenix wrote it: no food keys.
private struct VersionOneFile: Encodable {
    let format = "serenix-body"
    let version = 1
    let weighIns: [WeighIn]
    let goals: [GoalRecord]
}

@Test func aVersionOneFileImportsItsWeighInsAndGoalsWithNoFood() throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let file = try encoder.encode(
        VersionOneFile(weighIns: fullData.weighIns, goals: fullData.goals)
    )
    let top = try #require(try JSONSerialization.jsonObject(with: file) as? [String: Any])
    #expect(Set(top.keys) == ["format", "version", "weighIns", "goals"])

    let decoded = try BodyDataFile.decode(file)

    #expect(decoded.weighIns == fullData.weighIns)
    #expect(decoded.goals == fullData.goals)
    #expect(decoded.foodEntries == [])
    #expect(decoded.completeDays == [])
    #expect(decoded.foodTargets == FoodTargets())
    #expect(decoded.foodTargets.isEmpty)
}

/// Food Entry A, on 4 Nov (UTC).
private let entryA = FoodEntry(time: at(4, 8), kilocalories: 400, protein: 20, name: "Porridge")
/// Food Entry B, on 4 Nov (UTC).
private let entryB = FoodEntry(time: at(4, 13), kilocalories: 550)
/// Food Entry C, on 5 Nov (UTC).
private let entryC = FoodEntry(time: at(5, 19), kilocalories: 700, fat: 30)

@Test func importingFoodAddsWhatIsNewAndSkipsWhatIsHere() {
    let d1 = Day(year: 2026, month: 11, day: 4)
    let d2 = Day(year: 2026, month: 11, day: 5)
    let current = BodyData(
        weighIns: [],
        goals: [],
        foodEntries: [entryA, entryB],
        completeDays: [d1]
    )
    let file = BodyData(
        weighIns: [],
        goals: [],
        foodEntries: [entryA, entryC],
        completeDays: [d1, d2],
        foodTargets: FoodTargets(calorieTarget: 2000)
    )

    let result = BodyDataFile.importing(file, into: current, now: now, timeZone: utc)

    #expect(result.foodEntriesToAdd == [entryC])
    #expect(result.completeDaysToAdd == [d2])
    #expect(result.foodTargetsToSet == FoodTargets(calorieTarget: 2000))
    #expect(result.skipped == 2)  // entry A and Day d1, both already here
}

@Test func aFoodEntryDifferingOnlyInItsNameIsAdded() {
    let renamed = FoodEntry(time: at(4, 8), kilocalories: 400, protein: 20, name: "Oats")

    let result = BodyDataFile.importing(
        BodyData(weighIns: [], goals: [], foodEntries: [renamed]),
        into: BodyData(weighIns: [], goals: [], foodEntries: [entryA]),
        now: now,
        timeZone: utc
    )

    #expect(result.foodEntriesToAdd == [renamed])
    #expect(result.skipped == 0)
}

@Test func aFoodEntryRepeatedInTheFileIsAddedOnceAndSkippedOnce() {
    let result = BodyDataFile.importing(
        BodyData(weighIns: [], goals: [], foodEntries: [entryC, entryC]),
        into: empty,
        now: now,
        timeZone: utc
    )

    #expect(result.foodEntriesToAdd == [entryC])
    #expect(result.skipped == 1)
}

@Test func aCompleteDayWithNoFoodEntryHereOrInTheFileIsSkippedAndCounted() {
    // Entry A is on 4 Nov; nothing is on 3 Nov.
    let empty3Nov = Day(year: 2026, month: 11, day: 3)
    let file = BodyData(
        weighIns: [],
        goals: [],
        foodEntries: [entryA],
        completeDays: [empty3Nov]
    )

    let result = BodyDataFile.importing(file, into: empty, now: now, timeZone: utc)

    #expect(result.completeDaysToAdd == [])
    #expect(result.foodEntriesToAdd == [entryA])
    #expect(result.skipped == 1)
}

@Test func aCompleteDayWhoseFoodEntryIsAlreadyHereIsAdded() {
    let d1 = Day(year: 2026, month: 11, day: 4)

    let result = BodyDataFile.importing(
        BodyData(weighIns: [], goals: [], completeDays: [d1]),
        into: BodyData(weighIns: [], goals: [], foodEntries: [entryA]),
        now: now,
        timeZone: utc
    )

    #expect(result.completeDaysToAdd == [d1])
    #expect(result.skipped == 0)
}

@Test func aCompleteDayFollowsTheEntrysLocalDay() {
    // 5 Nov 23:30 UTC is 6 Nov 08:30 in Tokyo: in Tokyo that entry makes 6 Nov complete-able,
    // not 5 Nov.
    let lateEntry = FoodEntry(time: at(5, 23, 30), kilocalories: 300)
    let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    let file = BodyData(
        weighIns: [],
        goals: [],
        foodEntries: [lateEntry],
        completeDays: [Day(year: 2026, month: 11, day: 5), Day(year: 2026, month: 11, day: 6)]
    )

    let result = BodyDataFile.importing(file, into: empty, now: now, timeZone: tokyo)

    #expect(result.completeDaysToAdd == [Day(year: 2026, month: 11, day: 6)])
    #expect(result.skipped == 1)
}

@Test func aFilesTargetsAreNotUsedWhenTargetsAreAlreadySetHere() {
    let result = BodyDataFile.importing(
        BodyData(weighIns: [], goals: [], foodTargets: FoodTargets(calorieTarget: 2000)),
        into: BodyData(weighIns: [], goals: [], foodTargets: FoodTargets(calorieTarget: 1800)),
        now: now,
        timeZone: utc
    )

    #expect(result.foodTargetsToSet == nil)
    #expect(result.skipped == 1)
}

@Test func aFileWithNoTargetsSetsNoneAndSkipsNothing() {
    let result = BodyDataFile.importing(
        empty,
        into: BodyData(weighIns: [], goals: [], foodTargets: FoodTargets(calorieTarget: 1800)),
        now: now,
        timeZone: utc
    )

    #expect(result.foodTargetsToSet == nil)
    #expect(result.skipped == 0)
}

// MARK: - Version 2: food Serenix would refuse

@Test func aFileOfFoodSerenixWouldSaveIsNotRefused() {
    #expect(BodyDataFile.refusal(fullDataWithFood, now: now) == nil)
}

@Test func aFileWithAFoodEntryOver5000KilocaloriesIsRefused() {
    let file = BodyData(
        weighIns: [],
        goals: [],
        foodEntries: [FoodEntry(time: at(4, 12), kilocalories: 5_001)]
    )

    #expect(BodyDataFile.refusal(file, now: now) == .invalidEntry)
}

@Test func aFileWithACalorieTargetUnder800IsRefused() {
    let file = BodyData(weighIns: [], goals: [], foodTargets: FoodTargets(calorieTarget: 799))

    #expect(BodyDataFile.refusal(file, now: now) == .invalidEntry)
}

@Test func aFileWithOverridesLeavingNoRoomForCarbsIsRefused() {
    // 300 g protein (1,200 kcal) and 100 g fat (900 kcal) need 2,100 kcal of a 2,000 target.
    let file = BodyData(
        weighIns: [],
        goals: [],
        foodTargets: FoodTargets(calorieTarget: 2000, proteinOverride: 300, fatOverride: 100)
    )

    #expect(BodyDataFile.refusal(file, now: now) == .invalidEntry)
}
