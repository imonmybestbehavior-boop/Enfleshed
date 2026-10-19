-- Roblox-independent trigger-step interpreter used by the server runtime.
-- Keeping the injected executors explicit makes event routing testable without
-- duplicating the production dispatch rules in a test harness.
local Dispatch = {}

-- `conditions` (optional) filters event targets for steps with a Condition;
-- without it, conditional steps never run (fail closed).
function Dispatch.execute(definition, event, context, payloads, behaviors, commands, targetDeath, conditions)
	for _, step in ipairs((definition.Triggers and definition.Triggers[event]) or {}) do
		local matches = true
		if event == "OnThreshold" and step.HealthPercent ~= context.HealthThreshold then
			matches = false
		elseif event == "OnCommand" and not commands.matches(step.Command, context.Command) then
			matches = false
		elseif event == "OnTargetDeath" and not targetDeath.matches(step.DeathMode, context.DeathCause) then
			matches = false
		end

		local stepContext = context
		-- TargetFrom = "Attacker" (OnDamageTaken): act on whoever dealt the damage,
		-- already filtered by the spell's relationship. No eligible attacker: skip.
		if matches and step.TargetFrom == "Attacker" then
			local attackers = context.EventAttackers
			if type(attackers) == "table" and #attackers > 0 then
				stepContext = table.clone(context)
				stepContext.Targets = attackers
			else
				matches = false
			end
		end
		if matches and step.Condition ~= nil then
			local passing = conditions and conditions.filter(step.Condition, stepContext)
			if passing then
				stepContext = table.clone(stepContext)
				stepContext.Targets = passing
			else
				matches = false
			end
		end

		if matches then
			if step.Behavior then
				behaviors.execute(step.Behavior, stepContext, step)
			else
				payloads.execute(step.Payloads or {}, stepContext)
			end
		end
	end
end

return Dispatch
