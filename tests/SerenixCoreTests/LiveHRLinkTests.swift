import Foundation
import SerenixCore
import Testing

// Frames copied from LiveHRSessionTests.swift (private there).

/// Hello (`0x91 01`), sequence 1, as hr-tracker whoop5.py sends it.
private let helloFrame: [UInt8] = [
    0xaa, 0x01, 0x08, 0x00, 0x00, 0x01, 0xe6, 0x71,
    0x23, 0x01, 0x91, 0x01, 0x36, 0x3e, 0x5c, 0x8d,
]

/// Live HR on (`0x03 01`), sequence 2, as hr-tracker whoop5.py sends it.
private let liveHROnFrame: [UInt8] = [
    0xaa, 0x01, 0x08, 0x00, 0x00, 0x01, 0xe6, 0x71,
    0x23, 0x02, 0x03, 0x01, 0xf7, 0x68, 0x6d, 0xcc,
]

/// Live HR off (`0x03 00`), sequence 3, as hr-tracker whoop5.py sends it.
private let liveHROffFrame: [UInt8] = [
    0xaa, 0x01, 0x08, 0x00, 0x00, 0x01, 0xe6, 0x71,
    0x23, 0x03, 0x03, 0x00, 0x56, 0x32, 0xa8, 0xba,
]

/// The first `0x28` Frame in the 27 Oct 2026 capture, as captured: HR 0x4d (77), Strap time
/// 0x6ae0ff05 (2026-10-27 19:44:05 UTC).
private let firstLiveHRFrame: [UInt8] = [
    0xaa, 0x01, 0x18, 0x00, 0x01, 0x00, 0x22, 0xe1,
    0x28, 0x02, 0x05, 0xff, 0xe0, 0x6a, 0x85, 0x4b,
    0x4d, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x32, 0x3c, 0xc8, 0xaa,
]

/// The second `0x28` Frame in the capture, as captured: HR 0x4c (76), one second later.
private let secondLiveHRFrame: [UInt8] = [
    0xaa, 0x01, 0x18, 0x00, 0x01, 0x00, 0x22, 0xe1,
    0x28, 0x02, 0x06, 0xff, 0xe0, 0x6a, 0x85, 0x4b,
    0x4c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x3f, 0xad, 0xeb, 0xdb,
]

private let shownAt = Date(timeIntervalSince1970: 1_793_523_600)
private let readyAt = shownAt.addingTimeInterval(3)
private let firstFrameAt = shownAt.addingTimeInterval(4)
private let hiddenAt = shownAt.addingTimeInterval(10)
private let failedPhase = StrapPhase.failed("The Strap disconnected mid-sync.", .strapUnreachable)

/// The Strap's link once connected, the command characteristic found and subscribed: the shell
/// shows "Connected".
private let readyFacts = StrapLinkFacts(phase: .connected, linkReady: true)

/// Checks `actions` are Live HR off, keep the "Live HR" Sync Log, disconnect and show `phase`,
/// in that order, as when a connection only for Live HR ends; returns the Sync Log kept.
private func endingActionsKeptLog(
    _ actions: [LiveHRAction],
    showing phase: StrapPhase,
    sourceLocation: SourceLocation = #_sourceLocation
) -> [SyncLogEntry]? {
    guard actions.count == 4, case .keepLog(let log) = actions[1] else {
        Issue.record(
            "expected off, keepLog, disconnect, showPhase: \(actions)",
            sourceLocation: sourceLocation
        )
        return nil
    }
    #expect(actions[0] == .write([liveHROffFrame]), sourceLocation: sourceLocation)
    #expect(
        Array(actions[2...]) == [.disconnect, .showPhase(phase)],
        sourceLocation: sourceLocation
    )
    return log
}

/// A link shown with `phase` on the shell, connected for Live HR and streaming.
private func streamingLink(standingInFor phase: StrapPhase = .idle) -> LiveHRLink {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: phase), at: shownAt)
    _ = link.linkReady(at: readyAt)
    return link
}

// MARK: Live HR on its own connection

