# What protein, fat and carb targets suit cutting, maintaining and gaining?

**Date:** 2026-11-04 (verified 2026-11-04) · **Unblocks:** macro suggestion rules (issue #54)

## Answer
- **Protein, maintain:** 1.6 g/kg/day (range 1.2–2.0 for active users; the 0.8 g/kg RDA is the floor for sedentary adults).
- **Protein, gain (surplus + resistance training):** 1.6 g/kg/day, upper suggestion 2.2 g/kg.
- **Protein, cut (deficit):** 2.2 g/kg/day (ISSN range 2.3–3.1 g/kg; Helms gives 2.3–3.1 g/kg of lean mass for lean, trained users); scale by goal or reference weight, not total weight, for users with obesity.
- **Fat:** at least 20% of energy (IOM AMDR 20–35%; EFSA RI 20–35%); default 25–30%; never below 15% during a cut (Helms 2014's floor).
- **Carbs:** take the energy left after protein and fat; warn if this drops below 130 g/day (the IOM RDA and EAR basis), and suggest 3–5 g/kg on moderately active Days and 5–7 g/kg on high-Load Days.

## Findings
Verified 2026-11-04 against abstracts from Europe PMC, which gives PubMed metadata; PubMed itself blocked fetches. Each DOI below matched its paper.

- Protein above 1.62 g/kg/day gave no further gain in fat-free mass under resistance training ([Morton et al. 2018, Br J Sports Med](https://doi.org/10.1136/bjsports-2017-097608)). **Verified.**
- The ISSN gives 1.4–2.0 g/kg/day for most exercising people, and 2.3–3.1 g/kg/day to keep lean mass during hypocaloric periods. It says intakes above 3.0 g/kg/day may help body composition in resistance-trained people ([Jäger et al. 2017, JISSN position stand](https://doi.org/10.1186/s12970-017-0177-8)). **Verified.** (The first draft said "above 3.0 g/kg during a cut", which was wrong; the cut range is 2.3–3.1.)
- The ISSN gives 2.3–3.1 g/kg of fat-free mass for lean, resistance-trained people who are dieting ([Aragon et al. 2017, JISSN](https://doi.org/10.1186/s12970-017-0174-y)). **Verified.**
- For natural bodybuilding contest prep, the review gives 2.3–3.1 g/kg of lean body mass for protein and 15–30% of calories from fat, with carbs making up the rest ([Helms, Aragon & Fitschen 2014, JISSN](https://doi.org/10.1186/1550-2783-11-20)). **Verified.** A systematic review reached the same protein range of 2.3–3.1 g/kg of fat-free mass for energy-restricted, resistance-trained athletes ([Helms et al. 2014, IJSNEM](https://doi.org/10.1123/ijsnem.2013-0054)). **Verified.**
- The IOM sets an adult protein RDA of 0.8 g/kg and a carbohydrate RDA of 130 g/day, based on the brain's glucose use, with a carbohydrate AMDR of 45–65% of energy ([IOM DRI Macronutrients](https://doi.org/10.17226/10490); [NAP workshop summary](https://www.nationalacademies.org/read/11767/chapter/9)). **Verified.** The fat AMDR of 20–35% and the protein AMDR of 10–35% are **not verified**: the NAP table PDF could not be read.
- EFSA sets the adult protein PRI at 0.83 g/kg/day, with an average requirement of 0.66 g/kg ([EFSA 2012](https://doi.org/10.2903/j.efsa.2012.2557); [EFSA press release](https://www.efsa.europa.eu/en/press/news/120209)). **Verified.** EFSA's fat reference intake of 20–35% of energy ([EFSA 2010](https://doi.org/10.2903/j.efsa.2010.1461)) and carbohydrate reference intake of 45–60% of energy ([EFSA 2010](https://doi.org/10.2903/j.efsa.2010.1462)) are **not verified**.
- The joint ACSM/AND/DC position on athletic performance is real, and its DOI matches ([Thomas, Erdman & Burke 2016](https://doi.org/10.1016/j.jand.2015.12.006)). Its abstract has no numbers, so the carb targets quoted from it (3–5 g/kg for moderate exercise, 6–10 g/kg for 1–3 h/day) and the fat floor of 20% or more are **not verified**.
- **Age:** for adults over 65, PROT-AGE recommends at least 1.0–1.2 g/kg/day, 1.2 g/kg or more for active people, and 1.2–1.5 g/kg for those with acute or chronic disease ([Bauer et al. 2013, JAMDA](https://doi.org/10.1016/j.jamda.2013.05.021)). **Verified.**
- **Sex:** the IOM and EFSA protein figures above are per kg and the same for both sexes, which is verified. Sex changes energy needs, and so the carbs left over, which follows from the arithmetic rather than from a cited source.

## Open / uncertain
- **Unverified numbers:**
  - Morton 2018's 95% CI (an upper bound of about 2.2 g/kg) and its subgroup findings (older people responding less, trained lifters more) are not in the abstract. The 2.2 g/kg upper suggestion for gaining therefore rests on the full paper, which was not read.
  - The IOM fat AMDR (20–35%) and protein AMDR (10–35%) were not confirmed. One NAP slide deck listed protein as 10–30%, which may apply to children.
  - EFSA's fat (20–35%) and carbohydrate (45–60%) reference intakes were not confirmed.
  - The Thomas 2016 carb g/kg ranges and fat floor were not confirmed.
- **Which body weight to use with obesity:** the sources do not agree on one method. The options are goal weight, adjusted body weight, or lean mass, which Serenix cannot measure. A practical rule: if BMI is over 30, use the weight at BMI 25 for the user's height. This needs height in the Profile, which it does not hold today.
- **Profile gaps:** the Profile has no body weight or height, so these fields would have to be added before any of these rules can run.
- **Small evidence base for the cut range:** 2.3–3.1 g/kg rests on small studies of lean, trained people. 2.2 g/kg is a conservative default just below that range.
- **Load to activity level:** the sources describe activity in hours of training. A mapping from Serenix's Load to activity level would be Serenix's own choice and needs its own spec.
