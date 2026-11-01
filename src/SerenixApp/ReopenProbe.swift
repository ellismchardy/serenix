import Foundation

// [DEBUG-n7r4] Throwaway probe for the "metrics blank after reopening" diagnosis. Keeps a short
// timestamped event list in UserDefaults so it survives the app being swiped away, and shows it
// on the Debug screen. Never merged.
@MainActor
enum ReopenProbe {
    private static let key = "debugProbe-n7r4"
    private static let maxLines = 300
    private static let launchedAt = Date()

    static var lines: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func log(_ event: String) {
        let time = Date().formatted(
            .dateTime.hour().minute().second().secondFraction(.fractional(3))
        )
        let sinceLaunch = String(format: "%.1f", Date().timeIntervalSince(launchedAt))
        let pid = ProcessInfo.processInfo.processIdentifier
        var all = lines
        all.append("\(time) +\(sinceLaunch)s pid\(pid) \(event)")
        UserDefaults.standard.set(Array(all.suffix(maxLines)), forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
