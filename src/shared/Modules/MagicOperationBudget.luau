--!strict
-- Bounds the work a single triggering event can cascade into. MaxMagicEventDepth
-- limits how long a reaction chain gets; this limits how wide it gets, since
-- every damaged target can re-emit a reaction that hits every target again.
-- A fresh budget starts at each root event (depth 0); nested reactions share it.
local OperationBudget = {}

export type Budget = { Remaining: number, Exhausted: boolean, Reported: boolean }

function OperationBudget.new(limit: number): Budget
	return { Remaining = limit, Exhausted = false, Reported = false }
end

-- Nested events (EventDepth > 0) inherit their parent's budget. Root events get
-- a new one, so long-lived effects that tick repeatedly never drain it.
function OperationBudget.resolve(runtimeState: any, limit: number): Budget
	local inherited = runtimeState and runtimeState.OperationBudget
	if type(inherited) == "table" and (runtimeState.EventDepth or 0) > 0 then
		return inherited
	end
	return OperationBudget.new(limit)
end

function OperationBudget.spend(budget: Budget, cost: number): boolean
	if budget.Exhausted then
		return false
	end
	if budget.Remaining < cost then
		budget.Exhausted = true
		return false
	end
	budget.Remaining -= cost
	return true
end

-- True exactly once after the budget runs out, so callers report it once.
function OperationBudget.takeReport(budget: Budget): boolean
	if budget.Exhausted and not budget.Reported then
		budget.Reported = true
		return true
	end
	return false
end

return OperationBudget
