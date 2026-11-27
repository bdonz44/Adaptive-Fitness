#!/bin/bash
# Frees space taken by building Hybrid 12. Only deletes things that are rebuilt
# automatically (build caches, old build copies, unused simulators); never your files.
# Don't run it while upload-testflight.sh is running.
#
#     ./scripts/cleanup-mac.sh
set -uo pipefail

say() { printf '\n==> %s\n' "$1"; }
size() { du -sh "$1" 2>/dev/null | cut -f1; }
remove() {
    [ -e "$1" ] || return 0
    printf '   deleting %-60s %s\n' "$1" "$(size "$1")"
    rm -rf "$1"
}

if pgrep -f upload-testflight.sh >/dev/null; then
    echo "The TestFlight upload is still running. Run this again when it says Done."
    exit 1
fi

say "Free space before"
df -h / /Volumes/* 2>/dev/null | awk 'NR==1 || /Volumes|\/$/'

# 1. Hybrid 12's own build folder on the Crucial drive: keep only the newest archive.
for build in /Volumes/*/Hybrid12Build; do
    [ -d "$build" ] || continue
    say "Hybrid 12 build files in $build"
    remove "$build/DerivedData"
    remove "$build/engine-tests"
    remove "$build/engine-tests.log"
    for e in "$build"/export-*; do remove "$e"; done
    ls -dt "$build"/Hybrid12-*.xcarchive 2>/dev/null | tail -n +2 | while read -r a; do remove "$a"; done
done

# 2. Xcode's build caches, wherever they are (rebuilt on the next build).
say "Xcode build caches"
for dd in "$HOME/Library/Developer/Xcode/DerivedData" /Volumes/*/DerivedData; do
    [ -d "$dd" ] || continue
    for x in "$dd"/*; do remove "$x"; done
done
remove "$HOME/Library/Caches/org.swift.swiftpm"
remove "$HOME/Library/Developer/Xcode/Products"

# 3. Archives Xcode kept from builds more than 30 days old (they're already in TestFlight).
say "Old Xcode archives (over 30 days)"
if [ -d "$HOME/Library/Developer/Xcode/Archives" ]; then
    find "$HOME/Library/Developer/Xcode/Archives" -name "*.xcarchive" -maxdepth 2 -mtime +30 -print0 2>/dev/null |
        while IFS= read -r -d '' a; do remove "$a"; done
fi

# 4. Simulators for iOS versions no longer installed.
say "Unused simulators"
xcrun simctl shutdown all >/dev/null 2>&1 || true
xcrun simctl delete unavailable 2>/dev/null && echo "   removed simulators for missing iOS versions"

say "Free space after"
df -h / /Volumes/* 2>/dev/null | awk 'NR==1 || /Volumes|\/$/'

say "Biggest folders left on each external drive (for a look, nothing deleted)"
for v in /Volumes/*; do
    [ -d "$v" ] && [ "$v" != "/Volumes/Macintosh HD" ] || continue
    echo "$v"
    du -sh "$v"/* 2>/dev/null | sort -h | tail -5 | sed 's/^/   /'
done
echo
echo "Done. The next build will take a few minutes longer while caches rebuild."
