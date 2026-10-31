-- Arkhan's Land of the Dead uses his own ritual key. This keeps Nagash's
-- DLC29 Black Pyramid listeners from handling Arkhan's ritual completion.

arkhan_lotd = arkhan_lotd or {
    faction_key = "wh2_dlc09_tmb_followers_of_nagash",
    map_event_key = "wh3_dlc29_nag_undead_legions",
    vfx_key = "land_of_the_dead",
    effect_bundle_key = "arkhan_lotd_land_of_the_dead_devastated",
    provinces = {},
    group_regions = {},
    necropolis_regions = {},
    last_result = "Not used yet"
}

local mod = arkhan_lotd
mod.anchor_region_key = "wh3_main_combi_region_wizard_caliphs_palace"
mod.region_group_key = "arkhan_lotd_necromantic_energy_network"
mod.energy_resource_key = "arkhan_lotd_necromantic_energy"
mod.region_group_category = "arkhan_lotd_land_of_the_dead"
mod.ritual_key = "arkhan_lotd_ritual_devastate_province"
mod.necropolis_chain_key = "wh2_dlc09_tmb_arkhan_burial_mound"
mod.over_cap_bundle_key = "wh3_dlc29_necropolis_over_cap"
mod.land_bundle_key = "arkhan_lotd_land_of_the_dead"
mod.necropolis_count_resource = "wh3_dlc29_nag_necropolises_count"
mod.necropolis_cap_resource = "wh3_dlc29_nag_necropolises_soft_cap"
mod.devastation_count_resource = "wh3_dlc29_nag_devastation_count"
mod.last_over_cap = nil

local function report(ok, message)
    mod.last_result = message
    return ok, message
end

-- Upgrade only the region group created by older Arkhan packs. The native
-- Nagash group ('land_of_the_dead') is never read, debited or removed here.
local LEGACY_ARKHAN_GROUP = "arkhan_lotd_wizard_caliphs_palace"
local LEGACY_ENERGY = "wh3_dlc29_nag_necromantic_energy"

function mod:migrate_legacy_energy()
    if not cm:dynamic_region_group_exists(LEGACY_ARKHAN_GROUP) then return end
    if not cm:dynamic_region_group_pooled_resource_manager_exists(self.region_group_key) then
        return -- No new pool yet; keep the old reserve until one can be created.
    end
    local system = cm:model():world():region_group_pooled_resource_managers_system()
    local manager = system:get_dynamic_manager_for_region_group_id(self.region_group_key)
    if not manager or manager:is_null_interface() then return end
    local resource = manager:resource(self.energy_resource_key)
    if not resource or resource:is_null_interface() then
        report(false, "Arkhan's separate energy pool is not ready; migration will retry.")
        return
    end

    local old_manager = system:get_dynamic_manager_for_region_group_id(LEGACY_ARKHAN_GROUP)
    if old_manager and not old_manager:is_null_interface() then
        local old_resource = old_manager:resource(LEGACY_ENERGY)
        if old_resource and not old_resource:is_null_interface() then
            local balance = old_resource:value()
            local delta = balance - resource:value()
            if delta ~= 0 then
                cm:pooled_resource_factor_transaction(resource, "other", delta)
            end
            report(true, "Moved Arkhan's legacy reserve into his separate energy pool: " .. tostring(balance))
        end
    end
    -- Removing the old group makes this migration one-time across saves.
    if cm:dynamic_region_group_pooled_resource_manager_exists(LEGACY_ARKHAN_GROUP) then
        cm:remove_dynamic_region_group_pooled_resource_manager(LEGACY_ARKHAN_GROUP)
    end
    cm:remove_dynamic_region_group(LEGACY_ARKHAN_GROUP)
end

local function each_region(province, fn)
    local regions = province:regions()
    for i = 0, regions:num_items() - 1 do
        fn(regions:item_at(i))
    end
end

local function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

