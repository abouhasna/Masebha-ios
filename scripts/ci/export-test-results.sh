#!/usr/bin/env bash
# Extracts a readable summary and all screenshots from the test result bundle.
# Never fails the job: it runs after failed tests too, to show what went wrong.
set -uo pipefail

result="build/TestResults.xcresult"
out="build/test-results"
mkdir -p "${out}/raw" "${out}/screenshots"

if [[ ! -d "${result}" ]]; then
  echo "No result bundle (the build probably failed before tests ran)."
  exit 0
fi

xcrun xcresulttool get test-results summary --path "${result}" > "${out}/summary.json" || true
xcrun xcresulttool get test-results tests --path "${result}" > "${out}/tests.json" || true
echo "=== Test summary ==="
cat "${out}/summary.json" || true

xcrun xcresulttool export attachments --path "${result}" --output-path "${out}/raw" || true
python3 -I scripts/ci/name_attachments.py "${out}/raw" "${out}/screenshots" || true
exit 0
