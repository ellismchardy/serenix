import Foundation

/// Where History Sync has got to, as the Today screen's sync pill reads it (spec 002).
public enum SyncStatus: Equatable, Sendable {
    /// Connecting to the Strap or syncing.
    case syncing
    /// A sync has just finished.
    case justFinished
    /// Nothing to say: no sync running and none just finished.
    case idle
    case failed(reason: String, cause: SyncFailureCause)
}

/// Why a History Sync failed, as far as the sync pill cares.
public enum SyncFailureCause: Equatable, Sendable {
    /// Not found, couldn't connect, Bluetooth off or not allowed, or the Strap disconnected.
    case strapUnreachable
    /// The user cancelled it, so there's nothing to warn about.
    case cancelled
    case other
}

/// Which sync pill shows.
public enum SyncPillKind: Equatable, Sendable {
    case syncing
    case successful
    case paused
    case failed
}

/// The sync pill's content (spec 002, Sync pill).
public struct SyncPill: Equatable, Sendable {
    public let kind: SyncPillKind
    public let text: String
    /// Why it paused or failed, shown with Retry; nil otherwise.
    public let detail: String?
    /// Whether 001's progress bar and time left show under the pill.
    public let showsProgress: Bool

    /// Paused and failed pills stay until put away; syncing stays until the sync ends, and
    /// successful goes by itself (spec 002, Sync pill).
    public var canBeDismissed: Bool { kind == .paused || kind == .failed }

    /// The pill for `status`; nil when there's nothing to say.
    init?(_ status: SyncStatus) {
        switch status {
        case .idle, .failed(_, .cancelled):
            return nil
        case .syncing:
            (kind, text, detail, showsProgress) = (.syncing, "Syncing", nil, true)
        case .justFinished:
            (kind, text, detail, showsProgress) = (.successful, "Sync successful", nil, false)
        case .failed(let reason, .strapUnreachable):
            (kind, text, detail, showsProgress) =
                (.paused, "Sync paused", "\(reason) \(Self.pausedRetryNote)", false)
        case .failed(let reason, .other):
            (kind, text, detail, showsProgress) = (.failed, "Sync failed", reason, false)
        }
    }

    /// Added to a paused sync's reason: an unreachable Strap is tried again on the next open.
    private static let pausedRetryNote = "Serenix will try again next time you open it."
}

/// A local clock time as "HH:mm", 24-hour (spec 002, Formats).
func clockText(_ time: Date, in timeZone: TimeZone) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.hour, .minute], from: time)
    guard let hour = parts.hour, let minute = parts.minute else { return missingText }
    return String(format: "%02ld:%02ld", hour, minute)
}
