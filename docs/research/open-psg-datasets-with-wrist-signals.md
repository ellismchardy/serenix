# Which open sleep-lab datasets pair wrist motion and beat-to-beat intervals with PSG-scored sleep stages, and can Serenix use them?

**Date:** 2026-11-16 · **Unblocks:** the wayfinder tickets (map [#78](https://github.com/ellismchardy/serenix/issues/78)) "Which sleep stages Serenix shows, and
what they're called" and "The accuracy bar sleep stages must clear": which labelled nights a
staging model is trained and measured on, and what the owner must do to get them. Follows
[sleep-wake-and-sleep-stages.md](sleep-wake-and-sleep-stages.md), which found that Walch's
sleep-accel set has no RR intervals.

## Answer
- **Two datasets match the Strap's signals: wrist motion, wrist beat-to-beat intervals and
  PSG-scored AASM stages from the same night.** Both use an Empatica E4 wristband.
  - **DREAMT** (PhysioNet, v2.2.0): 100 sleep-clinic patients, mostly with sleep apnea.
  - **Wearanize+** (Radboud, v1.0/v1.1): 130 healthy young adults, with full PSG at home.

  Both label 30-second epochs W/N1/N2/N3/REM, so one dataset serves both wake/NREM/REM and
  light/deep/REM (light = N1+N2, deep = N3). No other open set was found with all three.
- **Neither licence clearly allows shipping trained model weights in a public app.**
  - DREAMT's PhysioNet Restricted licence limits use to "scientific research and no other".
  - Wearanize+ is for "scientific research purposes" only, by a bona fide researcher.
  - Using either to *measure* Serenix's accuracy, and publishing the numbers, is plainly
    research. Shipping weights trained on them needs written permission from the data owners.
- **Fully open (ODC-By / CC BY) sets exist, but none has both wrist motion and RR intervals.**
  - sleep-accel (Walch) and BIDSleep have Apple Watch motion and heart rate, but no RR.
  - HMC, CAP and the PhysioNet/CinC Challenge 2018 have PSG ECG, from which RR intervals can be
    drawn, but no wrist motion. Challenge 2018 has 994 labelled training nights.
  - Serenix could ship weights trained on these without asking anyone, if it uses two models:
    motion and heart rate for sleep/wake, and RR intervals for the stage within sleep. RR from
    a PSG chest ECG is cleaner than the Strap's RR from wrist PPG, so expect some loss.
- **Recommendation.**
  - **(a) wake/NREM/REM:** measure on **DREAMT**, which has REM in a clinic population.
    Train on Challenge 2018 + HMC (ECG RR) and sleep-accel (motion + HR) for weights that can
    ship, or on DREAMT if Duke's team agrees in writing.
  - **(b) light/deep/REM:** use **Wearanize+** as the main reference. Its young, healthy sleepers
    have plenty of N3; DREAMT's older apnea patients have little. Check against DREAMT so the
    model isn't only good on easy nights.
  - **MESA** (NSRR, ~2,000 people) is the big set, but its wrist data are 30-second Actiwatch
    activity counts, not a signal like the Strap's. Leave it for later, if HRV-only
    pre-training ever needs more nights.
- **What the owner has to do:**
  - DREAMT: make a PhysioNet account and sign the Restricted Health Data Use Agreement 1.5.0.
    No training course is listed.
  - Wearanize+: download the open-access "OA" collection, which needs no agreement. Read its
    terms first. The full collection needs a DUA emailed to the PI, an ORCID account and an
    access request on the Radboud Data Repository.
  - To ship weights: email the DREAMT and Wearanize+ authors to ask whether model weights in a
    free, MIT-licensed app are allowed. Get the answer in writing before training a model that
    ships.

## Findings

### Comparison

"Wrist motion" here means a raw accelerometer on the wrist, like the Strap's. "Beat intervals"
means inter-beat (RR) intervals, or a PPG/ECG waveform they can be drawn from.

| Dataset (version) | Nights / people | Wrist motion | Beat intervals | Reference & labels | Population | Licence & access | Size |
|---|---|---|---|---|---|---|---|
| [DREAMT](https://physionet.org/content/dreamt/) v2.2.0, 2 Jun 2026 | 100 / 100 | E4 ACC 32 Hz | E4 BVP (PPG) 64 Hz, IBI, HR 1 Hz; PSG ECG | Lab PSG; W/N1/N2/N3/R per 30 s | Duke sleep-clinic patients; mean age 56, mean AHI 22, 23 severe OSA | PhysioNet Restricted Health Data License 1.5.0; account + DUA | Not shown before access |
| [Wearanize+](https://pmc.ncbi.nlm.nih.gov/articles/PMC12888818/) v1.0 / OA v1.1 | 130 / 130 (manual scores for 103) | E4 ACC 32 Hz | E4 BVP 64 Hz (IBI derived); PSG ECG 256 Hz | Home PSG (SOMNOscreen plus); AASM 30 s, one expert scorer + U-Sleep | Healthy, 18–39, mean 23 | Research use only; full set by DUA, an OA subset without | Not stated |
| [sleep-accel (Walch)](https://physionet.org/content/sleep-accel/1.0.0/) v1.0.0 | 31 / 31 | Apple Watch ACC | **None**: HR in bpm only | Lab PSG; W/N1/N2/N3/REM | Adults, apnea excluded | ODC-By 1.0; open | 2.2 GB |
| [BIDSleep](https://physionet.org/content/bidsleep-dataset/) v1.0.1, 25 Sep 2026 | 253 / 47 | Apple Watch ACC (rate not stated) | **None**: instantaneous HR at ~0.2 Hz | **Dreem 2 EEG headband, not PSG**; AASM W/N1/N2/N3/REM, expert-corrected | Healthy adults | ODC-By 1.0; open | 27.9 GB |
| [MESA Sleep](https://pmc.ncbi.nlm.nih.gov/articles/PMC4434554/) (NSRR) | 2,060 PSG, 2,156 actigraphy | Actiwatch Spectrum **activity counts**, 30 s epochs | PSG ECG + finger pulse oximetry | Home PSG, 15-channel Compumedics Somte; rules adapted from SHHS | Community, 54–93, four ethnic groups | NSRR DAUA per dataset; MESA has commercial-use limits | Not verified |
| MrOS Sleep (NSRR) | ~3,135 at visit 1 | SleepWatch-O, PIM counts | PSG ECG | Home PSG (Compumedics Safiro) | Men 65+ | NSRR DAUA | Not verified |
| [HMC](https://physionet.org/content/hmc-sleep-staging/) v1.1, 18 Mar 2022 | 151 (148 after removals) | **None** | ECG lead II, 256 Hz | PSG; **AASM v2.4**, W/N1/N2/N3/R | Sleep-clinic patients, mean 54 | **CC BY 4.0**; open | 15.7 GB |
| [Challenge 2018](https://physionet.org/content/challenge-2018/1.0.0/) v1.0.0 | 1,985 (994 with public labels) | **None** | ECG 200 Hz | PSG; AASM W/N1/N2/N3/REM | MGH sleep-lab patients | **ODC-By 1.0**; open | 266.6 GB |
| [CAP](https://physionet.org/content/capslpdb/1.0.0/) v1.0.0 | 108 | **None** | ECG | PSG; **R&K** (S1–S4) | 16 healthy, 92 with epilepsy, RBD, PLM, insomnia etc. | ODC-By 1.0; open | 40.1 GB |
| [Sleep-EDF Expanded](https://physionet.org/content/sleep-edfx/1.0.0/) v1.0.0 | 197 | **None** | **None**: no ECG | PSG; R&K | Healthy, 25–101 | ODC-By 1.0; open | 8.1 GB |
| SHHS (NSRR) | ~5,600 people, 8,080 PSGs | **None**: no actigraphy listed | PSG ECG | Home PSG | Adults 40+ | NSRR DAUA | Not verified |

Sources for the NSRR rows: participant counts and which sets have actigraphy are from Table 1 of
[Zhang 2018](https://pmc.ncbi.nlm.nih.gov/articles/PMC6188513/), the NSRR paper. MESA
details are from [Chen 2015](https://pmc.ncbi.nlm.nih.gov/articles/PMC4434554/). MrOS details
are from its
[actigraphy protocol](https://agingresearchbiobank.nia.nih.gov/studies/mros/documents/download/Protocols/Sleep_V2/SleepV2_Actigraphy.pdf/)
and [a concurrent actigraphy/PSG paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC5430938).

### The two sets that match the Strap

**DREAMT** ([PhysioNet page](https://physionet.org/content/dreamt/))
- **Who:** 100 adults from the Duke University Health System Sleep Disorder Lab, recruited with
  no selection criteria. Mean age 56.2 ± 16.6, mean AHI 22.1 ± 28.7, 68 obese, 23 with severe
  OSA.
- **Wrist (E4 on the left wrist):** BVP 64 Hz, ACC 32 Hz, EDA 4 Hz, TEMP 4 Hz, IBI, and HR
  at 1 Hz.
- **PSG (Nihon Kohden):** EEG, EOG, EMG, ECG, respiration and SpO2.
- **Files:** `data_64Hz` holds the wrist signals only. `data_100Hz` holds wrist + PSG,
  resampled to 100 Hz.
- **Labels:** W, N1, N2, N3, R per 30 s, plus P (mapped to W) and Missing. The page does not
  name the AASM manual.
- **Version:** v2.2.0 (2 Jun 2026) fixed a misalignment between ACC and PSG. Anything built on
  an earlier version should be redone.
- **Licence:** [PhysioNet Restricted Health Data License
  1.5.0](https://physionet.org/content/dreamt/view-license/2.2.0/):
  - Clause 3: "will not share access … with anyone else".
  - Clause 6: "for the sole purpose of lawful use in scientific research and no other".
  - Clause 7: contribute code associated with publications to an open repository.
  - It says nothing about trained models.
- **Paper:** [Wang et al., CHIL 2024 (PMLR 248)](https://proceedings.mlr.press/v248/wang24a.html).
  A sleep/wake model on the E4 signals reached κ 0.695, F1 0.823.
- **Unofficial copy:** a Hugging Face mirror exists (`bsaenz/dreamt`). Don't use it: the
  licence forbids sharing access, so get the data from PhysioNet.

**Wearanize+** ([Sikder et al., *Sleep Advances* 2025, 7(1):zpaf094](https://pmc.ncbi.nlm.nih.gov/articles/PMC12888818/))
- **Who:** 130 healthy adults, one night each at home, after set-up in the lab. Ages 18–39,
  mean 23.2, 89 women.
- **Exclusions:** sleep disorders, sleep-affecting medication, and mainly sleeping on the
  stomach, among others.
- **Devices:**
  - Empatica E4 wristband: BVP 64 Hz, ACC 32 Hz, EDA 4 Hz, temperature 4 Hz. HR and IBI are
    derived from BVP.
  - Zmax headband (EEG, ACC, PPG at 256 Hz), ActivPAL leg patch.
  - PSG: SOMNOscreen plus with 2 ECG channels at 256 Hz, or, for 15 people, a Mentalab Explore
    Pro.
- **Labels:**
  - Manual AASM scoring per 30 s by one expert, for 103 of 118 PSG recordings.
  - Also U-Sleep v2.0 automatic scores. These agree with the manual scores at κ 0.769.
- **Versions** ([repo README](https://github.com/Niloy333/Wearanize_plus), code MIT):
  - Raw v1.0, and "PlugNPlay" v1.0, which is synchronised EDF covering 100 participants.
  - v1.0 states the accelerometer unit wrongly (g/16 instead of g/64); fixed in OA v1.1.
- **Access:**
  - The full collection
    ([Radboud Data Repository](https://data.ru.nl/collections/di/dcmn/DSC_wearanize_t0000657a_579))
    needs a DUA emailed to the PI (EEA and non-EEA templates), then a request on the
    repository through ORCID.
  - A separate **Wearanize+ OA** collection downloads without a DUA but leaves out the
    questionnaires.
  - Both "may only be used for scientific research purposes".
- **Licence:** Radboud's scientific-use DUA,
  [RU-HD-SU-1.0](https://data.ru.nl/dua/RU-HD-SU-1.0):
  - The user must be a "bona fide researcher working within a bona fide research organization".
  - No redistribution.
  - Credit is required for "results or algorithms that benefitted from their use".
  - Commercial use isn't addressed.
  - Unverified: that this is the DUA attached to Wearanize+, and the OA collection's exact
    licence. One aggregator says CC BY 4.0.

### Fully open sets, and what they can't do
- **Licences:** ODC-By 1.0 and CC BY 4.0 allow any use, commercial included, with attribution.
  Weights trained on these sets can ship in an MIT app if their source is credited.
- **sleep-accel and BIDSleep** have motion and heart rate, but no RR:
  - sleep-accel: HR in bpm from the Apple Watch.
  - BIDSleep: HR at ~0.2 Hz. It is also scored from a Dreem 2 EEG headband, which its own page
    says is not equivalent to PSG.
  - Both are good for sleep/wake from motion + HR, which the Strap's per-second HR matches.
  - BIDSleep also has 253 nights from 47 people, up to 7 nights each. That suits checking
    night-to-night stability.
- **HMC, Challenge 2018 and CAP** have PSG ECG, which gives RR intervals, but no wrist motion.
  - Challenge 2018's test labels are held back, so only the 994 training subjects are
    labelled.
  - CAP uses R&K, so S3+S4 would have to be merged into N3. Most of its subjects are patients.
- **Sleep-EDF** has neither ECG nor wrist motion. Not useful here.
- **The catch with ECG data:** RR intervals from a chest ECG are cleaner than the Strap's, which
  come from wrist PPG. Moving an ECG-trained staging algorithm straight onto reflective PPG
  lowered its performance
  ([van Gilst 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7653690/)). Transfer learning
  recovered most of it ([Radha 2021](https://pmc.ncbi.nlm.nih.gov/articles/PMC8443610/), κ 0.65).

### NSRR (MESA, MrOS, SHHS)
- **Size:** MESA is the largest set with wrist actigraphy plus PSG: 2,060 PSG and 2,156
  actigraphy participants, 2010–13
  ([Chen 2015](https://pmc.ncbi.nlm.nih.gov/articles/PMC4434554/)).
- **Wrist data:** Actiwatch Spectrum activity counts per 30 s, scored by Actiware, not a raw
  accelerometer. Walch 2019 used 188 MESA participants this way.
- **Its PSG:** has ECG and finger pulse oximetry. A 2026 PPG-staging benchmark uses MESA as its
  main training set ([Zheng et al., arXiv 2608.00943](https://arxiv.org/abs/2608.00943)).
- **Access:** an NSRR account plus a data access and use agreement (DAUA) per dataset, with IRB
  review tracked in the portal ([Zhang 2018](https://pmc.ncbi.nlm.nih.gov/articles/PMC6188513/)).
- **Commercial use** (leads only, from the NSRR forum, not checked against the DAUA text):
  - MESA has commercial-use restrictions; a "mesa-commercial-use" approval covers only
    consenting participants.
  - SHHS's DAUA bars incorporating the data into a product
    ([forum thread](https://sleepdata.org/forum/scope-of-commercial-use-shhs)).
  - Other NSRR sets differ: STAGES allows commercial use; NCH and NFS are non-commercial only.

## Open / uncertain
- **Whether trained weights count as "use of the data" under the PhysioNet Restricted and
  Radboud agreements.** Neither text mentions models. Serenix is free and MIT, but an app is
  not plainly "scientific research". Only the data owners can settle this. Not legal advice.
- **Download sizes** of DREAMT, Wearanize+ and MESA aren't shown without access. DREAMT's
  100 Hz PSG+E4 folder is likely tens of GB, but that is an estimate.
- **sleepdata.org could not be read** from this environment: the TLS certificate failed. So the
  MESA/MrOS/SHHS DAUA texts, current file sizes and the exact MESA staging rules are not
  checked first-hand. The NSRR forum also carries a banner saying the repository is "under
  review for potential modification", so its terms may change.
- **How much N3 and REM DREAMT holds.** Not checked. Older patients with apnea usually have
  little N3, which is why Wearanize+ is the reference for deep sleep.
- **E4 IBI vs the Strap's RR.** The E4 drops beats it can't detect cleanly, and the Strap gives
  RR for ~70% of beats (previous note). Whether they lose beats the same way is unknown.
  Compare one of the owner's Nights before relying on either set.
- **Whether Wearanize+ OA is the same as the PlugNPlay subset**, and whether its manual scores
  (two score channels in v1.1) cover all 100 participants.
- **The accuracy bar:** none of these sets scores a WHOOP 5.0 Strap, so the published κ values
  (WHOOP 0.44–0.48, see the previous note) were measured on different sets from any bar set
  on DREAMT or Wearanize+.
