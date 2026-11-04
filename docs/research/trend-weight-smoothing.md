# Which smoothing should trend weight use, and how should multi-day gaps without a weigh-in be handled?

**Date:** 2026-11-04 · **Unblocks:** the weight trend & goals spec (issue #50)

## Answer
- Use the Hacker's Diet exponentially smoothed moving average: `T_n = T_(n-1) + 0.1 × (W_n − T_(n-1))`, seeded with the first weigh-in. It is the only one of the three methods with a published, reproducible formula. Happy Scale's recommended method and MacroFactor's trend are proprietary and undocumented, so nobody can port or test against them.
- Make the step time-aware so gaps don't distort the trend: with `Δd` days since the last weigh-in, use `α = 1 − 0.9^Δd`. One day gives exactly 0.1, so it matches Hacker's Diet for daily weigh-ins. A 3-day gap gives 0.271, the same result as carrying the trend through the two missing days unchanged and applying the formula once. Days with no weigh-in get no new trend point. The chart shows the trend held flat or dashed, never an invented weight. This extension is our own derivation, not something any source documents.
- Keep one weigh-in per Day. Happy Scale uses the lowest when there are several, which is a reasonable choice.
- If the gap runs past a cutoff (suggested: 14 days, where `0.9^14 ≈ 0.23` of the old trend would remain), reseed the trend from the new weigh-in and break the line. Treat this number as a judgement call for the spec to confirm.
- Don't offer trend "predictions" or forward/backward smoothing in v1. Happy Scale's own help says its look-ahead smoothing revises recent days as new weights arrive. That conflicts with a value that stays stable once shown and is easy to test.

## Findings
- Hacker's Diet trend formula: `T_n = T_(n−1) + 0.1(W_n − T_(n−1))`, done by hand by shifting the decimal point one place. The first day's weight is the starting trend, and the trend carries over across months ([The Hacker's Diet, "Pencil and Paper"](https://www.fourmilab.ch/hackdiet/e4/pencilpaper.html), e4 online edition, undated). That page gives no rule for a missing day.
- The book presents the trend as an exponentially smoothed moving average, where the weights are successive powers of a smoothing constant. A constant of 0.9 is described as lagging about like a 20-day simple moving average ([The Hacker's Diet, "Signal and Noise"](https://www.fourmilab.ch/hackdiet/e4/signalnoise.html)).
- Happy Scale offers four methods: Happy Scale Smoothing (recommended), Double Exponential Smoothing, Exponential Smoothing and a Seven Day Moving Average. Its help says plain exponential smoothing lags but is good for calculating trends, double exponential overshoots when the rate changes, and Happy Scale Smoothing uses future weigh-ins as well, so it can adjust the last few days. No constants or formulas are published. It says weighing in less often (even weekly) works, but the page doesn't describe gap handling. On Health import it keeps the lowest weight of each day ([Happy Scale Support](https://happyscale.com/support), fetched 2026-11-04).
- MacroFactor's help says the weight trend is "resilient to gaps in data" and recommends daily weigh-ins, or at least three a week. The method itself is not published there ([MacroFactor help: Weight Trend](https://help.macrofactorapp.com/en/articles/278-weight-trend), undated, fetched 2026-11-04). It also recommends weekly weigh-ins as the minimum ([MacroFactor help: logging frequency](https://help.macrofactorapp.com/en/articles/109-how-frequently-do-i-need-to-log-my-weight-for-the-expenditure-algorithm-and-weekly-coaching-updates)). Search snippets mention "imputation" for missed weigh-ins, but I couldn't confirm that on a fetched primary page.
- Hacker's Diet Online's legacy CSV export marks a day with no weight as `---`, so missing days are stored as gaps rather than filled in ([HDO Excel CSV format](https://fourmilab.ch/hackdiet/online/images/excelcsv.html); lead only, I didn't fetch it in full).

## Open / uncertain
- How Hacker's Diet Online computes the trend across missing days isn't documented on any page I fetched. The `1 − 0.9^Δd` rule is our own extension. The spec should fix it with literal test cases (for example: trend 80.0, weigh-in 79.0 after 3 days gives 79.729).
- The 14-day reseed cutoff is a judgement call, not taken from any source.
- MacroFactor's algorithm and Happy Scale Smoothing are proprietary. Matching their numbers isn't possible and shouldn't be a goal.
- The rate-of-change or goal-date projection (Hacker's Diet uses a regression slope of the trend) is out of scope here. It needs its own decision.
