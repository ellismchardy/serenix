# How do intake-plus-trend-weight methods (MacroFactor-style) estimate daily energy expenditure, and how accurate is ~7,700 kcal/kg?

**Date:** 2026-11-04 · **Unblocks:** the adaptive calorie target spec (issue #52)

## Answer
- **Method:** expenditure = mean logged intake − (Δ trend weight × energy density) / days. Smooth
  weight first (exponential moving average, α ≈ 0.1/day, i.e. a ~10-day time constant, as in
  Walker's "Hacker's Diet"), then compute the balance over a rolling window, then smooth the
  expenditure estimate itself so it moves slowly.
- **Recommended sketch:** (1) trend weight `T_t = T_{t-1} + 0.1·(w_t − T_{t-1})`, carrying T
  forward on days without a weigh-in; (2) over the last 14–21 Days, `TDEE = mean(intake on
  fully logged Days) − ρ·(T_end − T_start)/n_days`, with ρ = 7,700 kcal/kg for loss/gain
  under ~1 kg/week (or ρ ≈ 5,000–6,500 early in a diet / for lean people, see Findings);
  (3) blend `TDEE_new = 0.9·TDEE_old + 0.1·TDEE_window` per Day (or cap the change at
  ~±100 kcal/week) so one noisy week can't swing the target; (4) target = TDEE − chosen deficit.
- **Minimum data:** don't show a data-derived estimate before ~14 Days with ≥ ~10 fully logged
  Days and ≥ ~8 weigh-ins spanning at least 10 Days; before that use a formula prior
  (Mifflin-St Jeor RMR × activity factor, or RMR + Serenix's own Load-based activity estimate)
  and blend toward the data estimate as Days accrue (Bayesian-style weighting).
- **Missed / partial days:** exclude Days the user marks incomplete (or that fall far below
  their usual intake) from the intake mean instead of counting them as low intake; the weight
  side still uses the whole span. Under-logging biases TDEE low by exactly the unlogged
  kcal, so incomplete Days must not be treated as zero.
- **7,700 kcal/kg accuracy:** fine as a short-horizon converter for moderate change in adults
  with some fat to lose, but it overstates loss over months because expenditure falls (lost
  mass, less movement, modest adaptive thermogenesis) — which an adaptive TDEE estimate
  absorbs automatically. Don't use it to *project* months ahead; re-estimate instead.

## Findings
Verification status is marked on each item: **[verified]** means checked against the source's
abstract or page on 2026-11-04. **[unverified]** means the number comes from the full text or
from memory and was not confirmed.

- The "3,500 kcal per lb" rule (≈7,700 kcal/kg; 32.2 MJ/kg) roughly matches the predicted
  energy density of weight lost for obese people with more than ~30 kg of body fat. It
  overestimates the deficit needed per kg for people with less body fat **[verified]**
  ([Hall, Int J Obes 2008 (online 2007), "What is the required energy deficit per unit weight loss?"](https://doi.org/10.1038/sj.ijo.0803720)).
  The figures of fat ≈ 9,400 kcal/kg and lean tissue ≈ 1,800 kcal/kg are commonly drawn from
  this paper's full text **[unverified]**.
- The static 3,500-kcal rule overpredicts weight loss over time because it ignores how
  expenditure changes as weight falls **[verified, title and source; the abstract was not
  read]**
  ([Thomas et al., Int J Obes 2013;37(12), "Can a weight loss of one pound a week be achieved with a 3500-kcal deficit? Commentary on a commonly accepted rule"](https://doi.org/10.1038/ijo.2013.51)).
- Initial body fat sets how much of a weight change is lean mass rather than fat (the Forbes
  relationship), so leaner people's weight change carries fewer kcal per kg **[verified]**
  ([Forbes, Ann NY Acad Sci 2000;904:359-65](https://doi.org/10.1111/j.1749-6632.2000.tb06482.x)).
- Body weight responds slowly to a sustained change in intake, with a half-time of about
  1 year, and people with more body fat take longer to reach steady state **[verified]**
  ([Hall et al., Lancet 2011, "Quantification of the effect of energy imbalance on bodyweight"](https://doi.org/10.1016/S0140-6736(11)60812-X)).
  The full text's rule of thumb is 100 kJ/day (≈24 kcal/day) per ~1 kg of eventual change,
  ≈10 kcal/day per lb, with ~95% of the change in ~3 years **[unverified]**. Hall's model is
  implemented in the NIH Body Weight Planner (https://www.niddk.nih.gov/bwp). The early
  glycogen and water loss (larger weight change per kcal in weeks 1–2) is standard in Hall's
  models **[unverified]**.
- Adaptive thermogenesis is real and favours weight regain **[verified, qualitative]**
  ([Rosenbaum & Leibel, Int J Obes 2010](https://doi.org/10.1038/ijo.2010.184)). The abstract
  gives no typical kcal/day magnitude, so the ~50–150 kcal/day figure for ordinary diets is
  **[unverified]**. After extreme loss it can be large: Biggest Loser contestants showed
  metabolic adaptation of −499 ± 207 kcal/day six years later, with resting metabolic rate
  704 ± 427 kcal/day below baseline **[verified]**
  ([Fothergill et al., Obesity 2016;24(8)](https://doi.org/10.1002/oby.21538)).
- Back-calculating intake from doubly-labelled-water expenditure plus measured body
  composition change during 30% calorie restriction was accurate on average but noisy for
  individuals: intake came out 8.7 ± 36.7% high, and the authors judged individual
  assessment unreliable **[verified]**
  ([de Jonge et al., Am J Clin Nutr 2007;85(1):73-79](https://doi.org/10.1093/ajcn/85.1.73)).
  The same energy-balance identity underlies MacroFactor-style estimates, and the large
  individual error is a reason to use long windows and damping. (The previous version of this
  note cited the wrong DOI, journal and description for this paper.)
- Self-reported intake is unreliable. In non-obese adults the SD of individual error
  approaches 20%, and individual underestimates of 50% are "not uncommon" **[verified]**
  ([Schoeller, Metabolism 1995;44(2 Suppl 2):18-22](https://doi.org/10.1016/0026-0495(95)90204-X)).
  The earlier "10–45% under-reporting" range is **[unverified]** and has been dropped. An
  intake-based TDEE is expenditure measured in the user's own logging currency, so
  *consistent* under-logging largely cancels out of the target.
- Scale weight swings from day to day with water and gut content, so trend smoothing is
  needed. The 0.1 EMA comes from John Walker's *The Hacker's Diet* (fourmilab.ch/hackdiet),
  a book, not peer-reviewed **[unverified, lead only]**.
- What MacroFactor's own help centre says **[verified]**:
  - Expenditure = intake − change in stored energy, with the change taken from *trend*
    weight and adjusted for the fat and lean make-up of the change
    ([Expenditure](https://help.macrofactorapp.com/en/articles/20-expenditure)).
  - Partial logging makes expenditure come out too low ([Expenditure](https://help.macrofactorapp.com/en/articles/20-expenditure)).
    Skipping small items under ~50 kcal is fine, but leaving out whole meals is not
    ([Do I need to log everything…](https://help.macrofactorapp.com/en/articles/140-do-i-need-to-log-everything-i-eat-and-drink-to-have-an-accurate-expenditure-and-use-macrofactor-s-coaching-features)).
  - Per search-result summaries of its help centre (pages not opened directly), the estimate
    looks back over about the past three weeks and starts from onboarding data or a manual
    initial estimate. Optional "Step-Informed Updates" speed changes when step counts trend
    ([Expenditure Modifiers](https://help.macrofactorapp.com/en/articles/274-expenditure-modifiers)).
  - Not found in its docs: smoothing constants, minimum data, the kcal/kg used, or a
    "mark day incomplete" rule. The earlier claim that MacroFactor excludes marked partial days
    is **[unverified]**; MacroFactor links to a separate partial-logging article not yet read.
- Mifflin-St Jeor predicted resting metabolic rate within 10% of measured in more non-obese
  and obese people than any other equation **[verified]**
  ([Frankenfield et al., J Am Diet Assoc 2005](https://doi.org/10.1016/j.jada.2005.02.005)).
  The earlier "~70–80% of people" figure is **[unverified]**: the abstract gives no percentage.

## Open / uncertain
- **Verified (abstract or page, 2026-11-04):** Hall 2008's 3,500 kcal/lb statement; the
  Thomas 2013 citation; Forbes 2000 (DOI corrected); Hall 2011's ~1-year half-time;
  Fothergill 2016's numbers; de Jonge 2007 (citation corrected); Schoeller 1995's numbers;
  Frankenfield 2005's ranking; MacroFactor's equation, trend weight and under-logging effect.
- **Unverified:** fat 9,400 and lean 1,800 kcal/kg; the 10 kcal/day-per-lb and 95%-in-3-years
  rule; ~50–150 kcal/day ordinary adaptive thermogenesis; the glycogen early-weeks effect;
  MacroFactor's 3-week window and its onboarding start (seen only in search summaries);
  MacroFactor's handling of partial days. PubMed blocked automated fetching, so abstracts were
  read through Europe PMC and Crossref.
- MacroFactor publishes no constants. The recommended α 0.1, 14–21 Day window and 0.1 blend
  are engineering choices consistent with its stated ~3-week lookback, not validated values.
  Tune them on the owner's own logs.
- Whether Serenix's Load-based activity estimate beats a plain activity factor as the
  starting estimate is untested.
- Menstrual-cycle water swings may need a longer window for some users.
