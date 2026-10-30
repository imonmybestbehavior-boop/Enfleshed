local Spec = require("../src/shared/Modules/FeatureFlagSpec")
local Defaults = require("../src/shared/Configuration/FeatureFlags")

local flags = Spec.merge(Defaults, nil)
assert(Spec.enabled(flags, "DefendTheWalls", 0), "defaults are on")
assert(not Spec.enabled(flags, "Typo", 0), "unknown features are off")

-- Kill switch and early access
flags = Spec.merge(Defaults, {
	Features = {
		DefendTheWalls = { Enabled = false },
		NewMode = { Enabled = true, PublicReleaseAt = 1000 },
	},
})
assert(not Spec.enabled(flags, "DefendTheWalls", 0, true), "kill switch beats early access")
assert(not Spec.enabled(flags, "NewMode", 999, false), "unreleased feature hidden from everyone else")
assert(Spec.enabled(flags, "NewMode", 999, true), "early access sees it before release")
assert(Spec.enabled(flags, "NewMode", 1000, false), "everyone gets it at release")
assert(Spec.enabled(flags, "LootDrops", 0), "unmentioned defaults survive an override")

-- Defaults are never mutated by a merge
assert(Spec.enabled(Spec.merge(Defaults, nil), "DefendTheWalls", 0), "merge does not mutate defaults")

-- Invalid overrides fail closed to defaults
flags = Spec.merge(Defaults, {
	Features = { DefendTheWalls = { Enabled = "no" }, ["bad name!"] = { Enabled = true } },
	DisabledForms = { "Beam", 5, "Beam", string.rep("x", 60) },
})
assert(Spec.enabled(flags, "DefendTheWalls", 0), "non-boolean Enabled is ignored")
assert(flags.Features["bad name!"] == nil, "invalid feature names are ignored")
assert(#flags.DisabledForms == 1 and flags.DisabledForms[1] == "Beam", "lists are cleaned and de-duplicated")
assert(Spec.merge(Defaults, "garbage").Features.DefendTheWalls.Enabled, "non-table override ignored")

-- Spell kill switches
local spell = {
	Form = "Projectile",
	Projectile = { Behaviors = { { Kind = "Homing" } } },
	Triggers = {
		OnImpact = { { Behavior = "Explode", Payloads = { { Kind = "Damage" }, { Kind = "Control" } } } },
	},
}
local open = Spec.merge(Defaults, nil)
assert(Spec.spellAllowed(open, spell), "nothing disabled by default")
assert(not Spec.spellAllowed(Spec.merge(Defaults, { DisabledForms = { "Projectile" } }), spell), "form switch")
assert(not Spec.spellAllowed(Spec.merge(Defaults, { DisabledPayloads = { "Control" } }), spell), "payload switch")
assert(
	not Spec.spellAllowed(Spec.merge(Defaults, { DisabledBehaviors = { "Homing" } }), spell),
	"projectile behavior switch"
)
assert(
	not Spec.spellAllowed(Spec.merge(Defaults, { DisabledBehaviors = { "Explode" } }), spell),
	"trigger behavior switch"
)
local ok, reason = Spec.spellAllowed(Spec.merge(Defaults, { DisabledPayloads = { "Control" } }), spell)
assert(not ok and reason:find("Control"), "reason names the disabled part")
assert(not Spec.spellAllowed(open, nil), "missing spell rejected")

print("Feature flags: defaults, kill switch, early access window, fail-closed merge and spell kill switches passed")
