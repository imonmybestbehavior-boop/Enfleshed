local Summons = dofile("src/shared/Configuration/MagicSummons.luau")
local RolePolicy = dofile("src/shared/Modules/MagicSummonRolePolicy.luau")
local Wisp = Summons.Archetypes.Wisp
local Sentinel = Summons.Archetypes.Sentinel

assert(table.concat(Summons.ArchetypeOrder, ",") == "Wisp,Sentinel", "Summon archetype registry changed unexpectedly")
for name, archetype in pairs(Summons.Archetypes) do
	assert(archetype.Health > 0 and archetype.CoreSize > 0, name .. " requires positive health and model size")
	assert(archetype.MoteCount >= 0 and archetype.MoteCount <= 6, name .. " mote count exceeds the presentation cap")
	assert(
		archetype.ArmorPlateCount >= 0 and archetype.ArmorPlateCount <= 4,
		name .. " armor plate count exceeds the presentation cap"
	)
	if archetype.ArmorPlateCount > 0 then
		assert(
			archetype.ArmorPlateThickness > 0
				and archetype.ArmorPlateHeight > 0
				and archetype.ArmorPlateWidth > 0
				and archetype.ArmorPlateDistance > archetype.CoreSize * 0.5,
			name .. " armor silhouette must have valid dimensions and clear the core"
		)
	end
	assert(Summons.GuardRadius + archetype.FollowDistance <= archetype.SearchRadius)
	assert(Summons.MaxCommandRange + archetype.FollowDistance <= Summons.CommandChaseRange)
end
assert(Sentinel.Health > Wisp.Health, "Ward Sentinel should provide a distinct durable archetype")
assert(Sentinel.CoreShape == "Block" and Wisp.CoreShape == "Ball", "Archetype presentation should remain distinct")
assert(Sentinel.CoreMaterial ~= Wisp.CoreMaterial, "Archetypes should not share one core material treatment")
assert(
	Sentinel.ArmorPlateCount == 4 and Wisp.ArmorPlateCount == 0,
	"Only the Sentinel should use a guarded armor silhouette"
)
assert(Wisp.MoteCount > Sentinel.MoteCount, "The Wisp should keep the lighter, more active orbital silhouette")

