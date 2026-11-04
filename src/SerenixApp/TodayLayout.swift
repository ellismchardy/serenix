/// How the Today screen lays out the Day shown (spec 012): Rings (spec 002's layout) or Story.
/// Kept on this phone with `@AppStorage(TodayLayout.storageKey)`; Rings until changed.
enum TodayLayout: String, CaseIterable, Identifiable {
    case rings
    case story

    /// The UserDefaults key the choice is kept under.
    static let storageKey = "todayLayout"

    var id: Self { self }

    var label: String {
        switch self {
        case .rings: "Rings"
        case .story: "Story"
        }
    }
}
