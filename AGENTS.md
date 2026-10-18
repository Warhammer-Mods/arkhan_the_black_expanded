# Main-mod source policy

The user-designated authoritative baseline is `arkhan_the_black_expanded(6).zip`, supplied on 18 October 2026. Its `arkhan_the_black_expanded.pack` has SHA-256 `4afde9a4cd35be9ad81d48c36c3253540da77dce7e73d99e09d6b84416d6d00d` and contains 746 game files, excluding three RPFM editor metadata entries.

- Use this baseline and subsequent explicitly authorised changes. Do not merge or restore entries, rows, assets or scripts from earlier uploaded versions.
- When syncing a user-supplied replacement baseline, reflect removals as well as additions and edits. Earlier files may be compared to describe the diff, but must not supply missing content.
- The main game sources are under `animations`, `db`, `script`, `text`, `ui`, `variantmeshes` and `vfx`. Keep repository tooling, documentation and separate `submods` outside a main-pack replacement unless the user requests changes to them.
- Preserve the supplied data and gameplay keys. Export DB/LOC resources through compatible schema-aware tooling, retain native files where required, and verify that rebuilding preserves the supplied values and newline semantics.
- Do not end newly created DB fragment filenames in numbers.
- Verify the main pack's complete game-file inventory against its authoritative source; do not preserve extra game files merely because they existed in an older repository revision.
