#!/usr/bin/env bash
# Prints the UDID of an available iPhone simulator matching the selected Xcode's iOS SDK.
set -euo pipefail

sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
xcrun simctl list devices available --json | python3 -I scripts/ci/pick_simulator.py "${sdk_version}"