@Test func liveHRLinkShownInTheForegroundConnectsToTheRememberedStrap() {
    var link = LiveHRLink()
    let actions = link.setShown(true, facts: StrapLinkFacts(phase: .idle), at: shownAt)
    #expect(actions == [.connect])
    #expect(link.pill(at: shownAt) == .connecting)
    #expect(link.heldPhase == .idle)
}

@Test func liveHRLinkReadyWritesHelloThenLiveHROn() {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: .idle), at: shownAt)
    let actions = link.linkReady(at: readyAt)
    #expect(actions == [.write([helloFrame, liveHROnFrame])])
    #expect(link.isStreaming)
    // No reading yet, so the pill still shows it's connecting.
    #expect(link.pill(at: readyAt) == .connecting)
}

@Test func liveHRLinkFrameFromTheStrapShowsItsBpmOnThePill() {
    var link = streamingLink()
    let actions = link.receive(firstLiveHRFrame, at: firstFrameAt)
    #expect(actions == [])
    #expect(link.pill(at: firstFrameAt.addingTimeInterval(1)) == .bpm(77))
    #expect(link.connection == .connected)
    #expect(link.arrivedAt == firstFrameAt)
    #expect(
        link.lastReading
            == LiveHRReading(heartRate: 77, strapTime: Date(timeIntervalSince1970: 1_793_130_245))
    )
}

@Test func liveHRLinkNextFrameFromTheStrapShowsTheNewBpm() {
    var link = streamingLink()
    _ = link.receive(firstLiveHRFrame, at: firstFrameAt)
    let next = firstFrameAt.addingTimeInterval(1)
    _ = link.receive(secondLiveHRFrame, at: next)
    #expect(link.pill(at: next) == .bpm(76))
    #expect(link.arrivedAt == next)
}

@Test func liveHRLinkHiddenWritesLiveHROffKeepsTheSyncLogAndDisconnects() throws {
    var link = streamingLink()
    _ = link.receive(firstLiveHRFrame, at: firstFrameAt)
    let actions = link.setShown(false, facts: readyFacts, at: hiddenAt)
    let log = try #require(endingActionsKeptLog(actions, showing: .idle))
    #expect(log.map(\.bytes) == [helloFrame, liveHROnFrame, firstLiveHRFrame, liveHROffFrame])
    #expect(log.map(\.direction) == [.toStrap, .toStrap, .fromStrap, .toStrap])
    #expect(log.map(\.time) == [readyAt, readyAt, firstFrameAt, hiddenAt])
}

@Test func liveHRLinkHiddenForgetsTheReadingAndTheHeldPhase() {
    var link = streamingLink()
    _ = link.receive(firstLiveHRFrame, at: firstFrameAt)
    _ = link.setShown(false, facts: readyFacts, at: hiddenAt)
    #expect(link.lastReading == nil)
    #expect(link.arrivedAt == nil)
    #expect(link.heldPhase == nil)
    #expect(!link.isStreaming)
}

// MARK: Hidden or in the background

@Test func liveHRLinkNotShownDoesNotConnect() {
    var link = LiveHRLink()
    #expect(!link.isWanted)
    let actions = link.setForeground(true, facts: StrapLinkFacts(phase: .idle), at: shownAt)
    #expect(actions == [])
    #expect(link.heldPhase == nil)
}

@Test func liveHRLinkShownInTheBackgroundDoesNotConnect() {
    var link = LiveHRLink()
    _ = link.setForeground(false, facts: StrapLinkFacts(phase: .idle), at: shownAt)
    let actions = link.setShown(true, facts: StrapLinkFacts(phase: .idle), at: shownAt)
    #expect(actions == [])
    #expect(!link.isWanted)
    #expect(link.heldPhase == nil)
}

@Test func liveHRLinkLeavingTheForegroundWhileStreamingStopsItLikeHiding() throws {
    var link = streamingLink()
    _ = link.receive(firstLiveHRFrame, at: firstFrameAt)
    let actions = link.setForeground(false, facts: readyFacts, at: hiddenAt)
    let log = try #require(endingActionsKeptLog(actions, showing: .idle))
    #expect(log.map(\.bytes) == [helloFrame, liveHROnFrame, firstLiveHRFrame, liveHROffFrame])
    #expect(!link.isStreaming)
    #expect(link.lastReading == nil)
}

