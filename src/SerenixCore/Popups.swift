import Foundation

/// The Readiness popup (specs 002 and 008): Readiness with each of its inputs against what it's
/// measured against, and Sleep Score, or instead, while Calibrating, why there's no Readiness yet.
public struct ReadinessPopup: Equatable, Sendable {
    /// As on the ring: the number, or "n/4" while Calibrating.
    public let readinessText: String
    public let band: ReadinessBand?
    /// HRV, Sleeping HR, Time Asleep, then Yesterday's Load; none while Calibrating.
    public let rows: [ReadinessPopupRow]
    /// Nil while Calibrating.
    public let sleepScoreText: String?
    /// "Baseline: your last N Nights"; nil while Calibrating.
    public let baselineNote: String?
    /// Why there's no Readiness yet; nil once there's a Baseline.
    public let calibratingText: String?
}

/// One input to Readiness in the Readiness popup (spec 008, Readiness popup).
public struct ReadinessPopupRow: Equatable, Sendable {
    /// e.g. "HRV", "Time Asleep", "Yesterday's Load".
    public let name: String
    /// As on the tile for a Nightly Metric and Time Asleep; the whole Load for Yesterday's Load.
    public let valueText: String
    /// What the value is measured against: the Baseline as a whole number with its unit, e.g. "60
    /// ms" ("Calibrating" while it is), the Night's Sleep Need for Time Asleep ("8h 0m"), or
    /// "Typical 45" ("Calibrating" while typical Load is) for Yesterday's Load.
    public let referenceText: String
    /// As on the tile for a Nightly Metric; hours and minutes for Time Asleep; a signed whole
    /// number ("+40", "−5", "±0") for Yesterday's Load.
    public let differenceText: String

    init(_ tile: MetricTile) {
        name = tile.metric.name
        valueText = tile.valueText
        referenceText = tile.baselineText
        differenceText = tile.differenceText
    }

    /// The Night's Time Asleep against its Sleep Need (spec 009), e.g. "7h 30m", "8h 0m", "−30m".
    init(timeAsleep: TimeInterval?, sleepNeed: TimeInterval) {
        name = "Time Asleep"
        valueText = timeAsleep.map(durationText) ?? missingText
        referenceText = durationText(sleepNeed)
        differenceText =
            timeAsleep.map { Self.differenceText($0 - sleepNeed) }
            ?? missingText
    }

    /// The previous Day's Load against its typical Load (spec 006), e.g. "85", "Typical 45",
    /// "+40", or "85", "Calibrating", "—" while typical Load is calibrating; "—" for a missing
    /// Load.
    init(previousDayLoad load: Int?, typical: TypicalLoad) {
        name = "Yesterday's Load"
        valueText = load.map(String.init) ?? missingText
        switch typical {
        case .value(let typical):
            referenceText = "Typical \(typical)"
            differenceText = load.map { signedText($0 - typical) } ?? missingText
        case .calibrating:
            referenceText = "Calibrating"
            differenceText = missingText
        }
    }

    /// A signed difference in whole minutes: "−30m", "+1h 10m", "±0".
    private static func differenceText(_ seconds: TimeInterval) -> String {
        guard let minutes = Int(exactly: (seconds / 60).rounded()) else { return missingText }
        return signedText(minutes, magnitude: hoursMinutesText(abs(minutes)))
    }
}

/// Whole minutes in hours and minutes for a popup: "35m", "1h 10m", "2h 0m".
func hoursMinutesText(_ minutes: Int) -> String {
    minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
}

/// A signed difference for a popup: "+12", "−5" or "±0" (spec 006 and 008), with `magnitude`
/// as the size shown after the sign (by default the number itself).
func signedText(_ difference: Int, magnitude: String? = nil) -> String {
    let shown = magnitude ?? "\(abs(difference))"
    return switch difference {
    case 1...: "+\(shown)"
    case 0: "\u{00B1}0"
    default: "\u{2212}\(shown)"
    }
}

