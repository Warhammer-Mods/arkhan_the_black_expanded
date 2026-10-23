"""Check that research cost tooltip tokens have DB registrations and localisation."""
import csv
from pathlib import Path
import struct
import sys

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")


def table_rows(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.reader(stream, delimiter="\t", quoting=csv.QUOTE_NONE))
    return [dict(zip(rows[0], row)) for row in rows[2:]]


resources = table_rows(root / "db/pooled_resources_tables/arkhan_research.tsv")
if not resources:
    raise ValueError("Research resource table is empty")
registered = {
    row["key"]
    for path in (root / "db/ui_text_replacements_tables").glob("*.tsv")
    for row in table_rows(path)
}
localised = {}
for path in (root / "text/db").glob("*.loc"):
    data = path.read_bytes()
    if data[:6] != b"\xff\xfeLOC\0":
        raise ValueError(f"Invalid native LOC header: {path}")
    count = struct.unpack_from("<I", data, 10)[0]
    offset = 14
    for _ in range(count):
        values = []
        for _ in range(2):
            length = struct.unpack_from("<H", data, offset)[0]
            offset += 2
            values.append(data[offset:offset + length * 2].decode("utf-16-le"))
            offset += length * 2
        offset += 1  # tooltip flag
        localised[values[0]] = values[1]
    if offset != len(data):
        raise ValueError(f"Unexpected native LOC payload length: {path}")

errors = []
for resource in resources:
    token = "tech_pooled_resource_cost_tooltip_" + resource["key"]
    loc_key = "ui_text_replacements_localised_text_" + token
    if token not in registered:
        errors.append(f"Missing ui_text_replacements registration: {token}")
    text = localised.get(loc_key, "")
    if not text.strip() or "{{tr:" in text:
        errors.append(f"Missing or unresolved localisation: {loc_key}")
for error in errors:
    print(f"::error::{error}")
print(f"Research cost tooltips: {len(resources)} resources; {len(errors)} errors.")
sys.exit(bool(errors))
