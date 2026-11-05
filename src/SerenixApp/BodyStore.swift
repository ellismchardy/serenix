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

/// What the user enters on the Body tab, on the phone only and kept forever (ADR 0008). It lives
/// in its own store file, apart from History Records and Nights, so a build that doesn't know
/// the Body models never opens it and so can't drop its tables. Body data is never written to
/// the Sync Log, `os.Logger` or bug reports.
/// One stored Weigh-in with the ID of its row, so editing or deleting it touches that row only,
/// even when another has the same time and weight.
struct WeighInRow: Identifiable, Equatable {
    let id: PersistentIdentifier
    let weighIn: WeighIn
}

@MainActor
final class BodyStore: ObservableObject {
    /// Every stored Weigh-in with its row ID, newest first.
    @Published private(set) var rows: [WeighInRow] = []
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
                schema: Schema([StoredWeighIn.self]),
                url: folder.appending(path: "Body.store")
            )
            let container = try ModelContainer(
                for: StoredWeighIn.self,
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
