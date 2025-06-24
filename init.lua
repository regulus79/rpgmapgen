


core.register_node("tectonicgen:temporary_node", {
	drawtype = "airlike",
	paramtype = "light",
	walkable = false,
	buildable_to = true,
	pointable = false,
})
-- Ideally this would be an lbm, but those are buggy
core.register_abm({
	label = "Remove temporary mapgen nodes",
	nodenames = {"tectonicgen:temporary_node"},
	chance = 1,
	interval = 10,
	action = function(pos)
		core.set_node(pos, {name = "air"})
	end,
})



core.register_mapgen_script(core.get_modpath("tectonicgen") .. "/mapgen.lua")

