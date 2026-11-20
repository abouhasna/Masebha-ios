#!/usr/bin/env bash
# Builds an unsigned Release .ipa for free sideloading (Sideloadly signs it with your Apple ID).
# It uses a separate bundle id (nafii.masebha.dev) so the real id stays clean
# for the App Store build under the paid developer account. Both can be installed side by side.
#
# DEV_BUILD adds the "Supporter" test switch in Settings (purchases cannot work in a sideloaded
# build). The App Store build is made without it, so the switch can never reach real users.
set -euo pipefail

rm -rf build/ipa build/Masebha-dev.ipa
mkdir -p build/ipa/Payload

xcodebuild build \
  -project Masebha.xcodeproj \
  -scheme Masebha \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/dd-device \
  -quiet \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  PRODUCT_BUNDLE_IDENTIFIER=nafii.masebha.dev \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) DEV_BUILD'

# The switch must really be in this build (its id exists only inside `#if DEBUG || DEV_BUILD`).
app=build/dd-device/Build/Products/Release-iphoneos/Masebha.app
grep -aq "settings.debugSupporter" "$app/Masebha" || { echo "DEV_BUILD flag missing from the test build"; exit 1; }

cp -R "$app" build/ipa/Payload/
(cd build/ipa && zip -qry ../Masebha-dev.ipa Payload)
ls -lh build/Masebha-dev.ipa
