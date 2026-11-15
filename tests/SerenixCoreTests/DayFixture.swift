import Foundation
import SerenixCore

/// A fixture Day in `Fixtures/`: real History Records of one Day from the project owner's own
/// Strap, not cut down, because spec 007's Resting HR needs the whole Day; one CSV row per
/// second (docs/conventions.md, Testing). Day CSVs carry a trailing `steps` column, the Strap's
/// running step count, which restarts at 0 when the Strap reboots. Read by `NightFixture`'s
/// reader.
enum DayFixture {
    /// Wed 28 Oct 2026, Europe/London (UTC on that date): every record the owner's captures
    /// hold, 04:26:03–23:59:59. The Strap recorded nothing 05:08–05:22, 05:24–05:48,
    /// 05:55–06:00 and 16:47–23:20, and rebooted at 04:33, 04:37, 04:39, 04:46 and 14:11.
    static let day20261028: [HistoryRecord] = NightFixture.records(fixture: "Day-2026-10-28")
}
