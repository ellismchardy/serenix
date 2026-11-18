import Foundation

// How the harness's Markdown reports write their numbers (spec 019), shared so every report
// reads the same.

/// A rate or κ to 3 decimals; "—" when missing.
func rate(_ value: Double?) -> String {
    value.map { String(format: "%.3f", $0) } ?? "—"
}

/// Minutes to 1 decimal; "—" when missing.
func minutes(_ value: Double?) -> String {
    value.map { String(format: "%.1f", $0) } ?? "—"
}

/// A whole percent, rounded down so a share under 90% never shows as "90%" (the tiny nudge
/// absorbs binary rounding, e.g. 0.89 × 100 = 88.99999…); "—" when missing.
func percent(_ share: Double?) -> String {
    share.map { "\(Int(($0 * 100 + 1e-9).rounded(.down)))%" } ?? "—"
}

/// Degrees, as briefly as they were given (2°, 2.5°).
func degrees(_ value: Double) -> String {
    String(format: "%g°", value)
}

/// Text for a Markdown table cell: a `|` would end the cell.
func cell(_ text: String) -> String {
    text.replacingOccurrences(of: "|", with: "\\|")
}
