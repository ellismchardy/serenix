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
                schema: Schema([StoredFoodEntry.self]),
                url: folder.appending(path: "Food.store")
            )
            let container = try ModelContainer(
                for: StoredFoodEntry.self,
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
        }
    }

    /// Deletes the Food Entry in row `id`.
    func delete(_ id: PersistentIdentifier) {
        change { context in context.delete(try Self.stored(id, in: context)) }
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