// MARK: Already ready

@Test func liveHRLinkShownOnALinkAlreadyReadyStartsWithoutConnecting() {
    var link = LiveHRLink()
    let actions = link.setShown(true, facts: readyFacts, at: shownAt)
    #expect(actions == [.write([helloFrame, liveHROnFrame])])
    #expect(link.heldPhase == nil)
    #expect(link.isStreaming)
}

// MARK: Wiped sync pill

@Test func liveHRLinkConnectingHoldsAFailedSyncsPhaseForTheSyncPill() {
    var link = LiveHRLink()
    let actions = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    #expect(actions == [.connect])
    #expect(link.heldPhase == failedPhase)
    let pillPhase = link.phaseForSyncPill(StrapLinkFacts(phase: .connecting))
    #expect(pillPhase == failedPhase)
    #expect(
        pillPhase.syncStatus(connectionWanted: false)
            == .failed(reason: "The Strap disconnected mid-sync.", cause: .strapUnreachable)
    )
}

@Test func liveHRLinkConnectingHoldsASyncedPhaseForTheSyncPill() {
    var link = LiveHRLink()
    let actions = link.setShown(true, facts: StrapLinkFacts(phase: .synced), at: shownAt)
    #expect(actions == [.connect])
    #expect(link.heldPhase == .synced)
    #expect(link.phaseForSyncPill(StrapLinkFacts(phase: .connecting)) == .synced)
    #expect(link.phaseForSyncPill(readyFacts) == .synced)
}

@Test func liveHRLinkEndingItsConnectionShowsTheFailedSyncsPhaseAgain() {
    var link = streamingLink(standingInFor: failedPhase)
    #expect(link.phaseForSyncPill(readyFacts) == failedPhase)
    let actions = link.setShown(false, facts: readyFacts, at: hiddenAt)
    #expect(actions.last == .showPhase(failedPhase))
    #expect(link.heldPhase == nil)
}

@Test func liveHRLinkEndingItsConnectionShowsTheSyncedPhaseAgain() {
    var link = streamingLink(standingInFor: .synced)
    let actions = link.setShown(false, facts: readyFacts, at: hiddenAt)
    #expect(actions.last == .showPhase(.synced))
}

@Test func syncPillReadsTheShellsPhaseWhileASyncIsRunningOrWanted() {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    #expect(
        link.phaseForSyncPill(StrapLinkFacts(phase: .syncing, syncRunning: true)) == .syncing
    )
    #expect(
        link.phaseForSyncPill(StrapLinkFacts(phase: .connecting, syncWanted: true)) == .connecting
    )
}

@Test func syncPillReadsTheShellsPhaseWhenLiveHRHoldsNone() {
    let link = LiveHRLink()
    #expect(link.phaseForSyncPill(StrapLinkFacts(phase: failedPhase)) == failedPhase)
}

// MARK: Closing while searching or connecting

@Test func liveHRLinkClosedWhileSearchingStopsScanningAndEndsAtOnce() {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: .synced), at: shownAt)
    let actions = link.setShown(false, facts: StrapLinkFacts(phase: .searching), at: hiddenAt)
    #expect(actions == [.stopScanning, .disconnect, .showPhase(.synced)])
    #expect(link.heldPhase == nil)
}

@Test func liveHRLinkClosedWhileConnectingCancelsTheAttempt() {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: .synced), at: shownAt)
    let actions = link.setShown(false, facts: StrapLinkFacts(phase: .connecting), at: hiddenAt)
    #expect(actions == [.cancelConnecting])
    // The attempt hasn't resolved yet: the sync pill still shows what it showed.
    #expect(link.phaseForSyncPill(StrapLinkFacts(phase: .connecting)) == .synced)
}

@Test func liveHRLinkCancelledAttemptThatBecomesReadyDisconnectsQuietly() {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    _ = link.setShown(false, facts: StrapLinkFacts(phase: .connecting), at: hiddenAt)
    let actions = link.linkReady(at: hiddenAt.addingTimeInterval(1))
    #expect(actions == [.disconnect, .showPhase(failedPhase)])
    #expect(!link.isStreaming)
    #expect(link.heldPhase == nil)
}

