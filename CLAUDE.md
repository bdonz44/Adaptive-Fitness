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
- **WHOOP connected via API (Nov 3):** `Services/WhoopService.swift`, `Engine/WhoopReadiness.swift`. Keys: `Config/Secrets.xcconfig` (gitignored) generated from `~/Downloads/whoop.txt`; GitHub CI builds have no WHOOP keys (WHOOP off) unless secrets are added there. Privacy policy: PRIVACY.md (private repo link used in the WHOOP developer app). WHOOP sends no HRV or recovery to Apple Health.
- **Since Nov 3:** hold timer, round timer (bag, intervals, EMOM), coach prompts, remove set / skip exercise.
- **Add exercise (Nov 7):** Today has an "Add exercise" button; picks are stored in `SessionDraft.extras` and built as an "Extras" block (keys `x-<id>`, accessory sets/reps, progress like accessories, no Swap, "Remove from today" in the ⋯ menu).
- **Milestone 6 (adaptive layer) in progress.** Switches live in `AdaptiveSettings` (`Engine/Adaptive.swift`), stored by `AppStore.adaptive`, shown on Plan > Smart coaching (`Features/Adaptive/SmartCoachingView.swift`). A switch missing from an older save takes its value from `AdaptiveSettings.starting`. Done (Nov 7): **1. Effort counts (RIR)**, **2. Time today** (`Engine/TimeBox.swift`, picker on Today, applied in `AppStore.session`). Brandon declined 3 (fatigue-timed back-off weeks: "I want to grind"; keep weeks 4 and 8), a voice coach and Siri. Left: 4 re-entry, 5 Health reads (runs/walks into cardio), 6 nutrition, 7 equipment profiles, 8 weekly review. WHOOP is his primary device (Watch optional).
- **Live heart rate + WHOOP strain (Nov 7):** `Services/HeartRateMonitor.swift` reads WHOOP's Bluetooth Heart Rate Broadcast (service 180D; any strap works), `Engine/HeartRate.swift` (parsing, zones as % of max, per-item targets `hrLow/hrHigh`, time in zone, WHOOP workout parsing/matching). Bar on round timer, rest screen, Today; buzz + PUSH after 8 s under target in work rounds. Finish shows WHOOP strain/zones for the session (`/developer/v2/activity/workout`), else the live summary. Max HR is set by hand (default 176). Did NOT add the WHOOP read:body_measurement scope: unknown whether the WHOOP developer app allows it, and an unapproved scope could break sign-in.
- **Programs (Nov 7):** Plan > Programs picks Hybrid 12, Engine Strength, Define 45, Strength & Boxing, Screen Ready (actor cut) or Agent Circuits (3/4/5 days). `Engine/Programs.swift` (ProgramID, switching, saving), `Engine/ProgramLibrary.swift` (day plans + builder), `Features/Plan/ProgramsView.swift`. `ProgramState.week` is absolute and only goes up; `programWeek` is the week in the running program (`startWeek`). Never add fields to SwiftData models for this: program choice rides in `doneSlots` as "@" markers. Research and choices: README "Programs".
- **Cleans and snatches, TRX (Nov 7):** categories `power`, `trx` and `abs` in exercises.json, add-by-hand only (no plan rotates through them). Never append to a category Hybrid 12 rotates through (core, delt, chest, ...): `pick` is position-based, so it would reshuffle current weeks. Swap on a core move also walks the abs list (`Catalog.swapChoices`). Brandon has TRX straps: include them when equipment profiles and the research programs come. Brandon wants deep research into workout plans that fit him (see the five extra programs).

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
