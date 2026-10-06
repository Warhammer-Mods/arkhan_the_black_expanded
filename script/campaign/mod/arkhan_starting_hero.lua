cm:add_first_tick_callback(function()
    if not cm:is_new_game() then
        return
    end

    local faction = cm:get_faction(
        "wh2_dlc09_tmb_followers_of_nagash"
    )

    if not faction or faction:is_null_interface() then
        return
    end

    local characters = faction:character_list()

    for i = 0, characters:num_items() - 1 do
        local character = characters:item_at(i)
        local subtype = character:character_subtype_key()

        if subtype == "wh2_dlc09_tmb_tomb_prince"
            or subtype == "stephen_tmb_tomb_prince"
            or subtype == "wh3_dlc29_tmb_tomb_herald"
        then
            CUS:convert_character(
                character,
                "dignitary",
                "stephen_tmb_tomb_herald",
                -1
            )
            return
        end
    end
end)