
--
-- Example Map Parameters
--
-- Create a new mod folder "mod/rpgmapgen_settings/", add an empty init.lua, and add a copy of this file.
-- If the mod is named correctly, the mapgen will recognize it and load the settings from its "map_parameters.lua"
--


local map_parameters = {}

-- Wavelengths of each noise layer
map_parameters.noiseperiods = {500, 100, 50, 10}
-- Amplitudes of each noise layer
map_parameters.noiseamps = {30, 10, 5, 1}



-- Procedurally generated paths from one place to another
map_parameters.paths = {
	{
		startpos = vector.new(0,0,0),
		endpos = vector.new(1000,0,0),
		radius = 5,
		node = "default:cobble",
		-- To make walking up hills easier, you can specify a slab node to use on inclines
		halfheight_node = "stairs:slab_cobble"
		-- You can specify noise parameters to add waviness in the path
		noise = {
			scale = 10,
			spread = vector.new(50,50,50),
		},
	},
}



-- Flat, circular areas around the map that are guaranteed to exist at that position
-- For use in story-based games which require stable areas for important locations
map_parameters.level_grounds = {
	{
		pos = vector.new(0,10,0),
		radius = 30,
		-- Radius outside of circle which is used to interpolate between the flat ground and the surrounding mapgen
		interpolation_length = 40,
		node = "default:dirt_with_grass"
		-- If true, it tries to prevent grass from being spawned. This is a little buggy though, and it may be removed in future versions.
		suppress_decorations = false,
	}
}


-- General map height, before any noise or flat areas are added
-- Useful for adding a mountain range or ocean at a specific location on the map
map_parameters.map_height = function(x,z)
	-- Simple dome-ish shape to test
	return  100 - (x*x + z*z) / 100
end

-- You can also modify the terrain generation based on the slope of the noise
-- Inspired by https://www.youtube.com/watch?v=gsJHzBTPG0Y
-- Input is slope squared because it's faster to calcuate and doesn't really matter
map_parameters.slope_adjustment = function(height, slope_squared)
    return height - 10 * slope_squared
end

return map_parameters