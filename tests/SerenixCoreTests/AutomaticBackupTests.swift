import Foundation
import SerenixCore
import Testing

// Automatic Backup decisions (spec 020; Seams → "Automatic Backup decisions"): when a write is
// due, what to do when the chosen folder already holds a Backup, and the status text under the
// toggle. Every value here is built by hand; expected values are literals from the spec.

/// `hour`:`minute` UTC on `day` November 2026.
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(
        from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)
    )!
}

private let night2Nov = Night(
    day: Day(year: 2026, month: 11, day: 2),
    sleepingHR: 52,
    hrv: 61,
    sleepOnset: at(1, 23, 10),
    finalWake: at(2, 6, 40),
    timeAsleep: 25_200
)

private let night3Nov = Night(
    day: Day(year: 2026, month: 11, day: 3),
    sleepingHR: 54,
    hrv: 58,
    sleepOnset: at(2, 23, 30),
    finalWake: at(3, 7, 5),
    timeAsleep: 26_100
)

/// `night3Nov` with a different Sleeping HR, as a rebuild of that Night might give.
private let night3NovChanged = Night(
    day: Day(year: 2026, month: 11, day: 3),
    sleepingHR: 51,
    hrv: 58,
    sleepOnset: at(2, 23, 30),
    finalWake: at(3, 7, 5),
    timeAsleep: 26_100
)

private let day2Nov = DayLoad(day: Day(year: 2026, month: 11, day: 2), load: 41, restingHR: 58)
private let day3Nov = DayLoad(day: Day(year: 2026, month: 11, day: 3), load: 37, restingHR: 57)
/// `day3Nov` with a different Load.
private let day3NovChanged = DayLoad(
    day: Day(year: 2026, month: 11, day: 3),
    load: 63,
    restingHR: 57
)

private let backup = Backup(
    nights: [night2Nov, night3Nov],
    days: [day2Nov, day3Nov],
    body: BodyData(weighIns: [], goals: [])
)

// MARK: - When a write is due

@Test func aWriteIsDueRightAfterTurningTheAutomaticBackupOn() {
    #expect(AutomaticBackup.isWriteDue(after: .turnedOn))
}

@Test func aWriteIsDueAfterABodyChange() {
    #expect(AutomaticBackup.isWriteDue(after: .bodyChanged))
}

@Test func aWriteIsDueAfterASyncThatAddedANight() {
    let event = AutomaticBackupEvent.rebuildPass(
        nightsBefore: [night2Nov],
        nightsAfter: [night2Nov, night3Nov],
        daysBefore: [day2Nov],
        daysAfter: [day2Nov]
    )
    #expect(AutomaticBackup.isWriteDue(after: event))
}

@Test func aWriteIsDueAfterASyncThatChangedANight() {
    let event = AutomaticBackupEvent.rebuildPass(
        nightsBefore: [night2Nov, night3Nov],
        nightsAfter: [night2Nov, night3NovChanged],
        daysBefore: [day2Nov],
        daysAfter: [day2Nov]
    )
    #expect(AutomaticBackup.isWriteDue(after: event))
}

@Test func aWriteIsDueAfterASyncThatAddedADay() {
    let event = AutomaticBackupEvent.rebuildPass(
        nightsBefore: [night2Nov],
        nightsAfter: [night2Nov],
        daysBefore: [day2Nov],
        daysAfter: [day2Nov, day3Nov]
    )
    #expect(AutomaticBackup.isWriteDue(after: event))
}

@Test func aWriteIsDueAfterASyncThatChangedADay() {
    let event = AutomaticBackupEvent.rebuildPass(
        nightsBefore: [night2Nov],
        nightsAfter: [night2Nov],
        daysBefore: [day2Nov, day3Nov],
        daysAfter: [day2Nov, day3NovChanged]
    )
    #expect(AutomaticBackup.isWriteDue(after: event))
}

@Test func aWriteIsDueAfterARebuildPassThatRemovedADay() {
    let event = AutomaticBackupEvent.rebuildPass(
        nightsBefore: [night2Nov],
        nightsAfter: [night2Nov],
        daysBefore: [day2Nov, day3Nov],
        daysAfter: [day2Nov]
    )
    #expect(AutomaticBackup.isWriteDue(after: event))
}

@Test func noWriteIsDueAfterASyncThatChangedNothing() {
    let event = AutomaticBackupEvent.rebuildPass(
        nightsBefore: [night2Nov, night3Nov],
        nightsAfter: [night2Nov, night3Nov],
        daysBefore: [day2Nov, day3Nov],
        daysAfter: [day2Nov, day3Nov]
    )
    #expect(!AutomaticBackup.isWriteDue(after: event))
}

// MARK: - Turning it on with a folder that already holds a Backup

@Test func turningItOnWithNoBackupInTheFolderWrites() {
    #expect(AutomaticBackup.onTurningOn(found: .noBackup) == .write)
}

@Test func turningItOnWithAReadableBackupInTheFolderOffersToImportIt() {
    #expect(AutomaticBackup.onTurningOn(found: .readable(backup)) == .offerImport(backup))
}

@Test func turningItOnWithAnUnreadableBackupInTheFolderOffersOnlyToReplaceIt() {
    #expect(
        AutomaticBackup.onTurningOn(found: .unreadable(.unreadable)) == .offerReplace(.unreadable)
    )
}

// MARK: - Status

@Test func thereIsNoStatusBeforeAnyWrite() {
    #expect(AutomaticBackup.status(after: nil, in: TimeZone(identifier: "UTC")!) == nil)
}

@Test func afterAWriteTheStatusShowsTheLastBackupsDayAndTime() {
    let status = AutomaticBackup.status(
        after: .wrote(at: at(3, 7, 15)),
        in: TimeZone(identifier: "UTC")!
    )
    #expect(status == "Last backup: Tue 3 Nov at 07:15")
}

@Test func theLastBackupTimeIsShownInTheGivenTimeZone() {
    let status = AutomaticBackup.status(
        after: .wrote(at: at(3, 7, 15)),
        in: TimeZone(identifier: "America/New_York")!
    )
    #expect(status == "Last backup: Tue 3 Nov at 02:15")
}

@Test func afterAFailedWriteTheStatusShowsWhyItFailed() {
    let status = AutomaticBackup.status(
        after: .failed(at: at(3, 7, 15), reason: "The folder is gone."),
        in: TimeZone(identifier: "UTC")!
    )
    #expect(status == "Backup failed: The folder is gone.")
}
