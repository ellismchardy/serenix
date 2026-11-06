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

    init() {}
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
    /// The Calorie Target, kcal a Day; nil when not set.
    @Published private(set) var calorieTarget: Double?
    /// Why the last open or save failed, shown to the user; nil when all is well.
    @Published var failure: String?
    private let context: ModelContext?

    /// Every stored Food Entry.
    var entries: [FoodEntry] { rows.map(\.entry) }

    init() {
        do {
            let folder = URL.applicationSupportDirectory
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(
                "Food",
                schema: Schema([
                    StoredFoodEntry.self, StoredCompleteDay.self, StoredFoodTargets.self,
                ]),
                url: folder.appending(path: "Food.store")
            )
            let container = try ModelContainer(
                for: StoredFoodEntry.self,
                StoredCompleteDay.self,
                StoredFoodTargets.self,
                configurations: configuration
            )
            context = ModelContext(container)
        } catch {
            context = nil
            failure = "Your Food Entries couldn't be opened: \(error.localizedDescription)"
        }
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

    /// Sets the Calorie Target, or clears it with nil. A refused one keeps nothing and tells the
    /// user.
    func setCalorieTarget(_ kilocalories: Double?) {
        change { context in
            if let kilocalories, let refusal = CalorieTarget.refusal(kilocalories) {
                throw FoodStoreError(refusal.message)
            }
            try Self.targets(in: context).calorieTarget = kilocalories
        }
    }

    /// The one targets row, made when first needed.
    private static func targets(in context: ModelContext) throws -> StoredFoodTargets {
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
        if let refusal = entry.refusal(now: Date()) { throw FoodStoreError(refusal.message) }
    }

    private static func stored(
        _ id: PersistentIdentifier,
        in context: ModelContext
    ) throws -> StoredFoodEntry {
        guard let stored = context.model(for: id) as? StoredFoodEntry, !stored.isDeleted else {
            throw FoodStoreError("That Food Entry is no longer stored.")
        }
        return stored
    }

    /// Makes a change and saves it; on any failure nothing changes and the user is told.
    private func change(_ edit: (ModelContext) throws -> Void) {
        guard let context else {
            failure = "Your Food Entries couldn't be opened, so the change wasn't saved."
            return
        }
        defer { reload() }
        do {
            try edit(context)
            try context.save()
        } catch {
            context.rollback()
            failure = "The change wasn't saved: \(error.localizedDescription)"
        }
    }

    private func reload() {
        guard let context else { return }
        do {
            rows = try context.fetch(
                FetchDescriptor<StoredFoodEntry>(sortBy: [SortDescriptor(\.time, order: .reverse)])
            ).map { FoodEntryRow(id: $0.persistentModelID, entry: $0.entry) }
            completeDays = Set(try context.fetch(FetchDescriptor<StoredCompleteDay>()).map(\.day))
            calorieTarget = try context.fetch(FetchDescriptor<StoredFoodTargets>()).first?
                .calorieTarget
        } catch {
            failure = "Your Food Entries couldn't be read: \(error.localizedDescription)"
        }
    }
}

/// A food store failure, with the message shown to the user.
private struct FoodStoreError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
