# Hybrid 12 iOS Build Spec

Nov 1, 2026 · Brandon Zieske

> Converted from the PDF. The exercise library, engine workouts and finishers tables are stored word for word in `Engine/Resources/*.json`, so they aren't repeated here.

## Overview

Hybrid 12 is a 12-week home-gym program app that picks each session, suggests every weight, and adjusts the plan from what you log. This spec captures every rule from the current web version (live since 2026-09-28) so a native SwiftUI app can match it exactly, then adds new adaptive features.

**Assumption:** built for one user first (Brandon), but equipment, goals and exercise data live in data files, not code, so it can become a multi-user product later without a rewrite.

**v1 (parity):** Today, Progress and Plan tabs; session builder; weight suggestions; progression; warm-up ramp; rest timer; weigh-ins, waist, cardio; coach check; iCloud sync.

**v2 (adaptive upgrades):** time-boxed sessions, effort-based progression (RIR), fatigue-triggered back-off weeks, missed-day re-entry, HealthKit readiness, nutrition guidance, equipment profiles.

**Migration:** the web app's data (lifts, history, weigh-ins, waist, cardio, current week) can be exported as JSON and imported on first launch.

## Program structure

A cycle is 12 weeks in three 4-week phases; weeks 4 and 8 are back-off (deload) weeks, and week 13 starts cycle 2 with the same structure and carried-over weights.

| Phase | Weeks | Focus |
|---|---|---|
| Foundation | 1-4 | Heavier compound lifts, clean technique, set baseline numbers |
| Build | 5-8 | More sets and supersets; extra shoulder, chest, arm and back volume |
| Define | 9-12 | Faster pace, shorter rest, longer finishers; lean out, hold muscle |

Derived from the stored absolute week number `week` (starts at 1, never resets):

- `wk = ((week - 1) % 12) + 1`
- `cycle = floor((week - 1) / 12) + 1`
- `phase = wk <= 4 ? 0 : wk <= 8 ? 1 : 2`
- `isDeload = wk == 4 || wk == 8`

### Sessions

| Day | Slot | Name | Main lift (F / B / D) | Superset pairs |
|---|---|---|---|---|
| 1 | B | Upper Physique | OHP / Incline Bench / Push Press | delt+bicep, chest+tricep, delt+tricep |
| 2 | C | Conditioning | none (Engine workout) | core+core (1 pair only) |
| 3 | A | Heavy Lower | Squat / Squat / Squat | hinge+core, quad+core, quad+hinge |
| 4 | D | Heavy Upper | Bench / Bench / Floor Press | row+bicep, row+tricep, delt+chest |
| 5 | E | Full-Body Lean-Out | Deadlift / Deadlift / Deadlift | full+row, quad+core, full+chest |
| + | R | Easy Run (optional) | none | none |

- `ORDER = [B, C, A, D, E]`; `LOWER = [A, E]`.
- Sessions are done in order on any days. Completing all five advances the week. Four done shows a "Start next week" link.
- The run (R) never counts toward the five and never advances the week.
- **Skip** marks a slot done with no log.

## Set and rep schemes

| Phase | Main sets × reps | Main rest | Accessory sets × reps | Accessory rest | Timed holds (sec) | Superset pairs |
|---|---|---|---|---|---|---|
| Foundation | 4 × 5 | 2:30 | 3 × 10-12 | 1:15 | 30-45 | 2 |
| Build | 4 × 6-8 | 2:00 | 4 × 10-15 | 1:00 | 40-60 | 3 |
| Define | 3 × 6 | 1:30 | 3 × 12-15 | 0:45 | 45-60 | 2 |

Modifiers:

- **Deadlift:** main sets minus 1.
- **Readiness Great:** main sets plus 1.
- **Readiness Beat up or deload week:** main sets minus 1; accessory sets minus 1 on deload weeks.
- **Readiness Beat up:** skips all accessory supersets (short day). Finishers and conditioning use half the rounds, rounded up. Runs drop 10 min (minimum 15).
- **Carries (yd unit):** fixed 40 yd per set.
- **Conditioning slot (C):** always 1 core pair regardless of phase.
- **Define phase:** finisher rounds × 1.3, rounded up.