-- Reusable console command: lua arkhan_lotd:devastate("REGION_KEY")
function mod:devastate(region_key)
    if type(region_key) ~= "string" or region_key == "" then
        return report(false, "Supply a region key in quotes")
    end
    if not devastation_manager then
        return report(false, "DLC29 devastation manager has not loaded")
    end

    local region = cm:get_region(region_key)
    if not region or region:is_null_interface() then
        return report(false, "Unknown region: " .. region_key)
    end
    local province = region:province()
    if not province then
        return report(false, "Region has no province")
    end
    if region:owning_faction():name() ~= self.faction_key then
        return report(false, "Arkhan must own the selected settlement")
    end
    local province_key = province:key()
    if self.provinces[province_key] then
        return report(false, "Province is already devastated by Arkhan")
    end
    if devastation_manager:is_region_devastated(province:capital_region():name()) then
        return report(false, "Province is already devastated by another effect")
    end

    local success = devastation_manager:devastate_region(
        region_key, self.map_event_key, "land_of_the_dead"
    )
    if success == false then
        return report(false, "The game refused to devastate " .. province_key)
    end

    self.provinces[province_key] = true
    each_region(province, function(current)
        cm:remove_effect_bundle_from_region(self.land_bundle_key, current:name())
        cm:remove_effect_bundle_from_region("wh3_dlc29_land_of_the_dead_devastated", current:name())
        cm:apply_effect_bundle_to_region(self.effect_bundle_key, current:name(), -1)
        cm:add_region_vfx(current, self.vfx_key, true, false)
    end)
    return report(true, "Devastated " .. province_key)
end

function mod:cleanse(province_key)
    if not self.provinces[province_key] then return end
    local province = cm:get_province(province_key)
    self.provinces[province_key] = nil
    if not province then return end

    devastation_manager:remove_devastation(province:capital_region():name())
    each_region(province, function(region)
        cm:remove_effect_bundle_from_region(self.effect_bundle_key, region:name())
        cm:remove_effect_bundle_from_region("wh3_dlc29_land_of_the_dead_devastated", region:name())
        if self.group_regions[region:name()] then
            cm:apply_effect_bundle_to_region(self.land_bundle_key, region:name(), -1)
        end
        cm:remove_region_vfx(region, self.vfx_key, true, false)
    end)
    report(true, "Cleansed " .. province_key)
end

function mod:check_provinces()
    if not devastation_manager then return end
    for _, province_key in ipairs(sorted_keys(self.provinces)) do
        local province = cm:get_province(province_key)
        if not province then
            self.provinces[province_key] = nil
        else
            local owned = 0
            each_region(province, function(region)
                if region:owning_faction():name() == self.faction_key then
                    owned = owned + 1
                end
            end)
            if owned == 0 then self:cleanse(province_key) end
        end
    end
end

-- Devastation survives changes to the Necropolis energy network. Reapply its
-- marker on load so the engine also reevaluates conditional building effects.
function mod:restore_devastation_effects(refresh_existing)
    for _, province_key in ipairs(sorted_keys(self.provinces)) do
        local province = cm:get_province(province_key)
        if province then
            each_region(province, function(region)
                local region_key = region:name()
                if region:has_effect_bundle(self.land_bundle_key) then
                    cm:remove_effect_bundle_from_region(self.land_bundle_key, region_key)
                end
                if region:has_effect_bundle("wh3_dlc29_land_of_the_dead_devastated") then
                    cm:remove_effect_bundle_from_region("wh3_dlc29_land_of_the_dead_devastated", region_key)
                end
                if refresh_existing and region:has_effect_bundle(self.effect_bundle_key) then
                    cm:remove_effect_bundle_from_region(self.effect_bundle_key, region_key)
                end
                if not region:has_effect_bundle(self.effect_bundle_key) then
                    cm:apply_effect_bundle_to_region(self.effect_bundle_key, region_key, -1)
                end
            end)
        end
    end
end

