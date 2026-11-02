import Foundation

/// The Readiness popup (spec 002, Popups): Readiness with HRV and Resting HR against their
/// Baselines and Sleep Score, or instead, while Calibrating, why there's no Readiness yet.
public struct ReadinessPopup: Equatable, Sendable {
    /// As on the ring: the number, or "n/4" while Calibrating.
    public let readinessText: String
    public let band: ReadinessBand?
    /// HRV, then Resting HR; none while Calibrating.
    public let rows: [ReadinessPopupRow]
    /// Nil while Calibrating.
    public let sleepScoreText: String?
    /// "Baseline: your last N Nights"; nil while Calibrating.
    public let baselineNote: String?
    /// Why there's no Readiness yet; nil once there's a Baseline.
    public let calibratingText: String?
}

/// One metric in the Readiness popup.
public struct ReadinessPopupRow: Equatable, Sendable {
    public let metric: NightlyMetric
    /// As on the tile.
    public let valueText: String
    /// The Baseline as a whole number with its unit, e.g. "60 ms"; "Calibrating" while it is.
    public let baselineText: String
    /// As on the tile.
    public let differenceText: String

    init(_ tile: MetricTile) {
        metric = tile.metric
        valueText = tile.valueText
        baselineText = tile.baseline.map { formattedValue(of: tile.metric, $0) } ?? "Calibrating"
        differenceText = tile.differenceText
    }
}

/// The Sleep popup (spec 002, Popups).
public struct SleepPopup: Equatable, Sendable {
    public let sleepScoreText: String
    /// Start–end in local time, e.g. "22:30–07:05"; "—" if either is missing.
    public let timeInBedText: String
    /// e.g. "8h 35m"; "—" if missing.
    public let timeInBedDurationText: String
    public let sleepOnsetText: String
    public let finalWakeText: String
    public let timeAsleepText: String
    /// Minutes awake within the Sleep Period: Final Wake − Sleep Onset − Time Asleep, e.g.
    /// "32 min"; "—" if any is missing or it comes out negative.
    public let minutesAwakeText: String

    init(_ night: Night, sleepScoreText: String, timeZone: TimeZone) {
        self.sleepScoreText = sleepScoreText
        let timeInBed = night.timeInBedStart.flatMap { start in
            night.timeInBedEnd.map { (start: start, end: $0) }
        }
        timeInBedText =
            timeInBed.map {
                "\(clockText($0.start, in: timeZone))\u{2013}\(clockText($0.end, in: timeZone))"
            } ?? missingText
        timeInBedDurationText =
            timeInBed.map { durationText($0.end.timeIntervalSince($0.start)) } ?? missingText
        sleepOnsetText = night.sleepOnset.map { clockText($0, in: timeZone) } ?? missingText
        finalWakeText = night.finalWake.map { clockText($0, in: timeZone) } ?? missingText
        let timeAsleep = night.plausibleTimeAsleep
        timeAsleepText = timeAsleep.map(durationText) ?? missingText
        minutesAwakeText =
            if let onset = night.sleepOnset, let wake = night.finalWake, let timeAsleep,
                let minutes = Int(
                    exactly: ((wake.timeIntervalSince(onset) - timeAsleep) / 60).rounded()
                ),
                minutes >= 0
            {
                "\(minutes) min"
            } else {
                missingText
            }
    }
}

/// The Nightly Metric popup (spec 002, Popups).
public struct MetricPopup: Equatable, Sendable {
    public let metric: NightlyMetric
    /// As on the tile.
    public let valueText: String
    /// As on the tile: the difference, or SpO2's level.
    public let differenceText: String
    public let zone: Zone?
    /// The Night shown and up to 13 earlier Nights, oldest first, without missing values.
    public let chart: [MetricPopupPoint]
    /// The 5 most recent of those, newest first.
    public let recent: [MetricPopupEntry]
    /// Nil while Calibrating, and always for SpO2.
    public let baseline: Double?
    /// The In range limits around the Baseline; nil on a side with no limit, and both nil
    /// without a Baseline.
    public let inRangeLow: Double?
    public let inRangeHigh: Double?

    /// How many Nights the chart covers, including the one shown (spec 002, Popups).
    static let chartNights = 14
    /// How many of them are listed (spec 002, Popups).
    static let listedNights = 5

    init(_ tile: MetricTile, for night: Night, among nights: [Night]) {
        metric = tile.metric
        valueText = tile.valueText
        differenceText = tile.differenceText
        zone = tile.zone
        chart = recentNights(Self.chartNights, upTo: night, among: nights).compactMap { night in
            night.value(of: tile.metric).map { MetricPopupPoint(day: night.day, value: $0) }
        }
        recent = chart.reversed().prefix(Self.listedNights).map {
            MetricPopupEntry(
                dayText: $0.day.text,
                valueText: formattedValue(of: tile.metric, $0.value)
            )
        }
        baseline = tile.baseline
        let limits = tile.comparedBaseline.map { Zone.inRangeLimits(tile.metric, baseline: $0) }
        inRangeLow = limits?.low
        inRangeHigh = limits?.high
    }
}

/// One Night's value on the Nightly Metric popup's chart.
public struct MetricPopupPoint: Equatable, Sendable {
    public let day: Day
    public let value: Double
}

