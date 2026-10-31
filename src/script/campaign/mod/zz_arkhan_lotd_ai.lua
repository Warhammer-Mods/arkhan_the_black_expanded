-- AI decisions only. The native ritual owns validation, costs and completion;
-- arkhan_land_of_the_dead.lua remains responsible for applying/saving devastation.
local FACTION = "wh2_dlc09_tmb_followers_of_nagash"
local ATTEMPT_TURN = "ArkhanLandOfTheDeadAILastAttemptTurn"
local ai = {}
arkhan_lotd_ai = ai

function ai:try_devastation(faction)
    local mod = arkhan_lotd
    if not mod or not devastation_manager or not faction
        or faction:is_null_interface() or faction:name() ~= FACTION
        or faction:is_human() then
        return
    end

    local turn = cm:turn_number()
    if cm:get_saved_value(ATTEMPT_TURN) == turn then return end

    -- Refresh from campaign state, never from a local-player/UI callback.
    mod:check_provinces()
    mod:sync_necropolises()
    if not cm:dynamic_region_group_pooled_resource_manager_exists(mod.region_group_key) then
        return
    end
    local system = cm:model():world():region_group_pooled_resource_managers_system()
    local manager = system:get_dynamic_manager_for_region_group_id(mod.region_group_key)
    if not manager or manager:is_null_interface() then return end
    local resource = manager:resource(mod.energy_resource_key)
    if not resource or resource:is_null_interface() or resource:value() <= 0 then return end

    local status = faction:rituals():ritual_status(mod.ritual_key)
    if not status or status:is_null_interface() or status:disabled()
        or status:script_locked() or status:on_cooldown()
        or status:blocked_by_pending_battle() or status:blocked_by_pending_action() then
        return
    end
    -- Do not use status:available() before setting a target: a region ritual
    -- can report invalid_target at this point. Native execution checks full
    -- availability and the target's actual, scaled regional resource cost.
    local setup = cm:create_new_ritual_setup(faction, mod.ritual_key)
    if not setup then return end
    local target = setup:target()
    local candidates, seen = {}, {}
    local regions = faction:region_list()
    for i = 0, regions:num_items() - 1 do
        local region = regions:item_at(i)
        local province = region:province()
        local province_key = province:key()
        if not seen[province_key] then
            seen[province_key] = true
            local capital = province:capital_region()
            if mod.group_regions[capital:name()] and not mod.provinces[province_key]
                and not devastation_manager:is_region_devastated(capital:name()) then
                local owned = 0
                local members = province:regions()
                for j = 0, members:num_items() - 1 do
                    if members:item_at(j):owning_faction():name() == FACTION then
                        owned = owned + 1
                    end
                end
                if owned > members:num_items() / 2
                    and target:is_region_valid_target(capital) then
                    candidates[#candidates + 1] = {
                        region = capital,
                        key = capital:name(),
                        anchor = capital:name() == mod.anchor_region_key,
                        complete = owned == members:num_items(),
                        owned = owned
                    }
                end
            end
        end
    end

    -- A total ordering prevents region-list iteration order affecting MP state.
    table.sort(candidates, function(a, b)
        if a.anchor ~= b.anchor then return a.anchor end
        if a.complete ~= b.complete then return a.complete end
        if a.owned ~= b.owned then return a.owned > b.owned end
        return a.key < b.key
    end)
    for _, candidate in ipairs(candidates) do
        if target:set_target_region(candidate.region) and target:valid() then
            -- Save before issuing the command: never issue two attempts during
            -- the same faction turn, even when a save is reloaded afterward.
            cm:set_saved_value(ATTEMPT_TURN, turn)
            ai.last_attempt_region = candidate.key
            ai.last_attempt_turn = turn
            cm:perform_ritual_with_setup(setup)
            return
        end
    end
end

cm:add_first_tick_callback(function()
    core:add_listener("ArkhanLandOfTheDeadAIDevastationTurn", "FactionTurnStart",
        function(context)
            local faction = context:faction()
            return faction:name() == FACTION and not faction:is_human()
        end,
        function(context) ai:try_devastation(context:faction()) end,
        true)

    core:add_listener("ArkhanLandOfTheDeadAIDevastationCompleted", "RitualCompletedEvent",
        function(context)
            return arkhan_lotd and context:performing_faction():name() == FACTION
                and not context:performing_faction():is_human()
                and context:ritual():ritual_key() == arkhan_lotd.ritual_key
        end,
        function(context)
            local region = context:ritual_target_region()
            if not region or region:is_null_interface() then return end
            ai.last_completed_region = region:name()
            ai.last_completed_turn = cm:turn_number()
            out("Arkhan AI completed the Ritual of Undeath at " .. ai.last_completed_region)
        end,
        true)
end)
