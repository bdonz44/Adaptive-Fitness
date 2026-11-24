#!/bin/sh
# Xcode Cloud runs this right after it downloads the code, before building.
# The Xcode project isn't stored in git (XcodeGen makes it from project.yml),
# so make it here, along with the WHOOP keys if they were added to the workflow.
set -e
cd "$CI_PRIMARY_REPOSITORY_PATH"

# WHOOP keys: add WHOOP_CLIENT_ID and WHOOP_CLIENT_SECRET (as a secret) under the
# workflow's Environment in Xcode Cloud. Without them the app builds with WHOOP off.
if [ -n "$WHOOP_CLIENT_ID" ] && [ -n "$WHOOP_CLIENT_SECRET" ]; then
    printf 'WHOOP_CLIENT_ID = %s\nWHOOP_CLIENT_SECRET = %s\n' "$WHOOP_CLIENT_ID" "$WHOOP_CLIENT_SECRET" > Config/Secrets.xcconfig
    echo "WHOOP keys added."
else
    echo "No WHOOP keys in the workflow environment: building with WHOOP off."
fi

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
brew install xcodegen
xcodegen generate
echo "Generated Hybrid12.xcodeproj"
