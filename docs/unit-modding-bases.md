# Zombies and Black Coach: modding bases

Zombies already exist in the main mod. Reuse their existing records rather than creating a second unit.

| Record | Zombies | Black Coach |
| --- | --- | --- |
| Main/land unit | `xereus_tmb_inf_zombie` | `xereus_tmb_veh_black_coach` |
| Unit set | `xereus_tmb_inf_zombie` | `xereus_tmb_veh_black_coach` |
| Unit card | `xereus_tmb_inf_zmb` | `xereus_tmb_veh_black_coach` |
| Model variant | `xereus_tmb_inf_zombie` | `wh_vmp_ghost_hexwraith` (vanilla crew) |
| Campaign recruitment | Existing Arkhan settlement chains | Not assigned yet |
| Capacity effect | Existing Zombies have no unit cap | `stephen_cap_black_coach` |

## Black Coach

The new records live in `db/*_tables/arkhan_black_coach.tsv`; localisation is in `text/db/arkhan_black_coach.loc.tsv`. No vanilla unit records are overridden.

Battle stats and all six ability junctions are copied from the vanilla Black Coach. The model, articulated vehicle, mount, weapons, attributes, porthole scene reference the existing game assets. The unit has an Arkhan-themed purple card at `ui/units/icons/xereus_tmb_veh_black_coach.png` (60×130, opaque edges) and an infopic of the same name (120×260), using the existing Mortis Engine infopic’s edge mask. The card uses the vanilla Black Coach unit-card composition, with its yellow-green background changed to purple using the built-in image-generation tool. It replaces the earlier newly illustrated card. This changes UI artwork only; no battle shader recolour is included.

The main-unit record follows Tomb Kings economics: zero recruitment cost, zero upkeep and a starting campaign capacity of zero. Its custom-battle price remains 1,100. Military access is assigned to `wh2_dlc09_tomb_kings_arkhan`, and the custom-battle permission follows the existing Mortis Engine record, including its campaign-exclusive flag. This does not add a new selectable custom-battle entry.

The unit is in its own unit set and Arkhan's Vampiric unit set. It also has the vanilla undead/tier-three/war-machine classifications and Black Coach single-entity cap groups. It does not join Nagash's recruitment sets or the Mortis Engine-only technology sets.

To enable campaign recruitment:

1. Add a row in `building_units_allowed_tables` for the chosen building and `xereus_tmb_veh_black_coach`, filtered to `wh2_dlc09_tmb_followers_of_nagash`.
2. Add `stephen_cap_black_coach` to the chosen building in `building_effects_junction_tables`, using `building_to_faction_own` and the desired capacity value. The effect is already connected to the unit's own set through `effect_bonus_value_ids_unit_sets_tables`.
3. Choose any building conditions, technologies and recruitment duration changes before testing in game.

Do not duplicate the existing Zombie settlement recruitment rows. Zombie stats, skills, technology links, model and artwork remain unchanged.

## Source and validation

Black Coach source: the game-data export for WH3 9.0.4, [Shazbot/WH3-Dump at fd977bb](https://github.com/Shazbot/WH3-Dump/tree/fd977bb755b3c765c51cf442be2c13ca3d5fa023). Game assets belong to Creative Assembly and their respective rights holders.

The new TSVs have been checked for structure and schema encoding/decoding. Battle rendering, recruitment and campaign balance still need in-game testing once recruitment is assigned.
