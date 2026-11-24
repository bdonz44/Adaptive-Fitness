# Hybrid 12

A 12-week home-gym program app for iPhone. It picks each session, suggests every weight, and adjusts the plan from what you log. The full rules are in [`HYBRID12_SPEC.md`](HYBRID12_SPEC.md).

## Status

| Milestone | What | Status |
|---|---|---|
| 1 | Engine and data: exercise JSON, program math, session builder, suggestions, progression, warm-up, coach check, with tests | **Built** |
| 2 | Today tab: session chips, readiness, set rows with suggested weights, warm-up ramp, bell button, swaps, rest timer, Finish summary, Skip, saved draft | **Built** |
| 3 | Progress tab (coach check, cardio, bodyweight and waist with charts, working weights, recent sessions) and Plan tab (phases, 12-week grid, sessions, jump to week, start over) | **Built** |
| 4 | Import web app data, iCloud sync | **Built** (two-device sync test still to do) |
| 5 | Live Activity rest timer, notifications, HealthKit | **Built** (check on the phone still to do) |
| 6 | Adaptive layer (RIR, time-boxed sessions, re-entry, readiness, back-off timing, weekly review, nutrition, equipment) | |
| 7 | TestFlight | Xcode Cloud on every change to `main`, or `scripts/upload-testflight.sh` from the Mac ([how](docs/BUILD_AND_RELEASE.md)) |

## Layout

```
Package.swift            Swift package for the Engine (iOS 17+, macOS 14+)
Engine/                  Pure, UI-free program logic
  Program.swift          week / cycle / phase / back-off math, slots, schemes, week advance, next slot
  SessionBuilder.swift   (slot, week, readiness, swaps) -> ordered blocks
  Suggestions.swift      e1RM, weight suggestions, related-lift ratios, clamping, kettlebells
  Progression.swift      reading the log, next weights, counters, cardio minutes, run length
  WarmUp.swift           main-lift warm-up ramp and plate math
  Coach.swift            coach check (weight trend, cardio, strength)
  Tracking.swift         bodyweight and waist lists, change since first, working-weights list
  PlanText.swift         Plan tab text: phases, schemes, the 12 weeks, session lines
  Workouts.swift         what a finished session writes to Apple Health
  Catalog.swift          loads the bundled JSON
  Resources/             exercises.json, engine.json, finishers.json (edit these, not code, to add moves)
Tests/EngineTests/       Swift Testing tests for every rule
Engine/SessionInsights.swift  plates per side, next open set, session stats, personal records
Features/Look/           the six looks (Look.swift), Look settings, program picker
Features/Today/          NowCard, FocusView, RestView (full-screen timer), SetTick
Services/                RestTimer, RestAlerts (notification + Live Activity), HealthService
Shared/                  RestTimerAttributes (used by the app and the widget extension)
Hybrid12Widgets/         Live Activity for the rest timer (bundle ID com.bdonz44.hybrid12.widgets)
```

The spec's project structure puts the JSON in `Data/`. Here it lives in `Engine/Resources/` so the package can bundle it. The SwiftData models (milestone 2) will sit in the app target and convert to and from the Engine's plain value types.

## Run the app on your Mac

One-time setup:

```bash
brew install xcodegen
git clone https://github.com/bdonz44/Adaptive-Fitness.git
```

Then, in the `Adaptive-Fitness` folder (do this again whenever new code is pulled):

```bash
git pull
xcodegen generate
open Hybrid12.xcodeproj
```

In Xcode pick an iPhone simulator (or your plugged-in iPhone) at the top and press Cmd-R.
Bundle ID `com.bdonz44.hybrid12`, team `9AY7PD87RL`.

App code: `App/` (entry point, tabs), `Data/` (SwiftData models and `AppStore`, which connects the Engine to storage), `Features/Today/`, `Features/Progress/`, `Features/Plan/` (the three tabs), `Services/` (rest timer).

Debug builds only (never TestFlight): launch with `-seedDemo` to fill the app with sample data, and `-tab 1` or `-tab 2` to open on Progress or Plan. Handy for simulator screenshots, e.g. `xcrun simctl launch booted com.bdonz44.hybrid12 -seedDemo -tab 1`. `-seedDemo` erases what is there first. `-importFile /path/to/hybrid12-data.json` imports a web app export at launch (replaces everything).

## Run the tests

On the Mac, in this folder:

```bash
swift test
```

Or open `Package.swift` in Xcode and press Cmd-U. (GitHub no longer runs them automatically: its free Mac minutes ran out. Claude runs them in cloud sessions, and `scripts/upload-testflight.sh` runs them before every upload.)

## Getting builds to TestFlight

Xcode Cloud builds and uploads every change to `main` (free with the developer membership); `scripts/upload-testflight.sh` does the same from the Mac, keeping its files on the Crucial drive. Step by step: [`docs/BUILD_AND_RELEASE.md`](docs/BUILD_AND_RELEASE.md).

