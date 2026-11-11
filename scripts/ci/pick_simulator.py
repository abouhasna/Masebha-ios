"""Reads `simctl list devices --json` from stdin and prints the best iPhone simulator UDID.

Prefers the newest iOS runtime not newer than the SDK, then a plain model
("iPhone 17") over Pro/Max/Plus variants, because it is closest to a typical user's phone.
"""
import json
import re
import sys

sdk = tuple(int(part) for part in sys.argv[1].split(".")[:2])
devices = json.load(sys.stdin)["devices"]

candidates = []
for runtime, items in devices.items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    if version > sdk:
        continue
    for device in items:
        name = device.get("name", "")
        if device.get("isAvailable", False) and name.startswith("iPhone"):
            is_plain = re.fullmatch(r"iPhone \d+", name) is not None
            candidates.append((version, is_plain, name, device["udid"]))

if not candidates:
    print("No available iPhone simulator found", file=sys.stderr)
    sys.exit(1)

candidates.sort(key=lambda c: (c[0], c[1]), reverse=True)
version, _, name, udid = candidates[0]
print(f"Using simulator: {name} (iOS {version[0]}.{version[1]})", file=sys.stderr)
print(udid)
