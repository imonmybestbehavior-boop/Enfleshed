--!strict
-- Pure rules for analytics: the onboarding funnel order and per-session spell
-- usage aggregation (one summary event per spell shape instead of one per cast).
local Spec = {}

-- Onboarding funnel, in order. Roblox records each step once per player.
Spec.Onboarding = {
	"Joined",
	"Spawned",
	"OpenedGrimoire",
	"CastSpell",
	"SavedSpell",
	"EnteredMission",
	"FinishedMission",
	"BoughtUnlock",
}

function Spec.onboardingStep(name: string): number?
	return table.find(Spec.Onboarding, name)
end

Spec.MaxSpellKeys = 20 -- distinct spell shapes summarized per player session

export type SpellUsage = { [string]: { Form: string, Element: string, Effect: string, Count: number } }

local function primaryEffect(definition: any): string
	for _, event in { "OnImpact", "OnCast", "OnTick", "OnExpire" } do
		local steps = type(definition.Triggers) == "table" and definition.Triggers[event]
		if type(steps) == "table" then
			for _, step in steps do
				local payloads = type(step) == "table" and step.Payloads
				if type(payloads) == "table" and type(payloads[1]) == "table" then
					return tostring(payloads[1].Kind)
				end
			end
		end
	end
	return "None"
end

-- Records one cast. Returns false when the session already tracks MaxSpellKeys
-- other shapes (the cast is then counted under "Other").
function Spec.recordCast(usage: SpellUsage, definition: any): boolean
	if type(definition) ~= "table" then
		return false
	end
	local form, element = tostring(definition.Form), tostring(definition.Element or "Neutral")
	local effect = primaryEffect(definition)
	local key = form .. "|" .. element .. "|" .. effect
	local entry = usage[key]
	if not entry then
		local count = 0
		for _ in usage do
			count += 1
		end
		if count >= Spec.MaxSpellKeys then
			key = "Other"
			entry = usage[key]
			if not entry then
				entry = { Form = "Other", Element = "Other", Effect = "Other", Count = 0 }
				usage[key] = entry
			end
			entry.Count += 1
			return false
		end
		entry = { Form = form, Element = element, Effect = effect, Count = 0 }
		usage[key] = entry
	end
	entry.Count += 1
	return true
end

return Spec
