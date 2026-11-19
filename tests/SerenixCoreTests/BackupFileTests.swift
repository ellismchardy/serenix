import Foundation
import SerenixCore
import Testing

// The Backup file (spec 020; Seams → "Backup file"): a lossless, versioned JSON file of every
// Night, Day and all Body data, which still reads the older Body data files (versions 1 and 2).
// Every value here is built by hand; expected values are those same literals.

/// `hour`:`minute`:`second` UTC on `day` November 2026.
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(
        from: DateComponents(
            year: 2026,
            month: 11,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
    )!
}

/// A Sleep Onset with a sub-second part, which the file must keep exactly: 02 Nov 23:15:00.123456
/// UTC, inside `fullNight`'s Time in Bed and before its first Wake Bout.
private let subSecondOnset = Date(timeIntervalSinceReferenceDate: 815_354_100.123456)

/// A Night with every value: all five Nightly Metrics, its Heart Rate Trace (two steps missing)
/// and two Wake Bouts. Its Time in Bed (22:41:03 to 06:55:00, 29,637 s) takes 99 steps.
private let fullNight = Night(
    day: Day(year: 2026, month: 11, day: 3),
    sleepingHR: 52.5,
    hrv: 61.25,
    respiratoryRate: 14.8,
    skinTemperature: 33.42,
    spo2: 96.5,
    sleepOnset: subSecondOnset,
    finalWake: at(3, 6, 42, 17),
    timeAsleep: 25_310.5,
    timeInBedStart: at(2, 22, 41, 3),
    timeInBedEnd: at(3, 6, 55),
    heartRateTrace: HeartRateTrace(
        start: at(2, 22, 41, 3),
        steps: [68.4, 61.0, nil, 55.25, 53.9, nil, 57.1] + Array(repeating: 55.0, count: 92)
    ),
    wakeBouts: [
        WakeBout(start: at(3, 1, 12), minutes: 6),
        WakeBout(start: at(3, 4, 30), minutes: 11),
    ]
)

/// A Night with only its date: every optional value missing.
private let bareNight = Night(day: Day(year: 2026, month: 11, day: 4))

/// A Night where the user didn't wake: a Heart Rate Trace and no Wake Bouts. Its Time in Bed
/// (23:00 to 06:40, 27,600 s) takes 92 steps.
private let unbrokenNight = Night(
    day: Day(year: 2026, month: 11, day: 5),
    sleepingHR: 50,
    hrv: 70,
    sleepOnset: at(4, 23, 10),
    finalWake: at(5, 6, 30),
    timeAsleep: 26_400,
    timeInBedStart: at(4, 23, 0),
    timeInBedEnd: at(5, 6, 40),
    heartRateTrace: HeartRateTrace(
        start: at(4, 23, 0),
        steps: [62.5, 58.0, 54.75] + Array(repeating: 55.0, count: 89)
    ),
    wakeBouts: []
)

/// Every HR Zone at 0 seconds.
private let noZoneSeconds: [HRZone: Int] = [.one: 0, .two: 0, .three: 0, .four: 0, .five: 0]

/// A Day with Load, Resting HR and its HR Zones hour by hour.
private let loadedDay = DayLoad(
    day: Day(year: 2026, month: 11, day: 3),
    load: 42,
    heartRate: DayHeartRate(
        zoneSeconds: [.one: 1_800, .two: 900, .three: 300, .four: 60, .five: 0],
        hourlyZoneSeconds: [
            noZoneSeconds,
            [.one: 1_200, .two: 600, .three: 0, .four: 0, .five: 0],
            [.one: 600, .two: 300, .three: 300, .four: 60, .five: 0],
        ],
        highestHR: HighestHR(bpm: 171, time: at(3, 18, 4, 9)),
        maxHRUsed: MaxHRUsed(bpm: 187.5, source: .estimated)
    ),
    restingHR: 54.5
)

