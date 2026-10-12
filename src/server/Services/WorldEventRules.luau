--!strict
-- Pure event rules, shared by the director and deterministic offline tests.
local Rules = {}
function Rules.available(now, cooldown, active, cap, enemies, count, enemyCap)
	return now >= cooldown and active < cap and enemies + count <= enemyCap
end
function Rules.eligible(credit, config)
	return credit ~= nil
		and (
			credit.Damage >= config.ContributionDamage
			or (credit.Seconds >= config.EscortSeconds and credit.Distance >= config.EscortDistance)
		)
end
function Rules.credit(ledger, userId, damage, seconds, distance)
	local credit = ledger[userId] or { Damage = 0, Seconds = 0, Distance = 0, Paid = false }
	credit.Damage = credit.Damage + math.max(0, damage)
	credit.Seconds = credit.Seconds + math.max(0, seconds)
	credit.Distance = credit.Distance + math.max(0, distance)
	ledger[userId] = credit
end
function Rules.claim(ledger, userId, success, config)
	local credit = ledger[userId]
	if not success or not Rules.eligible(credit, config) or credit.Paid then
		return false
	end
	credit.Paid = true
	return true
end
function Rules.escortStep(traveled, playerTravel, nearBefore, nearNow, dt)
	if
		not nearBefore
		or not nearNow
		or traveled <= 0.2
		or traveled >= 30
		or playerTravel <= 0.2
		or playerTravel >= 40
	then
		return 0, 0
	end
	return dt, math.min(traveled, playerTravel)
end
function Rules.outcome(alive, protectedAlive, arrived, travel, expired)
	if not protectedAlive then
		return "Failed"
	end
	if alive == 0 and (not travel or arrived) then
		return "Completed"
	end
	if expired then
		return "Failed"
	end
	return nil
end
return Rules
