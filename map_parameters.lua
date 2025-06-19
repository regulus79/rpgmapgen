local map_parameters = {}

map_parameters.noiseperiods = {500, 100, 50, 10}
map_parameters.noiseamps = {75, 30, 10, 1}

-- General map height, pre-noise
map_parameters.map_height = function(x,z)
	-- Simple kind of bell curve to test
	return 200 * math.exp(-(x*x + z*z) * 0.00001)
end

-- Input is slope squared because it's faster to calcuate and doesn't really matter
-- Inspired by https://www.youtube.com/watch?v=gsJHzBTPG0Y
map_parameters.slope_adjustment = function(height, slope_squared)
    return height - 10 * slope_squared
end

return map_parameters