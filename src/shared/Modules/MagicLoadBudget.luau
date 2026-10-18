--!strict
-- Cost-weighted server budget for active magic, layered on the per-player and
-- global count caps. A complex spell costs more of the shared budget than a
-- simple one, and the budget shrinks when the server frame time is slow, so a
-- crowded server degrades by refusing *new* casts instead of dropping frames.
local Budget = {}

Budget.MaxLoad = 120 -- ≈ 64 active spells of average complexity
Budget.ComplexityScale = 10 -- weight = 1 + complexity / scale
Budget.MaxComplexity = 40
Budget.HealthyFrameMs = 25 -- below this, the full budget is available
Budget.CriticalFrameMs = 50 -- at or above this, only MinShare of the budget is available
Budget.MinShare = 0.5
Budget.FrameSmoothing = 0.1 -- EMA factor per heartbeat

function Budget.weight(definition: any): number
	local cost = type(definition) == "table" and type(definition.Cost) == "table" and definition.Cost.Complexity
	local complexity = if type(cost) == "number" and cost == cost then math.clamp(cost, 0, Budget.MaxComplexity) else 0
	return 1 + complexity / Budget.ComplexityScale
end

-- Budget available at the given smoothed server frame time.
function Budget.allowed(frameMs: number): number
	if frameMs ~= frameMs or frameMs <= Budget.HealthyFrameMs then
		return Budget.MaxLoad
	end
	local t = math.clamp((frameMs - Budget.HealthyFrameMs) / (Budget.CriticalFrameMs - Budget.HealthyFrameMs), 0, 1)
	return Budget.MaxLoad * (1 - (1 - Budget.MinShare) * t)
end

function Budget.canAdd(currentLoad: number, weight: number, frameMs: number): boolean
	return currentLoad + weight <= Budget.allowed(frameMs)
end

function Budget.smooth(previousMs: number, deltaSeconds: number): number
	local sample = math.clamp(deltaSeconds * 1000, 0, 1000)
	return previousMs + (sample - previousMs) * Budget.FrameSmoothing
end

return Budget
