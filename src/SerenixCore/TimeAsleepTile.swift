import Foundation

/// The Time Asleep tile on the Today screen (spec 002, Tiles).
public struct TimeAsleepTile: Equatable, Sendable {
    /// e.g. "7h 40m", to the nearest minute; "—" when missing.
    public let valueText: String
    /// Sleep Onset → Final Wake in local time, e.g. "22:45 → 06:57"; "—" if either is missing.
    public let spanText: String
    /// Time Asleep in seconds, oldest first.
    public let trend: [Double]

    init(for night: Night, among nights: [Night], timeZone: TimeZone) {
        valueText = night.plausibleTimeAsleep.map(durationText) ?? missingText
        spanText =
            if let onset = night.sleepOnset, let wake = night.finalWake {
                "\(clockText(onset, in: timeZone)) → \(clockText(wake, in: timeZone))"
            } else {
                missingText
            }
        trend = trendValues(of: \.plausibleTimeAsleep, upTo: night, among: nights)
    }
}

/// A duration as hours and minutes, e.g. "7h 40m" (spec 002, Formats); "—" when it's negative or
/// too large to show.
func durationText(_ seconds: TimeInterval) -> String {
    guard let minutes = Int(exactly: (seconds / 60).rounded()), minutes >= 0 else {
        return missingText
    }
    return "\(minutes / 60)h \(minutes % 60)m"
}