/// One part of Sleep Score in the Sleep popup, drawn as a small ring (spec 010, Sleep popup).
public struct SleepScorePart: Equatable, Sendable {
    /// "Sleep Sufficiency", "Sleep Efficiency" or "Sleep Consistency".
    public let name: String
    /// The part as a whole number, halves up; "—" when it's left out or Sleep Score is missing.
    public let scoreText: String
    /// The ring's fill, 0 to 1; an empty ring when it's left out.
    public let fill: Double
    /// What it came from, e.g. "6h 0m of 8h 0m", "89% asleep", "35m off your usual", "Needs 3
    /// Nights"; "—" when there's nothing to show.
    public let detailText: String
    /// What the Sleep Score key shows beside the part's name: its score, or why it's left out
    /// ("Needs 3 Nights"); "—" when Sleep Score is missing.
    public var keyText: String { scoreText == missingText ? detailText : scoreText }

    init(name: String, score: Double?, detailText: String = missingText) {
        self.name = name
        let rounded = score.map(halvesUp)
        scoreText = SerenixCore.scoreText(rounded)
        fill = ringFill(rounded)
        self.detailText = detailText
    }

    /// Sleep Score's three parts, in order; each "—" when Sleep Score is missing (spec 010).
    static func parts(of sleepScore: SleepScore?) -> [SleepScorePart] {
        guard let sleepScore else {
            return [sufficiencyName, efficiencyName, consistencyName].map {
                SleepScorePart(name: $0, score: nil)
            }
        }
        let timeAsleep = durationText(sleepScore.timeAsleep)
        let sleepNeed = durationText(sleepScore.sleepNeed)
        let asleep = sleepScore.asleepShare.map { "\(halvesUp($0 * 100))% asleep" }
        let off = sleepScore.minutesOff.map { "\(hoursMinutesText(halvesUp($0))) off your usual" }
        return [
            SleepScorePart(
                name: sufficiencyName,
                score: sleepScore.sufficiency,
                detailText: "\(timeAsleep) of \(sleepNeed)"
            ),
            SleepScorePart(
                name: efficiencyName,
                score: sleepScore.efficiency,
                detailText: asleep ?? missingText
            ),
            SleepScorePart(
                name: consistencyName,
                score: sleepScore.consistency,
                detailText: off ?? "Needs \(SleepScore.fewestConsistencyNights) Nights"
            ),
        ]
    }

    static let sufficiencyName = "Sleep Sufficiency"
    static let efficiencyName = "Sleep Efficiency"
    static let consistencyName = "Sleep Consistency"
}

/// `value` rounded to a whole number with halves up, for scores and their parts, which are never
/// negative (rounding away from zero is then rounding halves up).
func halvesUp(_ value: Double) -> Int {
    Int(value.rounded(.toNearestOrAwayFromZero))
}

/// The Sleep popup (spec 002, Popups).
public struct SleepPopup: Equatable, Sendable {
    public let sleepScoreText: String
    /// Sleep Score's parts as three nested rings, outermost first: Sleep Sufficiency, Sleep
    /// Efficiency, Sleep Consistency (spec 010).
    public let parts: [SleepScorePart]
    /// Beside the "When you slept" heading (spec 010): Sleep Consistency's detail ("35m off your
    /// usual"), or "Usual times need 3 Nights" while it's left out; nil when Sleep Score is
    /// missing.
    public var whenYouSleptNote: String? {
        guard sleepScoreText != missingText else { return nil }
        let consistency = parts.first { $0.name == SleepScorePart.consistencyName }
        return consistency?.scoreText == missingText
            ? "Usual times need \(SleepScore.fewestConsistencyNights) Nights"
            : consistency?.detailText
    }
    /// Sleep Efficiency's detail, in the "When you slept" caption (spec 010).
    public var sleepEfficiencyDetailText: String { detail(of: SleepScorePart.efficiencyName) }
    /// Start–end in local time, e.g. "22:30–07:05"; "—" if either is missing.
    public let timeInBedText: String
    /// e.g. "8h 35m"; "—" if missing.
    public let timeInBedDurationText: String
    public let sleepOnsetText: String
    public let finalWakeText: String
    public let timeAsleepText: String
    /// The Night's Sleep Need (spec 009), e.g. "8h 15m".
    public let sleepNeedText: String
    /// The Sleep Debt behind it, e.g. "1h 0m".
    public let sleepDebtText: String
    /// Which Nights the Sleep Debt is from, e.g. "Your last 5 Nights"; "No earlier Nights" when
    /// none counted.
    public let sleepDebtCaption: String
    /// Minutes awake within the Sleep Period: Final Wake − Sleep Onset − Time Asleep, e.g.
    /// "32 min"; "—" if any is missing or it comes out negative.
    public let minutesAwakeText: String
    /// The "When you slept" timeline (spec 010); nil without Sleep Onset or Final Wake.
    public let timeline: SleepTimeline?
    /// The "How much you slept" bar: Time Asleep against Sleep Need (spec 010).
    public let sleepNeedBar: SleepNeedBar

