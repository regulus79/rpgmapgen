

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


if not core.get_modpath("rpgmapgen_settings") then
	core.request_shutdown("`rpgmapgen` is enabled, but no `rpgmapgen_settings` mod has been created. Please add a mod folder named `rpgmapgen_settings` with an empty `init.lua`. and copy the example `map_parameters.lua` from `rpgmapgen` into it.", false, 0)
end


core.register_mapgen_script(core.get_modpath("rpgmapgen") .. "/mapgen.lua")

