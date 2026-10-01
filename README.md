# Arkhan the Black: Expanded

Version: **4.0.1** · [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2852724610)

This is the vanilla version of Arkhan the Black: Expanded for Total War: Warhammer III. It adds technologies, skills and abilities for Lords and Heroes, Arkhan-specific Tomb Kings units with unique unit cards, additional recruitment buildings, and a mirrored Realm of Souls ability with different visual effects.

## Land of the Dead

Arkhan can devastate eligible provinces and establish Necropolises, using Wizard Caliph's Palace as his campaign anchor.

- Arkhan has his own Necromantic Energy pool, independent of Nagash's reserve.
- Supported buildings and battles provide energy; devastation rituals spend Arkhan's energy.
- The top bar displays Necromantic Energy and the Necropolis count and soft cap.
- The province interface displays energy with Arkhan-specific localisation.
- Necropolis campaign data refreshes when loading saves and after construction, demolition and turn events.
- Settlement map labels use the standard presentation without the custom energy overlay.

## Starting hero

New campaigns replace Arkhan's starting Tomb Prince or vanilla Tomb Herald with `stephen_tmb_tomb_herald`. The script passes zero inherited levels to the vanilla character-conversion helper so it requests level one. Existing campaigns do not run this starting-hero replacement.

## Source and validation

The source includes the newer building, unit, skill and asset changes from the supplied mod pack, merged with the Land of the Dead additions. Database fragments use readable RPFM TSV exports. The faction colour compatibility table and four custom localisation files remain in native binary form to preserve their values and literal escaped newlines. Added database fragment names do not end in numbers.

Import the source with RPFM configured for Total War: Warhammer III. The existing GitHub Actions workflows also build a pack and check the source tables and Lua scripts.

Local checks cover pack integrity, source-table round trips, resource/cost links, UI XML, Lua syntax, separate-pool migration and save-load refresh. The starting-hero replacement has been confirmed in game; the zero-inherited-level adjustment and multiplayer behaviour still need an in-game check. Campaign changes do not depend on local UI/player state; this is not a guarantee against multiplayer desynchronisation.

## Submods

- [Lore of Vampires](https://steamcommunity.com/sharedfiles/filedetails/?id=2854667379)
- [Lore of Undeath](https://steamcommunity.com/sharedfiles/filedetails/?id=3810060868)
- [Tomb Kings: Extended](https://steamcommunity.com/sharedfiles/filedetails/?id=2862052342)
- [SFO](https://steamcommunity.com/sharedfiles/filedetails/?id=2924973449)
- [Radious](https://steamcommunity.com/sharedfiles/filedetails/?id=2865162727)

## Bug reports and credits

Please report bugs in the [Workshop discussion](https://steamcommunity.com/workshop/filedetails/discussion/2852724610/3427822455473508703/), including whether the issue occurs in a new campaign or an existing save, your active mods, and single-player or multiplayer.

Thanks to the modders at [C&C Modding Den](https://discord.gg/jgVFtUJ), especially [im_mortal](https://steamcommunity.com/id/im_mortal/myworkshopfiles/) and [All is Dust](https://steamcommunity.com/profiles/76561198084410558/myworkshopfiles/?appid=1142710).

All images and assets used on the Workshop page are the property of Creative Assembly.