@Test func liveHRLinkCancelledAttemptThatDisconnectsEndsQuietlyWithoutARetry() {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    _ = link.setShown(false, facts: StrapLinkFacts(phase: .connecting), at: hiddenAt)
    let response = link.linkDisconnected(facts: StrapLinkFacts(phase: .connecting))
    #expect(response.wasLiveHRConnection)
    #expect(response.actions == [.stopConnectTimeout, .showPhase(failedPhase)])
    #expect(link.heldPhase == nil)
}

// MARK: Nothing to connect to

@Test func liveHRLinkWithNoRememberedStrapShowsUnavailableAndDoesNotConnect() {
    var link = LiveHRLink()
    let actions = link.setShown(
        true,
        facts: StrapLinkFacts(phase: .idle, hasStrap: false),
        at: shownAt
    )
    #expect(actions == [])
    #expect(link.pill(at: shownAt) == .unavailable)
    #expect(link.heldPhase == nil)
}

@Test func liveHRLinkWithBluetoothOffShowsUnavailableAndDoesNotConnect() {
    var link = LiveHRLink()
    let actions = link.setShown(
        true,
        facts: StrapLinkFacts(
            phase: .bluetoothUnavailable("Bluetooth is off."),
            bluetoothOn: false
        ),
        at: shownAt
    )
    #expect(actions == [])
    #expect(link.pill(at: shownAt) == .unavailable)
    #expect(link.heldPhase == nil)
}

// MARK: Live HR during a History Sync

/// A History Sync running on the ready link: the shell shows "Syncing".
private let syncingFacts = StrapLinkFacts(phase: .syncing, syncRunning: true, linkReady: true)
private let syncEndedAt = shownAt.addingTimeInterval(20)
private let retryAt = syncEndedAt.addingTimeInterval(1)

/// A link shown while a History Sync runs, so Live HR is on within that sync.
private func linkOnInSync() -> LiveHRLink {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: syncingFacts, at: shownAt)
    return link
}

@Test func liveHRLinkShownDuringASyncTurnsLiveHROnInTheSync() {
    var link = LiveHRLink()
    let actions = link.setShown(true, facts: syncingFacts, at: shownAt)
    #expect(actions == [.setLiveHRInSync(true)])
    #expect(link.pill(at: shownAt) == .connecting)
    #expect(!link.isStreaming)
    #expect(link.heldPhase == nil)
}

@Test func liveHRLinkShownAgainDuringASyncTurnsLiveHROnOnlyOnce() {
    var link = linkOnInSync()
    let actions = link.setForeground(true, facts: syncingFacts, at: firstFrameAt)
    #expect(actions == [])
}

@Test func liveHRLinkHiddenDuringASyncTurnsLiveHROffAndTheSyncCarriesOn() {
    var link = linkOnInSync()
    let actions = link.setShown(false, facts: syncingFacts, at: hiddenAt)
    #expect(actions == [.setLiveHRInSync(false)])
}

@Test func liveHRLinkReadingsFromASyncShowTheirBpmOnThePill() {
    var link = linkOnInSync()
    link.noteReadings(
        [LiveHRReading(heartRate: 72, strapTime: Date(timeIntervalSince1970: 1_793_130_245))],
        at: firstFrameAt
    )
    #expect(link.pill(at: firstFrameAt) == .bpm(72))
    #expect(link.arrivedAt == firstFrameAt)
    #expect(link.connection == .connected)
}

@Test func liveHRLinkSyncStartingWhileStreamingTakesTheStreamOver() {
    var link = streamingLink(standingInFor: failedPhase)
    let actions = link.syncStarting()
    guard actions.count == 2, case .keepLog(let log) = actions[0] else {
        Issue.record("expected keepLog, setLiveHRInSync(true): \(actions)")
        return
    }
    #expect(log.map(\.bytes) == [helloFrame, liveHROnFrame])
    #expect(actions[1] == .setLiveHRInSync(true))
    #expect(!link.isStreaming)
    #expect(link.heldPhase == nil)
    #expect(link.phaseForSyncPill(syncingFacts) == .syncing)
}

