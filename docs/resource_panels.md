# Arkhan resource panel display

The display-only script `zz_arkhan_lotd_resource_panels.lua` runs only for a local player controlling the Followers of Nagash.

- The post-battle summary hides `wh3_dlc29_nag_necromantic_energy_post_battle_not_gained`, the native warning about being outside Nagash's region group. The actual Arkhan energy reward and other rewards remain untouched.
- The technology header keeps its native Treasury, Canopic Jars and other resource entries. Arkhan's energy counter uses a separate small component bound to his existing region-network pool, with the same CCO lookup used by the working campaign top bar.
- The native header's energy placeholders are hidden only for Arkhan. The counter refreshes on panel opening and while the panel is visible, without creating duplicate widgets.
- No resource is added, removed, mirrored or transferred. No faction, campaign-group, transaction, technology-cost or income table changes are made.
- No shared vanilla panel XML is overridden. `arkhan_lotd_technology_energy.twui.xml` contains only the small header component, using native 90×34 geometry and the pooled-resource tooltip binding.

## Source layouts

The native component paths and callbacks were checked against the game-data dump:

- [technology_panel.twui.xml](https://github.com/Shazbot/WH3-Dump/blob/main/ui/campaign%20ui/technology_panel.twui.xml), blob `f6a26f819e3de13dae48f73ba89696491eb8dbe1`.
- [post_battle_results_panel.twui.xml](https://github.com/Shazbot/WH3-Dump/blob/main/ui/campaign%20ui/post_battle_results_panel.twui.xml), blob `d16f2a9e414f1e2fcb7d79f4da990b0497e68389`.

## Validation

The Lua script passed a local mocked regression run covering balance changes, valid CCO propagation, deterministic region selection, an absent pool, closing/reopening the technology panel, preserving Canopic Jars and real battle rewards, avoiding duplicate widgets, and excluding other local factions. The XML hierarchy and component references were validated.

In-game verification remains required: open and reopen the technology panel, research a technology that spends energy and check the updated balance, then win a battle and confirm the unwanted zero warning is absent while Arkhan's reward remains. Also check after loading a save. Multiplayer simulation state is not modified by this script, but its display has not been tested in multiplayer.
