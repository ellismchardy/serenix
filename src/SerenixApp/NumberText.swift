import Foundation

/// How the food sheets read and show the numbers typed into their fields (spec 016).
enum NumberText {
    /// A stored value as a field shows it, without a needless ".0".
    static func text(_ value: Double) -> String {
        value.formatted(.number.grouping(.never))
    }

    /// A typed number in the phone's locale; nil when blank or unreadable.
    static func number(_ text: String) -> Double? {
        try? Double(text, format: .number)
    }
}