@Test func liveHRLinkSyncStartingWhenNotWantedLeavesLiveHROff() {
    var link = LiveHRLink()
    #expect(link.syncStarting() == [])
}

@Test func liveHRLinkSyncEndingWithThePopupOpenAndNoReadingShowsUnavailableAndRetries() {
    var link = linkOnInSync()
    let actions = link.syncFinished()
    #expect(actions == [.scheduleRetry(after: 1)])
    #expect(link.pill(at: syncEndedAt) == .unavailable)
}

@Test func liveHRLinkSyncEndingWithAReadingKeepsItsBpmAndRetries() {
    var link = linkOnInSync()
    link.noteReadings(
        [LiveHRReading(heartRate: 72, strapTime: Date(timeIntervalSince1970: 1_793_130_245))],
        at: firstFrameAt
    )
    let actions = link.syncFinished()
    #expect(actions == [.scheduleRetry(after: 1)])
    #expect(link.connection == .connected)
    #expect(link.pill(at: firstFrameAt) == .bpm(72))
}

@Test func liveHRLinkSyncEndingWithThePopupClosedSchedulesNoRetry() {
    var link = linkOnInSync()
    _ = link.setShown(false, facts: syncingFacts, at: hiddenAt)
    #expect(link.syncFinished() == [])
}

@Test func liveHRLinkSyncEndingTwiceSchedulesOneRetry() {
    var link = linkOnInSync()
    _ = link.syncFinished()
    #expect(link.syncFinished() == [])
}

@Test func liveHRLinkRetryAfterASyncEndsConnectsHoldingTheSyncsResult() {
    var link = linkOnInSync()
    _ = link.syncFinished()
    let actions = link.retryDue(facts: StrapLinkFacts(phase: failedPhase), at: retryAt)
    #expect(actions == [.connect])
    #expect(link.heldPhase == failedPhase)
    #expect(link.phaseForSyncPill(StrapLinkFacts(phase: .connecting)) == failedPhase)
}

@Test func liveHRLinkRetryDueWhenNoLongerWantedDoesNothing() {
    var link = linkOnInSync()
    _ = link.syncFinished()
    _ = link.setShown(false, facts: StrapLinkFacts(phase: failedPhase), at: syncEndedAt)
    let actions = link.retryDue(facts: StrapLinkFacts(phase: failedPhase), at: retryAt)
    #expect(actions == [])
    #expect(link.heldPhase == nil)
}

@Test func liveHRLinkShownWhilePairingWaitsAndStartsWhenThatLinkIsReady() {
    var link = LiveHRLink()
    let shown = link.setShown(true, facts: StrapLinkFacts(phase: .connecting), at: shownAt)
    #expect(shown == [])
    #expect(link.pill(at: shownAt) == .connecting)
    let ready = link.linkReady(at: readyAt)
    #expect(ready == [.write([helloFrame, liveHROnFrame])])
    #expect(link.isStreaming)
}

@Test func liveHRLinkHiddenWhilePairingLeavesThatLinkAlone() {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: .connecting), at: shownAt)
    _ = link.setShown(false, facts: StrapLinkFacts(phase: .connecting), at: hiddenAt)
    #expect(link.linkReady(at: readyAt) == [])
    #expect(!link.isStreaming)
}

@Test func liveHRLinkShownWithASyncOnItsWayLetsTheSyncTurnLiveHROn() {
    var link = LiveHRLink()
    let shown = link.setShown(
        true,
        facts: StrapLinkFacts(phase: .connecting, syncWanted: true),
        at: shownAt
    )
    #expect(shown == [])
    #expect(link.syncStarting() == [.setLiveHRInSync(true)])
}

@Test func liveHRLinkSyncNowDuringACancelledAttemptShowsIdleAndConnectsForTheSync() {
    var link = LiveHRLink()
    #expect(link.setShown(true, facts: StrapLinkFacts(phase: .synced), at: shownAt) == [.connect])
    let hidden = link.setShown(false, facts: StrapLinkFacts(phase: .connecting), at: hiddenAt)
    #expect(hidden == [.cancelConnecting])
    let response = link.linkDisconnected(
        facts: StrapLinkFacts(phase: .connecting, syncWanted: true)
    )
    #expect(response.wasLiveHRConnection)
    #expect(response.actions == [.showPhase(.idle), .connect])
    #expect(link.heldPhase == nil)
}

