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
@MainActor
final class BodyStore: ObservableObject {
    /// Every Weigh-in, as stored.
    @Published private(set) var weighIns: [WeighIn] = []
    /// Why the last open or save failed, shown to the user; nil when all is well. Typed-in Body
    /// data can't be rebuilt, so a failure is never swallowed (ADR 0008).
    @Published var failure: String?
    private let context: ModelContext?

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

    /// Saves a Weigh-in. On failure nothing is kept and the user is told.
    func add(_ weighIn: WeighIn) {
        guard let context else {
            failure = "Your Body data couldn't be opened, so the Weigh-in wasn't saved."
            return
        }
        context.insert(StoredWeighIn(weighIn))
        do {
            try context.save()
        } catch {
            context.rollback()
            failure = "The Weigh-in couldn't be saved: \(error.localizedDescription)"
        }
        reload()
    }

    private func reload() {
        guard let context else { return }
        do {
            weighIns = try context.fetch(FetchDescriptor<StoredWeighIn>()).map(\.weighIn)
        } catch {
            failure = "Your Weigh-ins couldn't be read: \(error.localizedDescription)"
        }
    }
}