/// A Day whose Load is missing, with why.
private let loadMissingDay = DayLoad(
    day: Day(year: 2026, month: 11, day: 4),
    load: nil,
    missingReason: .noMaxHR,
    restingHR: 56
)

/// Body data: Weigh-ins (one at a sub-second time), an ended and a current goal, a Food Entry,
/// a Complete Day and food targets.
private let body = BodyData(
    weighIns: [
        WeighIn(time: Date(timeIntervalSinceReferenceDate: 815_000_000.654321), kilograms: 80.4),
        WeighIn(time: at(4, 7, 5), kilograms: 80.15),
    ],
    goals: [
        GoalRecord(
            goal: WeightGoal(
                startWeight: 85.3,
                startDay: Day(year: 2026, month: 9, day: 1),
                goalWeight: 80.0,
                pace: .rate(kilogramsPerWeek: 0.5)
            ),
            endedAt: at(1, 8, 15),
            endReason: .changed
        ),
        GoalRecord(
            goal: WeightGoal(
                startWeight: 81.0,
                startDay: Day(year: 2026, month: 11, day: 2),
                goalWeight: 78.0,
                pace: .rate(kilogramsPerWeek: 0.25)
            )
        ),
    ],
    foodEntries: [
        FoodEntry(
            time: at(4, 12, 30),
            kilocalories: 650,
            protein: 42.5,
            fat: 21,
            carbs: 70.25,
            name: "Chicken wrap"
        )
    ],
    completeDays: [Day(year: 2026, month: 11, day: 4)],
    foodTargets: FoodTargets(calorieTarget: 2000, proteinOverride: 150, fatOverride: 70)
)

private let fullBackup = Backup(
    nights: [fullNight, bareNight, unbrokenNight],
    days: [loadedDay, loadMissingDay],
    body: body
)

private let emptyBody = BodyData(weighIns: [], goals: [])

/// `object` as JSON bytes.
private func json(_ object: [String: Any]) -> Data {
    try! JSONSerialization.data(withJSONObject: object)
}

// MARK: - Round trip

@Test func exportThenImportGivesBackIdenticalNightsDaysAndBodyData() throws {
    let file = try BackupFile.encode(fullBackup)

    let decoded = try BackupFile.decode(file)

    #expect(decoded == fullBackup)
    #expect(decoded.nights == [fullNight, bareNight, unbrokenNight])
    #expect(decoded.days == [loadedDay, loadMissingDay])
    #expect(decoded.body == body)
}

@Test func anEmptyBackupRoundTrips() throws {
    let empty = Backup(nights: [], days: [], body: emptyBody)

    #expect(try BackupFile.decode(BackupFile.encode(empty)) == empty)
}

@Test func theFileSaysItIsVersionThreeOfTheSerenixBackupFormat() throws {
    let file = try BackupFile.encode(fullBackup)

    let top = try #require(try JSONSerialization.jsonObject(with: file) as? [String: Any])
    #expect(top["format"] as? String == "serenix-backup")
    #expect(top["version"] as? Int == 3)
    #expect(BackupFile.format == "serenix-backup")
    #expect(BackupFile.version == 3)
}

// MARK: - Files that can't be imported

@Test func aTruncatedBackupIsUnreadable() throws {
    let file = try BackupFile.encode(fullBackup)
    let truncated = file.prefix(file.count / 2)

    #expect(throws: BackupFileError.unreadable) { try BackupFile.decode(Data(truncated)) }
}

@Test func anEmptyJSONObjectIsNotABackup() {
    #expect(throws: BackupFileError.unreadable) { try BackupFile.decode(Data("{}".utf8)) }
}

@Test func aFileOfAnotherFormatIsNotABackup() {
    let file = json(["format": "other", "version": 3, "nights": [], "days": []])

    #expect(throws: BackupFileError.wrongFormat) { try BackupFile.decode(file) }
}

