# What units and presets should caffeine and alcohol logging use?

**Date:** 2026-11-04 · **Unblocks:** check-in presets for caffeine and alcohol — issue #57

## Answer
- **Store grams of ethanol, display in the user's local unit.** Grams convert cleanly to any national unit: UK unit = 8 g (10 ml), AU/NZ standard drink = 10 g, US standard drink = 14 g. Default the display to the UK unit (the owner is UK-based); US (14 g) and AU/NZ (10 g) units follow the user's locale (issue #57). Grams = volume ml × ABV × 0.789.
- **Alcohol presets** (grams of ethanol, UK units, US drinks):

  | Preset | Volume | ABV | g ethanol | UK units | US drinks |
  |---|---|---|---|---|---|
  | Pint of beer/lager | 568 ml | 4% | 17.9 | 2.3 | 1.3 |
  | Pint of strong beer | 568 ml | 5.2% | 23.3 | 3.0 | 1.7 |
  | Bottle/can of beer | 330 ml | 5% | 13.0 | 1.7 | 0.9 |
  | Small glass of wine | 125 ml | 12% | 11.8 | 1.5 | 0.8 |
  | Standard glass of wine | 175 ml | 12% | 16.6 | 2.1 | 1.2 |
  | Large glass of wine | 250 ml | 12% | 23.7 | 3.0 | 1.7 |
  | Single spirit (UK) | 25 ml | 40% | 7.9 | 1.0 | 0.6 |
  | Shot (US) | 44 ml (1.5 fl oz) | 40% | 13.9 | 1.7 | 1.0 |

  Let the user edit volume and ABV; the preset only fills defaults.
- **Caffeine presets** (mg per serving; typical values, real ranges are wide):

  | Preset | Serving | Caffeine |
  |---|---|---|
  | Espresso (single) | ~30 ml | 75 mg |
  | Filter/brewed coffee | mug ~240 ml | 95–140 mg (use 100) |
  | Instant coffee | mug | 60–100 mg (use 100, NHS figure) |
  | Tea (black) | mug | 40–75 mg (use 75, NHS figure) |
  | Green tea | cup | 30 mg |
  | Cola | 330 ml can | 32–40 mg (use 40, NHS figure) |
  | Diet cola | 330 ml can | ~45 mg |
  | Energy drink | 250 ml can | 80 mg (EU limit 32 mg/100 ml ⇒ 500 ml can ≈ 160 mg) |
  | Dark chocolate | 50 g | ~25 mg |

- **Daily limits:** healthy adults up to 400 mg/day (EFSA 2015, FDA); single dose up to 200 mg; pregnancy 200 mg/day. Alcohol: UK CMO guidance is no more than 14 UK units/week spread over 3+ days; US Dietary Guidelines say ≤2 drinks/day men, ≤1 women.
- **Sleep:** caffeine half-life is ~5 h in healthy adults (range ~2–10 h; longer in pregnancy and with oral contraceptives, shorter in smokers). EFSA found 100 mg close to bedtime can affect sleep; 400 mg taken 6 h before bed still measurably cut sleep (Drake 2013). A "caffeine still in you at bedtime" estimate can use simple exponential decay with t½ = 5 h.

## Findings
- UK unit is 10 ml / 8 g pure alcohol; men and women should not regularly exceed 14 units/week, spread over 3+ days; 5.2% pint 3 units, 330 ml 5% bottle 1.7, 125/175/250 ml 12% wine 1.5/2.1/3, 25 ml 40% spirit 1 unit; units = ABV × ml ÷ 1000 — [NHS, "Calculating alcohol units"](https://www.nhs.uk/live-well/alcohol-advice/calculating-alcohol-units/) (verified 2026-11-04). The 4% pint (2.3) is computed from the NHS formula.
- US standard drink = 14 g (0.6 fl oz) pure alcohol: 12 fl oz 5% beer, 5 fl oz 12% wine, 1.5 fl oz 40% spirits — [NIAAA, "What is a standard drink?"](https://www.niaaa.nih.gov/alcohols-effects-health/what-standard-drink) (verified 2026-11-04). Men ≤2 / women ≤1 drinks a day: [Dietary Guidelines for Americans 2020–2025](https://www.dietaryguidelines.gov/) (not re-fetched).
- Australian standard drink = 10 g; ≤10 standard drinks/week, ≤4/day — [Australian Government, "Standard drinks guide"](https://www.health.gov.au/topics/alcohol/about-alcohol/standard-drinks-guide) and [NHMRC](https://www.nhmrc.gov.au/health-advice/alcohol) (both timed out; not verified).
- Ethanol density 0.789 g/ml (physical constant; consistent with NIAAA's 0.6 fl oz ≈ 14 g).
- Caffeine (EFSA 2015): single doses up to 200 mg and up to 400 mg/day raise no safety concern for healthy adults (not pregnant women); up to 200 mg/day in pregnancy; 100 mg may affect sleep duration and patterns, especially close to bedtime — [EFSA caffeine topic page](https://www.efsa.europa.eu/en/topics/topic/caffeine) (verified 2026-11-04); full opinion [EFSA Journal 2015;13(5):4102](https://doi.org/10.2903/j.efsa.2015.4102) (403, not opened).
- FDA: 400 mg/day not generally linked to negative effects for most adults. Per 12 fl oz: soft drink 23–83 mg, green tea 37, black tea 71, brewed coffee 113–247, energy drink 41–246 — [FDA, "Spilling the Beans" (current as of 28 Aug 2024)](https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much) (verified 2026-11-04).
- UK per-serving values: instant coffee cup 100 mg (filter and coffee-shop drinks more), tea cup 75 mg, cola can 40 mg, 250 ml energy drink 80 mg, 50 g dark chocolate under 25 mg; pregnancy ≤200 mg/day — [NHS, "Foods to avoid in pregnancy"](https://www.nhs.uk/pregnancy/keeping-well/foods-to-avoid/) (verified 2026-11-04). This replaces a Food Standards Agency link that returned 404.
- Espresso ~63 mg/oz, green tea ~28 mg/8 oz: [USDA FoodData Central](https://fdc.nal.usda.gov/) (not re-fetched). Wide variation in UK retail espresso: [Crozier et al., Food Funct. 2012;3:30–33](https://doi.org/10.1039/C1FO10240K) (not re-fetched).
- EU "high caffeine content" labelling above 150 mg/l: [Regulation (EU) No 1169/2011, Annex III](https://eur-lex.europa.eu/eli/reg/2011/1169/oj) (not re-fetched).
- 400 mg caffeine 0, 3 or 6 h before bed disrupted sleep (6 h: >1 h less total sleep): [Drake et al., J Clin Sleep Med 2013;9(11):1195–1200](https://doi.org/10.5664/jcsm.3170) (DOI resolves, full text paywalled behind a sign-in; not verified).

## Open / uncertain
- **Verified on 2026-11-04 against the source page:** UK unit and NHS wine, spirit and beer figures; the 14 units/week guideline; the NIAAA 14 g definition; EFSA's 200/400/100 mg and pregnancy figures (from EFSA's topic page); the FDA 400 mg figure and per-12 oz ranges; NHS per-drink caffeine figures.
- **Not verified:**
  - The AU 10 g figure and NHMRC limits: health.gov.au timed out.
  - The US Dietary Guidelines limits, USDA espresso and green tea values, Crozier 2012 and the EU 150 mg/l rule were not re-fetched.
  - Drake 2013 is paywalled.
  - Neither the EFSA nor the FDA pages I opened state the caffeine half-life, so the ~5 h value (range 2–10 h) is unverified and needs a pharmacokinetics source.
- **Changes in this pass:**
  - 330 ml 5% beer goes from 1.6 to 1.7 UK units (NHS).
  - Instant, tea and cola presets now use the NHS values: 100, 75 and 40 mg.
  - The FSA link (404) is replaced with the NHS page.
  - The FDA figures now use FDA's current per-12 oz values.
- The filter coffee (100 mg) and espresso (75 mg) presets are still estimates: NHS gives no figure for either. Caffeine content varies 2–5× by brand and brew, so offer custom drinks.
- Which unit to default to for each locale is a product decision. Storing grams keeps it reversible.
- Many red wines are 13–14% ABV, so a 12% default under-counts them.
- How long caffeine lasts varies a lot between people (CYP1A2 genetics, pregnancy, smoking), so any "caffeine at bedtime" figure is an estimate.
