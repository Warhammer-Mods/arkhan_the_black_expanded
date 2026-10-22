# Main-mod source policy

The user-designated authoritative baseline is `arkhan_the_black_expanded.pack`, supplied from the Arkhan the Black mod folder on 22 October 2026. Its original SHA-256 is `2cf48507769cbc750095495ae488c69289555da2cff31e5785a015256c60f0fd`: 746 game files plus three RPFM editor metadata entries. This replaces the earlier pack (6) baseline, including its removed files and rows.

The sole overlay applied during adoption is the research-energy compatibility fix from `fef4fc46668b5a9a3faa93d577a317b2eb0b3a75`. The resulting pack SHA-256 is `d5a3efa06653f64320a2440ee60b3789027683667ec400b9aaf0051b884b18e8`, with 751 game files plus the same three editor entries. `docs/main_pack_baseline.json` records the complete approved internal paths, input payload hashes and adopted source hashes. Native LOC and the two ColourRGB-containing DB fragments remain binary to preserve supplied values exactly. All other adopted DB exports were decoded and round-trip checked against the schema.

Run `python .github/scripts/check_main_inventory.py` from the repository root to detect missing, duplicate or reintroduced paths. Update the approved inventory only for a new user-designated basis or an explicitly authorised file addition/removal. Old artwork, DB fragments and scripts missing from this baseline must not be restored because they remain in Git history.

- Use this baseline and subsequent explicitly authorised changes. Do not merge or restore entries, rows, assets or scripts from earlier uploaded versions.
- When syncing a user-supplied replacement baseline, reflect removals as well as additions and edits. Earlier files may be compared to describe the diff, but must not supply missing content.
- The main game sources are under `animations`, `db`, `script`, `text`, `ui`, `variantmeshes` and `vfx`. Keep repository tooling, documentation and separate `submods` outside a main-pack replacement unless the user requests changes to them.
- Preserve the supplied data and gameplay keys. Export DB/LOC resources through compatible schema-aware tooling, retain native files where required, and verify that rebuilding preserves the supplied values and newline semantics.
- Do not end newly created DB fragment filenames in numbers.
- Verify the main pack's complete game-file inventory against its authoritative source; do not preserve extra game files merely because they existed in an older repository revision.
