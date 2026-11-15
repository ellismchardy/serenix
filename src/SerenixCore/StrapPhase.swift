import Foundation

/// Where the shell's Strap connection and its History Sync have got to, for display.
public enum StrapPhase: Equatable, Sendable {
    case idle
    case bluetoothUnavailable(String)
    case searching
    case connecting
    case connected
    case syncing
    case synced
    case failed(String, SyncFailureCause)

    public var isBusy: Bool {
        switch self {
        case .searching, .connecting, .syncing: true
        case .idle, .bluetoothUnavailable, .connected, .synced, .failed: false
        }
    }

    public var displayText: String {
        switch self {
        case .idle: "Not connected"
        case .bluetoothUnavailable(let reason): reason
        case .searching: "Looking for your Strap…"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .syncing: "Syncing…"
        case .synced: "Up to date"
        case .failed(let reason, _): "Failed: \(reason)"
        }
    }

    /// The phase as the Today view's sync pill reads it (spec 002): looking for or connecting to
    /// the Strap counts as syncing, and Bluetooth being unavailable as the Strap being
    /// unreachable, but only when a sync or connection was wanted; otherwise there's nothing to
    /// say (spec 002, Sync pill).
    public func syncStatus(connectionWanted: Bool) -> SyncStatus {
        switch self {
        case .searching, .connecting, .syncing: .syncing
        case .synced: .justFinished
        case .idle, .connected: .idle
        case .bluetoothUnavailable(let reason):
            connectionWanted ? .failed(reason: reason, cause: .strapUnreachable) : .idle
        case .failed(let reason, let cause): .failed(reason: reason, cause: cause)
        }
    }
}