@Test func aBackupFromANewerVersionSaysWhichVersion() {
    let file = json([
        "format": "serenix-backup", "version": 4, "nights": [], "days": [], "weighIns": [],
        "goals": [],
    ])

    #expect(throws: BackupFileError.newerVersion(4)) { try BackupFile.decode(file) }
}

// MARK: - Older Body data files (spec 015, 016)

/// A version 1 Body data file's layout, as spec 015's Serenix wrote it.
private struct VersionOneBodyFile: Encodable {
    let format = "serenix-body"
    let version = 1
    let weighIns: [WeighIn]
    let goals: [GoalRecord]
}

@Test func aVersionOneBodyFileImportsItsBodyDataWithNoNightsOrDays() throws {
    let file = try JSONEncoder().encode(
        VersionOneBodyFile(weighIns: body.weighIns, goals: body.goals)
    )

    let decoded = try BackupFile.decode(file)

    #expect(decoded.nights == [])
    #expect(decoded.days == [])
    #expect(decoded.body == BodyData(weighIns: body.weighIns, goals: body.goals))
}

@Test func aVersionTwoBodyFileImportsItsBodyDataWithNoNightsOrDays() throws {
    let file = try BodyDataFile.encode(body)

    let decoded = try BackupFile.decode(file)

    #expect(decoded.nights == [])
    #expect(decoded.days == [])
    #expect(decoded.body == body)
}

// MARK: - Import (phone wins on a date clash)

/// A Night on `day` November 2026 with `sleepingHR`, so two Nights of one date tell apart.
private func night(_ day: Int, sleepingHR: Double) -> Night {
    Night(day: Day(year: 2026, month: 11, day: day), sleepingHR: sleepingHR)
}

/// A Day on `day` November 2026 with `load`, so two Days of one date tell apart.
private func dayLoad(_ day: Int, load: Int) -> DayLoad {
    DayLoad(day: Day(year: 2026, month: 11, day: day), load: load)
}

private let utc = TimeZone(identifier: "UTC")!

@Test func importingSkipsTheFilesNightsAndDaysWhoseDateIsAlreadyOnThePhone() {
    let file = Backup(
        nights: [
            night(10, sleepingHR: 50), night(11, sleepingHR: 51), night(12, sleepingHR: 52),
            night(13, sleepingHR: 53), night(14, sleepingHR: 54),
        ],
        days: [
            dayLoad(10, load: 20), dayLoad(11, load: 21), dayLoad(12, load: 22),
            dayLoad(13, load: 23), dayLoad(14, load: 24),
        ],
        body: emptyBody
    )
    let phone = Backup(
        nights: [night(11, sleepingHR: 61), night(13, sleepingHR: 63)],
        days: [dayLoad(12, load: 72)],
        body: emptyBody
    )

    let result = BackupFile.importing(file, into: phone, now: at(15, 9), timeZone: utc)

    #expect(
        result.nightsToAdd == [
            night(10, sleepingHR: 50), night(12, sleepingHR: 52), night(14, sleepingHR: 54),
        ]
    )
    #expect(
        result.daysToAdd == [
            dayLoad(10, load: 20), dayLoad(11, load: 21), dayLoad(13, load: 23),
            dayLoad(14, load: 24),
        ]
    )
    #expect(result.skipped == 3)
}

@Test func importingAFullBackupIntoAnEmptyPhoneAddsEverything() {
    let phone = Backup(nights: [], days: [], body: emptyBody)

    let result = BackupFile.importing(fullBackup, into: phone, now: at(15, 9), timeZone: utc)

    #expect(result.nightsToAdd == [fullNight, bareNight, unbrokenNight])
    #expect(result.daysToAdd == [loadedDay, loadMissingDay])
    #expect(result.body.weighInsToAdd == body.weighIns)
    #expect(result.body.goalsToAdd == body.goals)
    #expect(result.body.foodEntriesToAdd == body.foodEntries)
    #expect(result.body.completeDaysToAdd == [Day(year: 2026, month: 11, day: 4)])
    #expect(
        result.body.foodTargetsToSet
            == FoodTargets(calorieTarget: 2000, proteinOverride: 150, fatOverride: 70)
    )
    #expect(result.body.skipped == 0)
    #expect(result.skipped == 0)
}

