--!strict
-- Sequential delay that exits as soon as its playback session stops.
return {
	Run = function(session, config)
		session:Await(math.clamp(tonumber(config.Duration) or 0, 0, 30))
	end,
}
