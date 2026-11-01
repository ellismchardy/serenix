import Foundation

/// Seconds History Records are kept on the phone before they're pruned: 30 days
/// (docs/architecture.md, Data model).
let historyRecordRetention: TimeInterval = 30 * 24 * 60 * 60

/// Whether History Records starting at `start` can still be worked out at `now`: not once they
/// start more than `historyRecordRetention` before `now` (they may be pruned), nor while they start
/// after `now` (a Strap clock that's wrong). The rule Night and Day rebuilds share (specs 003 and
/// 005, When).
func isWithinRetention(start: Date, now: Date) -> Bool {
    start >= now.addingTimeInterval(-historyRecordRetention) && start <= now
}