@Test func theSkippedTotalCountsBodyEntriesAndNightsAlreadyHere() {
    let weighIn = WeighIn(time: at(10, 7, 30), kilograms: 79.6)
    let file = Backup(
        nights: [night(10, sleepingHR: 50)],
        days: [],
        body: BodyData(weighIns: [weighIn], goals: [])
    )
    let phone = Backup(
        nights: [night(10, sleepingHR: 60)],
        days: [],
        body: BodyData(weighIns: [weighIn], goals: [])
    )

    let result = BackupFile.importing(file, into: phone, now: at(15, 9), timeZone: utc)

    #expect(result.nightsToAdd == [])
    #expect(result.body.weighInsToAdd == [])
    #expect(result.body.skipped == 1)
    #expect(result.skipped == 2)
}

// MARK: - Invalid entries (all or nothing)

/// When the refusal tests judge a file: after every entry in it.
private let refusalNow = at(15, 9)

/// 10 November 2026, the date of `shortNight`.
private let tenth = Day(year: 2026, month: 11, day: 10)

/// A valid Night on 10 November unless a parameter makes it otherwise. Time in Bed runs 23:00 to
/// 00:00 (3,600 s, so 12 trace steps); asleep 23:10 to 23:55.
private func shortNight(
    sleepOnset: Date = at(9, 23, 10),
    finalWake: Date = at(9, 23, 55),
    heartRateTrace: HeartRateTrace = HeartRateTrace(
        start: at(9, 23, 0),
        steps: Array(repeating: 58.0, count: 12)
    ),
    wakeBouts: [WakeBout] = [WakeBout(start: at(9, 23, 30), minutes: 4)]
) -> Night {
    Night(
        day: tenth,
        sleepingHR: 51,
        sleepOnset: sleepOnset,
        finalWake: finalWake,
        timeAsleep: 2_460,
        timeInBedStart: at(9, 23, 0),
        timeInBedEnd: at(10, 0, 0),
        heartRateTrace: heartRateTrace,
        wakeBouts: wakeBouts
    )
}

/// `fullBackup` with `nights`, `days` and `foodEntries` added to it.
private func fullBackupAdding(
    nights: [Night] = [],
    days: [DayLoad] = [],
    foodEntries: [FoodEntry] = []
) -> Backup {
    Backup(
        nights: fullBackup.nights + nights,
        days: fullBackup.days + days,
        body: BodyData(
            weighIns: body.weighIns,
            goals: body.goals,
            foodEntries: body.foodEntries + foodEntries,
            completeDays: body.completeDays,
            foodTargets: body.foodTargets
        )
    )
}

@Test func aBackupWithEveryEntryValidIsNotRefused() {
    #expect(BackupFile.refusal(fullBackup, now: refusalNow) == nil)
}

@Test func aNightWhoseFinalWakeIsBeforeItsSleepOnsetIsRefused() {
    let file = fullBackupAdding(nights: [
        shortNight(sleepOnset: at(9, 23, 55), finalWake: at(9, 23, 10), wakeBouts: [])
    ])

    #expect(
        BackupFile.refusal(file, now: refusalNow)
            == .invalidEntry(.finalWakeBeforeSleepOnset(tenth))
    )
}

@Test func aNightWhoseFinalWakeIsItsSleepOnsetIsNotRefused() {
    let file = fullBackupAdding(nights: [
        shortNight(sleepOnset: at(9, 23, 30), finalWake: at(9, 23, 30), wakeBouts: [])
    ])

    #expect(BackupFile.refusal(file, now: refusalNow) == nil)
}

@Test func twoNightsWithOneDateAreRefused() {
    let file = fullBackupAdding(nights: [night(3, sleepingHR: 60)])

    #expect(
        BackupFile.refusal(file, now: refusalNow)
            == .invalidEntry(.repeatedNightDate(Day(year: 2026, month: 11, day: 3)))
    )
}