    init(
        _ night: Night,
        sleepNeed: SleepNeed,
        sleepScore: SleepScore?,
        timeZone: TimeZone
    ) {
        sleepScoreText = scoreText(sleepScore?.score)
        parts = SleepScorePart.parts(of: sleepScore)
        sleepNeedText = durationText(sleepNeed.sleepNeed)
        sleepDebtText = durationText(sleepNeed.sleepDebt)
        sleepDebtCaption =
            switch sleepNeed.nightsCounted {
            case 0: "No earlier Nights"
            case 1: "Your last 1 Night"
            case let count: "Your last \(count) Nights"
            }
        let timeInBed = night.timeInBedStart.flatMap { start in
            night.timeInBedEnd.map { (start: start, end: $0) }
        }
        timeInBedText =
            timeInBed.map {
                "\(clockText($0.start, in: timeZone))\u{2013}\(clockText($0.end, in: timeZone))"
            } ?? missingText
        timeInBedDurationText =
            timeInBed.map { durationText($0.end.timeIntervalSince($0.start)) } ?? missingText
        timeline = SleepTimeline(night, sleepScore: sleepScore, timeZone: timeZone)
        sleepOnsetText = night.sleepOnset.map { clockText($0, in: timeZone) } ?? missingText
        finalWakeText = night.finalWake.map { clockText($0, in: timeZone) } ?? missingText
        let timeAsleep = night.plausibleTimeAsleep
        timeAsleepText = timeAsleep.map(durationText) ?? missingText
        sleepNeedBar = SleepNeedBar(timeAsleep: timeAsleep, sleepNeed: sleepNeed.sleepNeed)
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

    /// The detail of the part named `name`; "—" if there's no such part.
    private func detail(of name: String) -> String {
        parts.first { $0.name == name }?.detailText ?? missingText
    }
}

/// The Sleep popup's "How much you slept" bar (spec 010): Time Asleep against Sleep Need, on a
/// scale of whichever is longer.
public struct SleepNeedBar: Equatable, Sendable {
    /// How far the bar fills, 0 to 1: Time Asleep's share of the scale; 0 with no Time Asleep.
    public let fill: Double
    /// Where the Sleep Need marker sits, 0 to 1: Sleep Need's share of the scale.
    public let marker: Double
    /// e.g. "8h 0m asleep"; "—" with no Time Asleep.
    public let asleepText: String
    /// e.g. "needed 8h 0m".
    public let neededText: String

