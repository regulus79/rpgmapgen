



local biome_definitions = {}

for biomename, biome in pairs(core.registered_biomes) do
    biomeid = core.get_biome_id(biomename)
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



-- General map height, without noise
local map_height = function(x,z)
    -- Simple kind of cone/paraboloid/thing to test
    return -math.sqrt((x*x + z*z) / 5 + 200) + 200
end


local noiseperiods = {500, 100, 50, 5}
local noiseamps = {150, 50, 10, 2}

minetest.register_on_generated(function(vmanip, minp, maxp, blockseed)
    local noises = {}
    local noisemaps = {}
    for i, period in ipairs(noiseperiods) do
        noises[i] = minetest.get_perlin_map({
            offset = 0,
            scale = noiseamps[i],
            spread = vector.new(period, period, period),
            seed = i,
            octaves = 1,
        }, maxp - minp + vector.new(1, 1, 1))
        noisemaps[i] = noises[i]:get_2d_map_flat({x = minp.x, y = minp.z})
    end

    local data = vmanip:get_data()
    --local param2data = vmanip:get_param2_data()

    local emin, emax = vmanip:get_emerged_area()
    local area = VoxelArea(emin, emax)

    local noise2d_idx = 0
    local zstride = maxp.x - minp.x + 1

    local current_biomeid = -1
    local water_top_cutoff, riverbed_cutoff, top_cutoff, filler_cutoff
    local node_water_top, node_water, node_riverbed, node_stone, node_top, node_filler

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local final_noise2d_idx = noise2d_idx + x - minp.x + 1

            local height = map_height(x, z)
			for i, noisemap in pairs(noisemaps) do
			    height = height + noisemap[final_noise2d_idx]
			end

            for y = minp.y, maxp.y do
                local pos = {x=x, y=y, z=z}
                local idx = area:indexp(pos)
                -- Depth is positive when underground, negative when in air
                local depth = height - y

                -- Update biome cache if this node is on a different biome
                local biomedata = core.get_biome_data(pos)
                if biomedata.biome ~= current_biomeid then
                    local biomedef = biome_definitions[biomedata.biome]
                    current_biomeid = biomedata.biome

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

                
                -- First check, if this is too deep for anything, just place stone
                if depth > filler_cutoff then
                    data[idx] = node_stone
                -- Is it underwater?
                elseif y <= 0 then
                    if depth < 0 and y > -water_top_cutoff then
                	    data[idx] = node_water_top
                    elseif depth < 0 then
                	    data[idx] = node_water
                    elseif depth < riverbed_cutoff then
                        data[idx] = node_riverbed
                    else
                        -- Placing stone again just in case the riverbed cutoff isn't as deep as the filler cutoff
                	    data[idx] = node_stone
                    end
                else
                    if depth < 0 then
                        -- Just air
                    elseif depth < top_cutoff then
                        data[idx] = node_top
                    elseif depth < filler_cutoff then
                        data[idx] = node_filler
                    else
                        data[idx] = node_stone
                    end
                end
            end
        end
        noise2d_idx = noise2d_idx + zstride
    end

    vmanip:set_data(data)
    --vmanip:set_param2_data(param2data)
    minetest.generate_decorations(vmanip)
    minetest.generate_ores(vmanip)
    vmanip:calc_lighting()
end)