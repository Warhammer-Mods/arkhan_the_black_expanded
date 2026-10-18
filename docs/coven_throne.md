# Arkhan's Coven Throne

The standalone Coven Throne uses `xereus_tmb_veh_coven_throne`. It is a recruitable chariot, separate from the Lahmian lord's existing mount.

## Campaign setup

- Research `stephen_tech_arkhan_unlock_3`, the technology that adds the Lahmian Sister, to gain **one Coven Throne capacity**.
- Recruit from `stephen_tmb_estate_3`, the same estate tier that recruits Mortis Engines.
- Recruitment takes two turns, with no gold recruitment cost or upkeep.
- The recruitment row is restricted to the Followers of Nagash, and the unit's military permission uses Arkhan's own group.
- Base capacity is zero. The estate provides recruitment access; the Lahmian technology supplies capacity. No additional building capacity is included in this initial version.
- The unit belongs to Arkhan's Vampiric unit set and uses his existing global-recruitment-duration modifier.

## Assets and combat

Combat values, all seven native abilities, the vanilla card, engine and all seventeen crew/personality attachments come from the supplied vanilla standalone Coven Throne exports. Its seventeen-entity setup is preserved; it is not converted into a one-man character mount. Native engine, animation, weapon, personality and card records are referenced rather than copied or globally overridden.

The existing Lahmian mount and Black Coach foundation are unchanged. No model or card recolour is included. Radious-specific balancing is not added here.

## Validation and testing

All new DB fragments use the name `arkhan_coven_throne`. Static checks validate TSV layout, schema types, unique primary keys against the main mod, recruitment-key collisions against the supplied vanilla export, and references between the new unit, unit set, capacity effect and technology. A native validation pack was built and reopened locally. GitHub's pack workflow additionally imports and reopens the main pack with RPFM.

In-game checks are still required:

1. Before the Lahmian technology is researched, confirm Coven Throne capacity is zero.
2. Research it, then confirm one capacity and recruitment from the tier-three estate. Also test an existing save where the technology was already researched.
3. Recruit the unit and check its card, recruitment duration and upkeep.
4. In battle, inspect the full crew, movement, attacks and all native abilities; confirm it is a regular unit and the Lahmian mount is unchanged.
5. Save, reload, and confirm capacity and recruitment still work. Check that other Tomb Kings factions do not gain the unit.

Multiplayer behavior has not been tested in game. The integration adds DB rows and does not introduce campaign Lua or UI callbacks.
