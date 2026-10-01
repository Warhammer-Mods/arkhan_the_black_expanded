-- Campaign-state refreshes run on every peer, from campaign events only.
-- Never call this from a local UI timer or gate it on the local player.
local FACTION = "wh2_dlc09_tmb_followers_of_nagash"
local queued = false

local function queue_refresh()
    if queued then return end
    queued = true
    -- Building/load events may arrive before their final model state is visible.
    cm:callback(function()
        queued = false
        local mod = arkhan_lotd
        if not mod then return end
        mod:check_provinces()
        mod:sync_necropolises()
        out("[Arkhan Necropolis refresh v8] Region coverage and capacity refreshed.")
    end, 0.1)
end

cm:add_first_tick_callback(function()
    -- Called for new campaigns and loaded saves, after saved tables are read.
    queue_refresh()
    for _, event in ipairs({"BuildingCompleted", "BuildingDemolished"}) do
        core:add_listener("ArkhanNecropolisRefreshV8_" .. event, event,
            function(context)
                local building = context:building()
                return building and not building:is_null_interface()
                    and building:faction():name() == FACTION
            end,
            queue_refresh, true)
    end
    core:add_listener("ArkhanNecropolisRefreshV8_Turn", "FactionTurnStart",
        function(context) return context:faction():name() == FACTION end,
        queue_refresh, true)
end)
