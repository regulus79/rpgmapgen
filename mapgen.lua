

local map_parameters = dofile(minetest.get_modpath("tectonicgen") .. "/map_parameters.lua")


-- Convert path nodes to content ids
-- And initialize the noise
for _, path in pairs(map_parameters.paths) do
	path.node = core.get_content_id(path.node)
	path.noise = core.get_value_noise(path.noise)
	if path.halfheight_node then
		path.halfheight_node = core.get_content_id(path.halfheight_node)
	end
end

-- Convert level ground nodes to content ids
for _, level_ground in pairs(map_parameters.level_grounds) do
	if level_ground.node then
		level_ground.node = core.get_content_id(level_ground.node)
	end
end


local distance_to_line = function(startpos, endpos, pos, noise)
	local flat_startpos = vector.new(startpos.x, 0, startpos.z)
	local flat_endpos = vector.new(endpos.x, 0, endpos.z)
	local flat_pos = vector.new(pos.x, 0, pos.z)
	local dir = (flat_endpos - flat_startpos):normalize()
	local len = (flat_endpos - flat_startpos):length()
	local dist_along = (flat_pos - flat_startpos):dot(dir)
	if dist_along > len or dist_along < 0 then
		return math.min(flat_pos:distance(flat_startpos), flat_pos:distance(flat_endpos))
	end
	-- TODO maybe make the interpolation at the endpoints customizable
	if dist_along < 30 then
		noise = noise * dist_along / 30
	elseif dist_along > len - 30 then
		noise = noise * (len - dist_along) / 30
	end
	local rotated_dir = vector.new(-dir.z, 0, dir.x)
	local dist_from = math.abs((flat_pos - flat_startpos):dot(rotated_dir) + noise)
	return dist_from
end

-- Basically two quadratic curves, one flipped, connected together at (0.5, 0.5) to give a smooth transition from 0 to 1
local quadratic_interpolation = function(a, b, t)
	local j
	if t < 0.5 then
		j = 2*t^2
	else
		j = 1 - 2*(t - 1)^2
	end
	return (1 - j)*a + j*b
end


local temporary_node = core.get_content_id("tectonicgen:temporary_node")


local biome_definitions = {}

for biomename, biome in pairs(core.registered_biomes) do
	print(biomename)
	local biomeid = core.get_biome_id(biomename)
	if not biome_definitions[biomeid] then
		biome_definitions[biomeid] = {}
	end
	for key, value in pairs(biome) do
		if type(value) == "string" and string.find(value, ":") then
			biome_definitions[biomeid][key] = minetest.get_content_id(value)
		elseif type(value) == "table" then
			biome_definitions[biomeid][key] = {}
			for i,v in pairs(value) do
				if type(v) == "string" and string.find(v, ":") then
					biome_definitions[biomeid][key][i] = minetest.get_content_id(v)
				else
					biome_definitions[biomeid][key][i] = v
				end
			end
		elseif type(value) == "number" then
			biome_definitions[biomeid][key] = value
		end
	end
end


local default_biome = {
	node_dust = minetest.get_content_id("air"),

	node_top = minetest.get_content_id("mapgen_dirt_with_grass"),
	depth_top = 1,

	node_filler = minetest.get_content_id("mapgen_dirt"),
	depth_filler = 3,

	node_stone = minetest.get_content_id("mapgen_stone"),

	node_water = minetest.get_content_id("mapgen_water_source"),

	node_water_top = minetest.get_content_id("air"),
	depth_water_top = 0,

	node_riverbed = minetest.get_content_id("mapgen_sand"),
	depth_riverbed = 2
}




local noises = {}
for i, period in pairs(map_parameters.noiseperiods) do
	noises[i] = core.get_value_noise_map({
		offset = 0,
		scale = map_parameters.noiseamps[i],
		spread = vector.new(period, period, period),
		seed = i,
		octaves = 1,
	}, {x = 80, y = 80})
end

