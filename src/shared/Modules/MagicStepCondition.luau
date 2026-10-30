-- Pure per-step condition filter for trigger dispatch. The runtime supplies
-- resolverFor(target), which returns a (family, property) -> value resolver
-- for that target (or for no target when the event has none).
local Evaluator = require(script.Parent.MagicConditionEvaluator)
local StepCondition = {}

-- Returns the event targets that pass, or nil when the step must not run.
-- With no event targets the condition is checked once without a target and
-- an empty list means "run the step" (for example an Explode at the event).
-- Fails closed: only an explicit true result passes.
function StepCondition.filter(condition, targets, resolverFor)
	if #targets == 0 then
		if Evaluator.evaluate(condition, resolverFor(nil), nil) == true then
			return {}
		end
		return nil
	end
	local passing = {}
	for _, target in ipairs(targets) do
		if Evaluator.evaluate(condition, resolverFor(target), nil) == true then
			table.insert(passing, target)
		end
	end
	return if #passing > 0 then passing else nil
end

return StepCondition
