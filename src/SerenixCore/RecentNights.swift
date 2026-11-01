import Foundation

/// The `count` most recent Nights up to and including `night`, oldest first.
func recentNights(_ count: Int, upTo night: Night, among nights: [Night]) -> [Night] {
    nights
        .filter { $0.day <= night.day }
        .sorted { $0.day > $1.day }
        .prefix(count)
        .reversed()
}