## Exercise library

8 main barbell lifts and 46 accessories in 9 categories, shipped as bundled `exercises.json` so new moves need no code change. Equipment: bb = barbell, db = dumbbell, kb = kettlebell, bw = bodyweight. Increment applies to barbell lifts only (dumbbells default to 5 lb). Order within a category matters because rotation walks the list. See `Engine/Resources/exercises.json`.

Engine workouts (Conditioning slot): rounds by phase (F / B / D) and minutes per round. See `Engine/Resources/engine.json`.

Finishers (by slot): default minutes per round is 2 when not set. See `Engine/Resources/finishers.json`.

**Easy Run:** conversational pace on trails or treadmill; slow down or walk if you cannot talk in full sentences. Starts at 25 min, unit is minutes, logs distance in miles and an effort rating (Felt easy / Solid / Too hard).

## Session builder

A pure function: (slot, week, readiness, swaps, history) in, an ordered list of blocks out.

**Inputs:** `slot`, `wk`, `cycle`, `phase`, `isDeload`, `readiness` (great / normal / beat), and the draft's `swaps`, `condSwap`, `finSwap`.

**Rotation seed:** `seed = (wk - 1) + (cycle - 1) * 5 + indexOf(slot in "ABCDER") * 2`.

**Picking an accessory:** `pick(category, n, used)` walks the category list starting at `n % count` and returns the first exercise not already in this session. For pair `pi` (0-based) and position `ci` (0 or 1), `n = seed + pi + ci * 3`. A user swap for that position overrides the pick.

**Blocks, in order:**

1. **Get strong** (slots with a main lift): one main-lift item using the phase scheme and modifiers.
2. **Engine** (slot C only): index = `(condSwap ?? (wk - 1 + cycle - 1)) % 6`. Rounds = phase value, halved and rounded up on a Beat-up day.
3. **Run** (slot R only): minutes = `run.min` (default 25); Beat-up day = `max(15, run.min - 10)`.
4. **Build the look** (skipped on Beat-up days): pair count = 1 for C, else 3 in Build and 2 otherwise. Each item gets accessory sets (minus 1 on deload), the phase rep range (timed holds and carries use their own ranges), the phase rest, and a tag like B1, B2, C1 (letters start at B when there is a main lift).
5. **Burn it** (slots A, B, D, E): finisher index = `(finSwap ?? (wk - 1)) % 3`. Rounds × 1.3 in Define, halved on Beat-up days.

**Swaps:** an accessory Swap moves to the next exercise in the same category not already in the session. Engine and finisher Swaps increment their index. Swaps live on the draft, so they reset when the session is finished.

**Draft:** the in-progress session (slot, readiness, entries per item, warm-up ticks, swaps) is saved on every change and survives app restarts. It is discarded when the week changes or the user picks a different slot. Changing readiness clears any items with no completed sets so weights recalculate.

## Weight suggestions

Every weighted item gets a suggested weight and a one-line reason, chosen by the first rule below that applies.

**Estimated one-rep max** (Epley, reps capped at 12): `e1RM = w × (1 + min(r, 12) / 30)`.

`best1RM(id)` = the highest e1RM across the last 3 history entries that have both weight and reps.

**Weight for a rep target** (about 2 reps in reserve): `w = e1RM / (1 + (reps + 2) / 30)`.

### Suggestion order (weighted, non-kettlebell)

1. Stored working weight exists and the last history entry used the same top rep target: use the stored weight. Reason: "Last time W × R" plus "You earned the bump", "Reset lower to build back" or "Same weight, beat your reps".
2. `best1RM` exists: weight for the current top rep target.
3. A related lift has history: its e1RM × ratio, then weight for reps. "Estimated from your X."
4. Stored weight only: "Last used W lb."
5. Nothing: blank, "Pick a weight you could lift for 2 more reps than the target."

