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

    /// The top of the 0–100 scale, where Ready ends.
    private static let scaleTop = 100

    /// The bands from lowest to highest, as on the Readiness popup's band scale (spec 012).
    static let lowestFirst: [ReadinessBand] = [.takeItEasy, .steady, .ready]

    /// The band's stretch of the 0–100 scale as 0 to 1, from its cut-offs (spec 012, band
    /// scale), so the scale and the band word can't disagree.
    var stretch: (from: Double, to: Double) {
        let scaleTop = Double(Self.scaleTop)
        return switch self {
        case .takeItEasy: (0, Double(Self.steadyFrom) / scaleTop)
        case .steady: (Double(Self.steadyFrom) / scaleTop, Double(Self.readyFrom) / scaleTop)
        case .ready: (Double(Self.readyFrom) / scaleTop, 1)
        }
    }

    init(_ readiness: Int) {
        switch readiness {
        case Self.readyFrom...: self = .ready
        case Self.steadyFrom...: self = .steady
        default: self = .takeItEasy
        }
    }

    /// The word on the Readiness message card.
    public var word: String {
        switch self {
        case .ready: "Ready"
        case .steady: "Steady"
        case .takeItEasy: "Take it easy"
        }
    }
}