/// One Night in the Nightly Metric popup's list.
public struct MetricPopupEntry: Equatable, Sendable {
    /// e.g. "Sun 1 Nov".
    public let dayText: String
    /// As on the tile, e.g. "62 ms".
    public let valueText: String
}

/// The Load popup (spec 006): the Day's Load against typical Load, its time in each HR Zone, hour
/// by hour, its Highest HR and the Max HR used, and on today the Live HR pill.
public struct LoadPopup: Equatable, Sendable {
    /// e.g. "Sun 1 Nov".
    public let dateText: String
    /// As on the ring.
    public let loadText: String
    /// "As of your last sync at 08:12" on today; nil on an earlier Day or before any sync.
    public let lastSyncText: String?
    /// e.g. "Typical: 45 · today +12", or "Typical Load after 4 Days (3 so far)".
    public let typicalText: String
    /// Today only.
    public let showsLiveHR: Bool
    /// Why there are no HR Zones, Highest HR or Max HR used; nil when they're there.
    public let note: String?
    /// HR Zone 1 to 5; none when there's a note.
    public let zoneRows: [LoadPopupZoneRow]
    /// The Day's seconds in each HR Zone, hour by hour from local midnight; none when there's a
    /// note.
    public let hourlyZoneSeconds: [[HRZone: Int]]
    /// e.g. "Highest HR 172 bpm at 18:40"; nil when there's a note.
    public let highestHRText: String?
    /// e.g. "Using Max HR 190 (entered)"; nil when there's a note.
    public let maxHRText: String?

    init(
        _ dayLoad: DayLoad?,
        loadText: String,
        for day: Day,
        isToday: Bool,
        among dayLoads: [DayLoad],
        lastSyncEnded: Date?,
        timeZone: TimeZone
    ) {
        let load = dayLoad?.load
        dateText = day.text
        self.loadText = loadText
        lastSyncText =
            isToday
            ? lastSyncEnded.map { "As of your last sync at \(clockText($0, in: timeZone))" } : nil
        typicalText = Self.typicalText(
            typicalLoad(for: day, among: dayLoads),
            load: load,
            dayWord: isToday ? "today" : "that Day"
        )
        showsLiveHR = isToday
        let heartRate = dayLoad?.heartRate
        note =
            if dayLoad == nil || dayLoad?.missingReason == .noRecords {
                "No heart rate recorded this Day"
            } else if heartRate == nil {
                "Heart rate zones aren't available for this Day"
            } else {
                nil
            }
        let zoneTotal = heartRate.map { $0.zoneSeconds.values.reduce(0, +) } ?? 0
        zoneRows =
            heartRate.map { heartRate in
                HRZone.allCases.map { zone in
                    LoadPopupZoneRow(zone, seconds: heartRate.zoneSeconds[zone] ?? 0, of: zoneTotal)
                }
            } ?? []
        hourlyZoneSeconds = heartRate?.hourlyZoneSeconds ?? []
        highestHRText = heartRate.map { heartRate in
            let highest = heartRate.highestHR.map {
                "\($0.bpm) bpm at \(clockText($0.time, in: timeZone))"
            }
            return "Highest HR \(highest ?? missingText)"
        }
        maxHRText = heartRate.map { heartRate in
            let used = heartRate.maxHRUsed
            let source =
                switch used.source {
                case .entered: "entered"
                case .estimated: "estimated from your age"
                }
            return "Using Max HR \(Int(used.bpm.rounded())) (\(source))"
        }
    }

    /// "Typical: 45 · today +12" ("−" below, "±0" equal), just "Typical: 45" with the Day's Load
    /// missing, or how many Days there are so far while typical Load is calibrating.
    private static func typicalText(_ typical: TypicalLoad, load: Int?, dayWord: String) -> String {
        switch typical {
        case .calibrating(let soFar):
            return "Typical Load after \(TypicalLoad.minimumDays) Days (\(soFar) so far)"
        case .value(let typical):
            guard let load else { return "Typical: \(typical)" }
            let difference = load - typical
            let signed =
                switch difference {
                case 1...: "+\(difference)"
                case 0: "\u{00B1}0"
                default: "\u{2212}\(-difference)"
                }
            return "Typical: \(typical) \u{00B7} \(dayWord) \(signed)"
        }
    }
}

/// One HR Zone in the Load popup.
public struct LoadPopupZoneRow: Equatable, Sendable {
    public let zone: HRZone
    /// e.g. "Zone 1 · 50–60%" (the popup heads these "Heart rate zones", so "Zone" alone is
    /// clear there).
    public let label: String
    /// Whole minutes: "42m" under an hour, "1h 05m" from an hour.
    public let timeText: String
    /// This HR Zone's share of the Day's time in HR Zones, 0 to 1; 0 with none.
    public let share: Double

    init(_ zone: HRZone, seconds: Int, of total: Int) {
        self.zone = zone
        let percent = { (share: Double) in Int((share * 100).rounded()) }
        let edges = zone.shareRange
        label =
            "Zone \(zone.rawValue) \u{00B7} \(percent(edges.lower))\u{2013}\(percent(edges.upper))%"
        let minutes = Int((Double(seconds) / 60).rounded())
        timeText =
            minutes < 60
            ? "\(minutes)m" : "\(minutes / 60)h " + String(format: "%02ldm", minutes % 60)
        share = total > 0 ? Double(seconds) / Double(total) : 0
    }
}
