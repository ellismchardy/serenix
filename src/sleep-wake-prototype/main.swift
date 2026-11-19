// PROTOTYPE (prototype/sleep-wake-candidates, #83). Never merged. Scores labeller variants on
// Walch's Reference Nights at a fixed Tilt threshold and prints one row per variant: all kept
// nights pooled, plus each half (A = even positions, B = odd, by sorted id) so a tuned choice
// can be checked on the half it wasn't picked on.
//
// Run: swift run -c release sleep-wake-prototype <walch folder> [group ...]
import Foundation
import SerenixCore
import SleepAccuracy

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("usage: sleep-wake-prototype <walch folder> [group ...]")
    exit(2)
}
let folder = URL(fileURLWithPath: arguments[1])
let groups = Set(arguments.dropFirst(2))
let threshold = 0.75

let start = Date()
let nights = try WalchAdapter.referenceNights(in: folder)
FileHandle.standardError.write(
    "loaded \(nights.count) in \(Int(Date().timeIntervalSince(start))) s\n".data(using: .utf8)!
)

func settings(_ change: (inout LabellerSettings) -> Void) -> LabellerSettings {
    var value = LabellerSettings()
    change(&value)
    return value
}

var variants: [(group: String, settings: LabellerSettings)] = [("base", LabellerSettings())]
for minutes in [5, 15, 30, 60] {
    variants.append(("period", settings { $0.mergeAcrossMissingMinutes = minutes }))
}
variants.append(("period", settings { $0.needsHeartRate = true }))
variants.append(("period", settings { $0.pickLongestSpan = true }))
for merge in [30, 90, 120, 180] {
    variants.append(("period", settings { $0.longestMergedWake = merge }))
}
for run in [3, 5, 10, 15] {
    variants.append(("period", settings { $0.shortestSleepRun = run }))
}
variants.append(("webster", settings { $0.websterRescoring = true }))
for above in [4.0, 6.0, 8.0, 10.0, 15.0] {
    variants.append(("hr", settings { $0.heartRateWakeAbove = above }))
}
for raised in [3.0, 4.0, 8.0] {
    variants.append(("hr", settings { $0.raisedHeartRate = raised }))
}
for extend in [20, 30] {
    variants.append(("hr", settings { $0.longestHeartRateExtension = extend }))
}
for degrees in [2.0, 3.0, 5.0, 8.0] {
    variants.append(("vanhees", settings { $0.vanHeesDegrees = degrees }))
}
for multiple in [3.0, 5.0, 10.0, 15.0] {
    variants.append(("pernight", settings { $0.perNightThresholdMultiple = multiple }))
}
for active in [3, 5, 7, 15] {
    for median in [2.0, 4.0, 6.0, 9.0] {
        variants.append(
            (
                "grid",
                settings {
                    $0.wakeActiveSeconds = active
                    $0.wakeMedianActiveSeconds = median
                }
            )
        )
    }
}
if let combos = ProcessInfo.processInfo.environment["COMBOS"] {
    // Each combo: comma-separated key=value, combos separated by ';'.
    for combo in combos.split(separator: ";") {
        var value = LabellerSettings()
        for pair in combo.split(separator: ",") {
            let parts = pair.split(separator: "=").map(String.init)
            let key = parts[0]
            let number = parts.count > 1 ? Double(parts[1]) : nil
            switch key {
            case "wakeActive": value.wakeActiveSeconds = Int(number!)
            case "median5": value.wakeMedianActiveSeconds = number!
            case "raisedHR": value.raisedHeartRate = number!
            case "hrExtend": value.longestHeartRateExtension = Int(number!)
            case "minRun": value.shortestSleepRun = Int(number!)
            case "merge": value.longestMergedWake = Int(number!)
            case "webster": value.websterRescoring = true
            case "hrWake": value.heartRateWakeAbove = number!
            case "needsHR": value.needsHeartRate = true
            case "mergeMissing": value.mergeAcrossMissingMinutes = Int(number!)
            case "longestSpan": value.pickLongestSpan = true
            case "perNight": value.perNightThresholdMultiple = number!
            case "vanHees": value.vanHeesDegrees = number!
            default: fatalError("unknown key \(key)")
            }
        }
        variants.append(("combo", value))
    }
}
if !groups.isEmpty {
    variants = variants.filter { groups.contains($0.group) || $0.group == "base" }
}

