import Foundation

/// Where History Sync has got to, as the Today screen's sync pill shows it (spec 002).
public enum SyncStatus: Equatable, Sendable {
    case connecting
    case syncing
    /// No sync running; `lastSync` is when the last one finished, nil if there has never been one.
    case upToDate(lastSync: Date?)
    case failed(reason: String)
}

/// The sync pill's content.
public struct SyncPill: Equatable, Sendable {
    public let text: String
    /// Why the sync failed, shown with Retry; nil unless it failed.
    public let failureReason: String?
    /// Whether 001's progress bar and time left show under the pill.
    public let showsProgress: Bool

    init(_ status: SyncStatus, timeZone: TimeZone) {
        switch status {
        case .connecting:
            (text, failureReason, showsProgress) = ("Connecting…", nil, false)
        case .syncing:
            (text, failureReason, showsProgress) = ("Syncing", nil, true)
        case .upToDate(let lastSync?):
            (text, failureReason, showsProgress) =
                ("Synced \(clockText(lastSync, in: timeZone))", nil, false)
        case .upToDate(nil):
            (text, failureReason, showsProgress) = ("Not synced", nil, false)
        case .failed(let reason):
            (text, failureReason, showsProgress) = ("Sync failed", reason, false)
        }
    }
}

/// A local clock time as "HH:mm", 24-hour (spec 002, Formats).
func clockText(_ time: Date, in timeZone: TimeZone) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.hour, .minute], from: time)
    return String(format: "%02ld:%02ld", parts.hour!, parts.minute!)
}
