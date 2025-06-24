

-- This system of using temporary nodes to suppress decorations will probably be removed.
core.register_node("rpgmapgen:temporary_node", {
	drawtype = "airlike",
	paramtype = "light",
	walkable = false,
	buildable_to = true,
	pointable = false,
})
-- Ideally this would be an lbm, but those are buggy
core.register_abm({
	label = "Remove temporary mapgen nodes",
	nodenames = {"rpgmapgen:temporary_node"},
	chance = 1,
	interval = 10,
	action = function(pos)
		core.set_node(pos, {name = "air"})
	end,
})


assert(core.get_modpath("rpgmapgen_settings"), "\n\nRPG Mapgen is enabled, but no `rpgmapgen_settings` mod has been created. Please copy the `rpgmapgen_settings` folder into your mods folder, and edit the `map_parameters.lua` file to customize your world!\n")


core.register_mapgen_script(core.get_modpath("rpgmapgen") .. "/mapgen.lua")

