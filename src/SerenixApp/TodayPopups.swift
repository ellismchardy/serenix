import Charts
import SerenixCore
import SwiftUI

/// Which popup is open over the Today screen (spec 002, Popups).
enum TodayPopup: Identifiable, Hashable {
    case readiness
    case sleep
    case metric(NightlyMetric)

    var id: Self { self }
}

/// The open popup's content, drawn from the Today view. Each slides up and closes on a tap
/// outside or a swipe down.
struct TodayPopupView: View {
    let popup: TodayPopup
    let today: TodayView

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch popup {
                case .readiness:
                    if let readiness = today.readinessPopup { ReadinessPopupView(popup: readiness) }
                case .sleep:
                    if let sleep = today.sleepPopup { SleepPopupView(popup: sleep) }
                case .metric(let metric):
                    if let content = today.metricPopup(metric) { MetricPopupView(popup: content) }
                }
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct ReadinessPopupView: View {
    let popup: ReadinessPopup

    var body: some View {
        Text("Readiness").font(.headline)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(popup.readinessText).font(.largeTitle.bold()).monospacedDigit()
            if let band = popup.band {
                Text(band.word).font(.title3.bold()).foregroundStyle(band.colour)
            }
        }
        if let calibrating = popup.calibratingText {
            Text(calibrating).foregroundStyle(.secondary)
        }
        if !popup.rows.isEmpty { rows }
        if let sleepScore = popup.sleepScoreText {
            LabeledContent("Sleep Score", value: sleepScore)
        }
        if let note = popup.baselineNote {
            Text(note).font(.footnote).foregroundStyle(.secondary)
        }
    }

    /// HRV and Resting HR: last night, Baseline and the difference.
    private var rows: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("")
                Text("Night").foregroundStyle(.secondary)
                Text("Baseline").foregroundStyle(.secondary)
                Text("")
            }
            .font(.footnote)
            ForEach(popup.rows, id: \.metric) { row in
                GridRow {
                    Text(row.metric.name)
                    Text(row.valueText).monospacedDigit()
                    Text(row.baselineText).monospacedDigit()
                    Text(row.differenceText).monospacedDigit()
                }
            }
        }
    }
}

private struct SleepPopupView: View {
    let popup: SleepPopup

    var body: some View {
        Text("Sleep").font(.headline)
        LabeledContent("Sleep Score", value: popup.sleepScoreText)
        LabeledContent("Time in Bed") {
            Text("\(popup.timeInBedText) · \(popup.timeInBedDurationText)")
        }
        LabeledContent("Sleep Onset", value: popup.sleepOnsetText)
        LabeledContent("Final Wake", value: popup.finalWakeText)
        LabeledContent("Time Asleep", value: popup.timeAsleepText)
        LabeledContent("Awake in the night", value: popup.minutesAwakeText)
    }
}

private struct MetricPopupView: View {
    let popup: MetricPopup

    var body: some View {
        Text(popup.metric.name).font(.headline)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(popup.valueText).font(.largeTitle.bold()).monospacedDigit()
            Text(popup.differenceText).font(.title3)
        }
        .foregroundStyle(popup.zone?.colour ?? .primary)
        chart.frame(height: 180)
        ForEach(popup.recent, id: \.dayText) { entry in
            LabeledContent(entry.dayText, value: entry.valueText)
        }
    }

    /// The values over the last 14 Nights, with the Baseline and its In range band.
    private var chart: some View {
        Chart {
            if let baseline = popup.baseline, let band = inRangeBand {
                RectangleMark(yStart: .value("Low", band.low), yEnd: .value("High", band.high))
                    .foregroundStyle(.green.opacity(0.15))
                RuleMark(y: .value("Baseline", baseline))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(dash: [4, 4]))
            }
            ForEach(Array(popup.chart.enumerated()), id: \.element.day) { index, point in
                LineMark(x: .value("Night", index), y: .value("Value", point.value))
                PointMark(x: .value("Night", index), y: .value("Value", point.value))
            }
        }
        .chartXAxis(.hidden)
    }

    /// The In range band, with an open side drawn to the edge of the chart's values.
    private var inRangeBand: (low: Double, high: Double)? {
        guard popup.inRangeLow != nil || popup.inRangeHigh != nil else { return nil }
        let values = popup.chart.map(\.value) + [popup.baseline].compactMap { $0 }
        guard let lowest = values.min(), let highest = values.max() else { return nil }
        // An open side reaches past every value but never crosses the other limit, so the band
        // can't flip onto the out-of-range part.
        let low = popup.inRangeLow ?? min(lowest, popup.inRangeHigh ?? lowest)
        let high = popup.inRangeHigh ?? max(highest, popup.inRangeLow ?? highest)
        return (low, high)
    }
}
