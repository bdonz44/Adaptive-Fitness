# Hybrid 12: project notes for Claude

Brandon's own 12-week home-gym program app for iPhone (separate from Bray-Ray, his son's app; nothing is shared between them except the Apple team ID). The full rules are in `HYBRID12_SPEC.md`; follow it exactly and work one milestone per session.

## Status (Nov 2, 2026)

- **Milestone 1 (Engine) done:** `Engine/` Swift package, bundled JSON in `Engine/Resources/`, Swift Testing tests in `Tests/EngineTests/` (all pass on GitHub's Mac runner).
- **Milestone 2 (Today tab) done** and checked in the simulator.
- **Milestone 3 (Progress and Plan tabs) done:** `Features/Progress/`, `Features/Plan/`, `Engine/Tracking.swift`, `Engine/PlanText.swift`. Checked in the simulator with `-seedDemo` (see README).
- **TestFlight upload works:** `.github/workflows/testflight.yml` uploads on every push to `main`. Secrets ASC_KEY_P8 / ASC_KEY_ID / ASC_ISSUER_ID are set; the key must be an **Admin** key (App Manager fails cloud signing). App record exists.
- **Next: milestone 4** (import web app JSON + CloudKit). Then 5 Live Activity/notifications/HealthKit, 6 adaptive layer.

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
