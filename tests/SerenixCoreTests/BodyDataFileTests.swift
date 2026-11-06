import Foundation
import SerenixCore
import Testing

// The Body data file (spec 014, "Backup and import"; Seams → "Body data file"): a lossless,
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

/// `object` as JSON bytes.
private func json(_ object: [String: Any]) -> Data {
    try! JSONSerialization.data(withJSONObject: object)
}

// MARK: - Round trip

@Test func exportThenImportGivesBackIdenticalBodyData() throws {
    let file = try BodyDataFile.encode(fullData)

    #expect(try BodyDataFile.decode(file) == fullData)
}

@Test func theFileSaysItIsVersionOneOfTheSerenixBodyFormat() throws {
    let file = try BodyDataFile.encode(fullData)

    let top = try #require(try JSONSerialization.jsonObject(with: file) as? [String: Any])
    #expect(top["format"] as? String == "serenix-body")
    #expect(top["version"] as? Int == 1)
}

@Test func emptyBodyDataRoundTrips() throws {
    #expect(try BodyDataFile.decode(BodyDataFile.encode(empty)) == empty)
}

// MARK: - Import: add and skip

@Test func importingIntoEmptyBodyDataAddsEverything() {
    let result = BodyDataFile.importing(fullData, into: empty, now: now)

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

    let result = BodyDataFile.importing(file, into: current, now: now)

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
        now: now
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
        now: now
    )

    #expect(result.goalsToAdd == [])
    #expect(result.skipped == 1)
}

@Test func anExactDuplicateWithinTheFileIsAddedOnceAndSkippedOnce() {
    let weighIn = WeighIn(time: at(4, 7, 5), kilograms: 80.15)

    let result = BodyDataFile.importing(
        BodyData(weighIns: [weighIn, weighIn], goals: []),
        into: empty,
        now: now
    )

    #expect(result.weighInsToAdd == [weighIn])
    #expect(result.skipped == 1)
}

// MARK: - Import: never two current goals

@Test func aFilesCurrentGoalIsEndedAsChangedWhenACurrentGoalIsAlreadyHere() {
    let result = BodyDataFile.importing(
        BodyData(weighIns: [], goals: [currentHoldGoal]),
        into: BodyData(weighIns: [], goals: [currentLoseGoal]),
        now: now
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
        now: now
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
    let file = json(["format": "serenix-body", "version": 2, "weighIns": [], "goals": []])

    #expect(throws: BodyDataFileError.newerVersion(2)) { try BodyDataFile.decode(file) }
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
