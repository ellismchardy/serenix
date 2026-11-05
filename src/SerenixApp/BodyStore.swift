import Foundation
import SerenixCore
import SwiftData

/// One stored Weigh-in (spec 014), in kg and UTC.
@Model
final class StoredWeighIn {
    var time: Date
    var kilograms: Double

    init(_ weighIn: WeighIn) {
        time = weighIn.time
        kilograms = weighIn.kilograms
    }

    var weighIn: WeighIn { WeighIn(time: time, kilograms: kilograms) }
}

/// One stored Weight Goal (spec 014), current or ended. The goal itself is kept as JSON; any
/// field `WeightGoal` gains later must be optional so goals stored before it still decode. It
/// ends with a time and why.
@Model
final class StoredWeightGoal {
    var goalJSON: Data
    var endedAt: Date? = nil
    /// A `GoalEnd` raw value; nil while current.
    var endReason: String? = nil

    init(_ goal: WeightGoal) throws {
        goalJSON = try JSONEncoder().encode(goal)
    }

    func goal() throws -> WeightGoal { try JSONDecoder().decode(WeightGoal.self, from: goalJSON) }
}

/// One stored Weigh-in with the ID of its row, so editing or deleting it touches that row only,
/// even when another has the same time and weight.
struct WeighInRow: Identifiable, Equatable {
    let id: PersistentIdentifier
    let weighIn: WeighIn
}

/// What the user enters on the Body tab, on the phone only and kept forever (ADR 0008). It lives
/// in its own store file, apart from History Records and Nights, so a build that doesn't know
/// the Body models never opens it and so can't drop its tables. Body data is never written to
/// the Sync Log, `os.Logger` or bug reports.
@MainActor
final class BodyStore: ObservableObject {
    /// Every stored Weigh-in with its row ID, newest first.
    @Published private(set) var rows: [WeighInRow] = []
    /// The Weight Goal not yet ended; nil when there is none.
    @Published private(set) var currentGoal: WeightGoal?
    /// Why the last open or save failed, shown to the user; nil when all is well. Typed-in Body
    /// data can't be rebuilt, so a failure is never swallowed (ADR 0008).
    @Published var failure: String?
    private let context: ModelContext?

    /// Every stored Weigh-in.
    var weighIns: [WeighIn] { rows.map(\.weighIn) }

    init() {
        do {
            let folder = URL.applicationSupportDirectory
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(
                "Body",
                schema: Schema([StoredWeighIn.self, StoredWeightGoal.self]),
                url: folder.appending(path: "Body.store")
            )
            let container = try ModelContainer(
                for: StoredWeighIn.self,
                StoredWeightGoal.self,
                configurations: configuration
            )
            context = ModelContext(container)
        } catch {
            context = nil
            failure = "Your Body data couldn't be opened: \(error.localizedDescription)"
        }
        reload()
    }

    /// Saves a Weigh-in. A refused one, or a failed save, keeps nothing and tells the user.
    func add(_ weighIn: WeighIn) {
        change { context in
            try Self.check(weighIn)
            context.insert(StoredWeighIn(weighIn))
        }
    }

    /// Deletes the Weigh-in in row `id`.
    func delete(_ id: PersistentIdentifier) {
        change { context in context.delete(try Self.stored(id, in: context)) }
    }

    /// Replaces the Weigh-in in row `id` with its edited version.
    func replace(_ id: PersistentIdentifier, with new: WeighIn) {
        change { context in
            try Self.check(new)
            let stored = try Self.stored(id, in: context)
            stored.time = new.time
            stored.kilograms = new.kilograms
        }
    }

    /// Saves `goal`. In the same direction as the current Weight Goal it edits that one in place;
    /// otherwise the current one ends now, kept (ADR 0008), and `goal` starts (spec 014).
    func setGoal(_ goal: WeightGoal) {
        change { context in
            if let current = try Self.currentGoal(in: context),
                try goal.edits(current.goal())
            {
                // An edit restarts Ease the goal's 7-Day count (spec 014).
                let edited = goal.changed(on: Day(containing: Date(), in: .current))
                current.goalJSON = try JSONEncoder().encode(edited)
            } else {
                try Self.endCurrentGoal(in: context, reason: .changed)
                context.insert(try StoredWeightGoal(goal))
            }
        }
    }

    /// Ends the current Weight Goal, keeping it.
    func removeGoal() {
        change { context in try Self.endCurrentGoal(in: context, reason: .removed) }
    }

    private static func currentGoal(in context: ModelContext) throws -> StoredWeightGoal? {
        try context.fetch(
            FetchDescriptor<StoredWeightGoal>(predicate: #Predicate { $0.endedAt == nil })
        ).first
    }

    private static func endCurrentGoal(in context: ModelContext, reason: GoalEnd) throws {
        if let current = try currentGoal(in: context) {
            current.endedAt = Date()
            current.endReason = reason.rawValue
        }
    }

    /// Makes a change and saves it; on any failure nothing changes and the user is told.
    private func change(_ edit: (ModelContext) throws -> Void) {
        guard let context else {
            failure = "Your Body data couldn't be opened, so the change wasn't saved."
            return
        }
        do {
            try edit(context)
            try context.save()
        } catch {
            context.rollback()
            failure = "The change wasn't saved: \(error.localizedDescription)"
        }
        reload()
    }

    private static func check(_ weighIn: WeighIn) throws {
        if let refusal = weighIn.refusal(now: Date()) { throw BodyStoreError(refusal.message) }
    }

    private static func stored(
        _ id: PersistentIdentifier,
        in context: ModelContext
    ) throws -> StoredWeighIn {
        guard let stored = context.model(for: id) as? StoredWeighIn, !stored.isDeleted else {
            throw BodyStoreError("That Weigh-in is no longer stored.")
        }
        return stored
    }

    private func reload() {
        guard let context else { return }
        // Goals and Weigh-ins load apart, so one that can't be read never hides the other.
        do {
            currentGoal = try Self.currentGoal(in: context)?.goal()
        } catch {
            failure = "Your Weight Goal couldn't be read: \(error.localizedDescription)"
        }
        do {
            rows = try context.fetch(
                FetchDescriptor<StoredWeighIn>(sortBy: [SortDescriptor(\.time, order: .reverse)])
            ).map { WeighInRow(id: $0.persistentModelID, weighIn: $0.weighIn) }
        } catch {
            failure = "Your Weigh-ins couldn't be read: \(error.localizedDescription)"
        }
    }
}

/// A Body store failure, with the message shown to the user.
private struct BodyStoreError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