-- All of Arkhan's necropolises share one regional pool, as Nagash's do.
-- A built Arkhan burial mound in a major city establishes an additional
-- centre. The starting palace remains the first centre without a prerequisite.
function mod:sync_necropolises()
    local faction = cm:get_faction(self.faction_key)
    if not faction or faction:is_null_interface() then return end

    local desired_regions = {}
    local anchors = {}
    local faction_regions = faction:region_list()
    for i = 0, faction_regions:num_items() - 1 do
        local region = faction_regions:item_at(i)
        local province = region:province()
        if region:name() == province:capital_region():name() and
            (region:name() == self.anchor_region_key or
                cm:region_has_chain_or_superchain(region, self.necropolis_chain_key)) then
            anchors[region:name()] = true
            local function include_province(current)
                each_region(current, function(member)
                    desired_regions[member:name()] = true
                end)
            end
            include_province(province)
            for _, neighbour in model_pairs(province:adjacent_provinces()) do
                include_province(neighbour)
            end
        end
    end

    local group = self.region_group_key
    -- v5 already created a group, before membership was saved in Lua. Seed
    -- the known original palace footprint when migrating an existing save.
    if cm:dynamic_region_group_exists(group) and not next(self.group_regions) then
        local palace = cm:get_region(self.anchor_region_key)
        if palace and not palace:is_null_interface() then
            local function seed(province)
                each_region(province, function(region)
                    self.group_regions[region:name()] = true
                end)
            end
            seed(palace:province())
            for _, neighbour in model_pairs(palace:province():adjacent_provinces()) do
                seed(neighbour)
            end
        end
    end

    if next(anchors) then
        if not cm:dynamic_region_group_exists(group) then
            cm:create_dynamic_region_group(group, self.region_group_category)
            self.group_regions = {}
        end
        if not cm:dynamic_region_group_pooled_resource_manager_exists(group) then
            cm:create_dynamic_region_group_pooled_resource_manager(group)
        end
        for _, region_key in ipairs(sorted_keys(self.group_regions)) do
            if not desired_regions[region_key] then
                local region = cm:get_region(region_key)
                if region and not region:is_null_interface() then
                    cm:remove_region_from_dynamic_region_group(group, region)
                    cm:remove_effect_bundle_from_region(self.land_bundle_key, region_key)
                    if not self.provinces[region:province():key()] then
                        cm:remove_effect_bundle_from_region(self.effect_bundle_key, region_key)
                    end
                end
            end
        end
        for _, region_key in ipairs(sorted_keys(desired_regions)) do
            if not self.group_regions[region_key] then
                local region = cm:get_region(region_key)
                if region and not region:is_null_interface() then
                    cm:add_region_to_dynamic_region_group(group, region)
                end
            end
        end
        -- Keep the Arkhan-specific bundle in step with membership and saved
        -- devastation. The original Nagash bundle and localisation stay intact.
        for _, region_key in ipairs(sorted_keys(desired_regions)) do
            local region = cm:get_region(region_key)
            if region and not region:is_null_interface() then
                if self.provinces[region:province():key()] then
                    if region:has_effect_bundle(self.land_bundle_key) then
                        cm:remove_effect_bundle_from_region(self.land_bundle_key, region_key)
                    end
                    if region:has_effect_bundle("wh3_dlc29_land_of_the_dead_devastated") then
                        cm:remove_effect_bundle_from_region("wh3_dlc29_land_of_the_dead_devastated", region_key)
                    end
                    if not region:has_effect_bundle(self.effect_bundle_key) then
                        cm:apply_effect_bundle_to_region(self.effect_bundle_key, region_key, -1)
                    end
                else
                    if region:has_effect_bundle(self.effect_bundle_key) then
                        cm:remove_effect_bundle_from_region(self.effect_bundle_key, region_key)
                    end
                    if not region:has_effect_bundle(self.land_bundle_key) then
                        cm:apply_effect_bundle_to_region(self.land_bundle_key, region_key, -1)
                    end
                end
            end
        end
    elseif cm:dynamic_region_group_exists(group) then
        for _, region_key in ipairs(sorted_keys(self.group_regions)) do
            cm:remove_effect_bundle_from_region(self.land_bundle_key, region_key)
            local region = cm:get_region(region_key)
            if region and not region:is_null_interface() and
                not self.provinces[region:province():key()] then
                cm:remove_effect_bundle_from_region(self.effect_bundle_key, region_key)
            end
        end
        cm:remove_dynamic_region_group_pooled_resource_manager(group)
        cm:remove_dynamic_region_group(group)
    end

    self.group_regions = desired_regions
    self.necropolis_regions = anchors
    self:restore_devastation_effects(false)
    self:migrate_legacy_energy()
    self:update_necropolis_soft_cap(faction)
end

