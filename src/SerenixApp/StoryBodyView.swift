import SerenixCore
import SwiftUI

/// The Story layout's body under the Readiness headline (spec 013, drawn in the Poster look of
/// spec 018): the Today view's Story as a timeline of steps, each a square dot on a hairline with
/// a time label, a title and its rows. Taps go back to the Today screen, which opens the popup
/// as the Rings layout would.
struct StoryBodyView: View {
    let today: TodayView
    let onTap: (StoryTap) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = today.story.noNightMessage {
                Text(message)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Poster.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 24)
            }
            let steps = today.story.steps
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                StoryStepRow(
                    step: step,
                    dotColour: dotColour(step),
                    isLast: index == steps.count - 1,
                    // The title opens the step's popup too, so This morning still opens
                    // Readiness while Calibrating, when it has no rows.
                    onTitleTap: step.tap.map { tap in { onTap(tap) } }
                ) {
                    content(step)
                }
            }
        }
    }

    /// Ink for the Night's steps, the band's colour for This morning, red for the Day's Load.
    private func dotColour(_ step: StoryStep) -> Color {
        switch step.kind {
        case .sleep, .overnight: Poster.ink
        case .thisMorning: today.readinessBand?.colour ?? Poster.waiting
        case .todaySoFar: Poster.red
        }
    }

    @ViewBuilder
    private func content(_ step: StoryStep) -> some View {
        switch step.kind {
        case .sleep: tappable(step) { sleepRows }
        case .overnight: overnightRows(step)
        case .thisMorning:
            if let advice = step.advice {
                tappable(step) {
                    Text(advice)
                        .font(.subheadline)
                        .foregroundStyle(Poster.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .todaySoFar:
            tappable(step) { loadRows(step) }
                .accessibilityHint(
                    today.loadOpensProfileMenu ? "Opens your profile" : "Shows your Load"
                )
        }
    }

    /// The step's rows as a button opening its popup.
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

    /// The Sleep Score as a large number named under it, then Time Asleep of Sleep Need and Sleep
    /// Efficiency.
    private var sleepRows: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(today.sleepScoreText)
                    .font(Poster.headlineFont(size: 40))
                    // -0.04 em, as the prototype's 40 pt figures.
                    .tracking(-1.6)
                    .foregroundStyle(Poster.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("SLEEP SCORE").font(Poster.labelFont).foregroundStyle(Poster.secondary)
            }
            .accessibilityElement(children: .combine)
            if let popup = today.sleepPopup {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(popup.timeAsleepText) of \(popup.sleepNeedText) needed")
                    Text(popup.sleepEfficiencyDetailText)
                }
                .font(.footnote)
                .foregroundStyle(Poster.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    /// One hairline row per Nightly Metric the Night has: name, value and its Zone as a tag.
    private func overnightRows(_ step: StoryStep) -> some View {
        VStack(spacing: 9) {
            ForEach(Array(zip(step.metrics, step.rowTaps)), id: \.0.metric) { tile, tap in
                Button {
                    onTap(tap)
                } label: {
                    RuledRow {
                        HStack(spacing: 12) {
                            Text(tile.metric.name).foregroundStyle(Poster.ink)
                            Spacer(minLength: 8)
                            Text(tile.valueText).bold().foregroundStyle(Poster.ink)
                            zoneTag(tile)
                        }
                        .font(.subheadline)
                        .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The Zone's status as a solid tag; without a Zone, the status in secondary type.
    @ViewBuilder
    private func zoneTag(_ tile: MetricTile) -> some View {
        Group {
            if let zone = tile.zone {
                PosterTag(text: tile.statusText, colour: zone.colour)
            } else {
                Text(tile.statusText).font(.footnote).foregroundStyle(Poster.secondary)
            }
        }
        // So the values line up whatever the tag's width.
        .frame(minWidth: 84, alignment: .trailing)
    }

    /// The Day's Load as a red bar against its typical Load, the typical Load in words, and
    /// Resting HR when the Day has one.
    private func loadRows(_ step: StoryStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full means the Day's typical Load; no fill while there's nothing to compare.
            PosterBar(fill: step.loadVsTypical ?? 0, height: 10)
            if let typical = today.loadPopup?.typicalText {
                Text(typical).font(.footnote).foregroundStyle(Poster.secondary)
            }
            if let restingHR = today.restingHRTile {
                Text("\(restingHR.name) \(restingHR.valueText)")
                    .font(.footnote)
                    .foregroundStyle(Poster.secondary)
            }
        }
    }
}

/// A square dot on the timeline's hairline, with the step's time label, title and rows beside it,
/// under a heavy rule like a section.
private struct StoryStepRow<Content: View>: View {
    let step: StoryStep
    let dotColour: Color
    let isLast: Bool
    /// Opens the step's popup from its title; nil for Overnight, whose rows are tapped instead.
    let onTitleTap: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                // Level with the time label, under the step's rule.
                Rectangle().fill(dotColour).frame(width: 12, height: 12).padding(.top, 11)
                if !isLast {
                    Rectangle().fill(Poster.hairline).frame(width: Poster.rowRule)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                PosterRule()
                Text(step.timeLabel.uppercased())
                    .font(Poster.labelFont)
                    .foregroundStyle(Poster.secondary)
                if let onTitleTap {
                    Button(action: onTitleTap) {
                        title
                    }
                    .buttonStyle(.plain)
                } else {
                    title
                }
                content()
            }
            .padding(.bottom, isLast ? 0 : 22)
        }
    }

    private var title: some View {
        Text(step.title).font(.headline.weight(.bold)).foregroundStyle(Poster.ink)
    }
}
