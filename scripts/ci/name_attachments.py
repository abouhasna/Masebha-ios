"""Copies exported xcresult attachments to readable file names, using their manifest.json."""
import json
import shutil
import sys
from pathlib import Path

raw, dest = Path(sys.argv[1]), Path(sys.argv[2])
dest.mkdir(parents=True, exist_ok=True)
manifest = raw / "manifest.json"
if not manifest.exists():
    print("No attachment manifest found")
    sys.exit(0)


def attachments(node):
    if isinstance(node, dict):
        if "exportedFileName" in node:
            yield node
        for value in node.values():
            yield from attachments(value)
    elif isinstance(node, list):
        for value in node:
            yield from attachments(value)


for item in attachments(json.loads(manifest.read_text())):
    source = raw / item["exportedFileName"]
    name = item.get("suggestedHumanReadableName") or item["exportedFileName"]
    if source.exists():
        shutil.copy2(source, dest / name)
        print(f"Screenshot: {name}")