## Choices the spec left open

- **Rule 2 suggestion wording** (best e1RM exists): "From your recent best (estimated max X lb)."
- **Kettlebell with no stored bell:** "Start with the X lb bell."
- **Beat up on a deload week:** main sets drop by 1, not 2.
- **Effort chips (adaptive 1):** the existing Easy / Solid / Grinder buttons stand in for the spec's 0 / 1 / 2 / 3+ chips (Easy = 3+, Solid = 2, Grinder = 0); the last one tapped on a lift counts. Effort rules apply to barbell and dumbbell lifts; kettlebells keep their bell jumps.
- **"Average RIR instead of 2 in reserve" (adaptive 1):** taken literally, easy sets would make suggestions lighter. Instead, logged reps left count toward the estimated max (up to 3), and suggestions still leave 2 in the tank.
- **Smart coaching switches** are saved on each phone (not synced through iCloud). Each starts on; a switch missing from an older save takes its starting value.
- **Time today (adaptive 2):** after the spec's trim order, Conditioning's engine rounds are cut (never below half), because nothing else on that day can be trimmed. Logged items and hand-added extras are never trimmed. The estimate uses the spec's formula as-is (supersets are counted as if done one after the other, so it runs a little long).
- **Cleans and snatches** sit in their own "power" category that no plan rotates through, so they only appear when added by hand, at 3-5 reps with 2 min rest.
- **A miss resets after any non-miss session**, for main lifts too, so "second miss in a row" means in a row.
- **Light days (deload, Beat up)** still store a weight the first time a lift is ever logged.
- **`firstWeight`** was added to the lift record so "heavier than where you started" survives the 12-entry history limit.
- **Lateral Raise Burnout** logs its weight but does not progress.
- **Start over** erases everything, including weigh-ins and waist entries, after two confirms.
- **Waist** shows the last 5 entries with Remove, like bodyweight, so a typo can be fixed.
- **Jump to week** is done by tapping a week in the Plan tab's 12-week grid; past weeks show a check.
- **Recent sessions** show the week within the cycle (1-12).
- **Health workout times:** a session runs from the first ticked set or warm-up step to Finish. If that comes out under 5 minutes or over 4 hours, it is written as 45 minutes ending at Finish. The easy run is a running workout of the logged minutes ending at Finish; every other session is a strength workout. A session with nothing logged writes nothing. No calories are written.
- **Health permission** is asked the first time you finish a session; **notification permission** the first time a rest timer starts.
- **Rest timer when locked:** the Live Activity counts down on its own and shows "Go" at zero; the notification says "Go". The Live Activity has no buttons (use +30s and Done in the app). Closing the app ends the timer and its Live Activity.
- **Looks:** six looks from the design canvas (Iron is the default), picked in Plan > Look. They use Apple's built-in fonts (compressed, condensed, serif, rounded, mono) rather than the Google fonts in the mockups. Changing the look rebuilds the screens.
- **Arcade** has the neon style but no XP or streak system (nothing in the program earns XP yet).
- **Pulse** puts the readiness picker first; WHOOP numbers arrive with milestone 6.
- **Now card and Focus mode** follow the next unfinished lift set in session order; superset partners alternate. Done logs the target reps (Focus lets you change reps and weight first).
- **Personal record** = a lift's estimated max (Epley) beats every earlier logged entry. A lift's first entry is never a record.
- **Lock Screen styles:** big number, session progress, or with +30s/Done buttons. The expanded Dynamic Island always has the buttons.
- **Programs:** only Hybrid 12 exists; the other five are listed as coming soon.
- **Carry forward:** finishing a set fills that exercise's later blank, unfinished sets with its weight and reps. Typed values and done sets are never changed.
- **Coach (Engine/CoachCues.swift):** before the first set, a target from last time ("Up 5 lb from last time", "Beat it: 5+ reps"); before the last set of a main lift, a push to go past the top of the range; after every set, a call: any rep over the top (or top reps rated Easy) offers +5 lb (+10 for a barbell at 200+, next bell for kettlebells) for the remaining sets, under the range offers -5/-10 lb, a Grinder holds. Light days never push. The Use button changes only unfinished sets. Easy / Solid / Grinder in Focus mode is saved as RIR 3 / 2 / 0.
- **Nudge:** finishing a session schedules a "Two days off" reminder for 7:30 am two days later; the next finish moves it.
- **Warm-up ramp** builds from set 1's weight, or today's suggestion when set 1 is blank, so it is filled in from the start. Each step shows the plates per side and can be edited; edits last for the session, and clearing a box (or typing the planned number) goes back to the plan.
- **Hold timer** (plank, hollow hold, side plank): Start counts in 3 sec, counts the hold down (beeps and buzzes on the last 3 seconds), then logs the seconds, ticks the set and starts the rest. Each-side moves add a 5 sec switch and the second side. Stop logs what was held. The screen stays awake while it runs. The target is the seconds typed in the set (or carried from the last set), else the top of the range.
- **Round timer** (heavy bag, intervals, EMOM, sprints): on every conditioning and finisher card. Work and rest seconds come from `work`/`rest` in engine.json and finishers.json (else the whole round is work); rounds, round length and rest can be changed before starting, and work/rest are remembered per workout name. 10 sec get ready, a bell to start and end each round, a clack at 10 sec left, pause, skip rest, end round. Finishing or stopping logs the rounds (minutes for EMOM) and ticks the item. Backup notifications ring the bell if the app is closed or the phone is locked. Bell sounds are generated (App/Sounds).
- **WHOOP** (Plan > WHOOP): OAuth sign-in once (redirect `hybrid12://whoop`); on launch and on every return to the app (at most every 20 min) it fetches the newest recovery, sleep and cycle from WHOOP API v2. Recovery 67+ sets readiness to Great, 34-66 Normal, under 34 Beat up, unless readiness was picked by hand that day or the session has started. Tokens are in the Keychain. The client ID and secret come from `Config/Secrets.xcconfig` (not committed; made from `~/Downloads/whoop.txt`). Without that file the app builds with WHOOP off. Fine for a personal app; an App Store version would need a server to hold the secret.
- **Exercise menu (…):** All sets done (ticks every set; blank weights take the suggestion, blank reps count as the top of the range), Remove a set (takes the last unfinished set off today's list, never below one; Put removed sets back), Skip exercise with a reason (Pain, No time, No equipment, Other; clears what was logged). A skipped lift is remembered on its record (`lastSkip`) and flagged next time until it's logged again. Removed or skipped sets don't count, so the weight holds.
- **Finish check:** if any planned sets on exercises that weren't skipped are unticked, Finish asks to log them as done at the planned weight and reps, or only what was ticked.

## Programs

Plan > Programs picks the program and days a week. Hybrid 12 (5 days) is the original; the others are day plans in `Engine/ProgramLibrary.swift`, each with 3, 4 and 5 day weeks, 12 weeks in three 4-week phases with back-off weeks 4 and 8. Lifts progress by the same rules as Hybrid 12 (and Smart coaching). Each program keeps its own week: switching saves the old program's week and starts the new one on a fresh week number, so logs never mix.

- **Engine Strength** (Base, Build, Peak): heavy lift first, then the engine. Norwegian 4×4 (Helgerud 2007: about +7% VO2 max in 8 weeks, more than steady or threshold work), KB snatch 15:15 (Falatic 2015: about +6% in 4 weeks), 40:20 circuits, heavy bag 2:1. Power before strength before intervals, because same-session endurance work blunts explosive strength but not size or max strength (Schumann 2022).
- **Define 45** (Build, Sculpt, Define): upper/lower (3 day: full body), about 12-16 hard sets per muscle a week (Schoenfeld 2016 dose-response), heavy sets 1-3 reps short of failure, short finishers. Nutrition text: 300-500 kcal deficit, 1 g protein per lb of goal weight (above Morton 2018's ~0.73 g/lb).
- **Strength & Boxing** (Fundamentals, Power, Fight Shape): power cleans, squats, deadlifts, presses and rows, then a "Box" block: technique rounds (3 min on, 1 off, combos change by phase), 30:30 power rounds, roadwork, and a 5th-day bag session.

- **Screen Ready** (Build, Cut, Camera Ready): the actor cut. Modeled on what film trainers report (e.g. Corey Calliet hitting chest, arms and abs twice a week for Michael B. Jordan): heavy compound first, then chest/shoulder/arm/ab supersets, rest shrinking from 60 to 30 sec, abs burner and incline walking. No dehydration "peak week".
- **Agent Circuits** (Base, Operator, Mission): modeled on Simon Waterson's reported Bond approach (about 45 min, 5 days, compound lifts plus kettlebell, bodyweight and circuit work): one heavy lift, a quick pair, then a kettlebell, TRX, dumbbell-complex or bag circuit.
- New ab and TRX moves (TRX chest fly, fallout, body saw, oblique tuck, power pull, high row, woodchop, Russian twist and others) are built into all five programs; Hybrid 12 is untouched.

Choices: deadlifts get one set fewer than other main lifts; TRX rows are never used as a heavy (6-8 rep) lift; Beat-up days keep the first superset pair, halve conditioning and drop finishers; back-off weeks take a set off and about 25% off conditioning.

Saving: the program, days, start week and other programs' saved weeks are stored as "@..." entries in the synced program record's done list (`ProgramState.storedDoneSlots`), so the CloudKit schema didn't change. Hybrid 12 records look exactly as before.

