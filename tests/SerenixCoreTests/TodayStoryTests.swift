import Foundation
import SerenixCore
import Testing

/// 1 Nov 2026 is in GMT here (BST ended on 25 Oct), so local time equals UTC.
private let london = TimeZone(identifier: "Europe/London")!
/// 2026-11-01T08:12:00Z, 08:12 local in London.
private let now = Date(timeIntervalSince1970: 1_793_520_720)
private let nov1 = Day(year: 2026, month: 11, day: 1)
/// 2026-10-31T23:18:00Z, 23:18 local in London.
private let onsetOct31At2318 = Date(timeIntervalSince1970: 1_793_488_680)
/// 2026-11-01T06:51:00Z, 06:51 local in London.
private let finalWakeNov1At0651 = Date(timeIntervalSince1970: 1_793_515_860)
/// Time Asleep of 7 h 12 m.
private let sevenHoursTwelve: TimeInterval = 25_920

private func storyForNov1() -> TodayStory {
    TodayView(
        nights: [
            Night(
                day: nov1,
                sleepOnset: onsetOct31At2318,
                finalWake: finalWakeNov1At0651,
                timeAsleep: sevenHoursTwelve
            )
        ],
        dayLoads: [],
        showing: nov1,
        now: now,
        timeZone: london,
        sync: .idle,
        profileName: nil
    ).story
}

@Test func aDayWithANightTellsItsStoryInFourStepsInOrder() {
    #expect(storyForNov1().steps.map(\.kind) == [.sleep, .overnight, .thisMorning, .todaySoFar])
}

@Test func theSleepStepRunsFromSleepOnsetToFinalWakeAndSaysHowLongYouSlept() {
    let sleep = storyForNov1().steps.first { $0.kind == .sleep }
    #expect(sleep?.timeLabel == "23:18 \u{2192} 06:51")
    #expect(sleep?.title == "You slept 7h 12m")
}
