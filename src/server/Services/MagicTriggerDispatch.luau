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
		if matches and step.TargetFrom == "Caster" then
			-- OnDamageDealt: act on the caster instead of the damaged target (lifesteal).
			local casters = context.CasterTargets
			if type(casters) == "table" and #casters > 0 then
				stepContext = table.clone(context)
				stepContext.Targets = casters
			else
				matches = false
			end
		elseif matches and step.TargetFrom == "Attacker" then
			local attackers = context.EventAttackers
			if type(attackers) == "table" and #attackers > 0 then
				stepContext = table.clone(context)
				stepContext.Targets = attackers
			else
				matches = false
			end
		end
		-- Tether: Anchor = "A" / "B" acts on one end (context.AnchorTargets);
		-- "Both" or nil keeps the event's targets (both ends).
		if matches and (step.Anchor == "A" or step.Anchor == "B") then
			local ends = context.AnchorTargets and context.AnchorTargets[step.Anchor]
			if type(ends) == "table" and #ends > 0 then
				stepContext = table.clone(stepContext)
				stepContext.Targets = ends
			else
				matches = false
			end
		end
		-- Spells as targets: the step acts on live spells it touches, not characters.
		if matches and step.TargetKind == "Spell" then
			local spells = context.ResolveSpellTargets and context.ResolveSpellTargets(step, stepContext)
			if type(spells) == "table" and #spells > 0 then
				stepContext = table.clone(stepContext)
				stepContext.Targets = {}
				stepContext.SpellTargets = spells
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
			-- Interception (OnBeforeDamageTaken): report the match and the first
			-- matching Intercept action to MagicInterception.
			local hooks = context.InterceptHooks
			if hooks then
				hooks.matched()
				if step.Intercept then
					hooks.intercept(step.Intercept)
				end
			end
			if step.TargetKind == "Spell" then
				-- Spell targets are already resolved (an Explode's radius is the
				-- reach); the payloads act on them directly.
				payloads.execute(step.Payloads or {}, stepContext)
			elseif step.Behavior then
				behaviors.execute(step.Behavior, stepContext, step)
			else
				payloads.execute(step.Payloads or {}, stepContext)
			end
		end
	end
end

return Dispatch
