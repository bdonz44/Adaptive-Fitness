# Hybrid 12: project notes for Claude

Brandon's own 12-week home-gym program app for iPhone (separate from Bray-Ray, his son's app; nothing is shared between them except the Apple team ID). The full rules are in `HYBRID12_SPEC.md`; follow it exactly and work one milestone per session.

## Status (Nov 2, 2026)

- **Milestone 1 (Engine) done:** `Engine/` Swift package, bundled JSON in `Engine/Resources/`, Swift Testing tests in `Tests/EngineTests/` (all pass on GitHub's Mac runner).
- **Milestone 2 (Today tab) done** and checked in the simulator.
- **Milestone 3 (Progress and Plan tabs) done:** `Features/Progress/`, `Features/Plan/`, `Engine/Tracking.swift`, `Engine/PlanText.swift`. Checked in the simulator with `-seedDemo` (see README).
- **TestFlight upload works:** `.github/workflows/testflight.yml` uploads on every push to `main`. Secrets ASC_KEY_P8 / ASC_KEY_ID / ASC_ISSUER_ID are set; the key must be an **Admin** key (App Manager fails cloud signing). App record exists.
- **Milestone 4 (import + iCloud) built:** `Engine/Importer.swift` (reads the web app's `hybrid12-data.json`; tested against Brandon's real export), Import buttons on Plan and on Today while empty, SwiftData syncing to CloudKit container `iCloud.com.bdonz44.hybrid12` (falls back to on-device without iCloud). CloudKit schema was pushed from his iPhone with `-initCloudKitSchema` and deployed to Production on Nov 2. TestFlight build 20261102.1440 has it. **Still to check:** the two-device sync test.
- **TestFlight signing:** the workflow ad-hoc signs the unsigned archive with `App/Hybrid12.entitlements` before export; without that step iCloud is dropped. GitHub's macOS runners sometimes never start ("job was not acquired"); the same archive → codesign → export steps work from the Mac with the key in ~/Downloads.
- **Mac quirks:** there is no Simulator app (Xcode 27.1 has none in Contents/Applications), so nobody can sign a simulator into iCloud; use his iPhone 16 Plus (`xcrun devicectl`, Developer Mode is on). Simulators themselves run headless from the DevCache image on the Crucial X6 drive (see memory).
- **Next: milestone 5** (Live Activity rest timer, notifications, HealthKit). Then 6 adaptive layer.

## Run

```bash
brew install xcodegen      # once
xcodegen generate          # after every pull; Hybrid12.xcodeproj is not committed
open Hybrid12.xcodeproj    # Cmd-R on an iPhone simulator
swift test                 # Engine tests
```

Bundle ID `com.bdonz44.hybrid12`, team `9AY7PD87RL`. App Store Connect app record: "Hybrid 12", Apple ID 6829599005.

## Decisions

- All program logic stays in the UI-free Engine package as pure functions with tests; screens only call it.
- SwiftData models store nested Engine values (lift history, logged entries, the draft) as JSON `Data`, every property has a default (CloudKit-ready).
- Choices the spec left open are listed in README.md ("Choices the spec left open").
- Brandon works from his phone a lot and is not a developer: give plain, step-by-step instructions and do the work yourself when you can.