assert(Summons.DefaultCommand == "Protect", "Existing auto-protection behavior should remain the default")
assert(Summons.MaxActiveCommands == 1, "V1 should permit one active CommandCast execution per owner")
assert(
	table.concat(Summons.CommandOrder, ",") == "Follow,Protect,Attack,Move,Patrol,Hold,Support,Dismiss",
	"Summon command order changed unexpectedly"
)
local seenCommandKeys = { [Summons.SelectionKey] = "selection" }
for _, command in ipairs(Summons.CommandOrder) do
	local key = Summons.CommandKeys[command]
	assert(type(key) == "string" and #key > 0, command .. " requires a keyboard command binding")
	assert(not seenCommandKeys[key], "Summon command keys must remain distinct")
	seenCommandKeys[key] = command
end
assert(
	table.concat(Summons.LifetimeModes, ",") == "FixedDuration,UntilCommanded",
	"Summon lifetime modes changed unexpectedly"
)
assert(table.concat(Summons.RespawnPolicies, ",") == "DismissOnDeath,PersistUntilDismissed")
assert(Summons.RespawnGracePeriod >= 10 and Summons.RespawnGracePeriod <= 120)
assert(
	Summons.GuardRadius + Wisp.FollowDistance <= Wisp.SearchRadius,
	"Protect radius must fit within Wisp search reach"
)
assert(
	Summons.MaxCommandRange + Wisp.FollowDistance <= Summons.CommandChaseRange,
	"Attack command must be reachable from the follow orbit"
)
assert(Summons.MaxActivePerPlayer <= Summons.MaxActiveGlobal, "Per-player summon cap exceeds the global cap")
assert(
	Summons.MaxMoveOrderRange > 0 and Summons.MaxMoveOrderRange <= Summons.MaxCommandRange,
	"Move orders must remain bounded"
)
assert(Summons.MinPatrolWaypointDistance >= 4, "Patrol points need enough separation to avoid hover jitter")
assert(Summons.DefaultRole == "Guardian", "Existing summon spells must retain guardian behavior by default")
assert(
	table.concat(Summons.RoleOrder, ",") == "Guardian,Hunter,Medic,Controller",
	"Summon role options changed unexpectedly"
)
assert(
	RolePolicy.targetMode(Summons.Roles.Guardian, "Protect", nil) == "Hostile",
	"Guardian should retain hostile acquisition"
)
assert(
	RolePolicy.requiresOwnerProtectionRadius(Summons.Roles.Guardian),
	"Guardian should protect the owner's local area"
)
assert(
	RolePolicy.targetMode(Summons.Roles.Hunter, "Protect", nil) == "Hostile"
		and not RolePolicy.requiresOwnerProtectionRadius(Summons.Roles.Hunter),
	"Hunter should use the full independent search radius"
)
assert(
	RolePolicy.targetMode(Summons.Roles.Medic, "Protect", "Ally") == "Ally"
		and RolePolicy.targetMode(Summons.Roles.Medic, "Protect", "Hostile") == "None",
	"Medic may only acquire valid Ally-support targets"
)
assert(Summons.Roles.Controller.RequiredCapability == "CanControl")
assert(RolePolicy.targetMode(Summons.Roles.Controller, "Protect", "Hostile") == "Hostile")
assert(not RolePolicy.canMelee(Summons.Roles.Controller, "Hostile"), "Controller must not fall back to melee")
assert(not RolePolicy.canMelee(Summons.Roles.Medic, nil), "Medic must never use built-in melee")
assert(not RolePolicy.canMelee(Summons.Roles.Guardian, "Ally"), "Support targeting must never fall through to melee")
assert(RolePolicy.canMelee(Summons.Roles.Guardian, nil), "Guardian melee fallback should remain available")
assert(
	RolePolicy.noHostileTargetReason(Summons.Roles.Guardian, {}, Summons.GuardRadius)
		== "No hostile Enfleshed or MagicHostileTarget is registered",
	"No-target feedback should explain the required hostile registration"
)
assert(
	RolePolicy.noHostileTargetReason(Summons.Roles.Guardian, {
		HasTaggedHostile = true,
		HasLivingHostile = true,
		WithinGuardRadius = false,
		WithinScanRange = true,
		Visible = false,
	}, Summons.GuardRadius)
		== string.format("Guardian only protects hostiles within %d studs of you", Summons.GuardRadius),
	"Guardian feedback should explain its owner-protection radius"
)
assert(
	RolePolicy.noHostileTargetReason(Summons.Roles.Hunter, {
		HasTaggedHostile = true,
		HasLivingHostile = true,
		WithinGuardRadius = false,
		WithinScanRange = true,
		Visible = false,
	}, Summons.GuardRadius) == "Hostile is in range but blocked from view",
	"Hunter feedback should identify world-occluded hostiles without the Guardian radius restriction"
)
assert(
	RolePolicy.targetScanRange(180, Wisp.SearchRadius, Summons.CommandChaseRange) == Summons.CommandChaseRange,
	"Ranged companion spells should scan out to the bounded chase limit"
)
assert(
	RolePolicy.targetScanRange(20, Wisp.SearchRadius, Summons.CommandChaseRange) == 20,
	"Companions should not acquire targets beyond a spell's authored range"
)
assert(
	RolePolicy.targetScanRange(nil, Wisp.SearchRadius, Summons.CommandChaseRange) == Wisp.SearchRadius,
	"Melee-only companions should preserve their existing search radius"
)
assert(
	RolePolicy.castRange(180, Wisp.AttackRange, Summons.CommandChaseRange) == Summons.CommandChaseRange
		and RolePolicy.castRange(20, Wisp.AttackRange, Summons.CommandChaseRange) == 20
		and RolePolicy.castRange(nil, Wisp.AttackRange, Summons.CommandChaseRange) == Wisp.AttackRange,
	"Spell reach should be honored within the server chase cap while melee fallback remains unchanged"
)
local uniqueStatuses = {}
for _, status in ipairs(Summons.SpellStatuses) do
	assert(not uniqueStatuses[status], "Summon spell statuses must be unique")
	uniqueStatuses[status] = true
end
for _, status in ipairs({
	"UNASSIGNED",
	"INVALID SPELL",
	"CASTING",
	"COOLDOWN",
	"OWNER BUSY",
	"RESOURCE LIMIT",
	"OUT OF RANGE",
	"BLOCKED",
}) do
	assert(uniqueStatuses[status], "Missing companion spell diagnostic: " .. status)
end
assert(uniqueStatuses.MOVING, "Summon command diagnostics must expose the move state")
assert(uniqueStatuses["WAITING FOR OWNER"], "Persistent parties should report their respawn wait state")

print("Magic summons: bounded commands and companion spell diagnostic states passed")
