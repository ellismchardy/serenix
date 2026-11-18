# 019 — Sleep accuracy harness

**Status:** built
**Last updated:** 2026-11-18 (Walch input limited to 12 h either side of the PSG)
**Issue:** https://github.com/ellismchardy/serenix/issues/82 (sleep accuracy map, #78; decisions
in #81)

## Problem
Serenix's sleep/wake labelling (spec 003) was ported from hr-tracker, whose constants were set by
eye on two nights. Nobody knows how well it finds wake: published actigraphy rules catch 90%+ of
sleep but only 30–55% of wake (`docs/research/sleep-wake-and-sleep-stages.md`). The sleep
accuracy map's next decisions — better sleep/wake labelling, the Wake Bout and Time Asleep rule,
and later sleep stages — all need a measuring stick before any rule changes, or a "better" rule
is just a different guess.

## Goal
A developer can score Serenix's sleep/wake labelling against sleep-lab Reference Nights (Walch's
open dataset first), and see on the owner's own Strap nights how far Tilt-based results move from
the quaternion-based ones the app uses, with reports that compare labellers like for like.

## User stories
1. As the developer, I want to run today's labelling on the Walch Reference Nights and get pooled
   κ and Time Asleep bias, so that the labelling ticket has a baseline to beat.
2. As the developer, I want to sweep the Tilt threshold and see one row per threshold, so that
   the 2° figure set for the Strap's quaternion isn't carried blindly to a different signal.
3. As the developer, I want the same numbers for the visible verdict and for the raw minute
   labels, so that a change to the labelling and a change to the Wake Bout rule can each be
   judged on its own layer.
4. As the developer, I want to see, on the owner's Strap nights, how far Time Asleep, Sleep
   Onset and Final Wake move between the quaternion turn and Tilt, so that a Walch score can be
   read as a statement about the shipped app.
5. As the developer, I want Reference Nights with too little usable data left out and listed,
   not silently scored as errors or silently dropped.
6. As the Strap owner, I want the app's Nights to stay exactly as they are, so that building a
   measuring tool changes nothing I see.

## Behavior

**Labelling input.** Serenix's sleep/wake labelling works on a per-second series: for each
second, its UTC time, its heart rate (optional) and a motion angle in degrees (optional; empty
when the second before is missing or more than 2 s earlier). A second is active when its angle
exceeds the threshold (2° in the app). Everything else — wake minutes, the heart-rate extension,
the Sleep Period, Time in Bed — is spec 003's rule unchanged. A minute's mean heart rate is over
its seconds that have one. In the app the series comes from History Records, with the angle being
the quaternion turn, so every Night comes out exactly as before.

**Reference Nights and Epochs.** A dataset adapter turns one recording into a Reference Night: the
per-second series, plus the PSG label of each 30-second Epoch (wake, N1, N2, N3 or REM, or
unscored). The Walch adapter (sleep-accel 1.0.0):
- places PSG time 0 on a whole UTC minute, so every Serenix minute covers exactly two Epochs;
- bins acceleration into whole seconds, takes each axis's median, normalises it to a gravity
  direction, and sets the second's angle to the Tilt from the previous second (empty if that
  second has no samples);
- gives each second the last heart-rate reading from up to 15 s before it, and none after that;
- keeps the seconds from 12 h before PSG time 0 to 12 h after the end of the last Epoch,
  including those before the PSG starts, and drops the rest. Some Walch recordings run for days
  before or after their PSG; without this the labeller could pick its Sleep Period on another
  night, which the app never does (it looks for one Night per Night window). Walch gives no
  calendar dates, so the span can't be the Night window itself;
- maps label 0 to wake, 1 to N1, 2 to N2, 3 and 4 to N3, 5 to REM, and −1 to unscored.

