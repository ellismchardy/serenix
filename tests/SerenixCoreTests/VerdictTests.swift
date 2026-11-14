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
