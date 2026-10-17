# AI Arkhan: Ritual of Undeath

AI-controlled Followers of Nagash now attempt the custom devastation ritual at the start of their faction turn. Human-controlled Arkhan is excluded, including in multiplayer.

The AI considers provinces in Arkhan's existing Necropolis energy network where he owns more than half the settlements and devastation is not already present. The native ritual target validator makes the final target decision. Wizard Caliph's Palace takes priority, followed by fully owned provinces, more owned settlements and finally capital-region key as a deterministic tie-breaker.

The script requests the real `arkhan_lotd_ritual_devastate_province` through `create_new_ritual_setup` and `perform_ritual_with_setup`. It does not grant energy, manually debit resources, bypass ritual locks or directly apply devastation. Native validation decides whether the selected ritual is affordable, including escalating costs and corruption discounts. An unaffordable request may fail; the AI retries on a later turn. There is at most one request per turn, with the attempt turn saved to prevent repetition after loading a save.

The existing completion listener applies the Arkhan-specific bundles, climate changes, saved devastation state and Necropolis counters. Nagash's ritual, scripts and energy pool are untouched.

## Testing

Use a campaign where Arkhan is AI-controlled and owns a majority of an eligible province within his energy network. Let him accumulate enough Necromantic Energy and advance through his turn. Check the devastated province and conditional building effects, then save/reload and check again. The script runs only on Arkhan's faction turn, not immediately on save load.

An optional standalone test pack contains only `script/campaign/mod/zz_arkhan_lotd_ai.lua`. Enable it alongside an older main mod; disable it once using a main build that already contains the script.

For console inspection, `arkhan_lotd_ai.last_attempt_region`, `last_attempt_turn`, `last_completed_region` and `last_completed_turn` describe the current session. A completed ritual also writes `Arkhan AI completed the Ritual of Undeath at ...` to the enabled script log. These diagnostic fields are not saved; the attempt-turn guard is.

Static and mocked tests cover faction filtering, deterministic target selection, locks, target rejection, missing pools, once-per-turn behavior and native ritual dispatch. Actual resource charging, campaign execution and multiplayer still require in-game testing.

The ritual setup/target API follows the native AI garden conversion implementation in `script/campaign/wh3_campaign_ai.lua` from the WH3 9.0.4 data export. No vanilla campaign script is overridden.
