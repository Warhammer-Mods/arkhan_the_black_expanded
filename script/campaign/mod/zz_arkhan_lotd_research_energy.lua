-- Native technology costs require a FACTION pool. The regional network remains
-- authoritative; this compatibility view has no income or independent reserve.
local FACTION = "wh2_dlc09_tmb_followers_of_nagash"
local ENERGY = "arkhan_lotd_necromantic_energy"
local VIEW = "arkhan_lotd_research_energy"
local GROUP = "arkhan_lotd_necromantic_energy_network"
local PREFIX = "ArkhanResearchEnergy"

local function regional_resource()
    local system = cm:model():world():region_group_pooled_resource_managers_system()
    local manager = system:get_dynamic_manager_for_region_group_id(GROUP)
    if not manager or manager:is_null_interface() then return nil end
    local resource = manager:resource(ENERGY)
    if resource and not resource:is_null_interface() then return resource end
end

local function research_resource()
    local faction = cm:get_faction(FACTION)
    if not faction or faction:is_null_interface() then return nil end
    local resource = faction:pooled_resource_manager():resource(VIEW)
    if resource and not resource:is_null_interface() then return resource end
end

local function synchronise()
    local view = research_resource()
    if not view then return end
    local source = regional_resource()
    local amount = (source and source:value() or 0) - view:value()
    if amount ~= 0 then
        -- Projection changes use 'other', never the native payment factor.
        cm:pooled_resource_factor_transaction(view, "other", amount)
    end
end

cm:add_first_tick_callback(function()
    local suffixes = {"Source", "Income", "Payment", "Turn", "Round", "Regions",
        "BuildingCompleted", "BuildingDemolished"}
    for _, suffix in ipairs(suffixes) do
        core:remove_listener(PREFIX .. suffix)
    end
    local function is_source(context)
        return context:resource():key() == ENERGY
    end
    core:add_listener(PREFIX .. "Source", "PooledResourceChanged", is_source, synchronise, true)
    core:add_listener(PREFIX .. "Income", "PooledResourceRegularIncome", is_source, synchronise, true)
    core:add_listener(PREFIX .. "Payment", "PooledResourceChanged",
        function(context)
            return context:resource():key() == VIEW
                and context:has_faction() and context:faction():name() == FACTION
                and context:factor():key() == "dynasties"
        end,
        function(context)
            local source = regional_resource()
            if source and context:amount() ~= 0 then
                -- Forward the actual native payment/refund, including discounts.
                -- Source-change callbacks update the view using 'other', so
                -- synchronous or queued projection events cannot charge twice.
                cm:pooled_resource_factor_transaction(source, "dynasties", context:amount())
            end
            synchronise()
        end, true)
    core:add_listener(PREFIX .. "Turn", "FactionTurnStart",
        function(context) return context:faction():name() == FACTION end, synchronise, true)
    core:add_listener(PREFIX .. "Round", "WorldStartRound", true, synchronise, true)
    core:add_listener(PREFIX .. "Regions", "RegionFactionChangeEvent", true, synchronise, true)
    for _, event in ipairs({"BuildingCompleted", "BuildingDemolished"}) do
        core:add_listener(PREFIX .. event, event, true,
            function()
                -- The Necropolis refresh coalesces building events after 0.1s.
                cm:callback(synchronise, 0.2)
            end, true)
    end
    -- Rebuild from the real reserve on new games and existing saves alike.
    -- Never initialise the regional reserve from the compatibility view.
    synchronise()
end)
