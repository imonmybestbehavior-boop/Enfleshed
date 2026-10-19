local policy = assert(loadfile("src/shared/Modules/MagicCompanionSpellPolicy.luau"))()

local labDraft = { SpellId = "test", Development = true, Casting = { Mode = "Instant" } }
local companionExecution = policy.executionDefinition(labDraft, "Summon_17_Slot_3")
assert(companionExecution.SpellId == "Summon_17_Slot_3", "Companion casts need isolated cooldown identities")
assert(companionExecution.Development == nil, "Companion casts must not bypass owner Locus costs")
assert(labDraft.Development == true, "Preparing a companion copy must not mutate the editable draft")

local function spell(payloads, relationship)
	return {
		Form = "Projectile",
		Targeting = "AimDirection",
		Casting = { Mode = "Instant" },
		TargetRules = { Relationship = relationship or "Any", Range = 60 },
		Triggers = { OnImpact = { { Payloads = payloads } } },
	}
end

local attack = policy.classify(spell({ { Kind = "Damage", Amount = 12 }, { Kind = "Force", Magnitude = 6 } }))
assert(attack and attack.Mode == "Hostile" and attack.CanDamage and not attack.CanHeal and not attack.CanControl)
local markedAttack = policy.classify(spell({
	{ Kind = "ElementalMark", Stacks = 1, Duration = 5 },
	{ Kind = "Damage", Amount = 12 },
}, "Hostile"))
assert(markedAttack and markedAttack.Mode == "Hostile", "Elemental marks should compose with companion attacks")
local markOnlySpell = spell({ { Kind = "ElementalMark", Stacks = 1, Duration = 5 } }, "Hostile")
markOnlySpell.Element = "Fire"
local markOnly = policy.classify(markOnlySpell)
assert(markOnly and markOnly.Mode == "Hostile", "A configured elemental interaction can be a companion attack")
local neutralMark = spell({ { Kind = "ElementalMark", Stacks = 1, Duration = 5 } }, "Hostile")
neutralMark.Element = "Neutral"
assert(not policy.classify(neutralMark), "Neutral elemental marks should be rejected for companions")
local constructSpell = spell({ { Kind = "Damage", Amount = 18 } }, "Hostile")
constructSpell.Form = "Construct"
constructSpell.Targeting = "EntityTarget"
local constructProfile = policy.classify(constructSpell)
assert(
	constructProfile and constructProfile.Mode == "Hostile",
	"Companions can cast targeted Constructs through the shared runtime"
)
local constructSupport = spell({ { Kind = "Shield", Amount = 20, Duration = 6 } }, "Ally")
constructSupport.Form = "Construct"
constructSupport.Targeting = "EntityTarget"
local constructSupportProfile = policy.classify(constructSupport)
assert(
	constructSupportProfile and constructSupportProfile.Mode == "Ally",
	"Construct support can target an eligible ally"
)
local bindAttack = policy.classify(spell({ { Kind = "Bind", Duration = 1.5 } }))
assert(
	bindAttack and bindAttack.Mode == "Hostile" and bindAttack.CanControl,
	"Bind should be a hostile companion control effect"
)
local slowAttack = policy.classify(spell({ { Kind = "Slow", Multiplier = 0.5, Duration = 3 } }))
assert(slowAttack and slowAttack.Mode == "Hostile" and slowAttack.CanControl)
local revealAttack = policy.classify(spell({ { Kind = "Reveal", Duration = 8 } }))
assert(revealAttack and revealAttack.Mode == "Hostile", "Reveal should classify as a hostile companion effect")
local displacementAttack =
	policy.classify(spell({ { Kind = "Displacement", Mode = "AwayFromCaster", Distance = 8 } }, "Hostile"))
