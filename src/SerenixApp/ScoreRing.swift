import SerenixCore
import SwiftUI

/// One 0–100 score as a ring (spec 002, Rings, ADR 0005): the arc fills to the score, with the
/// score's text in the middle and its name under the ring. An empty ring when the score is
/// missing.
struct ScoreRing: View {
    /// The Today view's text for the score: the number, or "—" when missing.
    let text: String
    /// The Today view's fill for the score, 0 to 1.
    let fill: Double
    let label: String
    let diameter: CGFloat
    var colour: Color = Theme.accent

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Theme.accentSoft, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: fill)
                    .stroke(colour, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(text)
                    .font(.system(size: diameter * 0.3, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: diameter, height: diameter)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var lineWidth: CGFloat { diameter * 0.08 }
}

extension ReadinessBand {
    /// The band's colour (spec 002): green, amber, red. Missing Readiness has no band and no
    /// colour.
    var colour: Color {
        switch self {
        case .ready: .green
        case .steady: .orange
        case .takeItEasy: .red
        }
    }
}
