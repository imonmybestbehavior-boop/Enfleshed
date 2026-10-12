-- Server-side budget for cosmetic particle emitters and explicit particle bursts.
local Budget = {}

function Budget.new(config, now)
	return {
		Config = config,
		ActiveEmitters = 0,
		ContinuousRate = 0,
		BurstTokens = config.BurstCapacity,
		LastRefill = now or 0,
	}
end

function Budget.acquireEmitter(state, rate)
	local config = state.Config
	rate = math.max(0, rate or 0)
	if state.ActiveEmitters >= config.MaxEmitters then
		return false
	end
	if state.ContinuousRate + rate > config.MaxContinuousRate then
		return false
	end
	state.ActiveEmitters = state.ActiveEmitters + 1
	state.ContinuousRate = state.ContinuousRate + rate
	return true
end

function Budget.releaseEmitter(state, rate)
	if state.ActiveEmitters <= 0 then
		return false
	end
	state.ActiveEmitters = state.ActiveEmitters - 1
	state.ContinuousRate = math.max(0, state.ContinuousRate - math.max(0, rate or 0))
	return true
end

function Budget.takeBurst(state, requested, now)
	requested = math.max(0, math.floor(requested or 0))
	if requested == 0 then
		return 0
	end
	local elapsed = math.max(0, (now or state.LastRefill) - state.LastRefill)
	state.LastRefill = now or state.LastRefill
	state.BurstTokens =
		math.min(state.Config.BurstCapacity, state.BurstTokens + elapsed * state.Config.MaxBurstPerSecond)
	local allowed = math.min(requested, math.floor(state.BurstTokens))
	state.BurstTokens = state.BurstTokens - allowed
	return allowed
end

return Budget
