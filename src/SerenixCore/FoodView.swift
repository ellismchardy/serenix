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
    /// The shown Day is marked complete and has at least one Food Entry.
    public let isComplete: Bool
    /// The shown Day has a Food Entry, so it may be marked complete (spec 016).
    public let canBeMarkedComplete: Bool
    /// The Calorie Target, kcal a Day; nil when not set.
    public let calorieTarget: Double?
    /// Intake against the Calorie Target; nil with no Calorie Target.
    public let calorieBalance: CalorieBalance?

    /// Each Food Entry counts on the local Day of its time in `timeZone`, as Weigh-ins do.
    /// `completeDays` are the Days the user marked complete.
    public init(
        foodEntries: [FoodEntry],
        completeDays: Set<Day> = [],
        calorieTarget: Double? = nil,
        day: Day,
        now: Date,
        timeZone: TimeZone
    ) {
        self.day = day
        entries =
            foodEntries
            .filter { Day(containing: $0.time, in: timeZone) == day }
            .sorted { $0.time > $1.time }
        intake = Intake(entries)
        canBeMarkedComplete = !entries.isEmpty
        isComplete = canBeMarkedComplete && completeDays.contains(day)
        self.calorieTarget = calorieTarget
        calorieBalance = calorieTarget.map { [intake] in
            CalorieBalance(intake: intake.kilocalories, target: $0)
        }
    }

    /// The marked Days that still have a Food Entry: what the store keeps after an entry is
    /// deleted or edited, so a Day whose last entry goes is no longer complete, even if an entry
    /// is added later (spec 016).
    public static func completeDays(
        _ marked: Set<Day>,
        keepingThoseWith foodEntries: [FoodEntry],
        in timeZone: TimeZone
    ) -> Set<Day> {
        marked.intersection(foodEntries.map { Day(containing: $0.time, in: timeZone) })
    }
}
