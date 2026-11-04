# Where do the 0.5% and 1% of body weight per week thresholds come from, and should caps differ for lean users or weight-gain goals?

**Date:** 2026-11-04 · **Unblocks:** pace warnings in the weight goals spec (warn >0.5%/wk, "too fast" >1%/wk, never block)

## Answer
- The 0.5–1%/wk loss band comes from sports nutrition, not from medical safety limits. Helms et al. 2014 recommend it for natural bodybuilders "to maximize muscle retention". Garthe et al. 2011 found that athletes losing 0.7%/wk gained lean mass, while athletes losing 1.4%/wk did not. Public-health guidance uses absolute rates instead: 1–2 lb/wk (CDC) and 0.5–1 kg/wk (NHS/NICE, not yet checked against their own pages). For an 80 kg adult that is about 0.6–1.25%/wk, so the two roughly agree.
- **Weight loss:** keep the prototype's thresholds. Warn above 0.5%/wk and say "too fast" above 1%/wk.
- **Lean users:** the sources support a slower pace (Helms 2014; Aragon 2017; Ann N Y Acad Sci 2000), but none gives a numeric body-fat cut-off. The Profile has no body fat, so keep the same thresholds and add a line to the warning text that leaner people should lose more slowly.
- **Weight gain:** use separate, lower caps. Target 0.25–0.5%/wk (Iraki et al. 2019; about 0.25%/wk for advanced lifters) and warn above 0.5%/wk. A "too fast" level of 1%/wk is a judgement call: no source names a gain cap. Garthe 2013 found that a larger surplus added mostly fat.
- **Never block,** as the wayfinder map already says. None of these sources treats these rates as hard safety limits for healthy adults.

## Findings
- **Helms, Aragon & Fitschen (2014):** "Caloric intake should be set at a level that results in bodyweight losses of approximately 0.5 to 1%/wk to maximize muscle retention." They also write that "the leaner the competitor becomes the greater the risk for LBM loss" and suggest a more gradual approach towards the end of a diet. [JISSN 11:20, PMC4033492](https://pmc.ncbi.nlm.nih.gov/articles/PMC4033492/)
- **Garthe et al. (2011):** 24 elite athletes were randomised to lose 0.7%/wk or 1.4%/wk while strength training. Lean mass rose 2.1% in the slow group and was unchanged (−0.2%) in the fast group. The authors recommend 0.7%/wk. [IJSNEM 21(2):97–104, doi:10.1123/ijsnem.21.2.97](https://doi.org/10.1123/ijsnem.21.2.97)
- **Aragon et al. (2017), ISSN position stand:** "Slower rates of weight loss can better preserve lean mass (LM) in leaner subjects." Higher body fat allows a larger deficit. [JISSN 14:16, PMC5470183](https://pmc.ncbi.nlm.nih.gov/articles/PMC5470183/)
- **Ann N Y Acad Sci (2000), "Body fat content influences the body composition response to nutrition and exercise":** the share of weight lost as lean tissue falls as starting body fat rises, so thin people lose relatively more lean mass. [PubMed 10865771](https://pubmed.ncbi.nlm.nih.gov/10865771/)
- **Iraki, Fitschen, Espinar & Helms (2019):** recommend gaining "~0.25–0.5% of bodyweight/week" for novice and intermediate bodybuilders, and about 0.25%/wk for advanced ones (Table 1). [Sports 7(7):154, PMC6680710](https://pmc.ncbi.nlm.nih.gov/articles/PMC6680710/)
- **Garthe et al. (2013):** 39 elite athletes in an 8–12 week weight-gain block. The guided group ate more and gained more weight (3.9% vs 1.5%) and much more fat (+15% vs +3%), with no significant difference in lean-mass gain. The authors warn that excess energy intake brings unwanted fat gain. This paper is in the *European Journal of Sport Science*, not IJSNEM as the first draft said. [PubMed 23679146](https://pubmed.ncbi.nlm.nih.gov/23679146/)
- **CDC:** recommends losing about 1 to 2 pounds a week, because people who lose weight at "a gradual, steady pace" are more likely to keep it off. [CDC, "Losing Weight"](https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html)
- **NHS:** gives a safe weekly loss of 0.5–1 kg (1–2 lb), but only secondary copies were seen, for example in the NHS 12-week plan. The nhs.uk page the first draft cited returns 404. Link to the official page once it is found.
- **NICE NG246 (Jan 2025, replaces CG189):** secondary sources (GPnotebook) say its criteria for weight-management programmes include a target of 0.5–1 kg/wk. nice.org.uk returned 403, so the wording is unconfirmed. [NICE NG246](https://www.nice.org.uk/guidance/ng246)

## Open / uncertain
- **Verified against the primary text or the PubMed/PMC abstract:** Helms 2014, Garthe 2011, Aragon 2017, the Ann N Y Acad Sci 2000 paper, Iraki 2019, Garthe 2013 and CDC.
- **Not verified:**
  - NHS 0.5–1 kg/wk: the official page wasn't found, only secondary copies.
  - NICE NG246 0.5–1 kg/wk: the site blocked fetching, so this rests on secondary sources.
  - Authorship of the 2000 paper: Forbes is widely cited as the author, but the search result didn't confirm it.
- **Removed:** the NHLBI 1998 citation. The page could not be fetched.
- The sports-nutrition evidence comes from small studies of trained, normal-weight athletes. How well it applies to general users, including people with obesity who can safely lose faster early on, is unknown.
- No source gives a numeric body-fat cut-off for "lean", and none sets a "too fast" cap for weight gain. The 1%/wk gain cap is our own choice.
- Week-to-week weight is noisy because of water and glycogen. The pace should be computed over a 2–4 week trend, but no source here sets that window.