**What is compared.** The labeller runs on the whole series; only some Epochs are compared. An
Epoch is compared when PSG scored it and its Serenix minute has data (≥ 30 seconds). Each Serenix
minute's label covers both of its Epochs. A Reference Night is left out when fewer than 90% of its
scored Epochs are compared, and the report lists it with its coverage.

Two layers are scored on every Reference Night:
- **Visible verdict** (the headline): an Epoch is asleep when its minute is inside the Sleep
  Period and labelled sleep; everything else is wake. A Reference Night with no Sleep Period is
  all wake.
- **Raw labels**: each minute's own sleep/wake label, wherever it falls.

**Per Reference Night**, for each layer: sensitivity (PSG sleep Epochs scored asleep),
specificity (PSG wake Epochs scored wake), accuracy and Cohen's κ, all over compared Epochs; and,
for the visible verdict only:
- Time Asleep bias: Serenix's Time Asleep minus PSG's (sleep Epochs × 30 s), in minutes;
- WASO bias: Serenix's wake minutes inside its Sleep Period minus PSG's wake Epochs between its
  Sleep Onset and Final Wake, in minutes;
- Sleep Onset error and Final Wake error, Serenix minus PSG, in minutes. PSG's Sleep Onset is
  the start of its first sleep Epoch; its Final Wake is the end of its last. Empty when Serenix
  found no Sleep Period;
- Wake Bout count and mean Wake Bout length, Serenix's and PSG's side by side. PSG's Wake Bouts
  are its runs of wake Epochs between its Sleep Onset and Final Wake, with no minimum length.

**Pooled.** Sensitivity, specificity, accuracy and κ over all compared Epochs of all kept
Reference Nights, per layer. Time Asleep bias: mean, SD and Bland–Altman 95% limits (mean ±
1.96 SD). Every other error: mean and SD over the Reference Nights that have it. **Headline:**
pooled κ of the visible verdict, with mean Time Asleep bias beside it.

**Threshold sweep.** Given a list of thresholds, the harness scores each one and writes one row
per threshold: pooled κ, sensitivity, specificity and mean Time Asleep bias (visible verdict).
The row with the highest pooled κ is marked best (the lowest threshold on a tie), and the full
report is written for it.

