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
