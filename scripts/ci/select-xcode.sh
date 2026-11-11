#!/usr/bin/env bash
# Selects the newest stable (non-beta) Xcode 26.x installed on the CI runner.
# Xcode 26+ is required: the App Store only accepts builds made with the iOS 26 SDK or later.
set -euo pipefail

candidate="$(ls -d /Applications/Xcode_26*.app 2>/dev/null | grep -viE 'beta|_rc|release_candidate' | sort -V | tail -n 1 || true)"
if [[ -z "${candidate}" ]]; then
  echo "::error::No stable Xcode 26 found on this runner. Installed:"
  ls -d /Applications/Xcode*.app || true
  exit 1
fi

sudo xcode-select -s "${candidate}/Contents/Developer"
xcodebuild -version
