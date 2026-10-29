#!/usr/bin/env bash
# Rebuild this fork's skill tree from emilkowalski/skills.
#
# Upstream deletions are honoured, EXCEPT for skills listed in scripts/keep.txt.
# That is the point of the fork: skills Emil retires stay available here, the
# same way the Matt fork keeps caveman and zoom-out.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

git archive upstream/main | tar -x -C "$TMP_DIR"

TMP_DIR="$TMP_DIR" python3 - <<'PY'
import os
import shutil
from pathlib import Path

root = Path(".")
source = Path(os.environ["TMP_DIR"])

keep = set()
keep_file = root / "scripts" / "keep.txt"
if keep_file.exists():
    for line in keep_file.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            keep.add(line)

upstream = {p.name for p in (source / "skills").iterdir() if p.is_dir()}
target_root = root / "skills"
target_root.mkdir(exist_ok=True)

# Drop skills upstream no longer ships, unless this fork keeps them on purpose.
for current in sorted(target_root.iterdir()):
    if current.is_dir() and current.name not in upstream and current.name not in keep:
        shutil.rmtree(current)

# Mirror upstream skills, preserving any extra files added in this fork.
for name in sorted(upstream):
    shutil.copytree(source / "skills" / name, target_root / name, dirs_exist_ok=True)

# Root docs are mirrors as well.
for doc in ("README.md", "ui-cheatsheet.md", "performance-cheatsheet.md", "LICENSE"):
    src = source / doc
    if src.exists():
        shutil.copy2(src, root / doc)

retired = sorted(keep - upstream)
print(f"upstream: {len(upstream)} skills | kept-only: {retired or 'none'}")
PY

# Keep a plugin manifest in sync so the fork installs as a Claude Code plugin.
python3 - <<'PY'
import glob
import json
import os

skills = sorted(path for path in glob.glob("skills/*") if os.path.isdir(path))
os.makedirs(".claude-plugin", exist_ok=True)
with open(".claude-plugin/plugin.json", "w", encoding="utf-8") as handle:
    json.dump({"name": "aiforui", "skills": ["./" + path for path in skills]}, handle, indent=2)
    handle.write("\n")
PY

echo "Synced $(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') skills from upstream."
