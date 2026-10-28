# Arkhan research energy costs

Deathly Incantations (`stephen_tech_arkhan_2`) uses the 250-energy research cost shared with Winds of Death and Binding the Fallen/Mastery of Death/Defiance of Death. Vampiric Sorcery uses the 500-energy cost.

The current user pack supplied on 22 October 2026 has SHA-256 `2cf48507769cbc750095495ae488c69289555da2cff31e5785a015256c60f0fd`. Its cost-to-factor links are valid, but the real `arkhan_lotd_necromantic_energy` reserve has `REGION_GROUP` scope. The native technology cost path needs a faction resource context. Replacing the technology header counter alone does not resolve native affordability or payment.

## Compatibility view

`arkhan_lotd_research_energy` is a separate FACTION resource, granted only to Arkhan's feature group and initially zero. It has no income, buildings, rewards or independent funds. `zz_arkhan_lotd_research_energy.lua` projects Arkhan's actual regional balance into it on campaign events and after loading. A missing regional manager projects zero.

Only the existing 250/500 technology cost links use the new view's `dynasties` factor. Native research still checks affordability and applies its usual costs. Each actual native payment/refund is forwarded once to the real regional resource using its existing `dynasties` factor. Projection corrections use `other`, which the payment listener ignores even if events are queued. No ResearchStarted/ResearchCompleted listener charges the player a second time.

The existing regional reserve remains authoritative. It is never initialised from the view. Nagash's energy key and region group are never queried or altered. All simulation listeners run on every campaign peer and support AI Arkhan; no local UI timer changes resources.

`zz_arkhan_lotd_resource_panels.lua` hides the extra native header entry for the view. Its visible balance and tooltip continue to use the real regional resource. Technology keys, prerequisites, effects, research times, prices, Jars, buildings, rituals, and artwork are unchanged.

## Validation

- Lua 5.1 regression: `.github/tests/arkhan_research_energy.lua`, run from the repository root. Covers 40 assertions, including immediate/queued events, exact affordability thresholds, 250/500 payments, refunds, income, stale saved view values, missing/restored networks, deferred building refresh, and faction isolation.
- Luacheck 1.2.0 passes with the existing main-mod configuration.
- The supplied native DB tables round-trip through their actual RPFM schema versions; new DB/LOC resources are encoded and decoded, not packed as TSV text.
- The corrected pack is reopened and compared by inventory and payload hash: two original entries changed, five support entries added, and the other 747 original entries retained byte for byte. The original ZIP and pack are preserved separately.

This is not an in-game or multiplayer test. Load an existing Arkhan save, verify the displayed balance, start Deathly Incantations, and check that the real reserve falls by 250 once. Also test insufficient energy, a 500-energy research, switching/resuming research, save/reload, and construction/ritual spending. Verify that Jars costs and Nagash's reserve are unaffected. If the new faction resource is missing in a particular old save, capture that save and script logs rather than granting free research or copying funds from Nagash.

## Technology cost tooltip correction

The native technology cost tooltip token `tech_pooled_resource_cost_tooltip_arkhan_lotd_research_energy` requires both a row in `db/ui_text_replacements_tables/atbe.tsv` and its `ui_text_replacements_localised_text_` localisation key in `text/db/arkhan_research.loc`. A localisation lookup can succeed while the `{{tr:...}}` tooltip still fails if the DB registration is missing.

The final correction supplies both records. Relative to the adopted research-energy pack, only those two native payloads change; the complete 754-entry inventory is preserved. The DB was schema-decoded after encoding and the pack reopened for payload comparison. `.github/scripts/check_research_tooltip.py` checks this DB/LOC relationship in CI.

On October 23 the installed `data/arkhan_the_black_expanded.pack` also still contained the earlier LOC without the tooltip key. It was backed up and replaced with the corrected pack. The working pack and installed pack now have SHA-256 `bbfae43152e798400f16716fd26b2bd3b76f058412c2fcc6d09272b923273c57`. Testing used only Arkhan and the existing WH3-MCP harness; no other gameplay mods were enabled.

Live engine check: in the isolated running game, a temporary frontend button tooltip using `{{tr:tech_pooled_resource_cost_tooltip_arkhan_lotd_research_energy}}` returned "In order to research this technology, this amount will be deducted from your total supply of Necromantic Energy." through `UIComponent:GetTooltipText()`. The original button tooltip was restored immediately. The campaign-panel check could not complete because the existing test harness stopped answering after campaign loading; this does not constitute a new live research-payment test. Both missing-registration and missing-localisation regression probes fail as expected.
