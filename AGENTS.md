# Main-mod source policy

The authoritative baseline is the Discord ZIP supplied on 31 October 2026, attachment `1566187714234032188`, containing `arkhan_the_black_expanded.pack`. Input pack SHA-256: `8b5ef9b20b4153ed417c895e86b273d456126a51d4c2b064c9315ce6ca16982e`; 724 game files and three editor metadata entries. This replaces all earlier uploaded baselines, preserving removals as well as additions and edits.

The only overlay is the previously requested Old World starting-centre fix in the existing `script/campaign/mod/arkhan_land_of_the_dead.lua`. Review pack SHA-256: `d4a98e364bb77d9da3ddec640e23a255b44713144c5c4f304ab1e776dc6e413b`. All other 723 game payloads remain identical to the supplied pack. `docs/main_pack_baseline.json` records approved paths and hashes. Preserve native LOC and both ColourRGB-containing DB fragments; all 204 other DB fragments are schema-aware TSV exports with verified byte-exact native round trips.

Do not reintroduce the standalone `xereus_tmb_veh_black_coach` or `xereus_tmb_veh_coven_throne` unit records or access rows. The supplied Lahmian Lord's Coven Throne mount, unused capacity effects and artwork remain part of this basis; their presence does not restore the standalone units. See `docs/baselines/2026-10-31.md` for the review notes.

Run `python .github/scripts/check_main_inventory.py` from the repository root to detect missing, duplicate or reintroduced paths. Update the approved inventory only for a new user-designated basis or an explicitly authorised file addition/removal. Old artwork, DB fragments and scripts missing from this baseline must not be restored because they remain in Git history.

- Use this baseline and subsequent explicitly authorised changes. Do not merge or restore entries, rows, assets or scripts from earlier uploaded versions.
- When syncing a user-supplied replacement baseline, reflect removals as well as additions and edits. Earlier files may be compared to describe the diff, but must not supply missing content.
- The main game sources are under `src/`, with game folders `animations`, `db`, `script`, `text`, `ui`, `variantmeshes` and `vfx`. Pack paths are relative to `src/`; never include the `src/` prefix inside a pack. Keep repository tooling, documentation and separate `submods` outside a main-pack replacement unless the user requests changes to them.
- Preserve the supplied data and gameplay keys. Export DB/LOC resources through compatible schema-aware tooling, retain native files where required, and verify that rebuilding preserves the supplied values and newline semantics.
- Do not end newly created DB fragment filenames in numbers.
- Verify the main pack's complete game-file inventory against its authoritative source; do not preserve extra game files merely because they existed in an older repository revision.

## Branch policy

- Use the repository's default branch (main) for direct commits, or submit changes through pull requests targeting the default branch. Do not continue committing to develop unless the user explicitly requests it.

## Submod layout

- Each submod stores game files in `submods/<name>/src/`. Keep build scripts, documentation and Workshop metadata in the submod root. Build packs relative to that submod's `src/`, without including the `src/` prefix in internal paths.
