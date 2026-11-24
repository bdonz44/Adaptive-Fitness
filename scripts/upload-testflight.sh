#!/bin/bash
# Builds Hybrid 12 on this Mac and uploads it to TestFlight. Free: no GitHub Actions.
# Everything it makes (build files, the archive, the export) goes on the Crucial drive,
# not the Mac's own disk.
#
# Run it from the Adaptive-Fitness folder:
#     ./scripts/upload-testflight.sh
#
# Needs: Xcode signed in to your Apple ID (Xcode > Settings > Accounts), and xcodegen
# (brew install xcodegen). If the Crucial drive has an unusual name, run it as
#     HYBRID12_DRIVE="/Volumes/Your Drive Name" ./scripts/upload-testflight.sh
set -euo pipefail

cd "$(dirname "$0")/.."
repo=$(pwd)

say() { printf '\n==> %s\n' "$1"; }
fail() { printf '\nStopped: %s\n' "$1" >&2; exit 1; }

# 1. Find the Crucial drive.
drive="${HYBRID12_DRIVE:-}"
if [ -z "$drive" ]; then
    for v in /Volumes/*; do
        case "$(basename "$v" | tr '[:upper:]' '[:lower:]')" in
            *crucial*|*x6*) drive="$v"; break ;;
        esac
    done
fi
if [ -z "$drive" ] || [ ! -d "$drive" ]; then
    echo "Drives plugged in:"; ls /Volumes
    fail "couldn't find the Crucial drive. Plug it in, or run: HYBRID12_DRIVE=\"/Volumes/<its name>\" $0"
fi
work="$drive/Hybrid12Build"
mkdir -p "$work"
say "Using $work for build files"

command -v xcodegen >/dev/null || fail "xcodegen is missing. Run: brew install xcodegen"

# 2. A running simulator can stall the build: shut them down.
xcrun simctl shutdown all >/dev/null 2>&1 || true

# 3. Engine tests first: never upload a build whose rules fail.
say "Running the engine tests"
if ! swift test --scratch-path "$work/engine-tests" > "$work/engine-tests.log" 2>&1; then
    grep -E "error:|✘" "$work/engine-tests.log" | head -20 || true
    fail "engine tests failed (nothing was uploaded). Full log: $work/engine-tests.log"
fi
tail -1 "$work/engine-tests.log"

# 4. Make the Xcode project and archive the app.
say "Generating the Xcode project"
xcodegen generate

build=$(TZ=America/Chicago date +%Y%m%d.%H%M)
archive="$work/Hybrid12-$build.xcarchive"
say "Building $(git rev-parse --abbrev-ref HEAD) as build $build (a few minutes)"
xcodebuild archive \
    -project Hybrid12.xcodeproj \
    -scheme Hybrid12 \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive" \
    -derivedDataPath "$work/DerivedData" \
    -allowProvisioningUpdates \
    CURRENT_PROJECT_VERSION="$build" \
    -quiet || fail "the build failed. Copy the red error lines above to Claude."

# 5. Upload. Xcode picks a build number above anything already in TestFlight
#    (so this never clashes with Xcode Cloud's numbers).
say "Uploading to TestFlight"
options="$work/ExportOptions.plist"
sed "s/TEAM_ID_PLACEHOLDER/9AY7PD87RL/" ExportOptions.plist > "$options"
/usr/libexec/PlistBuddy -c "Set :manageAppVersionAndBuildNumber true" "$options"
xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportOptionsPlist "$options" \
    -exportPath "$work/export-$build" \
    -allowProvisioningUpdates \
    -quiet || fail "the upload failed. Copy the red error lines above to Claude."

# Keep the last 3 archives on the drive; older ones only take space.
ls -dt "$work"/Hybrid12-*.xcarchive 2>/dev/null | tail -n +4 | while read -r old; do rm -rf "$old"; done
rm -rf "$work"/export-*

say "Done. The build shows up in TestFlight on your iPhone in about 10-30 minutes."