@Test func liveHRLinkSyncsLinkDisconnectingWithThePopupOpenSchedulesARetry() {
    var link = linkOnInSync()
    let response = link.linkDisconnected(facts: syncingFacts)
    #expect(!response.wasLiveHRConnection)
    #expect(response.actions == [.scheduleRetry(after: 1)])
}

@Test func liveHRLinkSyncsLinkDisconnectingWithThePopupClosedSchedulesNoRetry() {
    var link = linkOnInSync()
    _ = link.setShown(false, facts: syncingFacts, at: hiddenAt)
    let response = link.linkDisconnected(facts: syncingFacts)
    #expect(!response.wasLiveHRConnection)
    #expect(response.actions == [])
}

@Test func liveHRLinkSyncStartingDuringALiveHRAttemptForgetsTheAttempt() {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    // "Sync now" rides on the attempt, and the shell starts the sync once the link is ready.
    #expect(link.syncStarting() == [.setLiveHRInSync(true)])
    #expect(link.heldPhase == nil)
    #expect(link.linkReady(at: readyAt) == [])
    let response = link.linkDisconnected(facts: syncingFacts)
    #expect(!response.wasLiveHRConnection)
}

@Test func liveHRLinkSyncFinishingDuringALiveHRAttemptForgetsTheHeldPhase() {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    _ = link.syncFinished()
    #expect(link.heldPhase == nil)
    #expect(link.phaseForSyncPill(StrapLinkFacts(phase: .idle)) == .idle)
    #expect(link.linkReady(at: readyAt) == [])
}

// MARK: Quiet failures

private let quietFailureAt = shownAt.addingTimeInterval(30)
private let quietRetryAt = quietFailureAt.addingTimeInterval(1)
private let secondQuietRetryAt = quietRetryAt.addingTimeInterval(10)
private let readyAfterRetryAt = secondQuietRetryAt.addingTimeInterval(2)
private let frameAfterRetryAt = readyAfterRetryAt.addingTimeInterval(1)

/// A link shown with a failed sync's phase on the shell, whose own connection attempt then
/// failed quietly, leaving a retry pending.
private func linkAfterAQuietFailure() -> LiveHRLink {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    _ = link.linkFailed(facts: StrapLinkFacts(phase: .connecting))
    return link
}

@Test func liveHRLinkFailureOfItsOwnAttemptIsQuietAndRetries() {
    var link = LiveHRLink()
    let shown = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    #expect(shown == [.connect])
    let response = link.linkFailed(facts: StrapLinkFacts(phase: .connecting))
    #expect(response.wasLiveHRConnection)
    #expect(
        response.actions
            == [.stopScanning, .disconnect, .showPhase(failedPhase), .scheduleRetry(after: 1)]
    )
    #expect(link.pill(at: quietFailureAt) == .unavailable)
    #expect(link.heldPhase == nil)
}

@Test func liveHRLinkFailureWhileASyncRunsIsNotLiveHRs() {
    var link = linkOnInSync()
    let response = link.linkFailed(facts: syncingFacts)
    #expect(!response.wasLiveHRConnection)
    #expect(response.actions == [])
}

@Test func liveHRLinkFailureWhileASyncIsWantedIsNotLiveHRs() {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    let response = link.linkFailed(facts: StrapLinkFacts(phase: .connecting, syncWanted: true))
    #expect(!response.wasLiveHRConnection)
    #expect(response.actions == [])
    #expect(link.heldPhase == failedPhase)
}

@Test func liveHRLinkFailureWithNoLiveHRAttemptIsNotLiveHRs() {
    var link = LiveHRLink()
    let response = link.linkFailed(facts: StrapLinkFacts(phase: .connecting))
    #expect(!response.wasLiveHRConnection)
    #expect(response.actions == [])
}

