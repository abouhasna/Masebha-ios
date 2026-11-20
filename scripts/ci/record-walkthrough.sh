#!/usr/bin/env bash
# Films the walkthrough UI test (MasebhaUITests/WalkthroughVideoTests) for the owner to watch:
# the Simulator screen is recorded while the test runs, into build/walkthrough.mp4.
# Runs after run-tests.sh, so the build is already up to date.
set -euo pipefail

udid="$1"
mkdir -p build
rm -f build/walkthrough.mp4

project=(-project Masebha.xcodeproj -scheme Masebha -destination "id=${udid}")

# Build first (nothing left to compile after run-tests.sh), so the video starts with the test.
xcodebuild build-for-testing "${project[@]}" -quiet \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=""

xcrun simctl boot "$udid" 2>/dev/null || true   # already booted by the tests
xcrun simctl bootstatus "$udid" -b >/dev/null

xcrun simctl io "$udid" recordVideo --codec=h264 --force build/walkthrough.mp4 &
recorder=$!
# Ctrl-C (SIGINT) makes simctl finish the file properly, also when the test fails.
stop_recording() {
  kill -INT "$recorder" 2>/dev/null || true
  wait "$recorder" 2>/dev/null || true
}
trap stop_recording EXIT
sleep 3

# One device, no clones: the test must run on the simulator being filmed.
xcodebuild test-without-building "${project[@]}" -quiet \
  -only-testing:MasebhaUITests/WalkthroughVideoTests \
  -parallel-testing-enabled NO
