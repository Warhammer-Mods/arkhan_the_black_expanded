# Land of the Dead on The Old World

The starting Necropolis now resolves from regions present on the active map,
not the campaign name. The Old World also supplies a `wh3_main_combi` startpos,
so checking only for the campaign name would select the wrong settlement.

- The Old World: `cr_oldworld_region_black_tower_of_arkhan`.
- Immortal Empires: `wh3_main_combi_region_wizard_caliphs_palace`.

The Old World region key was verified in `db/regions_tables/cr_oldworld_campaign`
inside the installed Workshop mod `3081800026/!cr_oldworld_campaign.pack`.
Its presence takes precedence over the Immortal Empires region. The starting
settlement establishes a centre even if a map makes it a minor settlement.
Additional centres still require Arkhan's burial mound in a province capital.
There is no fallback that gives whichever capital Arkhan owns a free centre.

The same regional network supplies building/battle energy, research projection,
ritual costs and the energy display. The faction counters, Necropolis capacity,
AI choices and saved devastation use the resolved centre. No DB keys, costs,
Nagash resources or summon abilities change. Saved campaigns resolve the map
again when the network refreshes, so a new campaign is not required by this fix.

## Validation

Run `lua5.1 .github/tests/arkhan_lotd_maps.lua` from the repository root.
The mock campaign tests execute the actual main script for Immortal Empires,
The Old World, and The Old World with a minor-settlement starting tower.
They check initial membership/counters, neighbouring regions, devastation,
foreign/duplicate rejection, save/load, loss of the starting centre, constructed
centres and energy preservation. Research payment tests remain separate.

These are script tests, not an in-game compatibility certification. Verify with
The Old World and this mod enabled: load an existing Arkhan campaign, check the
Black Tower's Necropolis counters and energy income, research a paid node,
devastate a valid owned province, inspect terrain/climate and VFX, build another
Necropolis, and save/reload. The custom map's event-area terrain effects and
multiplayer still require live testing.

## Planned Realm of Souls change

The user selected Crypt Horrors as the intended replacement for the standard
Ushabti summon. This is a future gameplay change; this compatibility fix leaves
summons unchanged. Summon size, tier/unlock, duration and limits remain to be set.
