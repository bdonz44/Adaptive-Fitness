# Hybrid 12

A 12-week home-gym program app for iPhone. It picks each session, suggests every weight, and adjusts the plan from what you log. The full rules are in [`HYBRID12_SPEC.md`](HYBRID12_SPEC.md).

## Status

| Milestone | What | Status |
|---|---|---|
| 1 | Engine and data: exercise JSON, program math, session builder, suggestions, progression, warm-up, coach check, with tests | **Built** |
| 2 | Today tab | Next |
| 3 | Progress and Plan tabs | |
| 4 | Import web app data, iCloud sync | |
| 5 | Live Activity rest timer, notifications, HealthKit | |
| 6 | Adaptive layer (RIR, time-boxed sessions, re-entry, readiness, back-off timing, weekly review, nutrition, equipment) | |
| 7 | TestFlight | |

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
  Catalog.swift          loads the bundled JSON
  Resources/             exercises.json, engine.json, finishers.json (edit these, not code, to add moves)
Tests/EngineTests/       Swift Testing tests for every rule
```

The spec's project structure puts the JSON in `Data/`. Here it lives in `Engine/Resources/` so the package can bundle it. The SwiftData models (milestone 2) will sit in the app target and convert to and from the Engine's plain value types.

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
