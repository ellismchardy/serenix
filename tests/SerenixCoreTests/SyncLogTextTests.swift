import Foundation
import SerenixCore
import Testing

@Test func syncLogTextHasOneLinePerEntryWithUTCTimeDirectionAndHex() {
    var session = HistorySync()
    let start = Date(timeIntervalSince1970: 1_793_130_616.5)  // 2026-10-27T19:50:16.500Z
    var syncLog = session.start(at: start).syncLog
    // Not a Frame, so the session logs it as received and does nothing else.
    syncLog += session.receive([0xde, 0xad, 0x0f], at: start.addingTimeInterval(0.25)).syncLog

    // The hello the session sends first: the fixture's first command, sequence 1.
    #expect(
        syncLogText(syncLog) == """
            2026-10-27T19:50:16.500Z out aa0108000001e67123019101363e5c8d
            2026-10-27T19:50:16.750Z in dead0f

            """
    )
}

@Test func aSyncLogEntryGivesItsBytesAsLowercaseHex() throws {
    var session = HistorySync()
    let output = session.receive([0x00, 0x0a, 0xff], at: Date(timeIntervalSince1970: 0))
    let entry = try #require(output.syncLog.first)
    #expect(entry.hexBytes == "000aff")
}

@Test func anEmptySyncLogIsEmptyText() {
    #expect(syncLogText([]) == "")
}
