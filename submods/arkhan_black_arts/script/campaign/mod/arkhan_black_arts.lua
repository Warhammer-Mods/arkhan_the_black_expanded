-- Optional Black Arts add-on. Simulation listeners run on every client.
local FACTION = "wh2_dlc09_tmb_followers_of_nagash"
local RESOURCE = "arkhan_lotd_necromantic_energy"
local GROUP = "arkhan_lotd_necromantic_energy_network"
local DILEMMA = "arkhan_black_arts_awakening"
local BUNDLE = "arkhan_black_arts_awakening"
local COST = 750
local LAST_OFFER = "arkhan_black_arts_last_offer"
local PENDING = "arkhan_black_arts_pending"

local function reserve()
    local system = cm:model():world():region_group_pooled_resource_managers_system()
    local manager = system:get_dynamic_manager_for_region_group_id(GROUP)
    if not manager or manager:is_null_interface() then return nil end
    local resource = manager:resource(RESOURCE)
    if not resource or resource:is_null_interface() then return nil end
    return resource
end

cm:add_first_tick_callback(function()
    core:remove_listener("ArkhanBlackArtsOffer")
    core:remove_listener("ArkhanBlackArtsChoice")
    core:add_listener("ArkhanBlackArtsChoice", "DilemmaChoiceMadeEvent",
        function(context)
            return context:dilemma() == DILEMMA and context:faction():name() == FACTION
        end,
        function(context)
            if not cm:get_saved_value(PENDING) then return end
            cm:set_saved_value(PENDING, false)
            if context:choice() ~= 0 then return end
            local resource = reserve()
            if not resource or resource:value() < COST then return end
            -- Validate and spend against Arkhan's actual regional network.
            -- Never query or debit Nagash's reserve or a faction proxy.
            cm:pooled_resource_factor_transaction(resource, "other", -COST)
            local bundle = cm:create_new_custom_effect_bundle(BUNDLE)
            bundle:set_duration(5)
            bundle:add_effect("wh_main_effect_force_all_campaign_replenishment_rate", "faction_to_force_own", 4)
            bundle:add_effect("wh3_main_effect_winds_of_magic_pool_cap", "faction_to_force_own", 10)
            bundle:add_effect("wh3_main_effect_spell_mastery", "faction_to_character_own", 10)
            cm:apply_custom_effect_bundle_to_faction(bundle, cm:get_faction(FACTION))
        end, true)
    core:add_listener("ArkhanBlackArtsOffer", "FactionTurnStart",
        function(context)
            return context:faction():name() == FACTION and context:faction():is_human()
                and context:faction():has_technology("arkhan_black_arts_great_rite")
        end,
        function(context)
            local turn = cm:turn_number()
            local last = cm:get_saved_value(LAST_OFFER)
            if cm:get_saved_value(PENDING) or (last and turn < last + 5) then return end
            local resource = reserve()
            if not resource or resource:value() < COST then return end
            cm:set_saved_value(LAST_OFFER, turn)
            cm:set_saved_value(PENDING, true)
            -- A regular campaign dilemma synchronizes the player's choice.
            cm:trigger_dilemma(context:faction():name(), DILEMMA)
        end, true)
end)
