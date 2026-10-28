"""Validate RPFM TSV exports; binary DB/LOC files are checked by pack building."""
import csv
from pathlib import Path
import sys

errors = []
checked = 0
for root in (Path("db"), Path("text")):
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        raw = path.read_bytes()
        if b"\0" in raw:
            continue
        checked += 1
        try:
            # RPFM uses unquoted tab-separated fields, with escaped newlines.
            rows = list(csv.reader(raw.decode("utf-8-sig").splitlines(),
                                   delimiter="\t", quoting=csv.QUOTE_NONE))
            if len(rows) < 2:
                raise ValueError("missing header or RPFM metadata row")
            header = rows[0]
            if not all(header) or len(header) != len(set(header)):
                raise ValueError("empty or duplicate column names")
            metadata = rows[1][0].split(";")
            if len(metadata) != 3 or not metadata[0].startswith("#"):
                raise ValueError("invalid RPFM metadata")
            int(metadata[1])
            if metadata[2] != path.as_posix().removesuffix(".tsv"):
                raise ValueError("metadata path does not match file path")
            for line, row in enumerate(rows[2:], 3):
                if len(row) != len(header):
                    errors.append(f"{path}:{line}: expected {len(header)} fields, got {len(row)}")
                elif header == ["key", "text", "tooltip"] and row[2] not in ("true", "false"):
                    errors.append(f"{path}:{line}: invalid localisation tooltip flag")
                elif metadata[0] == "#building_effect_context_expressions_tables":
                    expression = row[header.index("expression")].strip()
                    # RPFM's importer disables CSV quoting. A CSV-wrapped
                    # expression becomes a literal string with doubled quotes,
                    # rather than the intended boolean condition.
                    if expression.startswith('"') and expression.endswith('"'):
                        errors.append(f"{path}:{line}: CSV-quoted building condition; use raw quotes in RPFM TSV")
        except (UnicodeError, ValueError, csv.Error) as exc:
            errors.append(f"{path}: {exc}")

for error in errors:
    print(f"::error::{error}")
print(f"Checked {checked} TSV exports; {len(errors)} errors.")
sys.exit(bool(errors))
