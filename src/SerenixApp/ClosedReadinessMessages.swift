import Foundation
import SerenixCore

/// The Nights whose Readiness message the user closed, by the Night's Day, kept in UserDefaults on
/// this phone so a closed message stays closed after relaunching (spec 002, Readiness message).
struct ClosedReadinessMessages {
    /// Most recently closed last.
    private var keys = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []

    func contains(_ day: Day) -> Bool { keys.contains(Self.key(day)) }

    /// Remembers `day` as closed. Only the most recently closed Nights are kept, so the one just
    /// closed always stays closed.
    mutating func close(_ day: Day) {
        let key = Self.key(day)
        keys.removeAll { $0 == key }
        keys.append(key)
        keys = Array(keys.suffix(Self.keptNights))
        UserDefaults.standard.set(keys, forKey: Self.storageKey)
    }

    /// e.g. "2026-11-01".
    private static func key(_ day: Day) -> String {
        String(format: "%04ld-%02ld-%02ld", day.year, day.month, day.dayOfMonth)
    }

    /// How many closed Nights to remember: about two months of daily Nights, plenty for the
    /// week strip and date picker. An assumption, chosen so the list can't grow for ever.
    private static let keptNights = 60
    private static let storageKey = "closedReadinessMessages"
}