assert(
	displacementAttack and displacementAttack.Mode == "Hostile" and displacementAttack.CanControl,
	"Space displacement should classify as a hostile companion effect"
)
local timeAttack = policy.classify(spell({ { Kind = "TimeDilation", Rate = 0.5, Duration = 5 } }, "Hostile"))
assert(timeAttack and timeAttack.Mode == "Hostile" and timeAttack.CanTimeDilation)
local timeSupport = policy.classify(spell({ { Kind = "TimeDilation", Rate = 1.5, Duration = 5 } }, "Ally"))
assert(timeSupport and timeSupport.Mode == "Ally" and timeSupport.TimeRate == 1.5)

local invalidSupport, invalidSupportReason = policy.classify(spell({ { Kind = "Heal", Amount = 18 } }))
assert(not invalidSupport, "support spells must reject Any targets")
assert(type(invalidSupportReason) == "string", "Rejected companion definitions need a visible reason")
local support = policy.classify(spell({ { Kind = "Heal", Amount = 18 } }, "Ally"))
assert(support and support.Mode == "Ally" and support.CanHeal and not support.CanShield)
local commandSpell = spell({ { Kind = "Damage", Amount = 12 } }, "Hostile")
commandSpell.Casting.Mode = "CommandCast"
local commandProfile = policy.classify(commandSpell)
assert(commandProfile and commandProfile.RequiresCommand, "CommandCast should be restricted to owner-ordered summons")
local instantProfile = policy.classify(spell({ { Kind = "Damage", Amount = 12 } }, "Hostile"))
assert(
	instantProfile and not instantProfile.RequiresCommand,
	"Instant companion spells should preserve autonomous role behavior"
)
local chargedSpell = spell({ { Kind = "Damage", Amount = 12 } }, "Hostile")
chargedSpell.Casting.Mode = "Charged"
local chargedProfile = policy.classify(chargedSpell)
assert(
	chargedProfile and chargedProfile.AutoReleasesAtFullCharge,
	"Companions should use the ordinary server charge lifecycle and auto-release at the configured maximum"
)
chargedSpell.Casting.MaximumCharge = 2.5
chargedSpell.Casting.CastTime = 0.4
assert(
	math.abs(policy.castLockDuration(chargedSpell, 0.3, 0.2) - 3.4) < 1e-8,
	"Companion lock time should include auto-charge and release timing"
)
chargedSpell.Casting.Mode = "HoldAndRelease"
local holdReleaseProfile = policy.classify(chargedSpell)
assert(
	holdReleaseProfile and holdReleaseProfile.AutoReleasesAtFullCharge,
	"Companions should safely auto-release HoldAndRelease spells at the authored maximum"
)
assert(policy.autoReleasesAtFullCharge(chargedSpell, true))
assert(not policy.autoReleasesAtFullCharge(chargedSpell, false), "Player HoldAndRelease must still wait for key-up")
assert(
	math.abs(policy.castLockDuration(chargedSpell, 0.3, 0.2) - 3.4) < 1e-8,
	"Companion lock time should include the full HoldAndRelease charge and release"
)
chargedSpell.Casting.Mode = "Channeled"
chargedSpell.Lifetime = { Mode = "FixedDuration", Duration = 3 }
local channeledProfile = policy.classify(chargedSpell)
assert(
	channeledProfile and channeledProfile.AutoChannelsToLifetime,
	"Companions should run server-owned channels only through their authored bounded duration"
)
assert(policy.requiresCommandSlot(chargedSpell), "A companion channel must consume the shared active-command slot")
chargedSpell.Casting.CastTime = 0.4
assert(
	math.abs(policy.castLockDuration(chargedSpell, 0.3, 0.2) - 3.9) < 1e-8,
	"Companion lock time should cover cast presentation and the full channel lifetime"
)
chargedSpell.Casting.Mode = "Instant"
assert(not policy.requiresCommandSlot(chargedSpell), "Instant companion spells retain their ordinary role loop")
local commandSupportSpell = spell({ { Kind = "Heal", Amount = 12 } }, "Ally")
commandSupportSpell.Casting.Mode = "CommandCast"
local commandSupportProfile = policy.classify(commandSupportSpell)
assert(commandSupportProfile and commandSupportProfile.RequiresCommand and commandSupportProfile.CanHeal)
support = policy.classify(spell({ { Kind = "Restoration", Amount = 4, Duration = 5, Interval = 1 } }, "Ally"))
assert(support and support.Mode == "Ally" and support.CanHeal, "Companions should recognize periodic Restoration")

