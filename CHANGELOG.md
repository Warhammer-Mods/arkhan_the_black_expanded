# Changelog

## [Unreleased]

### Added

- Arkhan-specific Land of the Dead, devastation and Necropolis mechanics anchored at Wizard Caliph's Palace.
- A separate Necromantic Energy resource, category, income factors and ritual cost for Arkhan.
- Necromantic Energy and Necropolis count/soft-cap displays in the top bar, province UI selectors and Arkhan-specific localisation.
- A new-campaign replacement of Arkhan's starting hero with `stephen_tmb_tomb_herald`, requesting level one.
- Current campaign, unit, building, skill, animation, model and visual-effect sources from the supplied mod pack.

### Changed

- Redirected Arkhan's building and battle energy income and ritual spending to his separate resource.
- Refresh Necropolis campaign data on saved-game load, construction, demolition and faction turns.
- Hide custom Necropolis energy overlays on settlement map labels.
- Recognise Arkhan's custom devastation effect bundle in the building context condition.
- Remove superseded 2022 table and asset fragments so they do not duplicate the current definitions.
- Use non-numeric endings for the added DB fragment names and retain localisation calls and escaped tooltip text.

### Validation

- Pack/source round trips, Lua syntax, UI XML and Arkhan resource/cost links checked locally.
- Mock campaign checks verify migration leaves Nagash's reserve untouched and refresh runs after loading a save.
- Starting-hero replacement confirmed in game; level-one adjustment and multiplayer still require in-game verification.
