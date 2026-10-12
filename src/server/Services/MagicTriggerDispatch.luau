-- Roblox-independent trigger-step interpreter used by the server runtime.
-- Keeping the injected executors explicit makes event routing testable without
-- duplicating the production dispatch rules in a test harness.
local Dispatch = {}

function Dispatch.execute(definition, event, context, payloads, behaviors, commands, targetDeath)
	for _, step in ipairs((definition.Triggers and definition.Triggers[event]) or {}) do
		local matches = true
		if event == "OnThreshold" and step.HealthPercent ~= context.HealthThreshold then
			matches = false
		elseif event == "OnCommand" and not commands.matches(step.Command, context.Command) then
			matches = false
		elseif event == "OnTargetDeath" and not targetDeath.matches(step.DeathMode, context.DeathCause) then
			matches = false
		end

		if matches then
			if step.Behavior then
				behaviors.execute(step.Behavior, context, step)
			else
				payloads.execute(step.Payloads or {}, context)
			end
		end
	end
end

return Dispatch
