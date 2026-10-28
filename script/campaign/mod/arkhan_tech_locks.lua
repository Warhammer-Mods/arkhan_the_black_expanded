
--[[
HOW TO USE
1) Add an entry to technology_script_lock_reasons for every technology
   that can be locked.
2) Add mutually exclusive technology groups below.
3) Technologies in the same group lock each other when one is researched.
4) Add dummy effects to indicate mutual exclusivity in the technology UI.
]]

arkhan_mutually_exclusive_techs = {
    data = {
        ["wh2_dlc09_sc_tmb_tomb_kings"] = {
           {"stephen_tech_arkhan_zombies_1", "stephen_tech_arkhan_zombies_2"}
        }
    }
};

function arkhan_mutually_exclusive_techs:initialise()
    -- Build hash tables for efficient lookup.
    self.hash_tables = {};

    for _, subculture in pairs(self.data) do
        for _, tech_lock_list in ipairs(subculture) do
            for _, tech_key in ipairs(tech_lock_list) do
                self.hash_tables[tech_key] = {};

                for _, tech_to_lock in ipairs(tech_lock_list) do
                    if tech_key ~= tech_to_lock then
                        table.insert(self.hash_tables[tech_key], tech_to_lock);
                    end
                end
            end
        end
    end

    self:add_listeners();
end

function arkhan_mutually_exclusive_techs:add_listeners()
    core:add_listener(
        "ResearchCompletedMutuallyExclusiveArkhanTechs",
        "ResearchCompleted",
        true,
        function(context)
            local faction = context:faction();
            local subculture = faction:subculture();

            -- Only process subcultures configured above.
            if self.data[subculture] then
                local tech_key = context:technology();

                if self.hash_tables[tech_key] then
                    local faction_key = faction:name();

                    for _, tech_to_lock in ipairs(self.hash_tables[tech_key]) do
                        cm:lock_technology(faction_key, tech_to_lock);
                    end
                end
            end
        end,
        true
    );
end

arkhan_mutually_exclusive_techs:initialise();
