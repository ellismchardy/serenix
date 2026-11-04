import SerenixCore
import SwiftUI

/// The Story layout's body under the week strip (spec 012): the Today view's Story as a
/// timeline of steps, each a dot on a line with a time label, a title and a card. Taps go back
/// to the Today screen, which opens the popup as the Rings layout would.
struct StoryBodyView: View {
    let today: TodayView
    let onTap: (StoryTap) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = today.story.noNightMessage {
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
            }
            let steps = today.story.steps
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                StoryStepRow(
                    step: step,
                    dotColour: dotColour(step),
                    isLast: index == steps.count - 1
                ) {
                    card(step)
                }
            }
        }
    }

    private func dotColour(_ step: StoryStep) -> Color {
        switch step.kind {
        case .sleep: Theme.accent
        case .overnight: Theme.accentMiddle
        case .thisMorning: today.readinessBand?.colour ?? .secondary
        case .todaySoFar: .orange
        }
    }

    @ViewBuilder
    private func card(_ step: StoryStep) -> some View {
        switch step.kind {
        case .sleep: tappable(step) { sleepCard }
        case .overnight: overnightCard(step)
        case .thisMorning:
            if let advice = step.advice {
                tappable(step) {
                    Text(advice)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .todaySoFar: tappable(step) { loadCard(step) }
        }
    }

    /// The step's card as a button opening its popup.
    private func tappable<Content: View>(
        _ step: StoryStep,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            if let tap = step.tap { onTap(tap) }
        } label: {
            content().contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The Sleep Score in a small ring, Time Asleep of Sleep Need, and Sleep Efficiency.
    private var sleepCard: some View {
        HStack(spacing: 14) {
            ScoreRing(
                text: today.sleepScoreText,
                fill: today.sleepScoreFill,
                label: "Sleep Score",
                diameter: 64,
                colour: Theme.accent
            )
            if let popup = today.sleepPopup {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(popup.timeAsleepText) of \(popup.sleepNeedText) needed")
                    Text(popup.sleepEfficiencyDetailText)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .themeCard()
    }

    /// One row per Nightly Metric the Night has: name, value and its Zone as a pill.
    private func overnightCard(_ step: StoryStep) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(zip(step.metrics, step.rowTaps)), id: \.0.metric) { tile, tap in
                Button {
                    onTap(tap)
                } label: {
                    HStack {
                        Text(tile.metric.name)
                        Spacer()
                        Text(tile.valueText).bold()
                        zonePill(tile)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .themeCard()
    }

    private func zonePill(_ tile: MetricTile) -> some View {
        let colour = tile.zone?.colour ?? .secondary
        return Text(tile.statusText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(colour)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(colour.opacity(0.15), in: Capsule())
            .frame(minWidth: 84, alignment: .trailing)
    }

    /// The Day's Load as a bar against its typical Load, the typical Load in words, and Resting
    /// HR when the Day has one.
    private func loadCard(_ step: StoryStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full means the Day's typical Load; no bar fill while there's nothing to compare.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.accentSoft)
                    Capsule().fill(.orange)
                        .frame(width: proxy.size.width * (step.loadVsTypical ?? 0))
                }
            }
            .frame(height: 10)
            if let typical = today.loadPopup?.typicalText {
                Text(typical).font(.footnote).foregroundStyle(.secondary)
            }
            if let restingHR = today.restingHRTile {
                Text("\(restingHR.name) \(restingHR.valueText)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .themeCard()
    }
}

/// A dot on the timeline's line, with the step's time label, title and card beside it.
private struct StoryStepRow<Card: View>: View {
    let step: StoryStep
    let dotColour: Color
    let isLast: Bool
    @ViewBuilder let card: () -> Card

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle().fill(dotColour).frame(width: 14, height: 14).padding(.top, 3)
                if !isLast {
                    Rectangle().fill(Theme.accentSoft).frame(width: 2)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(step.timeLabel).font(.footnote).foregroundStyle(.secondary)
                Text(step.title).font(.headline)
                card()
            }
            .padding(.bottom, isLast ? 0 : 22)
        }
    }
}