let chosen = variants.map(\.settings)
let nightsToScore = nights
nonisolated(unsafe) var results = [ScoredReferenceNights?](repeating: nil, count: variants.count)
let lock = NSLock()
DispatchQueue.concurrentPerform(iterations: chosen.count) { index in
    let scored = Scorer.score(nightsToScore, activeAboveDegrees: 0.75, settings: chosen[index])
    lock.lock()
    results[index] = scored
    lock.unlock()
}

func f(_ value: Double?, _ digits: Int = 3) -> String {
    value.map { String(format: "%.\(digits)f", $0) } ?? "—"
}

print(
    "| Group | Variant | κ visible | Sens | Spec | κ raw | TA bias | TA SD | |Onset| > 60 min | κ A | κ B | Kept |"
)
print("|---|---|---|---|---|---|---|---|---|---|---|---|")
let ids = nights.map(\.id).sorted()
for (index, variant) in variants.enumerated() {
    guard let scored = results[index], let pooled = scored.pooled else { continue }
    let halfA = scored.kept.filter { ids.firstIndex(of: $0.id)! % 2 == 0 }
    let halfB = scored.kept.filter { ids.firstIndex(of: $0.id)! % 2 == 1 }
    let lateOrEarly = scored.kept.filter { abs($0.sleepOnsetError ?? 999) > 60 }.count
    let cells = [
        variant.group,
        variant.settings.description,
        f(pooled.visible.kappa),
        f(pooled.visible.sensitivity),
        f(pooled.visible.specificity),
        f(pooled.raw.kappa),
        f(pooled.timeAsleepBias.mean, 1),
        f(pooled.timeAsleepBias.sd, 1),
        "\(lateOrEarly)",
        f(EpochAgreement.pooled(halfA.map(\.visible)).kappa),
        f(EpochAgreement.pooled(halfB.map(\.visible)).kappa),
        "\(scored.kept.count)",
    ]
    print("| " + cells.joined(separator: " | ") + " |")
}
if ProcessInfo.processInfo.environment["PER_NIGHT"] != nil {
    for (index, variant) in variants.enumerated() {
        guard let scored = results[index] else { continue }
        print("\n## \(variant.settings.description)")
        for night in scored.kept {
            print(
                "\(night.id)\tκ \(f(night.visible.kappa))\tTA \(f(night.timeAsleepBias, 1))"
                    + "\tonset \(f(night.sleepOnsetError, 1))\twake \(f(night.finalWakeError, 1))"
            )
        }
    }
}
FileHandle.standardError.write(
    "done in \(Int(Date().timeIntervalSince(start))) s\n".data(using: .utf8)!
)

// PROTOTYPE: STRAP=<folder of fixture CSVs> prints each night's Sleep Period with the Strap's turn
// at 2° under spec 003 and under each combo.
if let strap = ProcessInfo.processInfo.environment["STRAP"] {
    let time = ISO8601DateFormatter()
    for night in try HistoryRecordCSV.nights(in: URL(fileURLWithPath: strap)) {
        print("\n## Strap \(night.id)")
        let input = SleepWakeLabeller.input(from: night.records)
        for variant in variants where variant.group == "base" || variant.group == "combo" {
            let period = SleepWakeLabeller.label(
                input,
                activeAboveDegrees: SleepWakeLabeller.appThreshold,
                settings: variant.settings
            ).sleepPeriod
            let onset = period.map { time.string(from: $0.sleepOnset) } ?? "—"
            let wake = period.map { time.string(from: $0.finalWake) } ?? "—"
            let asleep = period.map { f($0.timeAsleep / 60, 0) } ?? "0"
            let bouts = period?.wakeBouts.count ?? 0
            print(
                "\(variant.settings.description)\tonset \(onset)\twake \(wake)\tasleep \(asleep) min\tbouts \(bouts)"
            )
        }
    }
}
