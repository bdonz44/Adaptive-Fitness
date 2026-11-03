# Hybrid 12: project notes for Claude

Brandon's own 12-week home-gym program app for iPhone (separate from Bray-Ray, his son's app; nothing is shared between them except the Apple team ID). The full rules are in `HYBRID12_SPEC.md`; follow it exactly and work one milestone per session.

## Status (Nov 2, 2026)

- **Milestone 1 (Engine) done:** `Engine/` Swift package, bundled JSON in `Engine/Resources/`, Swift Testing tests in `Tests/EngineTests/` (all pass on GitHub's Mac runner).
- **Milestone 2 (Today tab) done** and checked in the simulator.
- **Milestone 3 (Progress and Plan tabs) done:** `Features/Progress/`, `Features/Plan/`, `Engine/Tracking.swift`, `Engine/PlanText.swift`. Checked in the simulator with `-seedDemo` (see README).
- **TestFlight upload works:** `.github/workflows/testflight.yml` uploads on every push to `main`. Secrets ASC_KEY_P8 / ASC_KEY_ID / ASC_ISSUER_ID are set; the key must be an **Admin** key (App Manager fails cloud signing). App record exists.
- **Milestone 4 (import + iCloud) built:** `Engine/Importer.swift` (reads the web app's `hybrid12-data.json`; tested against Brandon's real export), Import buttons on Plan and on Today while empty, SwiftData syncing to CloudKit container `iCloud.com.bdonz44.hybrid12` (falls back to on-device without iCloud). CloudKit schema was pushed from his iPhone with `-initCloudKitSchema` and deployed to Production on Nov 2. TestFlight build 20261102.1440 has it. **Still to check:** the two-device sync test.
- **TestFlight signing:** the workflow ad-hoc signs the unsigned archive with `App/Hybrid12.entitlements` before export; without that step iCloud is dropped. GitHub's macOS runners sometimes never start ("job was not acquired"); the same archive → codesign → export steps work from the Mac with the key in ~/Downloads.
- **Mac quirks:** there is no Simulator app (Xcode 27.1 has none in Contents/Applications), so nobody can sign a simulator into iCloud; use his iPhone 16 Plus (`xcrun devicectl`, Developer Mode is on). Simulators themselves run headless from the DevCache image on the Crucial X6 drive (see memory). A booted simulator there can push the Mac's load into the hundreds and stall builds: shut it down (`pkill -9 -f launchd_sim` if `simctl shutdown` hangs) before archiving.
- **Milestone 5 (native extras) built:** rest timer end notification + Live Activity (`Services/RestAlerts.swift`, `Hybrid12Widgets/` extension, `Shared/RestTimerAttributes.swift`), Health workout writing (`Engine/Workouts.swift`, `Services/HealthService.swift`, `SessionDraft.startedAt`). Widget bundle ID is `$(APP_BUNDLE_ID).widgets`; CI overrides `APP_BUNDLE_ID`, never `PRODUCT_BUNDLE_IDENTIFIER`. Uploaded as TestFlight build 20261102.1803 (from the Mac). Apple requires NSHealthShareUsageDescription as soon as the HealthKit entitlement exists. **Still to check on the phone:** Lock Screen timer, notification, workout in Fitness.
- **Look redesign built (Nov 2):** six looks (`Features/Look/`), Now card, Focus mode, full-screen rest, new Finish screen with PRs, Lock Screen styles with buttons (LiveActivityIntents run in the app via `RestTimerControl`; the widget has a stub), six alternate app icons. Design canvas: https://claude.ai/artifact/EzKdJSbtEYo4pdbBcHen6m. Wanted next: an interval/EMOM timer; the five extra programs.
- **iCloud duplicates (fixed Nov 2, build 20261102.2031):** a launch before iCloud delivers data creates a second StoredProgram/StoredDraft; `.first` picked either, which lost a workout and jumped a week. `AppStore.load()` now merges duplicates on launch and on every remote change, never discards a draft with logged sets. Any new singleton-style model must go through the same merging. Logged sessions are re-marked done only when a week is picked (not on launch: a stray log once rolled week 5 over early). Plan has a per-session "Week N sessions" card to fix the done list, and Finish offers "Go back to week N" after a rollover.
- **Next: milestone 6** (adaptive layer, each piece behind its own setting).

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
