#!/usr/bin/env bash
# Waits for the CI run of the current commit and prints its real conclusion (success/failure).
# Usage (from Windows Git Bash): bash scripts/wait-for-ci.sh
set -uo pipefail

GH="${GH:-gh}"
command -v "$GH" >/dev/null 2>&1 || GH="/c/Program Files/GitHub CLI/gh.exe"
REPO="abouhasna/Masebha-ios"
SHA="$(git rev-parse HEAD)"

run_id=""
for _ in $(seq 1 30); do
  run_id="$("$GH" run list -R "$REPO" --commit "$SHA" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null)"
  [[ -n "$run_id" ]] && break
  sleep 10
done
if [[ -z "$run_id" ]]; then
  echo "No CI run found for $SHA"
  exit 2
fi

echo "Run $run_id for $SHA"
# `gh run watch` can return early (network hiccup), so poll until the run is really completed.
while true; do
  "$GH" run watch "$run_id" -R "$REPO" --interval 30 >/dev/null 2>&1
  status="$("$GH" run view "$run_id" -R "$REPO" --json status --jq .status 2>/dev/null)"
  [[ "$status" == "completed" ]] && break
  sleep 30
done
conclusion="$("$GH" run view "$run_id" -R "$REPO" --json conclusion --jq .conclusion)"
echo "Conclusion: $conclusion"
[[ "$conclusion" == "success" ]]
