import Foundation

/// Where the shell's Live HR connection is (spec 006).
public enum LiveHRConnection: Equatable, Sendable {
    /// Connecting to the Strap.
    case connecting
    /// Connected; until the first reading arrives the pill still shows it's connecting.
    case connected
    /// No Strap set up, Bluetooth off, or the connection failed or dropped.
    case unavailable
}

/// What the Live HR pill on today's Load popup shows (spec 006). It fails quietly: never an
/// error or a reason.
public enum LiveHRPill: Equatable, Sendable {
    /// A pulsing heart and "…", until the first reading.
    case connecting
    /// A heart and the bpm.
    case bpm(Int)
    /// A grey heart and "—".
    case unavailable

    /// "…", e.g. "72", or "—".
    public var text: String {
        switch self {
        case .connecting: "\u{2026}"
        case .bpm(let bpm): String(bpm)
        case .unavailable: missingText
        }
    }
}

/// Seconds without a new reading before the pill shows "—" (spec 006): five missed 1-second
/// `0x28` Frames. An assumption, to tune on the phone.
let liveHRStaleAfter: TimeInterval = 5

/// The pill for `connection`, the last reading and when it arrived on the phone, at `now`. The
/// Strap's clock is not used: it can be off from the phone's.
public func liveHRPill(
    connection: LiveHRConnection,
    last: LiveHRReading?,
    arrivedAt: Date?,
    now: Date
) -> LiveHRPill {
    guard connection != .unavailable else { return .unavailable }
    guard let last, let arrivedAt else { return .connecting }
    guard now.timeIntervalSince(arrivedAt) < liveHRStaleAfter, last.heartRate > 0 else {
        return .unavailable
    }
    return .bpm(last.heartRate)
}
