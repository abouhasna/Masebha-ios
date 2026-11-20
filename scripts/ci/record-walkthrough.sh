#!/usr/bin/env bash
# Films the walkthrough UI test (MasebhaUITests/WalkthroughVideoTests) for the owner to watch,
# into build/walkthrough.mp4. Runs after run-tests.sh, so the build is already up to date.
#
# It uses Xcode's own screen recording of UI tests, which normally keeps the video only when a
# test fails; this run asks to keep it always. (simctl's recorder dropped minutes of frames on
# the CI machine.)
set -euo pipefail

udid="$1"
mkdir -p build
rm -rf build/walkthrough.* build/Walkthrough.xcresult build/walkthrough-raw

# Nothing left to compile after run-tests.sh; this writes the .xctestrun file (the test run's settings).
xcodebuild build-for-testing -project Masebha.xcodeproj -scheme Masebha -destination "id=${udid}" -quiet \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=""

xctestrun=$(ls -t "$HOME"/Library/Developer/Xcode/DerivedData/Masebha-*/Build/Products/*.xctestrun | head -1)
echo "Test run settings: ${xctestrun}"

# Keep the screen recording even though the test passes.
python3 -I - "$xctestrun" <<'EOF'
import plistlib, sys
path = sys.argv[1]
with open(path, "rb") as f:
    plist = plistlib.load(f)
targets = [t for c in plist.get("TestConfigurations", []) for t in c.get("TestTargets", [])]
targets += [v for v in plist.values() if isinstance(v, dict) and "TestBundlePath" in v]   # older format
if not targets:
    sys.exit("No test targets found in " + path)
for target in targets:
    target["SystemAttachmentLifetime"] = "keepAlways"
    target["PreferredScreenCaptureFormat"] = "screenRecording"
with open(path, "wb") as f:
    plistlib.dump(plist, f)
print("Recording kept for", len(targets), "test targets")
EOF

# One device, no clones. A failing test still gives its video (that is when it matters most).
status=0
xcodebuild test-without-building -xctestrun "$xctestrun" -destination "id=${udid}" -quiet \
  -only-testing:MasebhaUITests/WalkthroughVideoTests \
  -parallel-testing-enabled NO \
  -resultBundlePath build/Walkthrough.xcresult || status=$?

mkdir -p build/walkthrough-raw
xcrun xcresulttool export attachments --path build/Walkthrough.xcresult --output-path build/walkthrough-raw || true
video=$(find build/walkthrough-raw -type f \( -name '*.mp4' -o -name '*.mov' \) -exec ls -S {} + 2>/dev/null | head -1 || true)
if [[ -n "${video}" ]]; then
  cp "${video}" "build/walkthrough.${video##*.}"
  ls -lh build/walkthrough.*
else
  echo "No screen recording in the result bundle:"
  ls -la build/walkthrough-raw || true
  [[ $status -ne 0 ]] || status=1
fi
exit $status
