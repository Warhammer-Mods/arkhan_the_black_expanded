"""Verify main-pack source paths against the current user-approved baseline."""
import csv
import json
from pathlib import Path
import sys

GAME_ROOTS = ("animations", "db", "script", "text", "ui", "variantmeshes", "vfx")
manifest = json.loads(Path("docs/main_pack_baseline.json").read_text(encoding="utf-8"))
expected = {item["internal_path"] for item in manifest["files"]}
actual = {}
errors = []
source_root = Path("src")
for root in GAME_ROOTS:
    for path in sorted((source_root / root).rglob("*")):
        if not path.is_file():
            continue
        target = path.relative_to(source_root).as_posix()
        if target.endswith(".tsv"):
            try:
                target = path.read_text(encoding="utf-8-sig").splitlines()[1].split("\t")[0].split(";")[2]
            except (UnicodeError, IndexError) as exc:
                errors.append(f"{path}: invalid TSV destination: {exc}")
                continue
        if target in actual:
            errors.append(f"Duplicate pack destination {target}: {actual[target]} and {path}")
        actual[target] = path.as_posix()
for path in sorted(expected - actual.keys()):
    errors.append(f"Missing approved game file: {path}")
for path in sorted(actual.keys() - expected):
    errors.append(f"Unexpected game file outside the approved baseline: {path}")
# Guard against restoring the removed units as rows in shared DB fragments.
removed_units = set(manifest.get("removed_unit_keys", []))
for path in sorted((source_root / "db").rglob("*.tsv")):
    rows = csv.reader(path.read_text(encoding="utf-8-sig").splitlines(),
                      delimiter="\t", quoting=csv.QUOTE_NONE)
    for line, row in enumerate(rows, 1):
        if line > 2 and removed_units.intersection(row):
            errors.append(f"{path}:{line}: removed standalone unit reference")
for error in errors:
    print(f"::error::{error}")
print(f"Main pack inventory: {len(actual)} paths; expected {len(expected)}; {len(errors)} errors.")
sys.exit(bool(errors))
