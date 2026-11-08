import Foundation
import SerenixCore
import SwiftData

/// One stored Food Entry (spec 016), in kcal, grams and UTC.
@Model
final class StoredFoodEntry {
    var time: Date
    var kilocalories: Double
    var protein: Double?
    var fat: Double?
    var carbs: Double?
    var name: String?

    init(_ entry: FoodEntry) {
        time = entry.time
        kilocalories = entry.kilocalories
        protein = entry.protein
        fat = entry.fat
        carbs = entry.carbs
        name = entry.name
    }

    var entry: FoodEntry {
        FoodEntry(
            time: time,
            kilocalories: kilocalories,
            protein: protein,
            fat: fat,
            carbs: carbs,
            name: name
        )
    }
}

/// One Day the user marked complete (spec 016), by its local calendar date.
@Model
final class StoredCompleteDay {
    var year: Int
    var month: Int
    var dayOfMonth: Int

    init(_ day: Day) {
        year = day.year
        month = day.month
        dayOfMonth = day.dayOfMonth
    }

    var day: Day { Day(year: year, month: month, day: dayOfMonth) }
}

/// The user's food targets (spec 016): one row at most. Fields added later must be optional so
/// a stored row still loads.
@Model
final class StoredFoodTargets {
    /// kcal a Day; nil when not set.
    var calorieTarget: Double?
    /// Protein the user set in place of the suggestion, g a Day; nil uses the suggestion.
    var proteinOverride: Double?
    /// Fat the user set in place of the suggestion, g a Day; nil uses the suggestion.
    var fatOverride: Double?

    init() {}

    /// The stored targets as one value.
    var targets: FoodTargets {
        get {
            FoodTargets(
                calorieTarget: calorieTarget,
                proteinOverride: proteinOverride,
                fatOverride: fatOverride
            )
        }
        set {
            calorieTarget = newValue.calorieTarget
            proteinOverride = newValue.proteinOverride
            fatOverride = newValue.fatOverride
        }
    }
}

/// One stored Food Entry with the ID of its row, so editing or deleting it touches that row only.
struct FoodEntryRow: Identifiable, Equatable {
    let id: PersistentIdentifier
    let entry: FoodEntry
}

/// The user's Food Entries (spec 016): Body data, on the phone only and kept forever (ADR 0008). It
/// has its own store file, `Food.store`, apart from `Body.store`: builds that know Weigh-ins but
/// not food open `Body.store`, and opening a store strips models a build doesn't know. Never
/// written to the Sync Log, `os.Logger` or bug reports.
@MainActor
final class FoodStore: ObservableObject {
    /// Every stored Food Entry with its row ID, newest first.
    @Published private(set) var rows: [FoodEntryRow] = []
    /// The Days marked complete.
    @Published private(set) var completeDays: Set<Day> = []
    /// The Calorie Target and the protein and fat overrides; empty when none are set.
    @Published private(set) var targets = FoodTargets()
    /// Why the last open or save failed, shown to the user; nil when all is well.
    @Published var failure: String?
    /// The store file this one's data lives in.
    private let storage: OnDeviceStore
    private var context: ModelContext? { storage.context }

    init() {
        storage = OnDeviceStore(
            name: "Food",
            models: [StoredFoodEntry.self, StoredCompleteDay.self, StoredFoodTargets.self],
            holds: "Your Food Entries"
        )
        failure = storage.openFailure
        reload()
    }

    /// Saves a Food Entry. A refused one, or a failed save, keeps nothing and tells the user.
    func add(_ entry: FoodEntry) {
        change { context in
            try Self.check(entry)
            context.insert(StoredFoodEntry(entry))
        }
    }

    /// Replaces the Food Entry in row `id` with its edited version.
    func replace(_ id: PersistentIdentifier, with new: FoodEntry) {
        change { context in
            try Self.check(new)
            let stored = try Self.stored(id, in: context)
            stored.time = new.time
            stored.kilocalories = new.kilocalories
            stored.protein = new.protein
            stored.fat = new.fat
            stored.carbs = new.carbs
            stored.name = new.name
            try Self.keepCompleteDaysWithEntries(in: context)
        }
    }

    /// Deletes the Food Entry in row `id`. A Complete Day whose last entry this was is no longer
    /// complete (spec 016).
    func delete(_ id: PersistentIdentifier) {
        change { context in
            context.delete(try Self.stored(id, in: context))
            try Self.keepCompleteDaysWithEntries(in: context)
        }
    }

    /// Marks `day` complete, or not. Only a Day with a Food Entry can be marked (spec 016): the
    /// Food screen offers the toggle only then, and `FoodView.isComplete` needs an entry anyway.
    func setComplete(_ complete: Bool, on day: Day) {
        change { context in
            let marked = try context.fetch(FetchDescriptor<StoredCompleteDay>())
                .filter { $0.day == day }
            if complete {
                if marked.isEmpty { context.insert(StoredCompleteDay(day)) }
            } else {
                for day in marked { context.delete(day) }
            }
        }
    }