### Related-lift ratios

| Lift | Estimated from | Ratio |
|---|---|---|
| Front Squat | Back Squat | 0.80 |
| Back Squat | Front Squat | 1.25 |
| Incline Bench | Bench | 0.82 |
| Floor Press | Bench | 0.90 |
| Bench | Incline Bench | 1.22 |
| Push Press | OHP | 1.20 |
| OHP | Push Press | 0.83 |
| Romanian Deadlift | Deadlift | 0.60 |
| Hip Thrust | Deadlift | 0.80 |
| Good Morning | Back Squat | 0.35 |
| Barbell Row | Pendlay Row | 1.05 |
| Pendlay Row | Barbell Row | 0.95 |
| DB Incline Press | DB Floor Press | 0.90 |
| DB Floor Press | DB Incline Press | 1.10 |
| DB Arnold Press | Seated DB Press | 0.85 |
| Seated DB Press | DB Arnold Press | 1.15 |
| DB Curl | Hammer Curl | 0.95 |
| Hammer Curl | DB Curl | 1.05 |
| Bulgarian Split Squat | Split Squat | 0.85 |
| Split Squat | Bulgarian Split Squat | 1.15 |
| Chest-Supported Row | One-Arm DB Row | 0.80 |
| One-Arm DB Row | Chest-Supported Row | 1.20 |

### Clamping to real equipment

- Round to the nearest 5 lb.
- Barbell: minimum 45.
- Dumbbell: 5 to 35.
- Kettlebell: snap to a bell, 43 and up = 50, 28 and up = 35, else 20.

### Kettlebells

- Bells are 20, 35 and 50 lb. Tapping the bell cycles 20, 35, 50 and applies the change to that set and later unfinished sets.
- Default start: 50 for Heavy Swing, Swing, Goblet Squat, Suitcase Carry and Gorilla Row; 20 for Bottoms-Up Press; 35 for everything else.
- With a stored bell: "Your W. Hit every rep and it moves you to the next bell." At 50: "Once you own every rep here, add reps."

### Today's adjustment

On deload weeks and Beat-up days, the suggested work weight is × 0.9, then clamped, and the reason adds "Lightened 10% for today."

## Progression rules

When a session is finished, each logged item updates its stored working weight, counters and note; the summary screen then lists every change (up, down, same).

### Reading the log

- A set counts if it was ticked or has reps typed. A ticked set with blank reps logs the top of the range.
- **Used weight** = the weight logged on the most sets (ties go to the heavier).
- **Top reps** = best reps at the used weight. History appends `{date, weight, reps, targetHi}` and keeps the last 12.
- **hitAll** = every set at the used weight reached the top of the range, and at least `min(sets, 3)` sets did.
- **miss** = any set at the used weight fell below the bottom of the range.
- **No progression** on deload weeks and Beat-up days: weights hold, counters do not change.

### Barbell and dumbbell

| Result | Next weight | Counters and note |
|---|---|---|
| hitAll | + increment (barbell per lift, dumbbell 5) | fails = 0, holds = 0 |
| hitAll, dumbbell already at 35 | same | Note: "At your heaviest dumbbells. Add 2 reps per set or take 3 seconds on the way down." |
| miss, first time | same | fails + 1 |
| miss, second in a row | × 0.9, rounded to 5 | fails = 0. Note: "Dropped 10% after two tough sessions." |
| In range, not top (main lift) | same; on 3rd hold × 0.95 | holds + 1, reset to 0 after the drop. Note: "Stuck 3 sessions. Dropped 5%." |
| In range, not top (accessory) | same | fails = 0 |

### Kettlebell

| Result | Next bell |
|---|---|
| hitAll | Next bell up. At 50: stays 50, note "You own the 50. Add 2 reps per set or slow it down." |
| miss, second in a row, above that exercise's default bell | Next bell down, fails = 0 |
| miss otherwise | Same bell, fails + 1 |
| In range | Same bell, "chase reps" |

