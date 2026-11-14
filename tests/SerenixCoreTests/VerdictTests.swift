import SerenixCore
import Testing

// Sleep Score's verdict (spec 018, Verdicts): 67–100 "STRONG NIGHT.", 34–66 "FAIR NIGHT.", 0–33
// "ROUGH NIGHT.", each a state verdict. Tested at both edges of each band.

@Test(arguments: [
    (100, "STRONG NIGHT."),
    (67, "STRONG NIGHT."),
    (66, "FAIR NIGHT."),
    (34, "FAIR NIGHT."),
    (33, "ROUGH NIGHT."),
    (0, "ROUGH NIGHT."),
])
func aSleepScoreGivesItsBandsStateVerdict(score: Int, text: String) {
    #expect(Verdict.sleepScore(score) == Verdict(text: text, kind: .state))
}

// Weight's verdict (spec 018, Verdicts): each pace badge gives its state verdict, and Settling in
// the waiting "SETTLING IN." on any of its Days.

@Test(arguments: [
    (PaceStatus.badge(.onPace), Verdict(text: "ON PACE.", kind: .state)),
    (PaceStatus.badge(.behind), Verdict(text: "A BIT BEHIND.", kind: .state)),
    (PaceStatus.badge(.offPace), Verdict(text: "OFF PACE.", kind: .state)),
    (PaceStatus.badge(.tooFast), Verdict(text: "TOO FAST.", kind: .state)),
    (PaceStatus.settlingIn(day: 0), Verdict(text: "SETTLING IN.", kind: .waiting)),
    (PaceStatus.settlingIn(day: 13), Verdict(text: "SETTLING IN.", kind: .waiting)),
])
func aPaceStatusGivesItsWeightVerdict(status: PaceStatus, verdict: Verdict) {
    #expect(Verdict.pace(status) == verdict)
}

// A hold goal's verdict (spec 018, Verdicts): In band "IN BAND.", Above band "ABOVE BAND.", Below
// band "BELOW BAND.", each a state verdict.

@Test(arguments: [
    (HoldState.inBand, "IN BAND."),
    (HoldState.aboveBand, "ABOVE BAND."),
    (HoldState.belowBand, "BELOW BAND."),
])
func aHoldStateGivesItsStateVerdict(state: HoldState, text: String) {
    #expect(Verdict.hold(state) == Verdict(text: text, kind: .state))
}
