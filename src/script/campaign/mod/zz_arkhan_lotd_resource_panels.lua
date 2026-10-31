-- Local presentation only: never create, credit, debit or mirror a resource pool.
local FACTION = "wh2_dlc09_tmb_followers_of_nagash"
local ENERGY = "arkhan_lotd_necromantic_energy"
local RESEARCH_ENERGY = "arkhan_lotd_research_energy"
local LEGACY_ENERGY = "wh3_dlc29_nag_necromantic_energy"
local WARNING = LEGACY_ENERGY .. "_post_battle_not_gained"
local WIDGET = "arkhan_lotd_technology_energy"
local TEMPLATE = "ui/campaign ui/arkhan_lotd_technology_energy.twui.xml"
local LISTENER = "arkhan_lotd_resource_panels"
local last_error

local function is_local_arkhan()
    return cm:get_local_faction_name(true) == FACTION
end

local function energy_state()
    local mod = arkhan_lotd
    if not mod or not mod.region_group_key then return nil end
    local system = cm:model():world():region_group_pooled_resource_managers_system()
    local manager = system:get_dynamic_manager_for_region_group_id(mod.region_group_key)
    if not manager or manager:is_null_interface() then return nil end
    local resource = manager:resource(ENERGY)
    if not resource or resource:is_null_interface() then return nil end
    local regions = {}
    for key in pairs(mod.necropolis_regions or {}) do regions[#regions + 1] = key end
    table.sort(regions)
    return resource:value(), regions[1] or mod.anchor_region_key
end

local function native_resource_key(component)
    local transaction = component:GetContextObject("CcoCampaignPooledResourceTransaction")
    if transaction then return transaction:Call("ResourceKey") end
    local resource = component:GetContextObject("CcoCampaignPooledResource")
    if resource then return resource:Call("Key") end
end

local function refresh_technology(root)
    local panel = find_uicomponent(root, "technology_panel")
    if not panel or not panel:Visible() then return end
    local holder = find_uicomponent(panel, "info_holder_parent", "info_holder")
    if not holder then return end
    -- Arkhan research uses pooled resources; omit the native Treasury display.
    local treasury = find_uicomponent(holder, "dy_treasury")
    if treasury then treasury:SetVisible(false) end

    local widget = find_uicomponent(holder, WIDGET)
        or core:get_or_create_component(WIDGET, TEMPLATE, holder)
    if not widget then return end

    -- Keep native Jar and other resource entries. Only replace energy entries.
    -- The native template looks up PlayersFaction.PooledResourceContext, which
    -- cannot resolve Arkhan's REGION_GROUP balance.
    local list = find_uicomponent(holder, "pooled_resource_list")
    if list then
        for i = 0, list:ChildCount() - 1 do
            local entry = UIComponent(list:Find(i))
            local key = native_resource_key(entry)
            if key == ENERGY or key == LEGACY_ENERGY or key == RESEARCH_ENERGY then
                entry:SetVisible(false)
            end
        end
        list:Layout()
    end

    local value, region = energy_state()
    local label = find_uicomponent(widget, "dy_label")
    local icon = label and find_uicomponent(label, "icon")
    local context
    if region then
        local expression = 'SettlementForRegionKey("' .. region
            .. '").FindPooledResourceFromSettlementRegionGroups("' .. ENERGY .. '")'
        local ok, result = pcall(common.get_context_value, expression)
        if ok and type(result) == "userdata" then context = result end
    end
    if context then
        -- As in the working campaign top bar, pass CCO userdata directly.
        widget:SetContextObject(context)
        if label then label:SetContextObject(context) end
        if icon then icon:SetContextObject(context) end
    else
        local title = common.get_localised_string("pooled_resources_display_name_" .. ENERGY)
        local description = common.get_localised_string("pooled_resources_description_" .. ENERGY)
        widget:SetTooltipText(title .. "\n\n" .. description, "", true)
    end
    if label then label:SetStateText(tostring(value or 0), "") end
    widget:SetVisible(true)
    widget:Layout()
    holder:Layout()
end

local function hide_legacy_battle_warning(root)
    local panel = find_uicomponent(root, "post_battle_results_panel")
    if not panel or not panel:Visible() then return end
    local list = find_uicomponent(panel, "reward_summary_list")
    local warning = list and find_uicomponent(list, WARNING)
    if warning and warning:Visible() then
        warning:SetVisible(false)
        list:Layout()
    end
end

local function refresh()
    if not is_local_arkhan() then return end
    local root = core:get_ui_root()
    if not root then return end
    for _, update in ipairs({refresh_technology, hide_legacy_battle_warning}) do
        local ok, message = pcall(update, root)
        if not ok and last_error ~= tostring(message) then
            last_error = tostring(message)
            out("Arkhan resource panel UI: " .. last_error)
        end
    end
end

cm:add_first_tick_callback(function()
    if not is_local_arkhan() then return end
    core:remove_listener(LISTENER)
    core:remove_listener(LISTENER .. "_opened")
    core:add_listener(LISTENER, "RealTimeTrigger",
        function(context) return context.string == LISTENER end, refresh, true)
    core:add_listener(LISTENER .. "_opened", "PanelOpenedCampaign",
        function(context)
            return context.string == "technology_panel"
                or context.string == "post_battle_results_panel"
        end,
        function()
            cm:real_callback(refresh, 0)
            cm:real_callback(refresh, 100)
        end, true)
    real_timer.unregister(LISTENER)
    real_timer.register_repeating(LISTENER, 500)
    refresh()
end)
