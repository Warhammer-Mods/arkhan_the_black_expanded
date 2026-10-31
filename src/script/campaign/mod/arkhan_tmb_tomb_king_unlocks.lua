local stephen_tmb_tomb_king_unlocks_techs = {
    ["stephen_tech_arkhan_unlock_1"] = {forename = "names_name_159753854", surname = "", subtype = "stephen_tmb_necrarch_vampire_lord"},              -- Thutmocris
    ["stephen_tech_arkhan_unlock_2"] = {forename = "names_name_159753853", surname = "", subtype = "stephen_tmb_strigoi_ghoul_king"},             -- Talongore
    ["stephen_tech_arkhan_unlock_3"] = {forename = "names_name_159753857", surname = "", subtype = "stephen_tmb_lahmian_vampire_lord"}             -- Khestra     
};

function STEPHEN_add_dynasty_tree_listeners()
    out("#### Adding Dynasty Tree Listeners ####");
    core:add_listener(
        "STEPHEN_DynastyTree_ResearchCompleted",
        "ResearchCompleted",
        true,
        function(context)
            STEPHEN_DynastyTree_ResearchCompleted(context);
        end,
        true
    );
end

function STEPHEN_DynastyTree_ResearchCompleted(context)
    out("#### ResearchCompleted Listener Triggered ####");
    local faction = context:faction();
    local tech_key = context:technology();

    out("Faction: " .. faction:name());
    out("Tech Key: " .. tech_key);

    if faction:is_human() and faction:culture() == "wh2_dlc09_tmb_tomb_kings" then
        out("### Faction is Human and Tomb Kings ###");
        if string.find(tech_key, "stephen_tech_arkhan_unlock_") then
            out("### Tech Key Matches Expected Pattern ###");
            local tomb_king = stephen_tmb_tomb_king_unlocks_techs[tech_key];

            if tomb_king then
                out("### Tomb King Found: " .. tomb_king.subtype .. " ###");
                create_tomb_king(faction:name(), tomb_king);
            else
                out("### No Tomb King Found for Tech Key: " .. tech_key .. " ###");
            end
        else
            out("### Tech Key Does Not Match Expected Pattern ###");
        end
    else
        out("### Faction is Not Human or Not Tomb Kings ###");
    end
end

function create_tomb_king(faction_key, tomb_king)
    out("### Spawning Tomb King for Faction: " .. faction_key);
    cm:spawn_character_to_pool(faction_key, tomb_king.forename, tomb_king.surname, "", "", 18, true, "general", tomb_king.subtype, true, "");
    out("### Tomb King Spawn Attempt Completed ###");
end

cm:add_first_tick_callback(function()
    out("#### First-Tick Callback Triggered ####");
    STEPHEN_add_dynasty_tree_listeners();
end);