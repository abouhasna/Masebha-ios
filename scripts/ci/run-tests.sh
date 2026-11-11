#!/usr/bin/env bash
# Runs all unit and UI tests on the given simulator. Results go to build/TestResults.xcresult.
set -euo pipefail

udid="$1"
mkdir -p build
rm -rf build/TestResults.xcresult

xcodebuild test \
  -project Masebha.xcodeproj \
  -scheme Masebha \
  -destination "id=${udid}" \
  -resultBundlePath build/TestResults.xcresult \
  -quiet \
  CODE_SIGNING_ALLOWED=NO
