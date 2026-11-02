import Foundation
import SerenixCore
import Testing

/// The phone's clock when the pill is worked out: 2026-11-01 09:00:00 UTC.
private let now = Date(timeIntervalSince1970: 1_793_523_600)

/// A reading of `heartRate` whose Strap time matches the phone's clock at `now`.
private func reading(_ heartRate: Int) -> LiveHRReading {
    LiveHRReading(heartRate: heartRate, strapTime: now)
}

@Test func connectingWithNoReadingShowsAPulsingHeartAndEllipsis() {
    let pill = liveHRPill(connection: .connecting, last: nil, arrivedAt: nil, now: now)
    #expect(pill == .connecting)
    #expect(pill.text == "…")
}

@Test func connectedButWaitingForTheFirstReadingStillShowsConnecting() {
    #expect(liveHRPill(connection: .connected, last: nil, arrivedAt: nil, now: now) == .connecting)
}

@Test func aReadingThatArrivedUnderFiveSecondsAgoShowsItsBpm() {
    let pill = liveHRPill(
        connection: .connected,
        last: reading(72),
        arrivedAt: now.addingTimeInterval(-4.9),
        now: now
    )
    #expect(pill == .bpm(72))
    #expect(pill.text == "72")
}

@Test func aReadingThatArrivedJustNowShowsItsBpm() {
    let pill = liveHRPill(connection: .connected, last: reading(72), arrivedAt: now, now: now)
    #expect(pill == .bpm(72))
}

@Test func aReadingThatArrivedFiveSecondsAgoIsStaleAndShowsADash() {
    let pill = liveHRPill(
        connection: .connected,
        last: reading(72),
        arrivedAt: now.addingTimeInterval(-5.0),
        now: now
    )
    #expect(pill == .unavailable)
    #expect(pill.text == "—")
}

@Test func aReadingOfZeroWhileTheStrapAcquiresShowsADash() {
    let pill = liveHRPill(connection: .connected, last: reading(0), arrivedAt: now, now: now)
    #expect(pill == .unavailable)
    #expect(pill.text == "—")
}

/// No Strap set up, Bluetooth off and a failed or dropped connection all reach the pill as an
/// unavailable connection.
@Test func anUnavailableConnectionShowsADashWithNoReading() {
    let pill = liveHRPill(connection: .unavailable, last: nil, arrivedAt: nil, now: now)
    #expect(pill == .unavailable)
    #expect(pill.text == "—")
}

@Test func anUnavailableConnectionShowsADashEvenWithAFreshReading() {
    let pill = liveHRPill(
        connection: .unavailable,
        last: reading(72),
        arrivedAt: now.addingTimeInterval(-1),
        now: now
    )
    #expect(pill == .unavailable)
}

@Test func stalenessUsesThePhonesArrivalTimeNotTheStrapsClock() {
    // The Strap's clock is 3 hours behind the phone's, but the reading arrived 1 s ago.
    let offClock = LiveHRReading(heartRate: 72, strapTime: now.addingTimeInterval(-3 * 3600))
    let pill = liveHRPill(
        connection: .connected,
        last: offClock,
        arrivedAt: now.addingTimeInterval(-1),
        now: now
    )
    #expect(pill == .bpm(72))
}
