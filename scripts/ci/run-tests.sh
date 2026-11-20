#!/usr/bin/env bash
# Runs all unit and UI tests on the given simulator. Results go to build/TestResults.xcresult.
#
# The app is signed ad hoc ("-", no certificate needed in the Simulator): StoreKit testing must
# be able to write into the app's container, which an unsigned app does not allow.
# The filmed walkthrough is left out here; record-walkthrough.sh runs it on its own.
set -euo pipefail

udid="$1"
mkdir -p build
rm -rf build/TestResults.xcresult

xcodebuild test \
  -project Masebha.xcodeproj \
  -scheme Masebha \
  -destination "id=${udid}" \
  -resultBundlePath build/TestResults.xcresult \
  -skip-testing:MasebhaUITests/WalkthroughVideoTests \
  -quiet \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM=""