support = policy.classify(spell({ { Kind = "Shield", Amount = 30, Duration = 8 } }, "Ally"))
assert(support and support.CanShield and support.ShieldAmount == 30)
support = policy.classify(spell(
	{ {
		Kind = "ModifyAttribute",
		Attribute = "MagicArmor",
		Amount = 25,
		Duration = 8,
	} },
	"Ally"
))
assert(support and support.Mode == "Ally" and support.CanModifyAttribute and support.ArmorAmount == 25)
local armorAttack = policy.classify(spell(
	{ {
		Kind = "ModifyAttribute",
		Attribute = "MagicArmor",
		Amount = -20,
		Duration = 8,
	} },
	"Hostile"
))
assert(
	armorAttack and armorAttack.Mode == "Hostile",
	"negative armor modification should be treated as an attack effect"
)

local mixed = policy.classify(spell({ { Kind = "Damage", Amount = 8 }, { Kind = "Heal", Amount = 8 } }))
assert(not mixed, "ambiguous mixed attack/support spells must be rejected")
mixed = policy.classify(spell({ { Kind = "Damage", Amount = 8 }, { Kind = "Heal", Amount = 8 } }, "Hostile"))
assert(mixed and mixed.Mode == "Hostile" and mixed.CanHeal)

local invalid = spell({ { Kind = "Summon", Archetype = "Wisp" } })
assert(not policy.classify(invalid))
invalid.Casting.Mode = "Channeled"
assert(not policy.classify(invalid))
invalid.Casting.Mode = "Instant"
assert(not policy.classify(invalid))

-- Medic companions may cast Boon-only Enchantments on allies.
local function enchantment(payloads, relationship, targeting, mode)
	return {
		Form = "SelfEnhancement",
		Targeting = targeting or "EntityTarget",
		Casting = { Mode = mode or "Instant" },
		TargetRules = { Relationship = relationship or "Ally", Range = 40 },
		Triggers = { OnCast = { { Payloads = payloads } } },
	}
end
local blessing = policy.classify(enchantment({ { Kind = "Shield", Amount = 20 }, { Kind = "Enhancement" } }))
assert(blessing and blessing.Mode == "Ally" and blessing.IsEnchantment and blessing.CanEnchant)
assert(blessing.CanShield and blessing.ShieldAmount == 20 and not blessing.CanDamage, "Boons only")
local swift = policy.classify(enchantment({ { Kind = "Enhancement", SpeedMultiplier = 1.2 } }))
assert(swift and swift.CanEnchant and not swift.CanHeal, "a Swiftness-only blessing is still a Boon enchantment")
local _, baneReason = policy.classify(enchantment({ { Kind = "Shield", Amount = 5 }, { Kind = "Slow" } }))
assert(baneReason and string.find(baneReason, "only contain Boons", 1, true), "Banes are refused")
assert(not policy.classify(enchantment({ { Kind = "AerialMovement" } })), "Aerial movement is self-only")
assert(not policy.classify(enchantment({ { Kind = "Heal", Amount = 5 } }, "Any")), "needs an Ally target rule")
assert(not policy.classify(enchantment({ { Kind = "Heal", Amount = 5 } }, "Ally", "Self")), "must target an ally")
assert(not policy.classify(enchantment({ { Kind = "Heal", Amount = 5 } }, "Ally", nil, "Channeled")))
assert(not policy.classify(enchantment({})), "an empty enchantment is refused")
print("Magic companion spell policy: hostile/support classification and unsupported cases passed")
