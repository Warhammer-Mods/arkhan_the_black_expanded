# Arkhan Radious Workshop upload

Prepared for the existing Workshop item:
https://steamcommunity.com/sharedfiles/filedetails/?id=2865162727

The Steam account owning that item must perform the update. Keep its existing published-file ID when choosing the update target in your uploader.

## Files

- `!!arkhan_the_black_radious_submod.pack`: the prepared compatibility pack, using the original upload basename.
- `!!arkhan_the_black_radious_submod.png`: matching 256×256 PNG thumbnail for the Total War uploader; place it next to the pack.
- `workshop_preview.jpg`: 1024×1024 cover for the Workshop image editor.
- `workshop_title.txt`, `workshop_description.txt`, `workshop_changelog.txt`: ready-to-paste page text and update notes.
- `workshop_units.png`: ten small feathered sample cards, with no labels or gaps.
- `workshop_metadata.json`: item and dependency IDs for reference, not an executable upload command.

## Upload

1. Extract the bundle. Put the `.pack` and same-named `.png` together in your WH3 mod upload/data location.
2. Open the upload/update function in your Total War mod uploader and select the existing Radious submod item, ID `2865162727`.
3. Select the prepared pack, confirm that the matching thumbnail is detected, and paste the title and change notes.
4. Paste the description on the Workshop page and retain all five required items listed in `workshop_metadata.json`.
5. Use `workshop_preview.jpg` if updating the full-size cover through Steam's image editor.

The release pack is a byte-identical copy of the previously prepared sandy test pack, renamed to the original Workshop pack basename. The repository's automated builds provide the same game assets from editable sources; uploader and validation metadata need not be distributed as game files.

Before making the update public, confirm a campaign launch with the current main mod, Radious Parts 1–4 and this replacement. Check recruitment, building caps, mounted Lords and the small/large cards. Structural checks and CI succeeded; in-game and multiplayer testing have not yet been confirmed.

Do not enable a separate old compatibility pack alongside this replacement.

## References

Total War's upload guide describes a 256×256 PNG with the same basename as the pack:
https://wiki.totalwar.com/w/Steam_Workshop_and_How_to_Make_Mods

Steamworks preview-image guidance:
https://partner.steamgames.com/doc/api/ISteamUGC#SetItemPreview