    /// The bar for `timeAsleep` (nil when there's no plausible Time Asleep) against `sleepNeed`,
    /// both in seconds.
    init(timeAsleep: TimeInterval?, sleepNeed: TimeInterval) {
        let scale = max(timeAsleep ?? 0, sleepNeed)
        fill = scale > 0 ? (timeAsleep ?? 0) / scale : 0
        // With nothing to scale by, the marker sits at the end, as with no Time Asleep.
        marker = scale > 0 ? sleepNeed / scale : 1
        asleepText = timeAsleep.map { "\(durationText($0)) asleep" } ?? missingText
        neededText = "needed \(durationText(sleepNeed))"
    }
}

/// The Nightly Metric popup (spec 011): where the value sits among the Zones, what that means,
/// the last 14 Nights, and what the metric is.
public struct MetricPopup: Equatable, Sendable {
    public let metric: NightlyMetric
    /// As on the tile.
    public let valueText: String
    public let zone: Zone?
    /// "Night of 31 Oct–1 Nov": the evening before the Night's date, then its date (spec 011).
    public let nightText: String
    /// As on the tile: its status word, or SpO2's level.
    public let statusText: String
    /// What the value means for the user, e.g. "−20% against your Baseline: about usual for
    /// you." (spec 011, Verdict). Its last words take `zone`'s colour.
    public let verdictText: String
    /// Where the value sits among the Zones (spec 011, Zone scale); nil with no Zone.
    public let scale: MetricPopupScale?
    /// "Your Zones · Baseline 60 ms", or "Zones" for SpO2 (spec 011, Your Zones); nil with no
    /// rows.
    public let zonesHeading: String?
    /// In range, Watch and Out of range, with their ranges; none without a Baseline to measure
    /// from (Calibrating).
    public let zoneRows: [MetricPopupZoneRow]
    /// The Night shown's date and the 13 dates before it, oldest first (spec 011, Last 14
    /// Nights).
    public let blocks: [MetricPopupBlock]
    /// The Baseline as the tile formats values, e.g. "60 ms"; "Calibrating" while it is; nil for
    /// SpO2, which has none.
    public let baselineText: String?
    /// The lowest value in the blocks, as on the tile; "—" when none has a value.
    public let lowestText: String
    /// The highest value in the blocks, as on the tile; "—" when none has a value.
    public let highestText: String
    /// What the metric is (spec 011, Text); the same every Night.
    public let whatItIsText: String
    /// What tends to move it, in order (spec 011, Text).
    public let whatMovesItTexts: [String]

    /// How many dates the blocks cover, including the Night shown's (spec 011, Last 14 Nights).
    static let blockDays = 14

    init(_ tile: MetricTile, for night: Night, among nights: [Night]) {
        metric = tile.metric
        valueText = tile.valueText
        zone = tile.zone
        nightText = "Night of \(night.day.nightSpanText)"
        statusText = tile.statusText
        verdictText = Self.verdict(tile, value: night.value(of: tile.metric))
        scale = MetricPopupScale(tile, value: night.value(of: tile.metric))
        zoneRows = MetricPopupZoneRow.rows(tile)
        // SpO2 has fixed levels, so no Baseline to name.
        zonesHeading =
            zoneRows.isEmpty
            ? nil
            : !tile.metric.hasBaseline
                ? "Zones"
                : tile.baseline.map {
                    "Your Zones · Baseline \(formattedValue(of: tile.metric, $0))"
                }
        let blockDates = night.day.lastDays(Self.blockDays)
        let blockNights = blockDates.map { day in
            nights.first { $0.day == day && $0.value(of: tile.metric) != nil }
        }
        blocks = zip(blockDates, blockNights).map { day, match in
            let state: MetricPopupBlockState =
                if let match {
                    // Judged against that Night's own Baseline, as its tile was.
                    MetricTile(tile.metric, for: match, among: nights).zone.map { .zone($0) }
                        ?? .noZone
                } else {
                    .noValue
                }
            return MetricPopupBlock(
                weekdayLetter: day.weekdayLetter,
                state: state,
                isNightShown: day == night.day
            )
        }
        baselineText = tile.metric.hasBaseline ? tile.baselineText : nil
        let blockValues = blockNights.compactMap { $0?.value(of: tile.metric) }
        lowestText = blockValues.min().map { formattedValue(of: tile.metric, $0) } ?? missingText
        highestText = blockValues.max().map { formattedValue(of: tile.metric, $0) } ?? missingText
        whatItIsText = MetricTexts.whatItIs(tile.metric)
        whatMovesItTexts = MetricTexts.whatMovesIt(tile.metric)
    }