### Bodyweight

On hitAll (not deload, not Beat up), set a note and show "Harder": timed holds "Add 10 to 15 seconds"; carries "Go a little farther or faster"; reps "Slow the lowering to 3 seconds or add reps."

### Cardio minutes

For Engine workouts, finishers and runs, minutes = rounds if the unit is minutes, otherwise rounds × minutes per round (default 2). Added to `cardio[week]`. A ticked item with no rounds typed logs the planned rounds.

### Easy run length

| Result | Next run |
|---|---|
| Rated Too hard, or finished more than 3 min short | max(20, planned - 5) |
| Rated Felt easy, finished the full time, not a Beat-up day | min(50, planned + 5) |
| Otherwise | max(planned, current) |

### Week advance

After saving the log, the slot is marked done (not for R). When A through E are all done, `week + 1` and `done` clears. The summary says "Week N done" and notes if the new week is a back-off week.

## Warm-up, timer and scheduling

### Warm-up ramp (main lift only)

Shown as "Step 1 · Ramp up" above "Step 2 · Work sets", built from the weight typed in set 1.

| Lift | Steps (% of work weight × reps) |
|---|---|
| All except deadlift | Empty bar (45) × 10, 40% × 5, 60% × 3, 80% × 2 |
| Deadlift | 40% × 5, 60% × 3, 80% × 2 (minimum 95) |
| Any lift at 225 or more | Add 90% × 1 at the end |

- Round each step to 5 lb, minimum 45; drop steps at or above the work weight and duplicates.
- Show plates as "(W - 45) / 2 per side" or "empty bar".
- Before a weight is typed, show the percentages with "Type your work weight in set 1 and these fill in."
- Each step has a tick; ticking starts a 60 sec rest.

### Rest timer

- Ticking a set starts the item's rest. If it is the first item of a superset pair, start a 20 sec "Transition to [next exercise]" instead.
- Controls: +30s and Done. At zero show "Go" and vibrate.
- **Native upgrade:** schedule a local notification for the end time and show a Live Activity on the Lock Screen and Dynamic Island so the timer works with the phone locked.

### Week order and leg recovery

- Next session = first open slot in `ORDER` (B, C, A, D, E).
- If any A or E session was logged in the last 48 hours, Next skips to the first open slot that is not A or E.
- All five done: Next = optional run.
- Any slot can be picked manually from the chip row.

### Plan controls

- Jump to week 1-12 within the current cycle (clears `done` and the draft).
- Start over with a two-step confirm; erases state and logs.

## Progress tracking and coach check

The Progress tab holds the coach check, bodyweight, waist, working weights and recent sessions; the coach check turns those numbers into one to three plain-language adjustments.

### Tracked data

- **Bodyweight:** log once or twice a week, same time of day; keep the last 120; show latest, change since first entry, sparkline, last 5 entries with Remove.
- **Waist:** inches at the belly button weekly; keep the last 60; show the under-40 in heart-health target until there are two entries.
- **Cardio:** minutes per week vs a 120 min goal, shown as a bar on Today and Progress.
- **Working weights:** every lift with a stored weight, main lifts first, with estimated max (not for kettlebells) and a sparkline of history.
- **Recent sessions:** last 12 logs (date, title, week).

### Coach check rules

**Weight trend** (weigh-ins from the last 28 days):

| Condition | Message |
|---|---|
| Fewer than 2 weigh-ins | "Log your weight once or twice a week and this checks whether the fat loss is on pace." |
| Span under 10 days | "Keep weighing in. The trend check needs about 10 days." |
| Rate slower than 0.25 lb/week loss | Flat: "Keep the lifting as is. Trim about 300 calories a day or add one more easy run." |
| Losing faster than 1% of bodyweight per week | Too fast: "Eat a little more and keep protein high (about 1 g per pound of goal weight)." |
| Otherwise | On pace: "Losing about X lb a week. Stay the course." |

