import Charts
import SerenixCore
import SwiftUI

/// The Body tab's chart (spec 015, Screen): counted Weigh-ins as dots and Trend Weight as a line
/// that breaks where Trend Weight restarted, over the range chips below it.
struct WeightChartCard: View {
    let view: BodyView
    /// Weights plot in kg, or in total pounds for lb and st.
    let units: WeightUnits
    @State private var range: ChartRange = .threeMonths

    var body: some View {
        if let chart = view.chart(range) {
            VStack(spacing: 10) {
                Chart {
                    ForEach(Array(lines(chart.points).enumerated()), id: \.offset) { index, line in
                        ForEach(line, id: \.day) { point in
                            if chart.showsLine {
                                LineMark(
                                    x: .value("Day", date(point.day)),
                                    y: .value("Trend Weight", units.chartValue(point.trendWeight)),
                                    series: .value("Line", "line \(index)")
                                )
                                .foregroundStyle(Theme.accent)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                            }
                            PointMark(
                                x: .value("Day", date(point.day)),
                                y: .value("Weigh-in", units.chartValue(point.weighIn))
                            )
                            .symbolSize(18)
                            .foregroundStyle(Theme.accentMiddle)
                        }
                    }
                    // Goal Weight as a dashed line, and on "All" the dashed projection to it.
                    if let goalWeight = chart.goalWeight {
                        RuleMark(y: .value("Goal Weight", units.chartValue(goalWeight)))
                            .foregroundStyle(.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    if let projection = chart.projection {
                        ForEach(
                            [
                                (projection.from, projection.fromWeight),
                                (projection.to, projection.toWeight),
                            ],
                            id: \.0
                        ) { day, weight in
                            LineMark(
                                x: .value("Day", date(day)),
                                y: .value("Projection", units.chartValue(weight)),
                                series: .value("Line", "projection")
                            )
                            .foregroundStyle(Theme.accent.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        }
                    }
                }
                // From the first Day's start to the end of the last (today, or the projected Day
                // on "All"), with each dot at its Day's
                // midday, so no dot sits on the edge and one Weigh-in still has room.
                .chartXScale(
                    domain: date(chart.firstDay, hour: 0)...date(chart.lastDay, hour: 24)
                )
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 220)
                HStack(spacing: 6) {
                    ForEach(ChartRange.allCases, id: \.self) { option in
                        Button(option.label) { range = option }
                            .buttonStyle(.bordered)
                            .tint(option == range ? Theme.accent : .secondary)
                            .controlSize(.small)
                            .accessibilityAddTraits(option == range ? .isSelected : [])
                    }
                }
            }
            .padding()
            .themeCard()
        }
    }

    /// The points split where Trend Weight restarted, one array per unbroken line.
    private func lines(_ points: [TrendPoint]) -> [[TrendPoint]] {
        var lines: [[TrendPoint]] = []
        for point in points {
            if point.startsNewLine || lines.isEmpty { lines.append([]) }
            lines[lines.count - 1].append(point)
        }
        return lines
    }

    /// `hour` o'clock on `day` in the phone's time zone, on the Gregorian calendar a Day uses.
    private func date(_ day: Day, hour: Int = 12) -> Date {
        day.date(atMinutes: hour * 60, in: .current)
    }
}
