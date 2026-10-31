--[[
	Script by Aexrael Dex
	Replaces the starting units for specified starting Lords
]]

local function arkhan_new_army()

	-- Checking whether it's a new game, we don't want to replace armies in the middle of a campaign
	if cm:is_new_game() then

		-- Creating a table with entries for the various starting Lords, their Faction key from Factions table, subtype key from agent_subtypes, Forename from names table and Unit List with keys from Main Units
		local starting_army = {
			-- Arkhan, the Black
			{faction_key = "wh2_dlc09_tmb_followers_of_nagash", subtype = "wh2_dlc09_tmb_arkhan", forename = "names_name_1543395740", units = {"xereus_tmb_inf_skeleton_spearmen", "xereus_tmb_inf_skeleton_archers", "xereus_tmb_inf_skeleton_archers", "wh2_dlc09_tmb_cav_hexwraiths", "wh2_dlc09_tmb_mon_crypt_horrors", "wh2_dlc09_tmb_inf_crypt_ghouls", "wh2_dlc09_tmb_inf_crypt_ghouls", "wh2_dlc09_tmb_inf_spirit_host", "wh2_dlc09_tmb_mon_fell_bats"}}
		};

		for i = 1, #starting_army do
			local faction_name = starting_army[i].faction_key;
			local faction = cm:get_faction(faction_name);
			local char_list = faction:character_list();
			local general_subtype = starting_army[i].subtype;
			local general_forename = starting_army[i].forename;
			local unit_list = starting_army[i].units;

			for j = 0, char_list:num_items() - 1 do
				local current_char = char_list:item_at(j);
				local char_str = cm:char_lookup_str(current_char);

				if current_char:is_null_interface() == false and current_char:character_subtype_key() == general_subtype and current_char:get_forename() == general_forename and current_char:has_military_force() == true then

					-- Removing all existing units from the General
					cm:remove_all_units_from_general(current_char);
					out("ARMY: Removing starting units from " .. general_subtype .. " with forename " .. general_forename);

					for k = 1, #unit_list do
						local unit = unit_list[k];

						-- Granting new units to the General
						cm:grant_unit_to_character(char_str, unit);
						out("ARMY: Adding new starting units to " .. general_subtype .. " with forename " .. general_forename);
					end;
				end;
			end;
		end;
	end;
end;

cm:add_first_tick_callback(function() arkhan_new_army() end);