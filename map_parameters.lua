local map_parameters = {}

map_parameters.noiseperiods = {500, 100, 50, 10}
map_parameters.noiseamps = {30, 20, 10, 1}


map_parameters.paths = {
	{
		startpos = vector.new(0,0,0),
		endpos = vector.new(1000,0,0),
		radius = 5,
		node = "default:cobble",
		-- Add some noise for waviness in the path
		noise = {
			scale = 10,
			spread = vector.new(50,50,50),
		},
		halfheight_node = "stairs:slab_cobble"
	}
}


-- Circular areas around the map that are guaranteed to exist, for
-- use in story-based games which require stable areas for important locations
map_parameters.level_grounds = {
	{
		pos = vector.new(0,10,0),
		radius = 30,
		interpolation_length = 40,
		node = "default:dirt_with_grass",
		-- Unfortunately this doesn't prevent trees from growing
		suppress_decorations = true
	}
}


-- General map height, pre-noise
map_parameters.map_height = function(x,z)
	-- Simple kind of bell curve to test
	return 20--200 * math.exp(-(x*x + z*z) * 0.00001)
end

-- Input is slope squared because it's faster to calcuate and doesn't really matter
-- Inspired by https://www.youtube.com/watch?v=gsJHzBTPG0Y
map_parameters.slope_adjustment = function(height, slope_squared)
    return height - 10 * slope_squared
end

return map_parameters