**Strap transfer run.** For History Record files in the fixture CSV format, the harness builds
two series per night: one with the quaternion turn (the app's) and one with Tilt (the vertical
rotated by each record's quaternion, angle between successive seconds). Per night it reports: the
share of seconds active by the turn (above 2°) that are also active by Tilt (above the chosen
threshold); the share of minutes whose active/not-active call agrees (a minute is active at ≥ 10
active seconds); and Time Asleep, Sleep Onset and Final Wake from each series, with the
differences in minutes. There is no Reference Night, so no κ.

**Reports.** Each run writes a Markdown summary and a JSON file with the same numbers into the
output folder. Both are stamped with the labeller name, its threshold(s), the dataset, the
command line and the git SHA (`git rev-parse HEAD`, or "unknown" when git can't be run). The
Markdown has: the headline, the pooled table for both layers, the per-Reference-Night table, the
sweep table when there is one, and "Reference Nights left out" with each one's coverage.

**Command line** (developer machine only, never CI):
- `sleep-accuracy walch --data <dir> --out <dir> (--threshold <deg> | --sweep <deg,…>)`
- `sleep-accuracy strap --data <dir> --out <dir> --threshold <deg>`

`--data` and `--out` are required. A missing or unreadable folder, or a Walch recording missing
one of its three files, stops the run with a message naming it; it never writes a partial report.

## Design decisions
- **A public labeller seam in `SerenixCore`.** A per-second labelling input type and a sleep/wake
  labeller that turns it, with a threshold, into per-minute labels and an optional Sleep Period
  (with Time in Bed and Wake Bouts). Today's rule is the first labeller. The Night-building path
  builds the input from History Records with the quaternion turn and calls the same labeller; it
  stays internal otherwise. A Tilt-from-quaternion function sits beside the turn function in
  `SerenixCore` for the Strap transfer run.
- **A `SleepAccuracy` library target**, Foundation only, depending on `SerenixCore`: Reference
  Night and Epoch types, one adapter per dataset (Walch, and the Strap fixture-CSV reader), the
  scorer (Reference Nights + labeller + threshold → a report value), the sweep, the Strap transfer
  comparison, and Markdown/JSON rendering of the report value.
- **A thin `sleep-accuracy` executable**: argument parsing, reading folders, running git for the
  SHA, writing the two files. No decisions in it.
- **Tests in `SleepAccuracyTests`**, part of `swift test` and CI, on small made-up inputs only.
  The real datasets live outside the repo and are never committed; summaries of chosen runs may
  be committed under `docs/research/sleep-accuracy/`, per-Epoch labels never.
- Stage labels are kept on each Epoch so the sleep stages spec can add stage scoring without a
  new adapter; this spec scores sleep/wake only.
- No ADR: the tool is developer-only and the seam is easy to change (decided in #81).

## Seams under test
- **Labeller seam (`SerenixCore`)** — per-second input → minute labels and Sleep Period. Catches
  the rule, gaps in the angle, the threshold and heart-rate handling. Misses file parsing.
- **History Records → Night (spec 003's existing seam)** — catches any change the refactor makes
  to the app's Nights. Adds nothing new.
- **Harness library (`SleepAccuracy`)** — adapter: files → Reference Nights; scorer: Reference
  Nights + labeller → report value, and its Markdown/JSON. Catches Epoch alignment, exclusions,
  κ and the biases, the sweep, the transfer comparison and report content. Misses the real
  datasets' scale and quirks, which the by-hand Walch run covers.

## Success criteria (must be checkable)
Labeller seam and app:
- [x] Every existing `SerenixCoreTests` test passes unchanged (none edited or removed).
- [x] The 29–30 Oct 2026 fixture night, turned into the labelling input with the quaternion turn
      and labelled at 2°, gives the same Sleep Onset, Final Wake, Time in Bed and Time Asleep as
      spec 003's Night for that date.
- [x] A labelling input whose seconds each have an angle of 2.0° labels every minute sleep at
      threshold 2°, and every minute wake at threshold 1.9°.
- [x] A second whose angle is empty is never active, whatever the threshold.
- [x] A minute with 29 seconds has no data; with 30 it has.
- [x] Tilt from quaternion: a rotation of 30° about the vertical between two seconds gives a Tilt
      of 0° (and a turn of 30°); a rotation of 30° about a horizontal axis gives a Tilt of 30°.

Walch adapter:
- [x] Acceleration with gravity along z in second 0 and along x in second 1 gives second 1 a
      Tilt of 90°; a second with no samples has no angle, and nor does the second after it.
- [x] Heart-rate readings at PSG time 0 s (60 bpm) and 20 s (70 bpm) give seconds 0–15 60 bpm,
      seconds 16–19 none, and second 20 70 bpm.
- [x] Labels 0, 1, 2, 3, 4, 5 and −1 become wake, N1, N2, N3, N3, REM and unscored.
- [x] PSG time 0 falls on a whole UTC minute: the Epochs at 0 s and 30 s share one Serenix minute.
- [x] Seconds before PSG time 0 are kept in the labelling input.
- [x] Seconds more than 12 h before PSG time 0, or more than 12 h after the end of the last Epoch,
      are not in the labelling input; seconds exactly 12 h either side are.
- [x] A recording missing its labels file stops the run with a message naming the recording, and
      no report is written.

Scorer:
- [x] Four compared Epochs, PSG sleep/sleep/sleep/wake against Serenix sleep/sleep/wake/wake, give
      sensitivity 0.667, specificity 1.000, accuracy 0.750 and κ 0.500.
- [x] A Serenix minute labelled sleep counts as sleep for both of its Epochs.
- [x] Unscored Epochs, and Epochs whose minute has no data, are not compared.
- [x] A Reference Night with 89% of its scored Epochs compared is left out and listed with
      "89%"; one with 90% is kept.
- [x] A sleep-labelled minute outside the Sleep Period is wake in the visible verdict and sleep in
      the raw labels.
- [x] A Reference Night where Serenix finds no Sleep Period scores all Epochs wake, has Time Asleep
      0, and empty Sleep Onset and Final Wake errors that the pooled means skip.
- [x] PSG sleep from Epoch 2 to Epoch 9 (0-based) with wake at Epochs 5 and 7 has Sleep Onset at
      60 s, Final Wake at 300 s, 2 Wake Bouts of 0.5 min each, and 3.0 min Time Asleep.
- [x] Time Asleep biases of +10 and −10 minutes pool to mean 0.0, SD 14.1 and limits −27.7 to
      +27.7 minutes.
- [x] A sweep over 1.0, 2.0 and 3.0 writes three rows and marks the highest-κ row best; two rows
      tied on κ mark the lower threshold.

Strap transfer run:
- [x] On a hand-built night where every turn is a rotation about the vertical above 2°, every
      turn-active second is missed by Tilt (share 0%), and the turn series has more wake minutes.
- [x] The run reports Time Asleep, Sleep Onset and Final Wake from both series and their
      differences in minutes.

Reports and tooling:
- [x] The Markdown and JSON from one run hold the same numbers, and both carry the labeller name,
      threshold(s), dataset, command line and git SHA ("unknown" when git can't be run).
- [x] The Markdown has the headline, both layers' pooled tables, the per-Reference-Night table,
      the sweep table (when swept) and "Reference Nights left out".
- [x] `sleep-accuracy` with no `--out` exits non-zero with a usage message and writes nothing.
- [ ] `swift test`, `swift format lint --strict --recursive src tests Package.swift` and
      `swift build` pass on Linux, and the macOS CI job builds the app.
- [x] By hand: `sleep-accuracy walch` on the downloaded sleep-accel 1.0.0 nights with a sweep
      writes a report covering every recording, kept or left out (posted on #82 as the baseline).
- [x] By hand: `sleep-accuracy strap` on the two fixture nights writes a transfer report.

## Non-goals (explicitly out of scope)
- Changing how the app labels sleep or wake, or any constant (the labelling ticket, #83).
- Changing the Wake Bout or Time Asleep rule (#84).
- Scoring sleep stages, or stage confusion matrices (the sleep stages spec).
- DREAMT and Wearanize+ adapters (once access is granted).
- Exporting more History Records from the phone for the Strap run.
- Running the harness on datasets in CI, or committing any dataset or per-Epoch labels.
- Settling whether the Strap's four floats are a quaternion (separate test on the Strap).

## Open questions
- **Walch file layout.** Assumed from sleep-accel 1.0.0's description: `motion/<id>_acceleration.txt`
  (time s, x, y, z in g, space-separated), `heart_rate/<id>_heartrate.txt` (time, bpm,
  comma-separated) and `labels/<id>_labeled_sleep.txt` (time, label, space-separated), times in
  seconds from PSG start. The first plan task checks this against a downloaded copy and corrects
  the adapter's made-up test files to match.
- **Label times off the 30-s grid.** Assumed none; the adapter rejects a recording whose label
  times aren't whole multiples of 30 s, naming it, rather than guessing an alignment.

## Notes
- Decisions: #81 (What the accuracy harness measures and reports); #79 (Walch motion → Tilt);
  #80 (datasets). Map: #78.
- Research: `docs/research/sleep-wake-and-sleep-stages.md`,
  `docs/research/walch-motion-for-serenix-motion-rule.md`,
  `docs/research/open-psg-datasets-with-wrist-signals.md`.
- Spec 003 (Nightly Metrics) holds the labelling rule this spec leaves unchanged.
