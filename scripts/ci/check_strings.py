"""Fails if a localization key used in the Swift code is missing, or a key lacks Arabic or English.

Usage: python3 scripts/ci/check_strings.py
Runs on CI before the build, and can run locally (no Mac needed).
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "Masebha" / "Resources" / "Localizable.xcstrings"
PREFIXES = ("theme", "colors", "font_size", "hijri", "vibration")  # keys built from tables in code

catalog = json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]
problems = []

for key, entry in catalog.items():
    for language in ("ar", "en"):
        value = entry.get("localizations", {}).get(language, {}).get("stringUnit", {}).get("value", "")
        if not value.strip():
            problems.append(f"'{key}' has no {language} text")

used = set()
for swift in (ROOT / "Masebha").rglob("*.swift"):
    text = swift.read_text(encoding="utf-8")
    text = re.sub(r'accessibilityIdentifier\("[^"]*"\)', "", text)  # test ids, not text keys
    used.update(re.findall(r'\btr\("([a-z0-9_.]+)"', text))
    used.update(k for k in re.findall(r'"([a-z0-9_]+\.[a-z0-9_.]+)"', text) if k.split(".")[0] in PREFIXES)
    # Theme name keys are built as "theme.\(key)" from the registry keys.
    used.update(f"theme.{k}" for k in re.findall(r'"(theme\d+)"', text))

for key in sorted(used - set(catalog)):
    problems.append(f"'{key}' is used in code but missing from Localizable.xcstrings")

if problems:
    print("\n".join(problems))
    sys.exit(1)
print(f"Strings OK: {len(catalog)} keys, {len(used)} referenced in code, Arabic and English complete.")
