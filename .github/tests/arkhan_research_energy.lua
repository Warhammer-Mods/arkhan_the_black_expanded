-- Run with Lua 5.1 from the repository root; no game runtime required.
local script_path = arg[1] or "src/script/campaign/mod/zz_arkhan_lotd_research_energy.lua"
local FACTION = "wh2_dlc09_tmb_followers_of_nagash"
local ENERGY = "arkhan_lotd_necromantic_energy"
local VIEW = "arkhan_lotd_research_energy"
local checks = 0
local function expect(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function setup(balance, projection, queued)
    local listeners, callbacks, queue, transactions = {}, {}, {}, {}
    local state = {source_available = true, view_available = true}
    local function resource(key, amount)
        return {key = function() return key end, value = function(self) return self.amount end,
            is_null_interface = function() return false end, amount = amount}
    end
    local source, view = resource(ENERGY, balance), resource(VIEW, projection)
    local faction = {name = function() return FACTION end, is_null_interface = function() return false end}
    local manager = {resource = function(_, key)
        assert(key == VIEW)
        return state.view_available and view or nil
    end}
    faction.pooled_resource_manager = function() return manager end
    local regional = {is_null_interface = function() return not state.source_available end,
        resource = function(_, key) assert(key == ENERGY); return source end}
    local system = {get_dynamic_manager_for_region_group_id = function(_, key)
        assert(key == "arkhan_lotd_necromantic_energy_network"); return regional
    end}
    local world = {region_group_pooled_resource_managers_system = function() return system end}
    local model = {world = function() return world end}
    local function dispatch(event, context)
        for _, l in ipairs(listeners) do
            if l.event == event and (l.filter == true or l.filter(context)) then l.callback(context) end
        end
    end
    local function emit(event, context)
        if queued then queue[#queue + 1] = {event, context} else dispatch(event, context) end
    end
    local function context(res, factor, amount, who)
        return {resource = function() return res end, factor = function() return {key = function() return factor end} end,
            amount = function() return amount end, has_faction = function() return res == view end,
            faction = function() return who or faction end}
    end
    core = {
        remove_listener = function(_, name)
            for i = #listeners, 1, -1 do if listeners[i].name == name then table.remove(listeners, i) end end
        end,
        add_listener = function(_, name, event, filter, callback)
            listeners[#listeners + 1] = {name = name, event = event, filter = filter, callback = callback}
        end
    }
    cm = {
        model = function() return model end,
        get_faction = function(_, key) assert(key == FACTION); return faction end,
        callback = function(_, callback) callbacks[#callbacks + 1] = callback end,
        add_first_tick_callback = function(_, callback) state.first_tick = callback end,
        pooled_resource_factor_transaction = function(_, res, factor, amount)
            assert(res == source or res == view, "Attempt to access Nagash or an unrelated pool")
            transactions[#transactions + 1] = {res = res, factor = factor, amount = amount}
            res.amount = math.max(0, res.amount + amount)
            emit("PooledResourceChanged", context(res, factor, amount))
        end
    }
    out = function() end
    dofile(script_path)
    local function drain()
        local limit = 0
        while #queue > 0 do
            limit = limit + 1; assert(limit < 100, "Resource-event feedback loop")
            local e = table.remove(queue, 1); dispatch(e[1], e[2])
        end
    end
    state.first_tick(); drain()
    local function change(res, amount, factor, event, who)
        res.amount = res.amount + amount
        emit(event or "PooledResourceChanged", context(res, factor or "other", amount, who)); drain()
    end
    return {source = source, view = view, transactions = transactions, state = state,
        change = change, drain = drain, dispatch = dispatch, callbacks = callbacks, faction = faction}
end

for _, queued in ipairs({false, true}) do
    local h = setup(900, 0, queued)
    expect(h.view.amount, 900, "Initial regional balance projected")
    expect(h.source.amount, 900, "Initial projection does not spend energy")
    h.change(h.view, -250, "dynasties")
    expect(h.source.amount, 650, "Native 250 research cost paid once")
    expect(h.view.amount, 650, "Research projection stays coherent")
    h.change(h.view, -500, "dynasties")
    expect(h.source.amount, 150, "Native 500 research cost paid once")
    h.change(h.view, 250, "dynasties")
    expect(h.source.amount, 400, "Native refund forwarded once")
    h.change(h.source, 191, "battles")
    expect(h.view.amount, 591, "Battle income changes research affordability")
    h.change(h.source, -500, "devastation")
    expect(h.view.amount, 91, "Ritual spending changes research affordability")
    h.change(h.source, 159, "buildings", "PooledResourceRegularIncome")
    expect(h.view.amount, 250, "Regular income updates exact affordability threshold")
    h.state.source_available = false
    h.dispatch("WorldStartRound", {}); h.drain()
    expect(h.view.amount, 0, "Missing regional manager fails closed")
    h.state.source_available = true
    h.dispatch("WorldStartRound", {}); h.drain()
    expect(h.view.amount, 250, "Restored manager rebuilds projection")
    h.dispatch("BuildingDemolished", {})
    expect(#h.callbacks, 1, "Building refresh is deferred after Necropolis rebuild")
    h.callbacks[1](); h.drain()
    expect(h.source.amount, 250, "Deferred refresh cannot spend funds")
    local native_charges = 0
    for _, tx in ipairs(h.transactions) do
        if tx.res == h.source and tx.factor == "dynasties" then native_charges = native_charges + 1 end
    end
    expect(native_charges, 3, "Exactly two payments and one refund; no projection feedback")
    h = setup(249, 9999, queued)
    expect(h.view.amount, 249, "Existing-save stale balance replaced from source")
    expect(h.source.amount, 249, "Loading stale projection cannot mint energy")
    expect(h.view.amount >= 250, false, "Native affordability rejects 249")
    h.change(h.source, 1, "buildings")
    expect(h.view.amount >= 250, true, "Native affordability accepts exactly 250")
    h.change(h.view, -250, "dynasties")
    expect(h.source.amount, 0, "Payment at exact threshold leaves zero")
    local other = {name = function() return "other_faction" end}
    h.change(h.view, 20, "dynasties", nil, other)
    expect(h.source.amount, 0, "Another faction cannot change Arkhan's real reserve")
end
print("Arkhan research energy: " .. checks .. " checks passed (immediate and queued resource events).")