    /// Every stored Food Entry, Complete Day and food target, fetched afresh in one go, so a
    /// failed read throws rather than exporting or comparing against stale data.
    func storedFoodData() throws -> (
        entries: [FoodEntry], completeDays: Set<Day>, targets: FoodTargets
    ) {
        guard let context else { throw OnDeviceStoreError("Your Food Entries couldn't be opened.") }
        return (
            try context.fetch(FetchDescriptor<StoredFoodEntry>()).map(\.entry),
            Set(try context.fetch(FetchDescriptor<StoredCompleteDay>()).map(\.day)),
            try context.fetch(FetchDescriptor<StoredFoodTargets>()).first?.targets ?? FoodTargets()
        )
    }

    /// Adds the food an import found new, all or nothing: one refused Food Entry or a failed
    /// save keeps none of it and tells the user (spec 016, Backup). Returns whether it saved.
    @discardableResult
    func add(_ found: BodyImport) -> Bool {
        change { context in
            for entry in found.foodEntriesToAdd {
                try Self.check(entry)
                context.insert(StoredFoodEntry(entry))
            }
            for day in found.completeDaysToAdd { context.insert(StoredCompleteDay(day)) }
            if let targets = found.foodTargetsToSet {
                try Self.storedTargets(in: context).targets = targets
            }
        }
    }

    /// Saves `targets` (a nil field clears it), checked by the core against `suggested`, the
    /// suggestions at that Calorie Target. A refused save keeps nothing and tells the user.
    func setTargets(_ targets: FoodTargets, suggested: MacroTargets?) {
        change { context in
            if let calorieTarget = targets.calorieTarget,
                let refused = CalorieTarget.refusal(calorieTarget)
            {
                throw OnDeviceStoreError(refused.message)
            }
            if let refused = MacroTargets.overrideRefusal(
                proteinOverride: targets.proteinOverride,
                fatOverride: targets.fatOverride,
                calorieTarget: targets.calorieTarget,
                suggested: suggested
            ) {
                throw OnDeviceStoreError(refused.message)
            }
            try Self.storedTargets(in: context).targets = targets
        }
    }

    /// The one targets row, made when first needed.
    private static func storedTargets(in context: ModelContext) throws -> StoredFoodTargets {
        if let stored = try context.fetch(FetchDescriptor<StoredFoodTargets>()).first {
            return stored
        }
        let new = StoredFoodTargets()
        context.insert(new)
        return new
    }

    /// Unmarks every Complete Day left with no Food Entry, as the Food view decides.
    private static func keepCompleteDaysWithEntries(in context: ModelContext) throws {
        // A just-deleted entry can still be fetched until the save, so it's skipped here.
        let entries = try context.fetch(FetchDescriptor<StoredFoodEntry>())
            .filter { !$0.isDeleted }
            .map(\.entry)
        let stored = try context.fetch(FetchDescriptor<StoredCompleteDay>())
        let kept = FoodView.completeDays(
            Set(stored.map(\.day)),
            keepingThoseWith: entries,
            in: .current
        )
        for marked in stored where !kept.contains(marked.day) { context.delete(marked) }
    }

    private static func check(_ entry: FoodEntry) throws {
        if let refusal = entry.refusal(now: Date()) { throw OnDeviceStoreError(refusal.message) }
    }

    private static func stored(
        _ id: PersistentIdentifier,
        in context: ModelContext
    ) throws -> StoredFoodEntry {
        guard let stored = context.model(for: id) as? StoredFoodEntry, !stored.isDeleted else {
            throw OnDeviceStoreError("That Food Entry is no longer stored.")
        }
        return stored
    }

    /// Makes a change and saves it; on any failure nothing changes and the user is told.
    /// Returns whether it saved.
    @discardableResult
    private func change(_ edit: (ModelContext) throws -> Void) -> Bool {
        defer { reload() }
        guard let message = storage.change(edit) else { return true }
        failure = message
        return false
    }

    private func reload() {
        guard let context else { return }
        do {
            rows = try context.fetch(
                FetchDescriptor<StoredFoodEntry>(sortBy: [SortDescriptor(\.time, order: .reverse)])
            ).map { FoodEntryRow(id: $0.persistentModelID, entry: $0.entry) }
            completeDays = Set(try context.fetch(FetchDescriptor<StoredCompleteDay>()).map(\.day))
            targets =
                try context.fetch(FetchDescriptor<StoredFoodTargets>()).first?.targets
                ?? FoodTargets()
        } catch {
            failure = "Your Food Entries couldn't be read: \(error.localizedDescription)"
        }
    }
}
