-- Exercise both maps against the real network/devastation implementation.
local FACTION = "wh2_dlc09_tmb_followers_of_nagash"
local IE = "wh3_main_combi_region_wizard_caliphs_palace"
local TOW = "cr_oldworld_region_black_tower_of_arkhan"
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function list(items)
    return {num_items=function() return #items end,
        item_at=function(_, index) return items[index + 1] end}
end
local function scenario(anchor_key, minor)
    arkhan_lotd = nil
    local regions, provinces, membership, counters, saved = {}, {}, {}, {}, {}
    local group, pool = false, false
    local balance, native_calls = 500, 0
    local callbacks = {}
    local faction = {is_null_interface=function() return false end,
        name=function() return FACTION end, has_effect_bundle=function() return false end}
    local foreign = {name=function() return "other_faction" end}
    local function region(key, province)
        local r = {key=key, owner=faction, bundles={}, province_obj=province}
        function r:name() return self.key end
        function r:is_null_interface() return false end
        function r:province() return self.province_obj end
        function r:owning_faction() return self.owner end
        function r:has_effect_bundle(key) return self.bundles[key] end
        regions[key] = r
        return r
    end
    local function province(key)
        local p = {key=function() return key end, members={}, adjacent={}}
        function p:regions() return list(self.members) end
        function p:capital_region() return self.members[1] end
        function p:adjacent_provinces() return self.adjacent end
        provinces[key] = p
        return p
    end
    local home, neighbour = province("home"), province("neighbour")
    local capital = region(minor and "home_capital" or anchor_key, home)
    home.members = {capital}
    local anchor = capital
    if minor then
        anchor = region(anchor_key, home)
        home.members[2] = anchor
    end
    local nearby = region("nearby", neighbour)
    neighbour.members = {nearby}
    home.adjacent = {neighbour}
    nearby.owner = foreign
    function faction:region_list()
        local owned, seen = {}, {}
        for _, r in ipairs({capital, anchor, nearby}) do
            if r.owner == self and not seen[r] then
                owned[#owned+1], seen[r] = r, true
            end
        end
        return list(owned)
    end
    function faction:pooled_resource_manager()
        return {resource=function(_, key)
            return {is_null_interface=function() return false end,
                value=function() return counters[key] or 0 end}
        end}
    end
    cm = {
        get_region=function(_, key) return regions[key] end,
        get_province=function(_, key) return provinces[key] end,
        get_faction=function() return faction end,
        region_has_chain_or_superchain=function(_, r) return r.burial_mound == true end,
        dynamic_region_group_exists=function(_, key)
            return key == "arkhan_lotd_necromantic_energy_network" and group
        end,
        dynamic_region_group_pooled_resource_manager_exists=function(_, key)
            return key == "arkhan_lotd_necromantic_energy_network" and pool
        end,
        create_dynamic_region_group=function(_, key)
            check(key == "arkhan_lotd_necromantic_energy_network", "Arkhan's own group")
            group = true
        end,
        create_dynamic_region_group_pooled_resource_manager=function() pool = true end,
        add_region_to_dynamic_region_group=function(_, _, r) membership[r:name()] = true end,
        remove_region_from_dynamic_region_group=function(_, _, r) membership[r:name()] = nil end,
        remove_dynamic_region_group_pooled_resource_manager=function() pool = false end,
        remove_dynamic_region_group=function() group = false end,
        apply_effect_bundle_to_region=function(_, key, r) regions[r].bundles[key] = true end,
        remove_effect_bundle_from_region=function(_, key, r) regions[r].bundles[key] = nil end,
        add_region_vfx=function() end, remove_region_vfx=function() end,
        get_factions_bonus_value=function() return 0 end,
        faction_add_pooled_resource=function(_, _, key, _, delta)
            counters[key] = (counters[key] or 0) + delta
        end,
        add_saving_game_callback=function(_, fn) callbacks.save = fn end,
        add_loading_game_callback=function(_, fn) callbacks.load = fn end,
        add_first_tick_callback=function(_, fn) callbacks.first = fn end,
        save_named_value=function(_, key, value) saved[key] = value end,
        load_named_value=function(_, key, default) return saved[key] or default end,
        model=function() return {world=function() return {
            region_group_pooled_resource_managers_system=function() return {
                get_dynamic_manager_for_region_group_id=function() return {
                    is_null_interface=function() return false end,
                    resource=function() return {is_null_interface=function() return false end,
                        value=function() return balance end} end
                } end
            } end
        } end} end
    }
    model_pairs = ipairs
    core = {add_listener=function() end}
    local devastated = {}
    devastation_manager = {
        is_region_devastated=function(_, key) return devastated[key] end,
        devastate_region=function(_, key, event, climate)
            check(event == "wh3_dlc29_nag_undead_legions" and climate == "land_of_the_dead",
                "native devastation event and climate")
            native_calls = native_calls + 1
            devastated[key] = true
            return true
        end,
        remove_devastation=function(_, key) devastated[key] = nil end
    }
    dofile("src/script/campaign/mod/arkhan_land_of_the_dead.lua")
    callbacks.first()
    local mod = arkhan_lotd
    check(mod.anchor_region_key == anchor_key, "map-specific starting anchor")
    check(group and pool, "regional energy network created")
    check(mod.necropolis_regions[anchor_key], "starting centre needs no building")
    check(membership[nearby:name()], "adjacent province shares network")
    check(counters[mod.necropolis_count_resource] == 1, "one initial necropolis")
    check(counters[mod.necropolis_cap_resource] == 1, "initial capacity")
    check(balance == 500, "sync preserves energy balance")
    check(mod:devastate(anchor_key), "owned home province can be devastated")
    check(native_calls == 1 and mod.provinces.home, "devastation recorded")
    check(anchor.bundles[mod.effect_bundle_key], "custom devastation bundle")
    check(not mod:devastate(anchor_key), "no duplicate devastation")
    check(not mod:devastate(nearby:name()), "cannot devastate foreign settlement")
    callbacks.save({})
    mod.provinces, mod.group_regions = {}, {}
    callbacks.load({})
    mod:sync_necropolises()
    check(mod.provinces.home and membership[anchor_key], "load preserves devastation and network")
    check(balance == 500, "reload preserves balance")
    -- Losing the starting settlement must not make a random capital free.
    anchor.owner = foreign
    if capital ~= anchor then capital.owner = foreign end
    mod:check_provinces()
    mod:sync_necropolises()
    check(not mod.provinces.home and not group, "loss cleanses and removes orphaned network")
    -- A constructed necropolis still establishes a network on either map.
    nearby.owner, nearby.burial_mound = faction, true
    mod:sync_necropolises()
    check(group and mod.necropolis_regions.nearby, "built major-city necropolis works")
end
scenario(IE, false)
scenario(TOW, false)
scenario(TOW, true)
print("Arkhan Land of the Dead map compatibility: " .. checks .. " checks passed.")
