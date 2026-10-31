-- Optional pack: keep AI Arkhan independent from Nagash.
-- No vanilla script replacements, persisted flags or local-player mutations.
local ARKHAN = "wh2_dlc09_tmb_followers_of_nagash"
local NAGASH = "wh3_dlc29_nag_host_of_nagash"
local RITUAL = "wh3_dlc29_nag_mortarchs_arkhan"
local SUBTYPE = "wh2_dlc09_tmb_arkhan"
local LISTENER = "arkhan_independent_option_turn_start"
local announced = false

local function apply_protection()
    local arkhan = cm:get_faction(ARKHAN)
    local nagash = cm:get_faction(NAGASH)
    if not arkhan or arkhan:is_null_interface() or arkhan:is_human()
        or not nagash or nagash:is_null_interface() then return end
    if not nag_mortarchs_config or not nag_mortarchs_config.initial_missions then return end

    -- Both normal AI unlocks and the forty-turn/random fallback iterate this
    -- table. MissionUpdated also looks up this entry before unlocking rituals.
    -- Removing only this entry excludes Arkhan without completing a mission,
    -- changing last_ai_unlock_turn or altering the other Mortarchs.
    nag_mortarchs_config.initial_missions[RITUAL] = nil

    -- The endgame independently performs the subjugation rituals from this
    -- roster, including when ordinary mission conditions have not been met.
    if episode_nagash_endgame and episode_nagash_endgame.mortarch_spawn_data then
        episode_nagash_endgame.mortarch_spawn_data[SUBTYPE] = nil
    end

    -- Covers a ritual already unlocked in an existing save and regular
    -- diplomatic confederation. Reapply on faction turns after loading.
    cm:lock_ritual(nagash, RITUAL)
    cm:force_diplomacy("faction:" .. NAGASH, "faction:" .. ARKHAN,
        "form confederation", false, false, true, true)
    if not announced then
        out("Arkhan independence option: protected AI Arkhan from Nagash")
        announced = true
    end
end

cm:add_first_tick_callback(function()
    apply_protection()
    core:remove_listener(LISTENER)
    core:add_listener(LISTENER, "FactionTurnStart",
        function(context)
            local key = context:faction():name()
            return key == NAGASH or key == ARKHAN
        end,
        apply_protection, true)
end)
