# 014 — Onboarding

**Status:** approved
**Last updated:** 2026-11-04

## Problem
A new Serenix user opens the app to a one-question name prompt (spec 002) and then a Today screen
with nothing on it. Nothing tells them what Serenix is, that their Strap has to be paired, that
the WHOOP app can hold the Strap's connection, or that Load needs their birth year. Birth year,
sex and Max HR sit in the profile menu (spec 005), where a new user won't look. The repo is
public, so people other than the owner will install it: first launch is the first impression.

## Goal
On first launch, Serenix holds a short conversation that explains itself, fills in the Profile,
pairs the Strap and starts the first History Sync, then hands over to the Today screen.

## User stories
1. As a new user, I want Serenix to tell me in a sentence or two what it does and that my data
   stays on my phone, so that I know what I've installed.
2. As a new user, I want to give my name, birth year, sex and Max HR by answering questions, so
   that I'm greeted by name and Load works from day one.
3. As a new user who doesn't know my Max HR or would rather not give my birth year or sex, I want
   to skip each question, so that I'm not stuck.
4. As a new user, I want to pair my Strap as part of the conversation and see my first History
   Sync start, so that I know it's working.
5. As a new user whose Strap isn't found or whose pairing fails, I want to be told why in plain
   words and to try again, so that I can fix it myself.
6. As a new user without my Strap to hand, I want to set it up later, so that I can still look
   around the app.
7. As a new user who closes the app halfway, I want to pick up where I left off, without
   retyping what I already answered.
8. As an existing user, I never want to see Onboarding.

## Behavior
**When it shows.** On launch, if Onboarding isn't finished, Serenix shows it instead of the
Today screen. It is finished when the user taps **Show me Today** or **Set up later** (below),
and it never shows again after that. It also counts as finished, and never shows, when the
NamePrompt of spec 002 was ever answered or any History Sync has completed: existing users skip
it. Onboarding replaces the NamePrompt, which is removed.

**Shape.** A conversation (prototype variant C): Serenix's lines are bubbles on the left, the
user's answers are bubbles on the right, and the current question's answer controls sit pinned at
the bottom (a text field with Send, and/or chips). Earlier bubbles can't be tapped or changed:
everything can be edited later in the profile menu. Serenix's bubbles use the Profile name once
it's given.

**The conversation, in order:**
1. **Hello.** "Hi! I'm Serenix. I read your Whoop Strap over Bluetooth and work out your sleep,
   Readiness and Load — all on this phone." Then "Serenix isn't affiliated with WHOOP, Inc."
2. **Name.** "What should I call you?" — a name field with Send, and a **Skip** chip. The name is
   trimmed; a blank name counts as Skip. The user's bubble shows the name, or "Skip".
3. **Birth year.** "Nice to meet you, <name>." (or "Nice to meet you." with no name) then "What
   year were you born? It sets how much sleep you need and estimates your Max HR." — a numeric
   field with Send, and a **Rather not** chip. Accepted: 100 years ago to 13 years ago (spec
   005's range). Anything else gets "I didn't get that — a year like 1992?" and the same question
   stays open.
4. **Sex.** "Which sex should I use for heart-rate calculations?" — chips **Female**, **Male**,
   **Prefer not to say**.
5. **Max HR.** "Do you know your Max HR from a test?" — a numeric field with Send, and a
   **Don't know** chip. Accepted: 100 to 230 bpm (spec 005). Out of range gets "I didn't get
   that — a number of beats per minute, like 185?" and the question stays open.
6. **Pair.** "Last thing: let's find your Strap. Put it on and keep your phone close." — chips
   **Find my Strap** and **Set up later**.
   - Finding: a "Looking for your Strap…" bubble while Serenix scans and connects as in spec
     001. iOS shows its own pairing prompt if the phone isn't already paired.
   - **Not found** (scan or connect fails): "I couldn't find your Strap. Make sure it's charged
     and close by, and that the WHOOP app isn't connected to it — close it, or turn off its
     Bluetooth access." Chips **Try again** and **Set up later**.
   - **Pairing refused or subscribing fails**: "Pairing didn't finish. Put your Strap in pairing
     mode and try again — it stays in pairing mode for a minute or two." (spec 001's advice).
     Chips **Try again** and **Set up later**.
   - **Connected**: "Found it — <model>." then the first History Sync starts at once.
7. **Syncing.** "Pulling in your history now. Readiness needs 4 Nights to calibrate, so it'll
   say Calibrating for the first few days." A bubble shows the sync's progress (spec 001's
   progress) and turns into "✓ Synced" when the sync completes. A **Show me Today** chip is
   offered at once; tapping it before the sync ends goes to Today, where the sync keeps running
   and the sync pill (spec 002) takes over. If the sync fails, the bubble says so and **Show me
   Today** stays; Today's sync pill shows the failure as for any sync.

**Set up later** finishes Onboarding and goes to Today; pairing is then done as today, from the
sync pill or Sync now.

