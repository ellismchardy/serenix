# What home blood pressure protocol should Serenix guide, which category bands should it use, and what is the crisis threshold and "seek care" wording?
**Date:** 2026-11-04 · **Unblocks:** blood pressure check-in design (issue #56)

## Answer
- **Protocol (the sources agree):** seated after 5 min of quiet rest, back supported, feet flat, cuff on bare upper arm at heart level. No caffeine, exercise or smoking in the 30 min before. Take **2 readings 1 min apart**, **morning** (before medication and food) and **evening**, for **7 days** (at least 3–4). **Discard day 1** and average the rest (NICE, ESH). Between monitoring weeks, one session now and then is enough.
- **Bands: use home thresholds, not office ones.** A home average of 135/85 matches an office reading of 140/90. AHA/ACC 2025 keeps its 2017 categories and maps them to home values. Suggested table (a category applies when systolic **or** diastolic meets it):

  | Serenix band | Home average (mm Hg) | Source basis |
  |---|---|---|
  | Normal | < 120 and < 80 | AHA/ACC "normal" (home equivalent is the same) |
  | Elevated | 120–129 and < 80 | AHA/ACC "elevated" |
  | High, stage 1 | 130–134 / 80–84 | AHA/ACC stage 1 (home 130/80) |
  | High, stage 2 | ≥ 135 / ≥ 85 | AHA/ACC home equivalent of office 140/90; ESH and NICE home hypertension threshold |
  | Very high (check now) | single reading > 180 and/or > 120 | AHA severe hypertension / NICE severe |

  Alternative: if the app should follow the European (ESH/NICE) model, use **≥ 135/85 = hypertension** (NICE stage 1) and **≥ 150/95 = NICE stage 2** (home).
- **Crisis rule:** a single reading **> 180 systolic or > 120 diastolic** means: wait 5 min and measure again. If it is still that high, contact a clinician straight away. If there are symptoms (chest pain, shortness of breath, back pain, numbness or weakness, vision change, difficulty speaking), call emergency services (AHA wording). Never base this on the 7-day average.
- **Copy:** use "Very high" or "Seek care" rather than diagnosing anything. AHA itself retired "hypertensive urgency" for "severe hypertension", and a home app cannot tell whether organ damage is present.

## Findings
- **AHA/ACC 2017** categories: normal < 120/< 80; elevated 120–129/< 80; stage 1 130–139 or 80–89; stage 2 ≥ 140 or ≥ 90. Table 11 maps office to home values: 120/80 = 120/80, 130/80 = 130/80, 140/90 = 135/85, 160/100 = 145/90. HBPM procedure: ≥ 2 readings 1 min apart, morning before meds and evening before supper, ideally 1 week, average of readings over ≥ 2 days ([Whelton et al., Hypertension 2018;71:e13](https://www.ahajournals.org/doi/10.1161/HYP.0000000000000065)).
- **2025 AHA/ACC/multisociety guideline** (published Aug 2025) keeps the 2017 categories and office-to-home equivalents. It uses "severe hypertension" (> 180/> 120) with or without target organ damage in place of "hypertensive urgency" ([Jones et al., Hypertension 2025](https://www.ahajournals.org/doi/10.1161/HYP.0000000000000249)).
- **AHA/AMA joint policy statement on self-measured BP (2020):** validated upper-arm cuff, 2 readings 1 min apart twice daily (morning and evening), ideally 7 days and at least 3, averaged for decisions ([Shimbo et al., Circulation/Hypertension 2020](https://www.ahajournals.org/doi/10.1161/CIR.0000000000000803)). Device validation list: [validatebp.org](https://www.validatebp.org/).
- **ESH 2023:** home hypertension threshold ≥ 135/85. Office grade 1 is ≥ 140/90, with "high-normal" at 130–139/85–89. Protocol: 3–7 days (preferably 7) before a visit, morning and evening, 2 readings 1–2 min apart, first day discarded ([Mancia et al., J Hypertens 2023;41:1874](https://journals.lww.com/jhypertension/fulltext/2023/12000/2023_esh_guidelines_for_the_management_of_arterial.2.aspx)).
- **NICE NG136** (2019, updated Nov 2023): HBPM is 2 consecutive seated readings ≥ 1 min apart, twice daily, ideally morning and evening, for at least 4 days and ideally 7. Discard day 1 and average the rest. Home stage 1 ≥ 135/85 (office 140/90); stage 2 ≥ 150/95 (office 160/100). Severe hypertension: office ≥ 180 systolic or ≥ 120 diastolic, with same-day specialist referral if signs of emergency are present ([NICE NG136 rec. 1.2, 1.5](https://www.nice.org.uk/guidance/ng136/chapter/Recommendations)).
- **AHA patient wording for crisis:** for readings above 180/120, wait 5 min and test again. If still high, contact your health care professional immediately. If there are signs of organ damage (chest pain, shortness of breath, back pain, numbness/weakness, vision change, difficulty speaking), call 911 ([AHA, "Understanding Blood Pressure Readings"](https://www.heart.org/en/health-topics/high-blood-pressure/understanding-blood-pressure-readings); [AHA, "When to Call 911 About High Blood Pressure"](https://www.heart.org/en/health-topics/high-blood-pressure/understanding-blood-pressure-readings/hypertensive-crisis-when-you-should-call-911-for-high-blood-pressure)).

## Open / uncertain
- **Verification pass (2026-11-04):** ahajournals.org, heart.org and nice.org.uk all returned HTTP 403 to the fetch tool, so no primary page was read directly. Status of each claim:
  - **Corroborated by secondary sources:** the 2025 AHA/ACC guideline keeps the 2017 categories, and "severe hypertension" (> 180/> 120 without acute target organ damage) replaces "hypertensive urgency" ([Pharmacy Times, Jan 2026](https://www.pharmacytimes.com/view/new-2025-hypertension-management-guidelines-include-key-updates); [2 Minute Medicine quick reference](https://www.2minutemedicine.com/guidelines/high-blood-pressure/); [AHA/ACC press release via EurekAlert](https://www.eurekalert.org/news-releases/1094543)). The AHA crisis wording is also corroborated: wait 5 min, test again, contact a clinician immediately if still high, call 911 if there are symptoms. Its source is a heart.org-hosted AHA handout ([Oregon toolbox PDF](https://heart.org/-/media/Files/Affiliates/WSA/Oregon/OR-Hard-Hats-Blood-Pressure/Oregon-HHWH-Toolbox-Talks-How-Take-Your-Own-BP.pdf?sc_lang=en)), not the live heart.org page.
  - **Not verified:** that the **2025** guideline restates the office-to-home table (135/85 ↔ 140/90 and so on). That table is from the 2017 guideline (Table 11), and no source seen confirms that 2025 repeats it unchanged. Also not verified this session: the AHA/AMA 2020 statement, ESH 2023 and NICE NG136 details (protocol, discard first day, 150/95, update date). These come from knowledge of the guideline text, not from a fetch.
- The 180/120 severe threshold is defined for **clinic** readings. No source gives a home equivalent, so using it on a single home reading is a product choice that follows AHA's patient advice.
- Whether the live heart.org consumer chart has changed its "Hypertensive crisis" label since 2025 is unconfirmed.
- The bands in the US and European models differ for stage 1 (US 130/80, EU 135/85). Pick one model; mixing them would confuse users.
- The "Normal/Elevated at home" equivalents are an AHA mapping. ESH and NICE do not define a home "normal" or "elevated" band.
- Outside the US, the emergency number varies by region, so the "call 911" text needs localising.