    /// The verdict sentence (spec 011): the difference and the Zone in words against a
    /// Baseline, SpO2's level, how many earlier Nights a Calibrating Baseline has, or that the
    /// value is missing.
    private static func verdict(_ tile: MetricTile, value: Double?) -> String {
        let name = tile.metric.name
        guard value != nil else { return "No \(name) for this Night." }
        if tile.metric == .spo2 {
            return switch tile.zone {
            case .inRange: "A healthy level."
            case .watch: "A little low."
            case .outOfRange: "Low."
            case nil: missingText
            }
        }
        guard let baseline = tile.comparedBaseline, !baseline.isCalibrating else {
            let soFar = tile.comparedBaseline?.earlierNights ?? 0
            return "Calibrating: Serenix needs \(Baseline.minEarlierNights) earlier Nights with "
                + "\(name) to know what's usual for you (\(soFar) so far)."
        }
        // HRV against a Baseline of 0 or less has no Zone, and so nothing to say.
        guard let zone = tile.zone else { return missingText }
        let meaning =
            switch zone {
            case .inRange: "about usual for you."
            case .watch: "unusual for you."
            case .outOfRange: "well outside your usual."
            }
        return "\(tile.differenceText) against your Baseline: \(meaning)"
    }
}

/// The Nightly Metric popup's Zone scale (spec 011): its segments, and where the value and the
/// Baseline sit on it, 0 (left) to 1 (right).
public struct MetricPopupScale: Equatable, Sendable {
    /// Left to right; the same for every Night of a metric.
    public let segments: [MetricPopupScaleSegment]
    /// Where the value's marker sits, clamped to the ends.
    public let valuePosition: Double
    /// Always 0.5 where there's a Baseline; nil for SpO2.
    public let baselinePosition: Double?
    /// The Baseline tick's label, e.g. "Baseline 62", no unit; nil for SpO2.
    public let baselineLabel: String?

    /// Nil when the value has no Zone: missing or Calibrating.
    init?(_ tile: MetricTile, value: Double?) {
        guard tile.zone != nil, let value,
            let position = Zone.scalePosition(
                tile.metric,
                value: value,
                baseline: tile.comparedBaseline
            )
        else { return nil }
        segments = Zone.scaleSegments(tile.metric)
        valuePosition = position
        baselinePosition = tile.metric.hasBaseline ? 0.5 : nil
        baselineLabel = tile.baseline.map { "Baseline \(numberText(of: tile.metric, $0))" }
    }
}

/// One Zone's stretch of the Zone scale.
public struct MetricPopupScaleSegment: Equatable, Sendable {
    public let zone: Zone
    public let from: Double
    public let to: Double
}

/// One date in the Nightly Metric popup's Last 14 Nights (spec 011).
public struct MetricPopupBlock: Equatable, Sendable {
    /// e.g. "S" for Sunday.
    public let weekdayLetter: String
    public let state: MetricPopupBlockState
    /// True only for the Night shown's date, which is outlined.
    public let isNightShown: Bool
}

/// What a block shows: its Night's Zone, a value with no Zone (Calibrating), or no value (no
/// Night that date, or no value for the metric).
public enum MetricPopupBlockState: Equatable, Sendable {
    case zone(Zone)
    case noZone
    case noValue
}

/// One row of the Nightly Metric popup's Your Zones (spec 011).
public struct MetricPopupZoneRow: Equatable, Sendable {
    public let zone: Zone
    /// The Zone's values, rounded as the metric's are shown, e.g. "41–48 ms, or above 87 ms".
    public let rangeText: String
    /// True for the Night's own Zone; with no value, no row is.
    public let isThisNight: Bool
    /// The Zone in words, "← this Night" after it on the Night's row, e.g. "Watch ← this Night".
    public var nameText: String {
        let name =
            switch zone {
            case .inRange: "In range"
            case .watch: "Watch"
            case .outOfRange: "Out of range"
            }
        return isThisNight ? "\(name) ← this Night" : name
    }

    /// In range, Watch and Out of range for `tile`'s metric (spec 011, Your Zones table); none
    /// when its Zones have no edges.
    static func rows(_ tile: MetricTile) -> [MetricPopupZoneRow] {
        guard let edges = Zone.edges(tile.metric, baseline: tile.comparedBaseline),
            let texts = rangeTexts(tile.metric, edges)
        else { return [] }
        return zip([Zone.inRange, .watch, .outOfRange], texts).map {
            MetricPopupZoneRow(zone: $0, rangeText: $1, isThisNight: $0 == tile.zone)
        }
    }

