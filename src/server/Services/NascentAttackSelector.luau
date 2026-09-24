--!strict

-- Pure, state-based selection for the Stage 1 Nascent. It intentionally has no
-- cooldown table: distance, recent commitment and desperation set the rhythm.
local Selector = {}

function Selector.choose(tuning, distance, lastAttack, serial, desperate)
	if distance <= tuning.MaulingCombination.Range and lastAttack ~= "MaulingCombination" then
		return "MaulingCombination"
	end
	if
		distance >= tuning.PredatoryLunge.MinimumRange
		and distance <= tuning.PredatoryLunge.Range
		and lastAttack ~= "PredatoryLunge"
	then
		return "PredatoryLunge"
	end
	if distance <= tuning.FrenziedChain.Range and lastAttack ~= "FrenziedChain" and (desperate or serial % 3 == 1) then
		return "FrenziedChain"
	end
	if distance <= tuning.RushingStrike.Range then
		return "RushingStrike"
	end
	return nil
end

return Selector