@Test func liveHRLinkFailureOfThePairingConnectionIsNotLiveHRs() {
    var link = LiveHRLink()
    // Shown while the user's pairing connection is in progress: Live HR waits for it.
    _ = link.setShown(true, facts: StrapLinkFacts(phase: .connecting), at: shownAt)
    let response = link.linkFailed(facts: StrapLinkFacts(phase: .connecting))
    #expect(!response.wasLiveHRConnection)
    #expect(response.actions == [])
}

// MARK: Stuck "…" (retry flips)

@Test func liveHRLinkRetryAfterAQuietFailureKeepsThePillUnavailable() {
    var link = linkAfterAQuietFailure()
    let actions = link.retryDue(facts: StrapLinkFacts(phase: failedPhase), at: quietRetryAt)
    #expect(actions == [.connect])
    // Never back to "…": it stays "—" until a reading arrives.
    #expect(link.pill(at: quietRetryAt) == .unavailable)
}

@Test func liveHRLinkRetriesKeepThePillUnavailableUntilAReadingShowsItsBpm() {
    var link = linkAfterAQuietFailure()
    _ = link.retryDue(facts: StrapLinkFacts(phase: failedPhase), at: quietRetryAt)
    let second = link.linkFailed(facts: StrapLinkFacts(phase: .connecting))
    #expect(second.wasLiveHRConnection)
    #expect(
        second.actions == [
            .stopScanning, .disconnect, .showPhase(failedPhase), .scheduleRetry(after: 1),
        ]
    )
    let retry = link.retryDue(facts: StrapLinkFacts(phase: failedPhase), at: secondQuietRetryAt)
    #expect(retry == [.connect])
    #expect(link.pill(at: secondQuietRetryAt) == .unavailable)
    #expect(link.linkReady(at: readyAfterRetryAt) == [.write([helloFrame, liveHROnFrame])])
    #expect(link.pill(at: readyAfterRetryAt) == .unavailable)
    _ = link.receive(firstLiveHRFrame, at: frameAfterRetryAt)
    #expect(link.pill(at: frameAfterRetryAt) == .bpm(77))
}

@Test func liveHRLinkRetryAfterASyncEndsWithNoReadingKeepsThePillUnavailable() {
    var link = linkOnInSync()
    _ = link.syncFinished()
    #expect(link.retryDue(facts: StrapLinkFacts(phase: failedPhase), at: retryAt) == [.connect])
    #expect(link.pill(at: retryAt) == .unavailable)
}

// MARK: Retries once at a time

@Test func liveHRLinkSyncEndingWhileARetryIsPendingSchedulesNoSecondRetry() {
    var link = linkAfterAQuietFailure()
    #expect(link.syncFinished() == [])
}

@Test func liveHRLinkHiddenWhileARetryIsPendingCancelsTheRetry() {
    var link = linkAfterAQuietFailure()
    let actions = link.setShown(false, facts: StrapLinkFacts(phase: failedPhase), at: hiddenAt)
    #expect(actions.first == .cancelRetry)
    // A retry that falls due all the same does nothing.
    #expect(link.retryDue(facts: StrapLinkFacts(phase: failedPhase), at: quietRetryAt) == [])
    #expect(link.heldPhase == nil)
}

@Test func liveHRLinkShownAgainWhileARetryIsPendingCancelsTheRetryAndConnects() {
    var link = linkAfterAQuietFailure()
    let actions = link.setShown(
        true,
        facts: StrapLinkFacts(phase: failedPhase),
        at: quietRetryAt
    )
    #expect(actions == [.cancelRetry, .connect])
}

// MARK: Quick close and reopen

private let reopenedAt = hiddenAt.addingTimeInterval(1)
private let reopenedAttemptEndsAt = reopenedAt.addingTimeInterval(1)

/// A link shown, closed mid-connect, then shown again while the cancelled attempt resolves.
private func linkReopenedMidConnect() -> LiveHRLink {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    _ = link.setShown(false, facts: StrapLinkFacts(phase: .connecting), at: hiddenAt)
    _ = link.setShown(true, facts: StrapLinkFacts(phase: .connecting), at: reopenedAt)
    return link
}

