#!/usr/bin/env bash
# Builds an unsigned Release .ipa for free sideloading (Sideloadly signs it with your Apple ID).
# It uses a separate bundle id (nafii.masebha.dev) so the real id stays clean
# for the App Store build under the paid developer account. Both can be installed side by side.
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
  PRODUCT_BUNDLE_IDENTIFIER=nafii.masebha.dev

cp -R build/dd-device/Build/Products/Release-iphoneos/Masebha.app build/ipa/Payload/
(cd build/ipa && zip -qry ../Masebha-dev.ipa Payload)
ls -lh build/Masebha-dev.ipa