@Test func twoDaysWithOneDateAreRefused() {
    let file = fullBackupAdding(days: [dayLoad(3, load: 10)])

    #expect(
        BackupFile.refusal(file, now: refusalNow)
            == .invalidEntry(.repeatedDayDate(Day(year: 2026, month: 11, day: 3)))
    )
}

@Test func aHeartRateTraceOneStepShortOfItsTimeInBedIsRefused() {
    let file = fullBackupAdding(nights: [
        shortNight(
            heartRateTrace: HeartRateTrace(
                start: at(9, 23, 0),
                steps: Array(repeating: 58.0, count: 11)
            )
        )
    ])

    #expect(
        BackupFile.refusal(file, now: refusalNow)
            == .invalidEntry(.traceDoesNotFitTimeInBed(tenth))
    )
}

@Test func aHeartRateTraceStartingAfterTimeInBedStartsIsRefused() {
    let file = fullBackupAdding(nights: [
        shortNight(
            heartRateTrace: HeartRateTrace(
                start: at(9, 23, 5),
                steps: Array(repeating: 58.0, count: 12)
            )
        )
    ])

    #expect(
        BackupFile.refusal(file, now: refusalNow)
            == .invalidEntry(.traceDoesNotFitTimeInBed(tenth))
    )
}

@Test func aWakeBoutEndingAfterFinalWakeIsRefused() {
    // Starts 23:50 and lasts 6 minutes, so it ends 23:56, a minute after Final Wake.
    let file = fullBackupAdding(nights: [
        shortNight(wakeBouts: [WakeBout(start: at(9, 23, 50), minutes: 6)])
    ])

    #expect(
        BackupFile.refusal(file, now: refusalNow)
            == .invalidEntry(.wakeBoutOutsideSleepPeriod(tenth))
    )
}

@Test func aWakeBoutStartingBeforeSleepOnsetIsRefused() {
    // Starts 23:05, five minutes before Sleep Onset at 23:10.
    let file = fullBackupAdding(nights: [
        shortNight(wakeBouts: [WakeBout(start: at(9, 23, 5), minutes: 3)])
    ])

    #expect(
        BackupFile.refusal(file, now: refusalNow)
            == .invalidEntry(.wakeBoutOutsideSleepPeriod(tenth))
    )
}

@Test func aHeartRateTraceOnANightWithNoTimeInBedIsRefused() {
    var night = shortNight()
    night.timeInBedStart = nil
    night.timeInBedEnd = nil
    let file = fullBackupAdding(nights: [night])

    #expect(
        BackupFile.refusal(file, now: refusalNow)
            == .invalidEntry(.traceDoesNotFitTimeInBed(tenth))
    )
}

@Test func wakeBoutsOnANightWithNoSleepOnsetAreRefused() {
    var night = shortNight()
    night.sleepOnset = nil
    let file = fullBackupAdding(nights: [night])

    #expect(
        BackupFile.refusal(file, now: refusalNow)
            == .invalidEntry(.wakeBoutOutsideSleepPeriod(tenth))
    )
}

@Test func aWakeBoutEndingExactlyAtFinalWakeIsNotRefused() {
    // Starts 23:50 and lasts 5 minutes, so it ends 23:55, at Final Wake.
    let file = fullBackupAdding(nights: [
        shortNight(wakeBouts: [WakeBout(start: at(9, 23, 50), minutes: 5)])
    ])

    #expect(BackupFile.refusal(file, now: refusalNow) == nil)
}

@Test func aFoodEntryOverFiveThousandKilocaloriesIsRefused() {
    let file = fullBackupAdding(foodEntries: [FoodEntry(time: at(4, 19), kilocalories: 5_001)])

    #expect(BackupFile.refusal(file, now: refusalNow) == .invalidEntry(.bodyEntry))
}