**Saving as it goes.** Each answer is saved to the Profile the moment it's given (name, birth
year, sex, Max HR, as in specs 002 and 005; a Skip/Rather not/Don't know leaves that field
unset). Setting birth year, sex or Max HR queues Days for Load as spec 005's Profile changes say.
If Serenix is closed before Onboarding finishes, it starts again from Hello on next launch; the
questions already answered show their saved answer as the user's bubble and are not asked again;
the conversation resumes at the first unanswered step.

**Privacy.** Nothing in Onboarding is sent anywhere. The Profile's fields stay out of the Sync
Log, shared logs and reports, as before.

## Design decisions
- **`SerenixCore`: the Onboarding conversation.** A pure value type: given the saved answers so
  far and the pairing/sync state, it returns the bubbles to show (who said what, in order) and
  the answer controls on offer (field kind with its placeholder, and chips). Events go in as
  values (an answer typed, a chip tapped, pairing found/not found/refused/connected, sync
  progress/completed/failed) and it returns the next state plus the Profile change to save, if
  any. It owns the wording, the order, validation of birth year and Max HR against the current
  year (passed in), resuming from saved answers, and when Onboarding counts as finished.
- **iOS shell: Onboarding screen.** SwiftUI draws the bubbles and controls, sends taps and text
  back, saves Profile changes through the Profile store, drives the Strap connection and the
  History Sync as spec 001 does, and stores the "Onboarding finished" flag on the phone. The
  NamePrompt and its "asked for name" flag are removed; an existing answered flag counts as
  finished.
- No new ADR: nothing here is hard to reverse.

## Seams under test
- **The Onboarding conversation (`SerenixCore`)** — catches wording, order, validation, skips,
  pairing error paths, resume after a relaunch, and the finished rule; misses SwiftUI layout,
  real CoreBluetooth and iOS's pairing prompt, which are checked by hand on a phone (ADR 0002).

## Success criteria (must be checkable)
- [ ] A fresh conversation shows the Hello bubbles then "What should I call you?" with a name
      field and a Skip chip.
- [ ] Answering "  Ellis " saves the name "Ellis" and the next bubble is "Nice to meet you,
      Ellis."; Skip (or a blank name) saves no name and says "Nice to meet you."
- [ ] Birth year: with the current year 2026, 1926 and 2013 are accepted and saved; 1925, 2014
      and "abc" give "I didn't get that — a year like 1992?" and keep the question open; Rather
      not saves no birth year and moves on.
- [ ] Sex: each of the three chips saves that sex and moves on.
- [ ] Max HR: 100 and 230 are accepted; 99, 231 and "abc" give the out-of-range bubble and keep
      the question open; Don't know saves no Max HR.
- [ ] At the pair step, Find my Strap shows "Looking for your Strap…"; not found gives the
      WHOOP-app advice with Try again and Set up later; refused gives the pairing-mode advice with
      the same chips; Try again goes back to Looking.
- [ ] Connected shows "Found it — <model>." and the Syncing bubble with Show me Today offered at
      once; sync progress 0.4 shows 40%; completed shows "✓ Synced"; failed says so and Show me
      Today stays.
- [ ] Show me Today and Set up later each mark Onboarding finished; nothing else does.
- [ ] Resuming with a saved name and birth year opens with Hello, the two saved answers as the
      user's bubbles, and the Sex question open.
- [ ] Onboarding counts as finished when the old NamePrompt was answered or a History Sync has
      completed.
- [ ] `swift test` passes.
- [ ] On a phone (by hand): a fresh install opens to Onboarding, not Today; going through it with
      the Strap pairs it, starts the sync and lands on Today with the name in the greeting and
      Load worked out from the birth year; closing the app at the Sex question and reopening
      resumes there; with the WHOOP app connected to the Strap, Find my Strap shows the
      not-found advice; Set up later lands on an empty Today; reopening after finishing never
      shows Onboarding; updating an existing install (NamePrompt answered) goes straight to Today.

## Non-goals (explicitly out of scope)
- The Apple Health permission step: added by the Health export spec when that exists.
- Explainer screens or a tour of the Today screen.
- Editing earlier answers inside the conversation (the profile menu does that).
- Choosing among several Straps in range: the first Whoop 5.0 found is used, as in spec 001.
- Redoing Onboarding (a "Replay onboarding" option).

## Open questions
- None outstanding. Assumption: the validation ranges follow spec 005's profile menu (birth year
  100 to 13 years ago, Max HR 100–230), not the rougher figures floated while grilling.

## Notes
- Prototype: branch `prototype/onboarding`, `src/SerenixApp/Prototype/onboarding-prototype.html`,
  variant C (Conversation) chosen over a paged wizard, a setup checklist and pair-first.
- Replaces spec 002's NamePrompt (Profile section); spec 002 is changed to point here when this
  ships.
- Related: spec 001 (pairing, sync, progress), spec 005 (birth year, sex, Max HR).