Rate = (last - first) / days × 7.

**Cardio** (last week): under 60% of goal = add an easy run on a non-leg day; otherwise praise.

**Strength:** count main lifts with a current weight above their first logged weight ("N of M main lifts are heavier than where you started"). Flag any main lift with holds of 2 or more, or fails of 1 or more, as one to watch.

## New adaptive features

These go beyond the web app and are proposed defaults to tune after a few weeks of use. Build them in this order; each sits behind a setting so it can be switched off.

### 1. Effort-based progression (RIR)

After the last set of each lift, ask "Reps left in the tank?" with chips 0 / 1 / 2 / 3+.

| Reps hit | RIR | Next time |
|---|---|---|
| All at top of range | 3+ | Double increment |
| All at top of range | 1-2 | Normal increment |
| All at top of range | 0 | Same weight (it was a grind) |
| In range | 3+ | Normal increment |
| Below range | any | Existing miss rules |

Also replace the fixed "2 reps in reserve" in weight suggestions with the lift's recent average RIR.

### 2. Time-boxed sessions

A "Time today" picker (20 / 30 / 45 / 60 min) replaces the Beat-up shortcut for time. Estimate each block's time: sets × (45 sec work + rest), plus warm-up of 5 min, plus finisher rounds × minutes per round. Then trim in this order until it fits: finisher, third superset pair, one accessory set per item, second pair. Never trim the main lift below 2 sets.

### 3. Fatigue-triggered back-off weeks

Keep weeks 4 and 8 as defaults, but move the back-off week when the data says so:

- **Pull it earlier** if 2 or more main lifts have a miss in the same week, or average RIR on main lifts is 0 for 2 sessions, or HealthKit readiness is low on 3 of the last 5 days.
- **Push it later** (up to 1 week) if every main lift went up in the last 3 weeks and no misses were logged.
- Never go more than 6 weeks without a back-off week.

### 4. Missed-day re-entry

| Days since last session | Response |
|---|---|
| 0-6 | Normal |
| 7-13 | First session back × 0.9 on all weights, no progression that session |
| 14-27 | × 0.85 for 2 sessions; restart the week at slot 1 |
| 28+ | × 0.8, offer to restart the current phase |

### 5. HealthKit readiness

Read sleep duration, resting heart rate and HRV (SDNN) each morning. Compare to the user's 14-day averages.

- **Low:** sleep under 6 hr, or resting HR more than 5 bpm above average, or HRV more than 15% below average. Default the readiness chip to Beat up and say why.
- **High:** sleep 7.5+ hr and HRV above average. Default to Great.
- The user can always override the chip.
- Write each finished session to HealthKit as a strength workout (and runs as running workouts) so it shows in Fitness. Read runs and walks from HealthKit into the cardio minutes.

### 6. Nutrition guidance

Turn the coach check's weight trend into numbers: a daily protein target (1 g per lb of goal weight) and a calorie adjustment (-300 when flat for 14+ days, +200 when losing more than 1% a week). Optional: read dietary energy and protein from HealthKit if logged by another app.

### 7. Equipment profiles

Move equipment to settings: barbell yes/no, plate pairs owned, dumbbell list, kettlebell list, bench, bag, treadmill, trails. The library filters exercises by equipment, clamps use the real lists, and the kettlebell button cycles the user's actual bells. Required if this becomes a product.

### 8. Weekly review card

Every Sunday evening, a notification opens a one-screen review: sessions done, cardio minutes, weight and waist change, lifts that went up, and next week's plan (including any moved back-off week).

## iOS architecture

SwiftUI and SwiftData with CloudKit sync, targeting iOS 17 or later. All program logic in a separate, UI-free `Engine` module that can be fully unit-tested.

