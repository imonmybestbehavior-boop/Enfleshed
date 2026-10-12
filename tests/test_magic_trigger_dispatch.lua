local Dispatch = dofile("src/server/Services/MagicTriggerDispatch.luau")

local calls = {}
local payloads = {
	execute = function(list, context)
		for _, payload in ipairs(list) do
			table.insert(calls, { Kind = payload.Kind, Event = context.Event })
			if payload.Kind == "Summon" then
				context.Summon(payload)
			end
		end
	end,
}
local behaviors = {
	execute = function(name, context, behavior)
		table.insert(calls, { Kind = name, Event = context.Event, Radius = behavior.Radius })
	end,
}
local commands = {
	matches = function(expected, actual)
		return expected == actual
	end,
}
local targetDeath = {
	matches = function(expected, actual)
		return expected == actual
	end,
}
local summonFeedback = {}
local context = {
	Event = "OnCast",
	Summon = function(payload)
		table.insert(summonFeedback, payload.Archetype)
	end,
}
local spell = {
	Triggers = {
		OnCast = { { Payloads = { { Kind = "Summon", Archetype = "Wisp" } } } },
		OnImpact = { { Payloads = { { Kind = "Damage", Amount = 12 } } } },
		OnCommand = { { Command = "Attack", Payloads = { { Kind = "Damage", Amount = 3 } } } },
		OnThreshold = { { HealthPercent = 25, Payloads = { { Kind = "Heal", Amount = 4 } } } },
		OnTargetDeath = { { DeathMode = "KilledByThisSpell", Payloads = { { Kind = "Shield", Amount = 5 } } } },
		OnSpawn = { { Behavior = "Explode", Radius = 6, Payloads = { { Kind = "Damage", Amount = 9 } } } },
	},
}

Dispatch.execute(spell, "OnCast", context, payloads, behaviors, commands, targetDeath)
assert(#summonFeedback == 1 and summonFeedback[1] == "Wisp", "OnCast must invoke its payload callback")
assert(#calls == 1 and calls[1].Event == "OnCast", "OnCast must not dispatch impact-only payloads")

context.Event = "OnImpact"
Dispatch.execute(spell, "OnImpact", context, payloads, behaviors, commands, targetDeath)
assert(#calls == 2 and calls[2].Kind == "Damage", "OnImpact must dispatch only when the runtime emits that event")

context.Command = "Hold"
Dispatch.execute(spell, "OnCommand", context, payloads, behaviors, commands, targetDeath)
assert(#calls == 2, "Mismatched named commands must not dispatch payloads")
context.Command = "Attack"
Dispatch.execute(spell, "OnCommand", context, payloads, behaviors, commands, targetDeath)
assert(#calls == 3 and calls[3].Kind == "Damage", "Matching named commands must dispatch payloads")

context.HealthThreshold = 50
Dispatch.execute(spell, "OnThreshold", context, payloads, behaviors, commands, targetDeath)
assert(#calls == 3, "A different health threshold must not dispatch")
context.HealthThreshold = 25
Dispatch.execute(spell, "OnThreshold", context, payloads, behaviors, commands, targetDeath)
assert(#calls == 4 and calls[4].Kind == "Heal", "A matching health threshold must dispatch")

context.DeathCause = "DiedWhileAffected"
Dispatch.execute(spell, "OnTargetDeath", context, payloads, behaviors, commands, targetDeath)
assert(#calls == 4, "A different target-death cause must not dispatch")
context.DeathCause = "KilledByThisSpell"
Dispatch.execute(spell, "OnTargetDeath", context, payloads, behaviors, commands, targetDeath)
assert(#calls == 5 and calls[5].Kind == "Shield", "A matching target-death cause must dispatch")

context.Event = "OnSpawn"
Dispatch.execute(spell, "OnSpawn", context, payloads, behaviors, commands, targetDeath)
assert(
	#calls == 6 and calls[6].Kind == "Explode" and calls[6].Radius == 6,
	"Named behaviors must use behavior dispatch"
)

print("Magic trigger dispatch integration tests passed")
