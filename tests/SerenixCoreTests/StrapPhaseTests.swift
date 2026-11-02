import SerenixCore
import Testing

@Test func lookingForConnectingToAndSyncingWithTheStrapAreBusy() {
    #expect(StrapPhase.searching.isBusy)
    #expect(StrapPhase.connecting.isBusy)
    #expect(StrapPhase.syncing.isBusy)
    #expect(!StrapPhase.idle.isBusy)
    #expect(!StrapPhase.connected.isBusy)
    #expect(!StrapPhase.synced.isBusy)
    #expect(!StrapPhase.bluetoothUnavailable("Bluetooth is off.").isBusy)
    #expect(!StrapPhase.failed("Cancelled mid-sync.", .cancelled).isBusy)
}

@Test func eachStrapPhaseReadsAsTheDebugScreenShowsIt() {
    #expect(StrapPhase.idle.displayText == "Not connected")
    #expect(StrapPhase.bluetoothUnavailable("Bluetooth is off.").displayText == "Bluetooth is off.")
    #expect(StrapPhase.searching.displayText == "Looking for your Strap…")
    #expect(StrapPhase.connecting.displayText == "Connecting…")
    #expect(StrapPhase.connected.displayText == "Connected")
    #expect(StrapPhase.syncing.displayText == "Syncing…")
    #expect(StrapPhase.synced.displayText == "Up to date")
    #expect(StrapPhase.failed("Timed out.", .other).displayText == "Failed: Timed out.")
}

@Test func lookingForOrConnectingToTheStrapCountsAsSyncingOnTheSyncPill() {
    #expect(StrapPhase.searching.syncStatus(connectionWanted: false) == .syncing)
    #expect(StrapPhase.connecting.syncStatus(connectionWanted: false) == .syncing)
    #expect(StrapPhase.syncing.syncStatus(connectionWanted: false) == .syncing)
}

@Test func aFinishedSyncJustFinishedAndAnIdleOrConnectedStrapHasNothingToSay() {
    #expect(StrapPhase.synced.syncStatus(connectionWanted: false) == .justFinished)
    #expect(StrapPhase.idle.syncStatus(connectionWanted: true) == .idle)
    #expect(StrapPhase.connected.syncStatus(connectionWanted: true) == .idle)
}

@Test func bluetoothBeingUnavailablePausesOnlyASyncOrConnectionThatWasWanted() {
    let off = StrapPhase.bluetoothUnavailable("Bluetooth is off.")
    #expect(
        off.syncStatus(connectionWanted: true)
            == .failed(reason: "Bluetooth is off.", cause: .strapUnreachable)
    )
    #expect(off.syncStatus(connectionWanted: false) == .idle)
}

@Test func aFailedPhaseKeepsItsReasonAndCauseOnTheSyncPill() {
    #expect(
        StrapPhase.failed("Timed out.", .other).syncStatus(connectionWanted: false)
            == .failed(reason: "Timed out.", cause: .other)
    )
    #expect(
        StrapPhase.failed("Timed out.", .other).syncStatus(connectionWanted: true)
            == .failed(reason: "Timed out.", cause: .other)
    )
}
