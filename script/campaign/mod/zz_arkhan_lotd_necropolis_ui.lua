-- Display-only extension of the confirmed recovery pack.
-- All local timers below read campaign state and modify UI components only.
-- They must never spend resources, update counters or invoke devastation.
local FACTION = "wh2_dlc09_tmb_followers_of_nagash"
local PREFIX = "arkhan_lotd_necropolis_ui_v10"
local TOPBAR_ID = "arkhan_lotd_necropolis_topbar"
local INDICATOR_ID = "arkhan_lotd_necropolis_indicator"
local TOPBAR_PATH = "ui/campaign ui/arkhan_lotd_necropolis_topbar.twui.xml"
local ENERGY_ID = "arkhan_lotd_necromantic_energy_topbar"
local ENERGY_PATH = "ui/campaign ui/arkhan_lotd_necromantic_energy_topbar.twui.xml"
local refresh_energy
local logged = {}

local function log_once(key, message)
    if logged[key] then return end
    logged[key] = true
    out("[Arkhan Necropolis UI v10] " .. message)
end

local function local_arkhan()
    return cm:get_local_faction_name(true) == FACTION
end

local function sorted_keys(map)
    local keys = {}
    for key in pairs(map or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

local function localised(key, ...)
    local text = common.get_localised_string(key)
    -- Keep the .loc entries/localisation lookup, decode escapes for Lua tooltips.
    text = text:gsub("\\\\n", "\n"):gsub("\\n", "\n")
    if select("#", ...) > 0 then text = string.format(text, ...) end
    return text
end

local function tooltip(component, text)
    if component then component:SetTooltipText(text, "", true) end
end

local function faction_resource(key)
    local faction = cm:get_faction(FACTION)
    if not faction or faction:is_null_interface() then return nil end
    local resource = faction:pooled_resource_manager():resource(key)
    if resource and not resource:is_null_interface() then return resource:value() end
end

local function refresh_counts(widget)
    local count = faction_resource("wh3_dlc29_nag_necropolises_count")
    local cap = faction_resource("wh3_dlc29_nag_necropolises_soft_cap")
    local devastated = faction_resource("wh3_dlc29_nag_devastation_count")
    if count == nil or cap == nil or devastated == nil then return end
    local values = {capacity=count, value=cap, devestation_count=devastated}
    for id, value in pairs(values) do
        local label = find_uicomponent(widget, id)
        if label then label:SetStateText(tostring(value), "") end
    end
    local details = localised("arkhan_lotd_capacity_tooltip_v8", count, cap,
        3 - devastated % 3, math.min(100, math.max(0, count - cap) * 10))
    tooltip(find_uicomponent(widget, "necropolis_holder"), details)
    tooltip(find_uicomponent(widget, "arkhan_lotd_necropolis_count"), details)
    local progress = localised("arkhan_lotd_progress_tooltip_v8", devastated, 3 - devastated % 3)
    tooltip(find_uicomponent(widget, "devestation_count_holder"), progress)
    tooltip(find_uicomponent(widget, "devestation_count"), progress)
end

local function attach_energy_bar(bar)
    local energy = find_uicomponent(bar, ENERGY_ID)
        or core:get_or_create_component(ENERGY_ID, ENERGY_PATH, bar)
    if not energy then return end
    local energy_index, counter_index
    for i = 0, bar:ChildCount() - 1 do
        local id = UIComponent(bar:Find(i)):Id()
        if id == ENERGY_ID then energy_index = i end
        if id == TOPBAR_ID then counter_index = i end
    end
    if energy_index and counter_index and energy_index + 1 ~= counter_index then
        local target = counter_index
        if energy_index < counter_index then target = target - 1 end
        bar:Adopt(energy:Address(), target)
    end
    local mod = arkhan_lotd
    if mod then
        local centres = sorted_keys(mod.necropolis_regions)
        refresh_energy(energy, centres[1] or mod.anchor_region_key)
    end
    energy:SetVisible(true)
    energy:Layout()
    bar:Layout()
end

local function refresh_topbar(root)
    local bar = find_uicomponent(root, "hud_campaign", "resources_bar_holder", "resources_bar")
    if not bar then
        bar = find_uicomponent(root, "resources_bar")
    end
    if not bar then
        log_once("missing_bar", "Resource bar not ready; retrying on the next UI refresh.")
        return
    end

    local existing = find_uicomponent(bar, TOPBAR_ID)
    local widget = existing or core:get_or_create_component(TOPBAR_ID, TOPBAR_PATH, bar)
    if not widget then
        log_once("failed_bar", "Could not create the Necropolis counter component.")
        return
    end
    widget:SetVisible(true)
    refresh_counts(widget)
    attach_energy_bar(bar)
    if not existing then
        -- Native bindings in the template read PlayersFaction's existing
        -- count, soft cap and devastation resources.
        widget:SetContextObject(cco("CcoCampaignFaction", FACTION))
        bar:Layout()
        log_once("bar_created", "Necropolis counter and three-province progress display attached.")
    end
end

refresh_energy = function(widget, region_key)
    local holder = find_uicomponent(widget, "resource_holder")
    if not holder then return end
    tooltip(holder, localised("arkhan_lotd_energy_tooltip_v8"))
    local mod = arkhan_lotd
    local system = cm:model():world():region_group_pooled_resource_managers_system()
    local manager = system:get_dynamic_manager_for_region_group_id(mod.region_group_key)
    if not manager or manager:is_null_interface() then
        holder:SetVisible(false)
        return
    end
    local resource = manager:resource("arkhan_lotd_necromantic_energy")
    if not resource or resource:is_null_interface() then
        holder:SetVisible(false)
        return
    end

    local value = find_uicomponent(holder, "dy_necrotic_power")
    if value then
        value:SetState("positive")
        value:SetStateText(tostring(resource:value()), "")
    end
    holder:SetVisible(true)

    -- The province panel's PendingFactorTotal is the projected income.
    -- Actual factor transactions this turn are not an income prediction.
    -- Resolve from the region key so the label need not expose a stored CCO.
    local expression = 'SettlementForRegionKey("' .. region_key
        .. '").FindPooledResourceFromSettlementRegionGroups("arkhan_lotd_necromantic_energy").PendingFactorTotal'
    local ok, pending = pcall(common.get_context_value, expression)
    pending = ok and tonumber(pending) or nil
    local change_holder = find_uicomponent(holder, "dy_necrotic_power_change_holder")
    if change_holder then change_holder:SetVisible(pending ~= nil) end
    local change = find_uicomponent(holder, "dy_income_necromantic_power")
    if change and pending ~= nil then
        change:SetState(pending < 0 and "negative" or "positive")
        change:SetStateText((pending > 0 and "+" or "") .. tostring(pending), "")
    elseif pending == nil then
        log_once("income_" .. region_key, "Income context not ready for " .. region_key .. "; reserve remains visible.")
    end
    holder:Layout()
end

-- Map labels use the game's standard settlement presentation. Do not create
-- the custom Necropolis/energy overlay; hide any surviving instance as well.
local function hide_map_indicators(root)
    local parent = find_uicomponent(root, "3d_ui_parent")
    if not parent then return end
    for i = 0, parent:ChildCount() - 1 do
        local label = UIComponent(parent:Find(i))
        local widget = find_uicomponent(label, INDICATOR_ID)
        if widget then widget:SetVisible(false) end
    end
end

local function refresh()
    if not local_arkhan() then return end
    local root = core:get_ui_root()
    if not root then return end
    local ok, err = pcall(refresh_topbar, root)
    if not ok then log_once("bar_error", "Counter display error: " .. tostring(err)) end
    ok, err = pcall(hide_map_indicators, root)
    if not ok then log_once("labels_error", "Settlement display error: " .. tostring(err)) end
end

cm:add_first_tick_callback(function()
    if not local_arkhan() then return end
    log_once("loaded", "Display extension loaded; using recovery-pack campaign mechanics.")
    core:remove_listener(PREFIX)
    core:add_listener(PREFIX, "RealTimeTrigger",
        function(context) return context.string == PREFIX end,
        refresh, true)
    real_timer.unregister(PREFIX)
    real_timer.register_repeating(PREFIX, 1000)
    refresh()
end)