@Test func liveHRLinkReopenedWhileTheCancelledAttemptResolvesWaitsForIt() {
    var link = LiveHRLink()
    let shown = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    #expect(shown == [.connect])
    let hidden = link.setShown(false, facts: StrapLinkFacts(phase: .connecting), at: hiddenAt)
    #expect(hidden == [.cancelConnecting])
    let reopened = link.setShown(true, facts: StrapLinkFacts(phase: .connecting), at: reopenedAt)
    #expect(reopened == [])
    #expect(link.pill(at: reopenedAt) == .connecting)
}

@Test func liveHRLinkReopenedAttemptThatBecomesReadyStartsTheSession() {
    var link = linkReopenedMidConnect()
    let actions = link.linkReady(at: reopenedAttemptEndsAt)
    #expect(actions == [.write([helloFrame, liveHROnFrame])])
    #expect(link.isStreaming)
}

@Test func liveHRLinkReopenedAttemptThatDisconnectsShowsThePhaseAgainAndRetries() {
    var link = linkReopenedMidConnect()
    let response = link.linkDisconnected(facts: StrapLinkFacts(phase: .connecting))
    #expect(response.wasLiveHRConnection)
    #expect(
        response.actions
            == [.stopConnectTimeout, .showPhase(failedPhase), .scheduleRetry(after: 1)]
    )
    let retry = link.retryDue(
        facts: StrapLinkFacts(phase: failedPhase),
        at: reopenedAttemptEndsAt.addingTimeInterval(1)
    )
    #expect(retry == [.connect])
}

// MARK: A link still closing

@Test func liveHRLinkShownWhileTheLinkIsStillClosingRetriesInsteadOfConnecting() {
    var link = LiveHRLink()
    let actions = link.setShown(
        true,
        facts: StrapLinkFacts(phase: .idle, linkClosing: true),
        at: shownAt
    )
    #expect(actions == [.scheduleRetry(after: 1)])
    let retry = link.retryDue(facts: StrapLinkFacts(phase: .idle), at: readyAt)
    #expect(retry == [.connect])
}

// MARK: Bluetooth off and on

@Test func liveHRLinkBluetoothOffWhileStreamingDropsTheSessionKeepingItsSyncLog() {
    var link = streamingLink(standingInFor: failedPhase)
    _ = link.receive(firstLiveHRFrame, at: firstFrameAt)
    let actions = link.bluetoothOff()
    guard actions.count == 1, case .keepLog(let log) = actions[0] else {
        Issue.record("expected keepLog: \(actions)")
        return
    }
    #expect(log.map(\.bytes) == [helloFrame, liveHROnFrame, firstLiveHRFrame])
    #expect(!link.isStreaming)
    #expect(link.pill(at: firstFrameAt) == .unavailable)
    #expect(link.heldPhase == nil)
}

@Test func liveHRLinkBluetoothOffWhileConnectingForgetsTheAttempt() {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    #expect(link.bluetoothOff() == [])
    #expect(link.heldPhase == nil)
    #expect(link.pill(at: shownAt) == .unavailable)
}

@Test func liveHRLinkBluetoothOnWhileWantedConnectsAgain() {
    var link = LiveHRLink()
    _ = link.setShown(true, facts: StrapLinkFacts(phase: failedPhase), at: shownAt)
    _ = link.bluetoothOff()
    let actions = link.bluetoothOn(
        facts: StrapLinkFacts(phase: .idle, bluetoothOn: true),
        at: readyAt
    )
    #expect(actions == [.connect])
    // Bluetooth coming back isn't a retry: the pill shows "…" again.
    #expect(link.pill(at: readyAt) == .connecting)
}

@Test func liveHRLinkBluetoothOnWhenNotWantedDoesNotConnect() {
    var link = LiveHRLink()
    let actions = link.bluetoothOn(
        facts: StrapLinkFacts(phase: .idle, bluetoothOn: true),
        at: readyAt
    )
    #expect(actions == [])
}

@Test func liveHRLinkBluetoothOffMidSyncTurnsLiveHROnAgainInTheNextSync() {
    var link = linkOnInSync()
    _ = link.bluetoothOff()
    #expect(link.setForeground(true, facts: syncingFacts, at: retryAt) == [.setLiveHRInSync(true)])
}
