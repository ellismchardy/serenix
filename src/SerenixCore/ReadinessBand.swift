import Foundation

/// Which third of 0–100 a Readiness falls in (spec 002, Rings).
public enum ReadinessBand: Equatable, Sendable {
    /// 67–100.
    case ready
    /// 34–66.
    case steady
    /// 0–33.
    case takeItEasy

    /// The lowest Readiness that is Ready, on the 0–100 scale (spec 002, Rings).
    private static let readyFrom = 67
    /// The lowest Readiness that is Steady, on the 0–100 scale (spec 002, Rings).
    private static let steadyFrom = 34

    init(_ readiness: Int) {
        switch readiness {
        case Self.readyFrom...: self = .ready
        case Self.steadyFrom...: self = .steady
        default: self = .takeItEasy
        }
    }

    /// The word under the Readiness ring.
    public var word: String {
        switch self {
        case .ready: "Ready"
        case .steady: "Steady"
        case .takeItEasy: "Take it easy"
        }
    }
}
