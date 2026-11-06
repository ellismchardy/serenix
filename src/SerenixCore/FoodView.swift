import Foundation

/// Everything the Body tab's Food view shows for one Day (spec 016), worked out from the stored
/// Food Entries each time, never stored (ADR 0008). The shell draws it.
public struct FoodView: Equatable, Sendable {
    /// The Day shown.
    public let day: Day
    /// The shown Day's Food Entries, newest first.
    public let entries: [FoodEntry]
    /// The shown Day's Food Entries added up.
    public let intake: Intake

    /// Each Food Entry counts on the local Day of its time in `timeZone`, as Weigh-ins do.
    public init(foodEntries: [FoodEntry], day: Day, now: Date, timeZone: TimeZone) {
        self.day = day
        entries =
            foodEntries
            .filter { Day(containing: $0.time, in: timeZone) == day }
            .sorted { $0.time > $1.time }
        intake = Intake(entries)
    }
}
