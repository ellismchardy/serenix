import SerenixCore
import SwiftUI

/// One metric in "vs your Baseline" (spec 002): its name, value and difference, and a bar from
/// the middle showing which way it moved, green the good way and red the other.
struct BaselineComparisonRow: View {
    let comparison: BaselineComparison

    var body: some View {
        HStack(spacing: 12) {
            Text(comparison.metric.name)
                .font(.subheadline)
                .frame(width: 84, alignment: .leading)
            DirectionBar(direction: comparison.direction, colour: barColour)
                .frame(height: 8)
            Text(comparison.valueText)
                .font(.subheadline.bold())
                .monospacedDigit()
            Text(comparison.differenceText)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(barColour)
        }
    }

    private var barColour: Color {
        switch comparison.movedTheGoodWay {
        case true?: .green
        case false?: .red
        case nil: .secondary
        }
    }
}

/// A track with a half-length bar from its middle: right for up, left for down, none without a
/// direction.
private struct DirectionBar: View {
    let direction: BaselineDirection?
    let colour: Color

    var body: some View {
        GeometryReader { geometry in
            let half = geometry.size.width / 2
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                if let direction {
                    Capsule()
                        .fill(colour)
                        .frame(width: half)
                        .offset(x: direction == .up ? half : 0)
                }
            }
        }
    }
}