core.register_on_generated(function(vmanip, minp, maxp, blockseed)
	local noisemaps = {}
	for i, noise in pairs(noises) do
		noisemaps[i] = noise:get_2d_map_flat({x = minp.x, y = minp.z})
	end

	local data = vmanip:get_data()
	--local param2data = vmanip:get_param2_data()

	local emin, emax = vmanip:get_emerged_area()
	local area = VoxelArea(emin, emax)

	local noise2d_idx = 0

	local current_biomeid = nil
	local water_top_cutoff, riverbed_cutoff, top_cutoff, filler_cutoff
	local node_water_top, node_water, node_riverbed, node_stone, node_top, node_filler

	for z = minp.z, maxp.z do
		local x_local = 1
		for x = minp.x, maxp.x do
			local final_noise2d_idx = noise2d_idx + x_local

            local x_slope_offset = x_local + 1 < 80 and 1 or -1
            local z_slope_offset = noise2d_idx + 80 < 80*80 and 1 or -1

			local height = map_parameters.map_height(x, z)
            local x_offset_height = map_parameters.map_height(x + x_slope_offset, z)
            local z_offset_height = map_parameters.map_height(x, z + z_slope_offset)
			for _, noisemap in pairs(noisemaps) do
				height = height + noisemap[final_noise2d_idx]
				x_offset_height = x_offset_height + noisemap[final_noise2d_idx + x_slope_offset]
				z_offset_height = z_offset_height + noisemap[final_noise2d_idx + 80 * z_slope_offset]
			end
            local slope_squared = (x_offset_height - height) * (x_offset_height - height) + (z_offset_height - height) * (z_offset_height - height)
            height = map_parameters.slope_adjustment(height, slope_squared)

			-- Update biome cache if this node is on a different biome
			local biomedata = core.get_biome_data({x=x, y=height, z=z})
			if biomedata.biome ~= current_biomeid then
				current_biomeid = biomedata.biome
				local biomedef = biome_definitions[current_biomeid]

				water_top_cutoff = biomedef.depth_water_top or default_biome.depth_water_top
				riverbed_cutoff = biomedef.depth_riverbed or default_biome.depth_riverbed
				top_cutoff = biomedef.depth_top or default_biome.depth_top
				filler_cutoff = biomedef.depth_filler or default_biome.depth_filler + top_cutoff

				node_water_top = biomedef.node_water_top or default_biome.node_water_top
				node_water = biomedef.node_water or default_biome.node_water
				node_riverbed = biomedef.node_riverbed or default_biome.node_riverbed
				node_top = biomedef.node_top or default_biome.node_top
				node_filler = biomedef.node_filler or default_biome.node_filler
				node_stone = biomedef.node_stone or default_biome.node_stone
			end

			-- Check if in range of level ground area
			local deco_suppressed = false
			local ground_node = nil
			for _, level_ground in pairs(map_parameters.level_grounds) do
				local xz_pos = level_ground.pos:copy()
				xz_pos.y = 0
				local dist = xz_pos:distance(vector.new(x, 0, z))
				if dist < level_ground.radius then
					deco_suppressed = level_ground.suppress_decorations
					-- Adding 0.5-ish (something >0.5) to make sure paths are level with the ground
					height = level_ground.pos.y + 0.5001
					ground_node = level_ground.node
					break
				elseif dist < level_ground.radius + level_ground.interpolation_length then
					local t = (dist - level_ground.radius) / level_ground.interpolation_length
					height = quadratic_interpolation(level_ground.pos.y + 0.5001, height, t)
					-- Randomly choose whether to use ground node during transition
					if math.random() > t then
						ground_node = level_ground.node
					end
					break
				end
			end


			-- Check if in range of path
			local on_path = false
			local path_node = false
			for _, path in pairs(map_parameters.paths) do
				if distance_to_line(path.startpos, path.endpos, vector.new(x,0,z), path.noise:get_2d({x=x,y=z})) < path.radius then
					on_path = true
					if path.halfheight_node then
						if height % 1 > 0.5 then
							path_node = path.node
						else
							path_node = path.halfheight_node
						end
					else
						path_node = path.node
					end
					break
				end
			end

			for y = minp.y, maxp.y do
				-- Depth is positive when underground, negative when in air
				local depth = height - y
				
				-- First check, if this is too deep for anything, just place stone
				if depth >= filler_cutoff then
					data[area:indexp({x=x, y=y, z=z})] = node_stone
				-- Is it underwater?
				elseif y <= 0 then
					if depth < 0 then
						if y > -water_top_cutoff then
							data[area:indexp({x=x, y=y, z=z})] = node_water_top
						else
							data[area:indexp({x=x, y=y, z=z})] = node_water
						end
					elseif depth < riverbed_cutoff then
						data[area:indexp({x=x, y=y, z=z})] = node_riverbed
					else
						-- Placing stone again just in case the riverbed cutoff isn't as deep as the filler cutoff
						data[area:indexp({x=x, y=y, z=z})] = node_stone
					end
				else
					if depth < -1 then
						-- Just air
					elseif depth < 0 then
						if deco_suppressed then
							-- Place a node right above the ground to stop any grass or trees from forming
							data[area:indexp({x=x, y=y, z=z})] = temporary_node
						end
						-- Else, air.
					elseif depth < top_cutoff then
						if on_path then
							data[area:indexp({x=x, y=y, z=z})] = path_node
						elseif ground_node then
							data[area:indexp({x=x, y=y, z=z})] = ground_node
						else
							data[area:indexp({x=x, y=y, z=z})] = node_top
						end
					else
						data[area:indexp({x=x, y=y, z=z})] = node_filler
					end
				end
			end
			x_local = x_local + 1
		end
		noise2d_idx = noise2d_idx + 80 -- Add block
	end

	vmanip:set_data(data)
	--vmanip:set_param2_data(param2data)
	core.generate_decorations(vmanip, minp, maxp)
	core.generate_ores(vmanip, minp, maxp)
	vmanip:calc_lighting(minp, maxp)
end)