| Need | Framework |
|---|---|
| UI | SwiftUI (TabView: Today, Progress, Plan) |
| Storage and iCloud sync | SwiftData with a CloudKit container |
| Charts | Swift Charts (bodyweight, waist, lift history) |
| Rest timer on Lock Screen | ActivityKit (Live Activity) + WidgetKit extension |
| Timer and weekly review alerts | UserNotifications |
| Sleep, HR, HRV, workouts | HealthKit |
| Haptics | UIImpactFeedbackGenerator / sensoryFeedback |
| Tests | Swift Testing |

### Project structure

```
Hybrid12/
  App/             Hybrid12App.swift, RootTabView.swift
  Engine/          Program.swift (week, phase, deload math)
                   SessionBuilder.swift, Suggestions.swift
                   Progression.swift, WarmUp.swift, Coach.swift
                   Adaptive/ (RIR, TimeBox, Fatigue, ReEntry, Readiness)
  Data/            Models.swift (SwiftData @Model types)
                   exercises.json, finishers.json, engine.json
                   Importer.swift (web app JSON import)
  Features/        Today/, Progress/, Plan/, Settings/
  Services/        HealthService.swift, TimerService.swift, Notifications.swift
  Hybrid12Widgets/ RestTimerLiveActivity.swift
  Tests/           EngineTests/ (one test file per Engine file)
```

### Data models (SwiftData)

| Model | Key fields |
|---|---|
| ProgramState | week, doneSlots [String], startDate, runMinutes, settings |
| LiftRecord | exerciseID, workingWeight, fails, holds, note, history [HistoryEntry] |
| HistoryEntry (Codable) | date, weight, reps, targetHi, rir? |
| SessionLog | date, week, phase, slot, title, readiness, entries [LoggedItem] |
| SessionDraft | slot, week, readiness, timeBudget?, swaps, condSwap, finSwap, entries, warmTicks |
| WeighIn | date, pounds |
| WaistEntry | date, inches |
| CardioWeek | week, minutes |

CloudKit rule: every stored property needs a default value or must be optional, and no unique constraints. Exercise data stays in bundled JSON, not SwiftData.

### Engine as pure functions

- `buildSession(slot:context:) -> Session`
- `suggest(item:lifts:) -> Suggestion`
- `progress(session:draft:lifts:) -> (updatedLifts, changes, cardioMinutes)`
- `ramp(lift:workWeight:) -> [WarmUpStep]`
- `nextSlot(state:logs:now:) -> Slot`
- `coachNotes(state:now:) -> [CoachNote]`

Each takes plain value types and returns new values, so tests can feed in a history and assert the exact next weight.

## Build plan

Build the engine first and prove it matches the web app, then the screens, then the adaptive layer. Work one milestone per session.

1. **Engine and data.** Exercise JSON, program math, session builder, suggestions, progression, warm-up, coach check. Tests: feed in your real history and check the next weights match what the web app shows.
2. **Today tab.** Session chips, readiness, cards with set rows, kettlebell bell button, swaps, ticks, rest timer, Finish and summary screen, draft saving.
3. **Progress and Plan tabs.** Weigh-ins, waist, cardio bar, Swift Charts, coach check, plan text, jump to week, start over.
4. **Import and sync.** Import the web app's data and turn on CloudKit. Test on two devices.
5. **Native extras.** Live Activity rest timer, notifications, HealthKit workout writing.
6. **Adaptive layer.** RIR, time-boxed sessions, re-entry, readiness, fatigue-timed back-off weeks, weekly review, nutrition, equipment profiles. Ship each one behind its own setting.
7. **TestFlight.** Install on your phone through TestFlight and use it for a full week before adding more.

## Before you start

- [ ] Apple Developer account ($99/year) for TestFlight, iCloud and HealthKit entitlements
- [ ] Xcode installed on the Mac, with Claude Code in the project folder
- [ ] Export this doc as Markdown and save it as `HYBRID12_SPEC.md` in the project folder
- [ ] Export current data from the web app as JSON for the importer