    /// The In range, Watch and Out of range texts; nil if an edge the metric needs is missing.
    private static func rangeTexts(_ metric: NightlyMetric, _ edges: ZoneEdges) -> [String]? {
        let (inLow, inHigh) = (edges.inRange.low, edges.inRange.high)
        let (watchLow, watchHigh) = (edges.watch.low, edges.watch.high)
        switch metric {
        case .hrv:
            guard let low = inLow.map(wholeText), let high = inHigh.map(wholeText),
                let watch = watchLow.map(wholeText)
            else { return nil }
            return [
                "\(low)–\(high) ms", "\(watch)–\(low) ms, or above \(high) ms", "under \(watch) ms",
            ]
        case .respiratoryRate:
            guard let low = inLow.map(tenthsText), let high = inHigh.map(tenthsText),
                let bottom = watchLow.map(tenthsText), let top = watchHigh.map(tenthsText)
            else { return nil }
            return [
                "\(low)–\(high) br/min", "\(bottom)–\(low) or \(high)–\(top) br/min",
                "under \(bottom) or above \(top) br/min",
            ]
        case .sleepingHR:
            guard let high = inHigh.map(wholeText), let top = watchHigh.map(wholeText) else {
                return nil
            }
            return ["under \(high) bpm", "\(high) to \(top) bpm", "\(top) bpm and up"]
        case .skinTemperature:
            guard let low = inLow.map(tenthsText), let high = inHigh.map(tenthsText),
                let bottom = watchLow.map(tenthsText), let top = watchHigh.map(tenthsText)
            else { return nil }
            return [
                "\(low) to \(high) °C", "\(bottom) to \(low) or \(high) to \(top) °C",
                "under \(bottom) or above \(top) °C",
            ]
        case .spo2:
            guard let from = inLow.map(wholeText), let watch = watchLow.map(wholeText) else {
                return nil
            }
            return ["\(from)% and up", "\(watch)% to \(from)%", "under \(watch)%"]
        }
    }
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
            return "Typical: \(typical) \u{00B7} \(dayWord) \(signedText(load - typical))"
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

/// The Resting HR popup (spec 011): the Day's Resting HR, its last 14 Days, and what it is.
/// Resting HR has no Baseline or Zone, so there's no pill, scale or Your Zones.
public struct RestingHRPopup: Equatable, Sendable {
    /// "Today" on today, else the Day's date, e.g. "Sat 31 Oct".
    public let dateText: String
    /// As on the tile, e.g. "57 bpm", or "—".
    public let valueText: String
    /// On today, that a stiller moment can still lower it; "No Resting HR for this Day." with
    /// none; nil on an earlier Day with Resting HR.
    public let sentenceText: String?
    /// The Day shown and the 13 Days before it, oldest first.
    public let blocks: [RestingHRPopupBlock]
    /// The lowest Resting HR over those Days, in whole bpm; "—" when none has one.
    public let lowestText: String
    /// The highest Resting HR over those Days, in whole bpm; "—" when none has one.
    public let highestText: String
    /// What Resting HR is (spec 011, Text).
    public let whatItIsText: String
    /// What tends to move it, in order (spec 011, Text).
    public let whatMovesItTexts: [String]

    /// `restingHR` is the Day shown's, as its tile has it.
    init(restingHR: Double?, for day: Day, isToday: Bool, among dayLoads: [DayLoad]) {
        dateText = isToday ? "Today" : day.text
        valueText = RestingHRTile.text(restingHR)
        sentenceText =
            if restingHR == nil {
                "No Resting HR for this Day."
            } else if isToday {
                "So far today. A stiller moment later today can still lower it."
            } else {
                nil
            }
        let blockDays = day.lastDays(MetricPopup.blockDays)
        let values = blockDays.map { blockDay in dayLoads.first { $0.day == blockDay }?.restingHR }
        blocks = zip(blockDays, values).map { blockDay, value in
            RestingHRPopupBlock(
                weekdayLetter: blockDay.weekdayLetter,
                hasValue: value != nil,
                isDayShown: blockDay == day
            )
        }
        let known = values.compactMap { $0 }
        lowestText = RestingHRTile.text(known.min())
        highestText = RestingHRTile.text(known.max())
        whatItIsText = MetricTexts.restingHRWhatItIs
        whatMovesItTexts = MetricTexts.restingHRWhatMovesIt
    }
}

/// One Day in the Resting HR popup's Last 14 Days (spec 011).
public struct RestingHRPopupBlock: Equatable, Sendable {
    /// e.g. "S" for Sunday.
    public let weekdayLetter: String
    /// False for a Day with no Resting HR, drawn hatched.
    public let hasValue: Bool
    /// True only for the Day shown, which is outlined.
    public let isDayShown: Bool
}
