import Charts
import SerenixCore
import SwiftUI

/// The Body tab's chart (spec 014, Screen): counted Weigh-ins as dots and Trend Weight as a line
/// that breaks where Trend Weight restarted, over the range chips below it.
struct WeightChartCard: View {
    let view: BodyView
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
                                    y: .value("Trend Weight", point.trendWeight),
                                    series: .value("Line", "line \(index)")
                                )
                                .foregroundStyle(Theme.accent)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                            }
                            PointMark(
                                x: .value("Day", date(point.day)),
                                y: .value("Weigh-in", point.weighIn)
                            )
                            .symbolSize(18)
                            .foregroundStyle(Theme.accentMiddle)
                        }
                    }
                }
                // From the first Day's start to the end of today, with each dot at its Day's
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

    /// `hour` o'clock on `day` in the phone's time zone, on the Gregorian calendar whatever the
    /// phone's own calendar is, since a Day's year, month and day are Gregorian. Only a Day far
    /// outside any real date has none; it falls back to the start of time, as `Day` does.
    private func date(_ day: Day, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(
            from: DateComponents(year: day.year, month: day.month, day: day.dayOfMonth, hour: hour)
        ) ?? .distantPast
    }
}
