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
                // An edit to what the goal aims for restarts Ease the goal's count (spec 014).
                let edited = try goal.saved(
                    over: current.goal(),
                    on: Day(containing: Date(), in: .current)
                )
                current.goalJSON = try JSONEncoder().encode(edited)
            } else {
                try Self.endCurrentGoal(in: context, reason: .changed)
                context.insert(try StoredWeightGoal(goal))
            }
        }
    }

    /// Ends the current Weight Goal, keeping it.
    func removeGoal() { endGoal(.removed) }

    /// Ends the current Weight Goal for `reason`, keeping it (ADR 0008). Returns whether it saved.
    @discardableResult
    func endGoal(_ reason: GoalEnd) -> Bool {
        change { context in try Self.endCurrentGoal(in: context, reason: reason) }
    }

    /// Undo after Reached: reopens the Weight Goal that ended last as Reached, marked reopened on
    /// `day` so it isn't Reached again at once (spec 014). Refused while another goal is current.
    func reopenReachedGoal(on day: Day) {
        change { context in
            guard try Self.currentGoal(in: context) == nil else {
                throw BodyStoreError("Another Weight Goal is current, so this one can't reopen.")
            }
            let reached = GoalEnd.reached.rawValue
            var descriptor = FetchDescriptor<StoredWeightGoal>(
                predicate: #Predicate { $0.endReason == reached },
                sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            guard let stored = try context.fetch(descriptor).first else {
                throw BodyStoreError("There's no reached Weight Goal to reopen.")
            }
            stored.goalJSON = try JSONEncoder().encode(stored.goal().reopened(on: day))
            stored.endedAt = nil
            stored.endReason = nil
        }
    }

    /// All Body data, for the backup file (spec 014, Backup and import). Throws, with a message
    /// for the user, when it can't be read.
    func allData() throws -> BodyData {
        guard let context else { throw BodyStoreError("Your Body data couldn't be opened.") }
        do {
            let goals = try context.fetch(FetchDescriptor<StoredWeightGoal>()).map {
                stored in
                var endReason: GoalEnd?
                if let raw = stored.endReason {
                    // An end this build doesn't know is never dropped from the backup.
                    guard let known = GoalEnd(rawValue: raw) else {
                        throw BodyStoreError("A Weight Goal ended for an unknown reason.")
                    }
                    endReason = known
                }
                return GoalRecord(
                    goal: try stored.goal(),
                    endedAt: stored.endedAt,
                    endReason: endReason
                )
            }
            // Fetched afresh, not from `rows`, so a failed read throws rather than exporting or
            // comparing against an incomplete list.
            let weighIns = try context.fetch(FetchDescriptor<StoredWeighIn>()).map(\.weighIn)
            return BodyData(weighIns: weighIns, goals: goals)
        } catch {
            throw BodyStoreError("Your Body data couldn't be read: \(error.localizedDescription)")
        }
    }

    /// Adds what an import found new, all or nothing: one refused Weigh-in or a failed save
    /// keeps none of it and tells the user.
    func add(_ found: BodyImport) {
        change { context in
            for weighIn in found.weighInsToAdd {
                try Self.check(weighIn)
                context.insert(StoredWeighIn(weighIn))
            }
            for record in found.goalsToAdd {
                let stored = try StoredWeightGoal(record.goal)
                stored.endedAt = record.endedAt
                stored.endReason = record.endReason?.rawValue
                context.insert(stored)
            }
        }
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
    /// Returns whether it saved.
    @discardableResult
    private func change(_ edit: (ModelContext) throws -> Void) -> Bool {
        guard let context else {
            failure = "Your Body data couldn't be opened, so the change wasn't saved."
            return false
        }
        defer { reload() }
        do {
            try edit(context)
            try context.save()
            return true
        } catch {
            context.rollback()
            failure = "The change wasn't saved: \(error.localizedDescription)"
            return false
        }
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
