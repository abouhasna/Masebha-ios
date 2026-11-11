#!/usr/bin/env bash
# Installs a pinned XcodeGen release, so a new XcodeGen version can never change the build silently.
set -euo pipefail

version="2.46.0"
dest="${RUNNER_TEMP:-/tmp}/xcodegen-${version}"
rm -rf "${dest}"
mkdir -p "${dest}"
curl -fsSL "https://github.com/yonaskolb/XcodeGen/releases/download/${version}/xcodegen.zip" -o "${dest}/xcodegen.zip"
unzip -q "${dest}/xcodegen.zip" -d "${dest}"
echo "${dest}/xcodegen/bin" >> "${GITHUB_PATH}"
"${dest}/xcodegen/bin/xcodegen" --version
