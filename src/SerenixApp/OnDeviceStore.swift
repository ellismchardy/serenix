import Foundation
import SwiftData

/// One SwiftData store file on the phone only, for typed-in data that can't be rebuilt (ADR
/// 0008): it opens the file, and makes changes that either save or leave nothing, with the
/// message to show the user when either fails. `BodyStore` and `FoodStore` each own one, with
/// their own models, so a build that doesn't know one file's models never opens it.
@MainActor
final class OnDeviceStore {
    /// The open store; nil when it couldn't be opened.
    let context: ModelContext?
    /// Why it couldn't be opened, for the user; nil when it opened.
    let openFailure: String?
    /// What it holds, as messages name it ("Your Body data").
    private let holds: String

    /// Opens `<name>.store` in Application Support with `models`. `holds` names what it holds in
    /// the messages, e.g. "Your Body data".
    init(name: String, models: [any PersistentModel.Type], holds: String) {
        self.holds = holds
        do {
            let folder = URL.applicationSupportDirectory
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let schema = Schema(models)
            let configuration = ModelConfiguration(
                name,
                schema: schema,
                url: folder.appending(path: "\(name).store")
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            context = ModelContext(container)
            openFailure = nil
        } catch {
            context = nil
            openFailure = "\(holds) couldn't be opened: \(error.localizedDescription)"
        }
    }

    /// Makes `edit` and saves it; on any failure rolls back, so nothing changes. Returns the
    /// message to show the user, or nil when it saved.
    func change(_ edit: (ModelContext) throws -> Void) -> String? {
        guard let context else { return "\(holds) couldn't be opened, so the change wasn't saved." }
        do {
            try edit(context)
            try context.save()
            return nil
        } catch {
            context.rollback()
            return "The change wasn't saved: \(error.localizedDescription)"
        }
    }
}

/// A store failure, with the message shown to the user.
struct OnDeviceStoreError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