function mod:update_necropolis_soft_cap(faction)
    local necropolises = 0
    for _ in pairs(self.necropolis_regions) do necropolises = necropolises + 1 end
    local devastated = 0
    for _ in pairs(self.provinces) do devastated = devastated + 1 end
    local cap_bonus = cm:get_factions_bonus_value(faction, "bonus_necropolis_limit") or 0
    local cap = 1 + math.floor(devastated / 3) + cap_bonus
    local over_cap = math.max(0, necropolises - cap)

    -- Once the two vanilla faction resources are assigned to Arkhan's
    -- campaign group, drive the native counters from the actual centres.
    local manager = faction:pooled_resource_manager()
    local function set_counter(key, target, factor)
        local resource = manager:resource(key)
        if resource and not resource:is_null_interface() then
            local delta = target - resource:value()
            if delta ~= 0 then
                cm:faction_add_pooled_resource(self.faction_key, key, factor, delta)
            end
        end
    end
    set_counter(self.necropolis_count_resource, necropolises, "other")
    set_counter(self.necropolis_cap_resource, cap, "wh3_dlc29_necropolis_cap_increase")
    set_counter(self.devastation_count_resource, devastated, "other")

    if self.last_over_cap ~= over_cap then
        if over_cap > 0 then
            local bundle = cm:create_new_custom_effect_bundle(self.over_cap_bundle_key)
            bundle:set_duration(0)
            local penalty = math.max(-100, -10 * over_cap)
            bundle:add_effect("arkhan_lotd_necromantic_energy_buildings_post_mod",
                "faction_to_region_own_regions", penalty)
            bundle:add_effect("arkhan_lotd_necromantic_energy_battle_post_mod",
                "faction_to_force_own", penalty)
            bundle:add_effect("wh_main_effect_economy_gdp_mod_all",
                "faction_to_region_own_regions", penalty)
            cm:apply_custom_effect_bundle_to_faction(bundle, faction)
        elseif faction:has_effect_bundle(self.over_cap_bundle_key) then
            cm:remove_effect_bundle(self.over_cap_bundle_key, self.faction_key)
        end
        self.last_over_cap = over_cap
        report(true, "Necropolises " .. necropolises .. "/" .. cap ..
            ", over-cap penalty " .. (over_cap * 10) .. "%")
    end
end

cm:add_saving_game_callback(function(context)
    cm:save_named_value("ArkhanLandOfTheDeadDevastation", mod.provinces, context)
    cm:save_named_value("ArkhanLandOfTheDeadGroupRegions", mod.group_regions, context)
end)

cm:add_loading_game_callback(function(context)
    mod.provinces = cm:load_named_value("ArkhanLandOfTheDeadDevastation", {}, context)
    mod.group_regions = cm:load_named_value("ArkhanLandOfTheDeadGroupRegions", {}, context)
end)

cm:add_first_tick_callback(function()
    core:add_listener("ArkhanLandOfTheDeadOwnership", "WorldStartRound", true,
        function()
            mod:check_provinces()
            mod:sync_necropolises()
        end, true)

    core:add_listener("ArkhanLandOfTheDeadRegionChange", "RegionFactionChangeEvent", true,
        function() mod:sync_necropolises() end, true)

    core:add_listener("ArkhanLandOfTheDeadNativeRitual", "RitualCompletedEvent",
        function(context)
            return context:ritual():ritual_key() == mod.ritual_key
                and context:performing_faction():name() == mod.faction_key
        end,
        function(context)
            local region = context:ritual_target_region()
            if not region or region:is_null_interface() then
                report(false, "Native ritual completed without a target region")
                return
            end
            local target_key = region:name()
            if region:owning_faction():name() ~= mod.faction_key then
                each_region(region:province(), function(candidate)
                    if candidate:owning_faction():name() == mod.faction_key then
                        target_key = candidate:name()
                    end
                end)
            end
            if mod:devastate(target_key) then
                mod:update_necropolis_soft_cap(cm:get_faction(mod.faction_key))
            end
        end, true)

    for _, province_key in ipairs(sorted_keys(mod.provinces)) do
        local province = cm:get_province(province_key)
        if province then
            each_region(province, function(region)
                cm:add_region_vfx(region, mod.vfx_key, true, false)
            end)
        end
    end

    mod:sync_necropolises()
    mod:restore_devastation_effects(true)
end)
