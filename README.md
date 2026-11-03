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
| 7 | TestFlight | Upload works: every push to `main` sends a build (`.github/workflows/testflight.yml`) |

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

Or open `Package.swift` in Xcode and press Cmd-U. GitHub also runs them on every push (`.github/workflows/engine-tests.yml`).

## Choices the spec left open

- **Rule 2 suggestion wording** (best e1RM exists): "From your recent best (estimated max X lb)."
- **Kettlebell with no stored bell:** "Start with the X lb bell."
- **Beat up on a deload week:** main sets drop by 1, not 2.
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
