# Hybrid 12: project notes for Claude

Brandon's own 12-week home-gym program app for iPhone (separate from Bray-Ray, his son's app; nothing is shared between them except the Apple team ID). The full rules are in `HYBRID12_SPEC.md`; follow it exactly and work one milestone per session.

## Status (Nov 2, 2026)

- **Milestone 1 (Engine) done:** `Engine/` Swift package, bundled JSON in `Engine/Resources/`, Swift Testing tests in `Tests/EngineTests/` (all pass on GitHub's Mac runner).
- **Milestone 2 (Today tab) done:** `App/`, `Data/` (SwiftData models + `AppStore`), `Features/Today/`, `Services/RestTimer.swift`. Compiles on GitHub (`.github/workflows/app-build.yml`), but **nobody has run it in the simulator yet**. First job on the Mac: build, run, and fix anything that looks or behaves wrong.
- **Next: milestone 3** (Progress and Plan tabs). Then 4 import + CloudKit, 5 Live Activity/notifications/HealthKit, 6 adaptive layer, 7 TestFlight.

## Run

```bash
brew install xcodegen      # once
xcodegen generate          # after every pull; Hybrid12.xcodeproj is not committed
open Hybrid12.xcodeproj    # Cmd-R on an iPhone simulator
swift test                 # Engine tests
```

Bundle ID `com.bdonz44.hybrid12`, team `9AY7PD87RL`. The App Store Connect app record does not exist yet (needed before TestFlight).

## Decisions

- All program logic stays in the UI-free Engine package as pure functions with tests; screens only call it.
- SwiftData models store nested Engine values (lift history, logged entries, the draft) as JSON `Data`, every property has a default (CloudKit-ready).
- Choices the spec left open are listed in README.md ("Choices the spec left open").
- Brandon works from his phone a lot and is not a developer: give plain, step-by-step instructions and do the work yourself when you can.
