-- Emergent-magic audit suite. See docs/EMERGENT_MAGIC_AUDIT.md.
-- Run: python3 scripts/run_emergent_magic_audit.py ~/.rokit/bin/luau
--
-- Appended after the real SpellSpec/schema fixture preamble of
-- tests/test_magic_lab.lua, so `spec`, `schema`, `limits` and `load` are the
-- production modules. Server modules (MagicTriggerDispatch,
-- MagicBehaviorExecutors, MagicPayloadExecutors,
-- MagicProjectileBehaviorExecutors) are loaded from source unchanged; only
-- Roblox services (DamageService, physics, workspace, RunService) are mocked.
--
-- The `emit` function below is a TEST DOUBLE for MagicService's emit/context
-- (src/server/Services/MagicService.luau ~757-1001). It reproduces the
-- documented routing contract (event -> Triggers[event] -> payload/behavior
-- executors, DamageContext.EmitEvent depth limit, ApplySpherePayloads) but it
-- is not the production function, which cannot run outside Roblox.
--
-- Every check records CAPABILITY (the engine can do it) or LIMITATION (the
-- audit observed a restriction). Limitation checks assert the CURRENT
-- behavior so this file doubles as a regression baseline: if one starts
-- failing because the engine gained the capability, update the audit report.

local results = {}
local failures = 0
local function check(test, kind, condition, message)
	table.insert(results, { Test = test, Kind = kind, Ok = condition and true or false, Message = message })
	if not condition then
		failures += 1
	end
end

local function payload(kind, extra)
	local p = spec.copy(schema.Payloads[kind].Defaults or {})
	p.Kind = kind
	for key, value in pairs(extra or {}) do
		p[key] = value
	end
	return p
end

local function draft(form, principle, mutate)
	local d = spec.createDraft(form, principle)
	assert(d, "draft " .. form .. "/" .. principle)
	mutate(d)
	return d
end

local function validates(d)
	local ok, reason = spec.validate(d)
	return ok == true, reason
end

---------------------------------------------------------------------------
-- Roblox environment doubles
---------------------------------------------------------------------------
local V3 = {}
local V3mt = {}
local function vec(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z, _v3 = true }, V3mt)
end
V3mt.__add = function(a, b)
	return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3mt.__sub = function(a, b)
	return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3mt.__unm = function(a)
	return vec(-a.X, -a.Y, -a.Z)
end
V3mt.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	return vec(a.X * b, a.Y * b, a.Z * b)
end
V3mt.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	elseif key == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif key == "Cross" then
		return function(a, b)
			return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	end
	return nil
end
V3.new = vec
V3.zero = vec(0, 0, 0)
V3.yAxis = vec(0, 1, 0)
V3.xAxis = vec(1, 0, 0)

local function typeOf(value)
	if type(value) == "table" then
		if value._v3 then
			return "Vector3"
		elseif value._instance then
			return "Instance"
		end
	end
	return type(value)
end

local workspaceDouble = { _instance = true, Name = "Workspace", Children = {} }

local function makeInstance(className, name, parent)
	local inst = { _instance = true, ClassName = className, Name = name, Parent = parent, Children = {} }
	function inst:IsA(class)
		if class == "BasePart" then
			return self.ClassName == "Part"
		end
		return self.ClassName == class
	end
	function inst:FindFirstChild(childName)
		return self.Children[childName]
	end
	function inst:GetAttribute(attribute)
		return self.Attributes and self.Attributes[attribute]
	end
	function inst:FindFirstAncestorOfClass(class)
		local node = self.Parent
		while node do
			if node.ClassName == class then
				return node
			end
			node = node.Parent
		end
		return nil
	end
	function inst:FindFirstChildOfClass(class)
		for _, child in pairs(self.Children) do
			if child.ClassName == class then
				return child
			end
		end
		return nil
	end
	function inst:IsDescendantOf(ancestor)
		local node = self.Parent
		while node do
			if node == ancestor then
				return true
			end
			node = node.Parent
		end
		return false
	end
	if parent then
		parent.Children[name] = inst
	end
	return inst
end

local enemies = {}
local function makeCharacter(name, position, health)
	local model = makeInstance("Model", name, workspaceDouble)
	local root = makeInstance("Part", "HumanoidRootPart", model)
	root.Position = position
	root.Anchored = false
	root.AssemblyMass = 1
	root.Impulses = {}
	function root:ApplyImpulse(impulse)
		table.insert(self.Impulses, impulse)
	end
	local humanoid = makeInstance("Humanoid", "Humanoid", model)
	humanoid.Health = health or 1000
	humanoid.MaxHealth = health or 1000
	humanoid.Died = {
		Connect = function()
			return { Disconnect = function() end }
		end,
	}
	return humanoid, model, root
end

-- Ordered event log shared by all doubles.
local log = {}
local function record(entry)
	table.insert(log, entry)
end
local function count(predicate)
	local n = 0
	for _, entry in ipairs(log) do
		if predicate(entry) then
			n += 1
		end
	end
	return n
end

local damageOps = 0
local DamageService = {
	apply = function(attacker, humanoid, amount, damageContext)
		damageOps += 1
		local before = humanoid.Health
		humanoid.Health = math.max(0, humanoid.Health - amount)
		record({
			Op = "Damage",
			Target = humanoid.Parent.Name,
			Amount = amount,
			Depth = damageContext and damageContext.Depth,
			Channel = damageContext and damageContext.DamageChannel,
		})
		-- Mirrors MagicService's Damage.Applied listener (MagicService.luau ~1084-1106).
		if damageContext and type(damageContext.EmitEvent) == "function" then
			local maxHealth = humanoid.MaxHealth
			damageContext.EmitEvent("OnDamageDealt", humanoid, { DamageDealt = before - humanoid.Health })
			for _, step in ipairs(damageContext.ThresholdSteps or {}) do
				local t = step.HealthPercent
				if t and before / maxHealth * 100 > t and humanoid.Health / maxHealth * 100 <= t then
					damageContext.EmitEvent("OnThreshold", humanoid, { HealthThreshold = t })
				end
			end
			if humanoid.Health <= 0 then
				damageContext.EmitEvent("OnTargetDeath", humanoid)
			end
		end
		return before - humanoid.Health, 0
	end,
}
local OwnershipDouble = {
	claim = function()
		return true
	end,
	release = function() end,
}
local MovementDouble = { allowMagicImpulse = function() end }
local StatusDouble = setmetatable({}, {
	__index = function(_, name)
		return function(_, target, ...)
			record({ Op = "Status." .. name, Target = target and target.Parent and target.Parent.Name })
			return 1, true
		end
	end,
})
-- Mirrors the real signatures: elementalMark returns (applied, reaction?) and
-- checkReaction returns a reaction or nil. No reactions unless a scenario
-- installs its own versions.
rawset(StatusDouble, "elementalMark", function(_, target)
	record({ Op = "Status.elementalMark", Target = target and target.Parent and target.Parent.Name })
	return true, nil
end)
rawset(StatusDouble, "checkReaction", function()
	return nil
end)
-- Heal and shield record their amounts; heal reports what the missing health
-- allowed (Status.heal's return), without changing health.
rawset(StatusDouble, "heal", function(_, target, amount)
	local restored = math.min(amount, math.max(0, target.MaxHealth - target.Health))
	record({ Op = "Status.heal", Target = target.Parent.Name, Amount = amount, Restored = restored })
	return restored
end)
rawset(StatusDouble, "shield", function(_, target, _, amount, duration)
	record({ Op = "Status.shield", Target = target.Parent.Name, Amount = amount, Duration = duration })
	return true
end)
local ControlDouble = {
	apply = function()
		return true, true
	end,
	applyObject = function()
		return true, true
	end,
}

local sharedModules = {
	MagicAttributeSpec = attributeSpec,
	MagicTemporalRate = load("src/shared/Modules/MagicTemporalRate.luau"),
	MagicBodyRegionSpec = load("src/shared/Modules/MagicBodyRegionSpec.luau"),
	MagicElementalInteractionSpec = load("src/shared/Modules/MagicElementalInteractionSpec.luau"),
	CombatPolicy = load("src/shared/Modules/CombatPolicy.luau"),
	SpellStatCapsConfig = load("src/shared/Configuration/SpellStatCaps.luau"),
	MagicSchema = schema,
	MagicScaleSpec = scaleSpec,
	MagicCrowdControlSpec = load("src/shared/Modules/MagicCrowdControlSpec.luau"),
	MagicOperationBudget = load("src/shared/Modules/MagicOperationBudget.luau"),
	MagicHealSpec = load("src/shared/Modules/MagicHealSpec.luau"),
}
sharedModules.SpellStatCaps = assert(loadfile(
	"src/shared/Modules/SpellStatCaps.luau",
	"t",
	setmetatable({
		script = { Parent = { CombatPolicy = "CombatPolicy" } },
		require = function()
			return sharedModules.CombatPolicy
		end,
	}, { __index = _G })
))()
-- No player characters in this harness: every target is an NPC for CombatPolicy.
local PlayersDouble = {
	GetPlayerFromCharacter = function()
		return nil
	end,
	GetPlayerByUserId = function()
		return nil
	end,
}
local serverEnv = setmetatable({
	Vector3 = V3,
	typeof = typeOf,
	workspace = workspaceDouble,
	task = {
		delay = function() end,
		defer = function() end,
	},
	RaycastParams = {
		new = function()
			return {}
		end,
	},
	Enum = { RaycastFilterType = { Exclude = "Exclude" } },
	CFrame = {
		new = function(p)
			return { Position = p }
		end,
		-- Rodrigues rotation; enough for Split/Spread/Homing steering.
		fromAxisAngle = function(axis, angle)
			local k = axis.Unit
			return {
				VectorToWorldSpace = function(_, v)
					local c, s = math.cos(angle), math.sin(angle)
					return v * c + k:Cross(v) * s + k * (k:Dot(v) * (1 - c))
				end,
			}
		end,
	},
	script = {
		Parent = {
			DamageService = "Damage",
			MovementService = "Movement",
			MagicStatusEffectService = "Status",
			MagicControlService = "Control",
			MagicPhysicsOwnership = "Ownership",
		},
	},
	game = {
		GetService = function(_, name)
			if name == "RunService" then
				return { Heartbeat = { Connect = function() end } }
			elseif name == "Players" then
				return PlayersDouble
			end
			return {
				Shared = {
					Modules = {
						MagicAttributeSpec = "MagicAttributeSpec",
						MagicTemporalRate = "MagicTemporalRate",
						MagicBodyRegionSpec = "MagicBodyRegionSpec",
						MagicElementalInteractionSpec = "MagicElementalInteractionSpec",
						CombatPolicy = "CombatPolicy",
						SpellStatCaps = "SpellStatCaps",
						MagicScaleSpec = "MagicScaleSpec",
						MagicCrowdControlSpec = "MagicCrowdControlSpec",
						MagicOperationBudget = "MagicOperationBudget",
						MagicHealSpec = "MagicHealSpec",
					},
					Configuration = {
						MagicLab = "MagicLab",
						SpellStatCaps = "SpellStatCapsConfig",
						MagicSchema = "MagicSchema",
					},
				},
			}
		end,
	},
	require = function(ref)
		if ref == "Damage" then
			return DamageService
		elseif ref == "Movement" then
			return MovementDouble
		elseif ref == "Status" then
			return StatusDouble
		elseif ref == "Control" then
			return ControlDouble
		elseif ref == "Ownership" then
			return OwnershipDouble
		elseif ref == "MagicLab" then
			return limits
		end
		return sharedModules[ref] or error("unexpected require " .. tostring(ref))
	end,
}, { __index = _G })

local function loadServer(name)
	return assert(loadfile("src/server/Services/" .. name .. ".luau", "t", serverEnv))()
end
local Dispatch = loadServer("MagicTriggerDispatch")
local BehaviorExec = loadServer("MagicBehaviorExecutors")
local PayloadExec = loadServer("MagicPayloadExecutors")
local ProjectileBehaviorExec = loadServer("MagicProjectileBehaviorExecutors")
local TargetDeath = load("src/shared/Modules/MagicTargetDeathSpec.luau")
local OperationBudget = load("src/shared/Modules/MagicOperationBudget.luau")
local ConditionEvaluator = load("src/shared/Modules/MagicConditionEvaluator.luau")
local RuntimeCounters = load("src/shared/Modules/MagicRuntimeCounters.luau")
local StepCondition = assert(loadfile(
	"src/shared/Modules/MagicStepCondition.luau",
	"t",
	setmetatable({
		script = { Parent = { MagicConditionEvaluator = "evaluator" } },
		require = function()
			return ConditionEvaluator
		end,
	}, { __index = _G })
))()
-- Test resolver standing in for MagicConditions.values: exposes the families
-- these doubles can actually compute (health and liveness).
local StepConditions = {
	filter = function(condition, ctx)
		return StepCondition.filter(condition, ctx.Targets or {}, function(humanoid)
			local casterH = ctx.Caster and ctx.Caster.Children.Humanoid
			local values = {
				Caster = {
					HealthPercent = casterH and casterH.Health / casterH.MaxHealth,
					IsAlive = casterH ~= nil and casterH.Health > 0,
				},
				Target = {
					HealthPercent = humanoid and humanoid.Health / humanoid.MaxHealth,
					IsAlive = humanoid ~= nil and humanoid.Health > 0,
				},
				-- Same sources as MagicConditions.values for these counters.
				SpellState = {
					TriggerCount = ctx.SpellState and ctx.SpellState.TriggerCount,
					EventTargets = ctx.SpellState and ctx.SpellState.EventTargets,
					AreaOccupants = ctx.SpellState and RuntimeCounters.occupants(ctx.SpellState),
				},
			}
			return function(family, property)
				return values[family] and values[family][property]
			end
		end)
	end,
}
local Commands = {
	matches = function(a, b)
		return a == nil or a == b
	end,
}

---------------------------------------------------------------------------
-- emit/context test double (see header)
---------------------------------------------------------------------------
local function sphereQuery(position, radius)
	local found = {}
	for _, humanoid in ipairs(enemies) do
		local root = humanoid.Parent.Children.HumanoidRootPart
		if (root.Position - position).Magnitude <= radius and humanoid.Health > 0 then
			table.insert(found, humanoid)
		end
	end
	return found
end

local emit
-- Children started by SpawnEffect, in spawn order (reset by resetWorld).
local spawnedEffects = {}
-- Mirrors MagicService.spendOperations: no budget means unbudgeted.
local function spend(budget, cost)
	if not budget or OperationBudget.spend(budget, cost) then
		return true
	end
	if OperationBudget.takeReport(budget) then
		record({ Op = "BudgetExhausted" })
	end
	return false
end

local function makeContext(definition, caster, position, targets, depth, budget)
	local ctx = {
		Caster = caster,
		SpellId = definition.SpellId,
		Targets = targets,
		Direction = vec(0, 0, 1),
		Potency = 1,
		Origin = position,
		EventDepth = depth,
		HitFeedback = function() end,
		EffectFeedback = function() end,
		Summon = function(p)
			record({ Op = "Summon", Archetype = p.Archetype, Depth = depth })
		end,
	}
	-- Mirrors MagicService's ScaleRead: mark stacks from the status service,
	-- everything else from the same values the step-condition double uses.
	-- Mirrors MagicService's reaction helpers: a sphere query (Conduct) and a
	-- reaction Field spawn (Firestorm, Toxic smoke), recorded instead of built.
	ctx.FindHumanoidsNear = function(at, radius)
		return sphereQuery(at, radius)
	end
	ctx.SpawnReactionField = function(effect, at)
		record({ Op = "ReactionField", Element = effect.Element, Radius = effect.Radius, Kind = effect.Kind })
	end
	ctx.ScaleRead = function(source, humanoid, element)
		if source == "ElementalMarkStacks" then
			return StatusDouble.elementalMarkStacks(humanoid, element)
		elseif source == "TargetMissingHealthPercent" then
			return humanoid.Health / humanoid.MaxHealth
		elseif source == "TriggerCount" then
			return ctx.SpellState and ctx.SpellState.TriggerCount
		end
		return nil
	end
	ctx.DamageContext = {
		Depth = depth,
		Element = definition.Element or "Neutral",
		ThresholdSteps = definition.Triggers.OnThreshold,
		EmitEvent = function(eventName, target, data)
			if depth >= limits.MaxMagicEventDepth then
				record({ Op = "DepthCapped", Event = eventName, Depth = depth })
				return
			end
			local where = target and target.Parent.Children.HumanoidRootPart.Position or position
			emit(definition, eventName, caster, where, target and { target } or {}, depth + 1, data, budget)
		end,
	}
	ctx.HealthThreshold = nil
	-- Mirrors MagicService.spawnEffect: expand with the real SpellSpec, spend
	-- the budget, then start the child. Wave targets use a sphere query here.
	ctx.SpawnEffect = function(step, eventTargets)
		local child = assert(spec.expandSpawnEffect(definition, step.Effect))
		local spawnCount = if child.Form == "Projectile" then step.Count or 1 else 1
		if not spend(budget, spawnCount) then
			return
		end
		record({ Op = "Spawn", Form = child.Form, Count = spawnCount, Depth = depth })
		if child.Form == "Wave" then
			emit(child, "OnCast", caster, position, sphereQuery(position, child.Wave.Range), 0)
		elseif child.Form == "Field" then
			table.insert(spawnedEffects, { Definition = child, Position = position })
			emit(child, "OnCast", caster, position, sphereQuery(position, child.Field.Radius), 0)
		elseif child.Form == "Projectile" then
			for _ = 1, spawnCount do
				table.insert(spawnedEffects, { Definition = child, Position = position })
				emit(child, "OnSpawn", caster, position, {}, 0)
			end
		else
			-- Beam/Aura/Construct/SelfEnhancement: the server-side placement
			-- is Studio-only; here the child just resolves its cast.
			table.insert(spawnedEffects, { Definition = child, Position = position })
			emit(child, "OnCast", caster, position, eventTargets or {}, 0)
		end
	end
	ctx.ApplySpherePayloads = function(radius, payloads)
		local found = sphereQuery(position, radius)
		if not spend(budget, 1 + #found) then
			return
		end
		record({ Op = "Sphere", Radius = radius, Depth = depth })
		PayloadExec.execute(payloads, makeContext(definition, caster, position, found, depth, budget))
	end
	return ctx
end

-- `origin` stands in for the persistent active-effect record (a Field,
-- projectile...) that MagicService passes as RuntimeOrigin.
emit = function(definition, event, caster, position, targets, depth, data, inherited, origin)
	local budget = OperationBudget.resolve(
		{ EventDepth = depth or 0, OperationBudget = inherited },
		limits.MaxOperationsPerCascade
	)
	if not spend(budget, 1 + #targets) then
		return
	end
	record({ Op = "Event", Event = event, Depth = depth or 0 })
	local ctx = makeContext(definition, caster, position, targets, depth or 0, budget)
	ctx.Event = event
	local eventState = { RuntimeOrigin = origin }
	eventState.TriggerCount, eventState.EventTargets = RuntimeCounters.record(origin or eventState, event, targets)
	ctx.SpellState = eventState
	ctx.HealthThreshold = data and data.HealthThreshold
	ctx.DeathCause = event == "OnTargetDeath" and (data and data.DeathCause or "KilledByThisSpell") or nil
	-- MagicService passes the (relationship-filtered) attacker for OnDamageTaken.
	ctx.EventAttackers = data and data.Attackers or {}
	-- OnDamageDealt: the hit's damage and the caster (TargetFrom = "Caster").
	ctx.DamageDealt = data and data.DamageDealt
	local casterHumanoid = caster:FindFirstChildOfClass("Humanoid")
	ctx.CasterTargets = if casterHumanoid and casterHumanoid.Health > 0 then { casterHumanoid } else {}
	Dispatch.execute(definition, event, ctx, PayloadExec, BehaviorExec, Commands, TargetDeath, StepConditions)
end

local casterHumanoid, caster = makeCharacter("Caster", vec(0, 0, -50))
local function resetWorld(positions, health)
	log = {}
	table.clear(spawnedEffects)
	damageOps = 0
	enemies = {}
	for i, p in ipairs(positions) do
		local h = makeCharacter("Enemy" .. i, p, health)
		table.insert(enemies, h)
	end
	return enemies
end
local function totalDamageTo(name)
	local sum = 0
	for _, e in ipairs(log) do
		if e.Op == "Damage" and e.Target == name then
			sum += e.Amount
		end
	end
	return sum
end

---------------------------------------------------------------------------
-- TEST A: multiple simultaneous independent effects
---------------------------------------------------------------------------
do
	local d = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = {
			{ Payloads = { payload("Damage", { Amount = 10 }), payload("Force", { Magnitude = 30 }) } },
			{ Behavior = "Explode", Radius = 6, Payloads = { payload("Damage", { Amount = 4 }) } },
		}
	end)
	local ok, reason = validates(d)
	check("A", "CAPABILITY", ok, "Damage + Force + Explode on one OnImpact validates: " .. tostring(reason))
	local e = resetWorld({ vec(0, 0, 0), vec(3, 0, 0) })
	emit(d, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("A", "CAPABILITY", totalDamageTo("Enemy1") == 14, "primary target takes direct 10 + explosion 4")
	check("A", "CAPABILITY", totalDamageTo("Enemy2") == 4, "bystander takes only explosion damage")
	check(
		"A",
		"CAPABILITY",
		#e[1].Parent.Children.HumanoidRootPart.Impulses == 1,
		"primary target receives knockback impulse"
	)
	check(
		"A",
		"CAPABILITY",
		#e[2].Parent.Children.HumanoidRootPart.Impulses == 0,
		"knockback is not leaked to explosion targets"
	)

	-- Remove the Force operation: remaining operations unaffected.
	d.Triggers.OnImpact[1].Payloads = { payload("Damage", { Amount = 10 }) }
	check("A", "CAPABILITY", validates(d), "removing Force keeps the spell valid")
	e = resetWorld({ vec(0, 0, 0), vec(3, 0, 0) })
	emit(d, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check(
		"A",
		"CAPABILITY",
		totalDamageTo("Enemy1") == 14 and #e[1].Parent.Children.HumanoidRootPart.Impulses == 0,
		"without Force: same damage, no impulse"
	)

	-- Explode carries any per-target payload, not only Damage.
	d.Triggers.OnImpact = {
		{ Behavior = "Explode", Radius = 6, Payloads = { payload("Force", { Magnitude = 25 }), payload("Slow") } },
	}
	local fok, freason = validates(d)
	check("A", "CAPABILITY", fok, "Explode carries Force + Slow: " .. tostring(freason))
	e = resetWorld({ vec(0, 0, 0), vec(3, 0, 0), vec(30, 0, 0) })
	emit(d, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check(
		"A",
		"CAPABILITY",
		#e[1].Parent.Children.HumanoidRootPart.Impulses == 1
			and #e[2].Parent.Children.HumanoidRootPart.Impulses == 1
			and #e[3].Parent.Children.HumanoidRootPart.Impulses == 0
			and damageOps == 0,
		"non-damage blast knocks back everyone inside the radius, nobody outside, and deals no damage"
	)
	check("A", "CAPABILITY", count(function(x)
		return x.Op == "Status.slow"
	end) == 2, "blast Slow applies once per target inside")
	local heal = draft("Projectile", "Body", function(d)
		d.Triggers.OnImpact = { { Behavior = "Explode", Radius = 6, Payloads = { payload("Heal") } } }
	end)
	check("A", "CAPABILITY", validates(heal), "Explode carries Heal")
	local summon = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = { { Behavior = "Explode", Radius = 6, Payloads = { payload("Summon") } } }
	end)
	local sok, sreason = validates(summon)
	check("A", "CAPABILITY", not sok, "Explode still rejects Summon (" .. tostring(sreason) .. ")")
	local tooMany = draft("Projectile", "Energy", function(d)
		local list = {}
		for _, kind in ipairs({ "Damage", "Force", "Slow", "Bind", "Reveal" }) do
			table.insert(list, payload(kind))
		end
		d.Triggers.OnImpact = { { Behavior = "Explode", Radius = 6, Payloads = list } }
	end)
	check("A", "CAPABILITY", not validates(tooMany), "Explode still capped at MaxPayloads payloads")
end

---------------------------------------------------------------------------
-- TEST B: collision -> event -> secondary area -> damage
---------------------------------------------------------------------------
do
	local d = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = { { Behavior = "Explode", Radius = 8, Payloads = { payload("Damage", { Amount = 7 }) } } }
	end)
	check("B", "CAPABILITY", validates(d), "Projectile OnImpact Explode validates")
	local e = resetWorld({ vec(0, 0, 0), vec(5, 0, 0), vec(20, 0, 0) })
	emit(d, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("B", "CAPABILITY", count(function(x)
		return x.Op == "Sphere"
	end) == 1, "one generic sphere area created")
	check(
		"B",
		"CAPABILITY",
		totalDamageTo("Enemy1") == 7 and totalDamageTo("Enemy2") == 7 and totalDamageTo("Enemy3") == 0,
		"area damages only enemies inside radius"
	)
	-- Second-order chain: explosion damage -> OnDamageDealt -> further payload
	d.Triggers.OnDamageDealt = { { Payloads = { payload("Force", { Magnitude = 10 }) } } }
	check("B", "CAPABILITY", validates(d), "OnDamageDealt reaction validates")
	e = resetWorld({ vec(0, 0, 0), vec(5, 0, 0) })
	emit(d, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check(
		"B",
		"CAPABILITY",
		#e[2].Parent.Children.HumanoidRootPart.Impulses == 1,
		"explosion damage re-emits OnDamageDealt which runs a further payload"
	)
end

---------------------------------------------------------------------------
-- TEST C: parallel branches from one event
---------------------------------------------------------------------------
do
	local d = draft("Projectile", "Energy", function(d)
		d.Projectile.Behaviors = { { Kind = "Split", ChildCount = 3, SpreadAngle = 24, DamageFalloff = 0.65 } }
		d.Triggers.OnImpact = {
			{ Behavior = "Explode", Radius = 6, Payloads = { payload("Damage", { Amount = 5 }) } },
			{ Payloads = { payload("Slow") } },
		}
	end)
	check("C", "CAPABILITY", validates(d), "Split behavior + Explode step + Slow step validate together")
	local e = resetWorld({ vec(0, 0, 0), vec(4, 0, 0) })
	emit(d, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("C", "CAPABILITY", totalDamageTo("Enemy2") == 5 and count(function(x)
		return x.Op == "Status.slow" or (x.Op and x.Op:find("Status") ~= nil)
	end) >= 1, "two trigger steps on one event both execute")
	-- Branch B (secondary projectiles) is the real Split executor:
	local spawned
	local parent = { Direction = vec(0, 0, 1), SplitDepth = 0, IgnoredTargetModels = {} }
	parent.Definition = d
	ProjectileBehaviorExec.impact(parent, { Normal = vec(0, 0, -1), Position = vec(0, 0, 0) }, {
		TargetFromHit = function()
			return e[1], e[1].Parent
		end,
		SpawnSplit = function(_, _, behavior, directions)
			spawned = #directions
			return true
		end,
		Now = 0,
	})
	check(
		"C",
		"CAPABILITY",
		spawned == 3,
		"Split executor fans out 3 child projectiles on impact (got " .. tostring(spawned) .. ")"
	)
	check("C", "CAPABILITY", parent.TerminateAfterImpact == true, "parent projectile terminates after splitting")
	-- Full Test C with SpawnEffect: one impact starts a damaging Wave
	-- (branch A) and three secondary Projectiles (branch B).
	local branching = draft("Projectile", "Energy", function(d)
		local wave = spec.defaultSpawnEffect("Wave")
		wave.Geometry = "Sphere"
		wave.Wave.Range = 8
		wave.Triggers = { OnCast = { { Payloads = { payload("Damage", { Amount = 6 }) } } } }
		d.Triggers.OnImpact = {
			{ Behavior = "SpawnEffect", Payloads = {}, Effect = wave },
			{
				Behavior = "SpawnEffect",
				Payloads = {},
				Count = 3,
				SpreadAngle = 60,
				Effect = spec.defaultSpawnEffect("Projectile"),
			},
		}
	end)
	local branchOk, branchReason = validates(branching)
	check("C", "CAPABILITY", branchOk, "Wave + 3-Projectile spawn branches validate: " .. tostring(branchReason))
	e = resetWorld({ vec(0, 0, 0), vec(5, 0, 0), vec(20, 0, 0) })
	emit(branching, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check(
		"C",
		"CAPABILITY",
		totalDamageTo("Enemy1") == 6 and totalDamageTo("Enemy2") == 6 and totalDamageTo("Enemy3") == 0,
		"branch A: spawned Wave damages everyone in its range"
	)
	check(
		"C",
		"CAPABILITY",
		#spawnedEffects == 3 and spawnedEffects[1].Definition.Form == "Projectile",
		"branch B: three secondary Projectiles start from the same impact"
	)
end

---------------------------------------------------------------------------
-- TEST D: independent secondary projectiles
---------------------------------------------------------------------------
do
	local d = draft("Projectile", "Energy", function(d)
		d.Projectile.Behaviors = {
			{ Kind = "Split", ChildCount = 3, SpreadAngle = 30, DamageFalloff = 0.6 },
			{ Kind = "Homing", SearchRadius = 24, TurnRate = 180 },
		}
		d.Triggers.OnImpact = { { Payloads = { payload("Damage", { Amount = 10 }) } } }
	end)
	check("D", "CAPABILITY", validates(d), "Split + Homing validate together")
	-- Children are separate runtime records (MagicService SpawnSplit creates a
	-- new table per child with its own Position/Velocity/TargetsHit/Lifetime)
	-- and run the same Homing executor. Prove per-child independent targeting:
	local e = resetWorld({ vec(-10, 0, 10), vec(0, 0, 10), vec(10, 0, 10) })
	local children = {}
	for i, dir in ipairs({ vec(-1, 0, 1).Unit, vec(0, 0, 1), vec(1, 0, 1).Unit }) do
		children[i] = {
			Position = vec(0, 0, 0),
			Direction = dir,
			Velocity = dir * 40,
			HitHumanoids = {},
			SplitDepth = 1,
			Distance = 0,
		}
	end
	local acquired = {}
	for i, child in ipairs(children) do
		child.Definition = d
		ProjectileBehaviorExec.update(child, 0.03, {
			Now = 0,
			FindTarget = function(projectile)
				local best, bestDot = nil, -2
				for _, h in ipairs(e) do
					local r = h.Parent.Children.HumanoidRootPart
					local to = (r.Position - projectile.Position).Unit
					local dot = to:Dot(projectile.Direction)
					if dot > bestDot then
						best, bestDot = r, dot
					end
				end
				return best
			end,
			TurnToward = function() end,
			SteerToward = function() end,
		})
		acquired[i] = child.HomingTarget and child.HomingTarget.Parent.Name
	end
	check(
		"D",
		"CAPABILITY",
		acquired[1] == "Enemy1" and acquired[2] == "Enemy2" and acquired[3] == "Enemy3",
		"each child acquires its own homing target: "
			.. tostring(acquired[1])
			.. ","
			.. tostring(acquired[2])
			.. ","
			.. tostring(acquired[3])
	)
	-- Nested split is blocked: children cannot split again.
	local grand
	ProjectileBehaviorExec.impact(children[1], { Normal = vec(0, 0, -1), Position = vec(0, 0, 0) }, {
		TargetFromHit = function()
			return nil
		end,
		SpawnSplit = function()
			grand = true
			return true
		end,
		Now = 0,
	})
	check("D", "LIMITATION", grand == nil, "child projectiles (SplitDepth>0) cannot split again")
	-- Children share the parent's definition: there is no way to give children
	-- different payloads/behaviors from the parent.
	local separate = draft("Projectile", "Energy", function(d)
		d.Projectile.Behaviors =
			{ { Kind = "Split", ChildCount = 3, SpreadAngle = 30, DamageFalloff = 0.6, Child = { Triggers = {} } } }
		d.Triggers.OnImpact = { { Payloads = { payload("Damage") } } }
	end)
	check("D", "LIMITATION", not validates(separate), "Split itself still copies its parent (no Child field)")
	-- SpawnEffect gives secondaries their own definition: homing children
	-- that slow instead of damaging, unlike their parent.
	local distinct = draft("Projectile", "Energy", function(d)
		local child = spec.defaultSpawnEffect("Projectile")
		child.Projectile.Behaviors = { { Kind = "Homing", SearchRadius = 24, TurnRate = 180 } }
		child.Triggers = { OnImpact = { { Payloads = { payload("Slow") } } } }
		d.Triggers.OnImpact = {
			{ Payloads = { payload("Damage", { Amount = 10 }) } },
			{ Behavior = "SpawnEffect", Payloads = {}, Count = 3, SpreadAngle = 45, Effect = child },
		}
	end)
	local distinctOk, distinctReason = validates(distinct)
	check(
		"D",
		"CAPABILITY",
		distinctOk,
		"children with their own behaviors and effects validate: " .. tostring(distinctReason)
	)
	e = resetWorld({ vec(0, 0, 0) })
	emit(distinct, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	local childDefinition = spawnedEffects[1] and spawnedEffects[1].Definition
	check(
		"D",
		"CAPABILITY",
		childDefinition ~= nil
			and childDefinition.Projectile.Behaviors[1].Kind == "Homing"
			and childDefinition.Triggers.OnImpact[1].Payloads[1].Kind == "Slow"
			and #distinct.Projectile.Behaviors == 0,
		"each child carries its own definition, distinct from the parent"
	)
	if childDefinition then
		local before = totalDamageTo("Enemy1")
		emit(childDefinition, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
		check("D", "CAPABILITY", totalDamageTo("Enemy1") == before and count(function(x)
			return x.Op == "Status.slow"
		end) == 1, "a child's impact runs its own effect (Slow), not the parent's Damage")
	end
end

---------------------------------------------------------------------------
-- TEST E: persistent area with entry reactions
---------------------------------------------------------------------------
do
	local d = draft("Field", "Energy", function(d)
		d.Lifetime = { Mode = "FixedDuration", Duration = 6 }
		d.Triggers = { OnEnter = { { Payloads = { payload("Damage", { Amount = 6 }) } } } }
	end)
	local ok, reason = validates(d)
	check("E", "CAPABILITY", ok, "Field OnEnter Damage validates: " .. tostring(reason))
	-- Real membership tracker used by MagicService's emitAreaTransition.
	local Membership = load("src/shared/Modules/MagicAreaMembership.luau")
	check("E", "CAPABILITY", type(Membership) == "table", "MagicAreaMembership module loads")
	local e = resetWorld({ vec(0, 0, 0) })
	emit(d, "OnEnter", caster, vec(0, 0, 0), { e[1] }, 0)
	check("E", "CAPABILITY", totalDamageTo("Enemy1") == 6, "OnEnter payload applies to the entering target")
	-- Triggered effect activates further behavior via OnDamageDealt
	d.Triggers.OnDamageDealt =
		{ { Behavior = "Explode", Radius = 5, Payloads = { payload("Damage", { Amount = 1 }) } } }
	check("E", "CAPABILITY", validates(d), "Field OnDamageDealt -> Explode validates")
	local entryExplode = draft("Field", "Energy", function(d)
		d.Triggers = { OnEnter = { { Behavior = "Explode", Radius = 5, Payloads = { payload("Damage") } } } }
	end)
	check("E", "LIMITATION", not validates(entryExplode), "Explode is not allowed directly on Field OnEnter/OnTick")
end

---------------------------------------------------------------------------
-- TEST F: projectile -> persistent field -> threshold -> wave
---------------------------------------------------------------------------
do
	-- Closest available mapping: Linger turns the projectile into a pulsing
	-- hazard (OnTick). Threshold is per-target health only.
	local d = draft("Projectile", "Energy", function(d)
		d.Projectile.Behaviors = { { Kind = "Linger", Duration = 4, Radius = 6, Interval = 0.5 } }
		d.Triggers.OnImpact = { { Payloads = { payload("Damage", { Amount = 5 }) } } }
		d.Triggers.OnTick = { { Payloads = { payload("Damage", { Amount = 100 }) } } }
		d.Triggers.OnThreshold = { { HealthPercent = 50, Payloads = { payload("Force", { Magnitude = 40 }) } } }
	end)
	local ok, reason = validates(d)
	check("F", "CAPABILITY", ok, "Linger + OnTick + OnThreshold validates: " .. tostring(reason))
	local p = { Kind = "Projectile", Position = vec(0, 0, 0), Velocity = vec(0, 0, 40), Direction = vec(0, 0, 1) }
	p.Definition = d
	ProjectileBehaviorExec.impact(
		p,
		{ Normal = vec(0, 0, -1), Position = vec(0, 0, 0), Instance = makeInstance("Part", "Wall") },
		{
			TargetFromHit = function()
				return nil
			end,
			Now = 10,
		}
	)
	check(
		"F",
		"CAPABILITY",
		p.Kind == "ProjectileLinger" and p.RemainingLifetime == 4 and p.LingerRadius == 6,
		"Linger converts projectile into a bounded persistent hazard with its own lifetime"
	)
	local e = resetWorld({ vec(0, 0, 0), vec(3, 0, 0) }, 180)
	for _ = 1, 1 do
		emit(d, "OnTick", caster, vec(0, 0, 0), sphereQuery(vec(0, 0, 0), 6), 0)
	end
	check(
		"F",
		"CAPABILITY",
		#e[1].Parent.Children.HumanoidRootPart.Impulses == 1 and #e[2].Parent.Children.HumanoidRootPart.Impulses == 1,
		"health threshold crossing triggers displacement on each crossing target"
	)
	-- Count-of-enemies threshold, stage-specific payloads, wave spawning:
	local countThreshold = draft("Projectile", "Energy", function(d)
		d.Triggers.OnThreshold = { { EnemyCount = 3, Payloads = { payload("Damage") } } }
	end)
	check(
		"F",
		"CAPABILITY",
		not validates(countThreshold),
		"OnThreshold stays health-only; occupancy thresholds use SpellState.AreaOccupants (COUNTERS)"
	)
	check(
		"F",
		"LIMITATION",
		d.Triggers.OnImpact ~= nil and d.Triggers.OnTick ~= nil,
		"within one definition, Linger ticks and Pulse ticks still share OnTick"
	)
	-- Full Test F with SpawnEffect + step conditions: a projectile impact
	-- starts a 4 s Field; when a wounded enemy enters, the Field starts a
	-- displacing Wave; everything ends on its own lifetime.
	local stagedWave = spec.defaultSpawnEffect("Wave")
	stagedWave.Geometry = "Sphere"
	stagedWave.Wave.Range = 10
	stagedWave.Triggers = { OnCast = { { Payloads = { payload("Force", { Magnitude = 30 }) } } } }
	local stagedField = spec.defaultSpawnEffect("Field")
	stagedField.Lifetime = { Mode = "FixedDuration", Duration = 4 }
	stagedField.Triggers = {
		OnEnter = {
			{
				Condition = {
					Operator = "ALL",
					Conditions = { { Family = "Target", Property = "HealthPercent", Operator = "<", Value = 0.5 } },
				},
				Behavior = "SpawnEffect",
				Payloads = {},
				Effect = stagedWave,
			},
		},
	}
	local staged = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = {
			{ Payloads = { payload("Damage", { Amount = 5 }) } },
			{ Behavior = "SpawnEffect", Payloads = {}, Effect = stagedField },
		}
	end)
	local stagedOk, stagedReason = validates(staged)
	check("F", "CAPABILITY", stagedOk, "projectile -> field -> conditional wave validates: " .. tostring(stagedReason))
	e = resetWorld({ vec(0, 0, 0), vec(4, 0, 0) }, 100)
	emit(staged, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	local spawnedField = spawnedEffects[1]
	check(
		"F",
		"CAPABILITY",
		spawnedField ~= nil
			and spawnedField.Definition.Form == "Field"
			and spawnedField.Definition.Lifetime.Duration == 4,
		"impact starts a 4 s Field with its own lifetime"
	)
	if spawnedField then
		emit(spawnedField.Definition, "OnEnter", caster, spawnedField.Position, { e[2] }, 0)
		check(
			"F",
			"CAPABILITY",
			#e[2].Parent.Children.HumanoidRootPart.Impulses == 0,
			"a healthy enemy entering does not trigger the wave"
		)
		e[2].Health = 30
		emit(spawnedField.Definition, "OnEnter", caster, spawnedField.Position, { e[2] }, 0)
		check(
			"F",
			"CAPABILITY",
			#e[2].Parent.Children.HumanoidRootPart.Impulses == 1
				and #e[1].Parent.Children.HumanoidRootPart.Impulses == 1,
			"a wounded enemy entering triggers a Wave that displaces everyone in range"
		)
	end
end

---------------------------------------------------------------------------
-- TEST G: unanticipated combinations (validated + executed where possible)
---------------------------------------------------------------------------
do
	-- G1 "Leech Comet": homing projectile, pierce, damage + lifesteal-on-kill.
	local g1 = draft("Projectile", "Body", function(d)
		d.Projectile.Behaviors = {
			{ Kind = "Homing", SearchRadius = 30, TurnRate = 240 },
			{ Kind = "Pierce", MaxPierces = 2 },
		}
		d.Triggers.OnImpact = { { Payloads = { payload("Damage", { Amount = 60 }) } } }
		d.Triggers.OnTargetDeath = { { Payloads = { payload("Heal", { Amount = 10 }) } } }
	end)
	local ok1, r1 = validates(g1)
	check("G", "CAPABILITY", ok1, "G1 Leech Comet validates: " .. tostring(r1))
	local e = resetWorld({ vec(0, 0, 0) }, 50)
	emit(g1, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("G", "CAPABILITY", count(function(x)
		return x.Op == "Event" and x.Event == "OnTargetDeath"
	end) == 1 and count(function(x)
		return x.Op == "Status.heal"
	end) == 1, "G1 kill emits OnTargetDeath which runs Heal")
	-- G2 "Grave Bloom": field that summons on target death.
	local g2 = draft("Field", "Soul", function(d)
		d.Triggers = {
			OnTick = { { Payloads = { payload("Damage", { Amount = 30 }) } } },
			OnTargetDeath = { { Payloads = { payload("Summon") } } },
		}
	end)
	local ok2, r2 = validates(g2)
	check("G", "CAPABILITY", ok2, "G2 Grave Bloom validates: " .. tostring(r2))
	e = resetWorld({ vec(0, 0, 0) }, 30)
	emit(g2, "OnTick", caster, vec(0, 0, 0), { e[1] }, 0)
	check("G", "CAPABILITY", count(function(x)
		return x.Op == "Summon"
	end) == 1, "G2 field kill triggers Summon payload")
	-- G3 "Ricochet Pulse": bouncing projectile that pulses a slow while
	-- flying and explodes at expiry.
	local g3 = draft("Projectile", "Time", function(d)
		d.Projectile.Behaviors = {
			{ Kind = "Bounce", MaxBounces = 3, Restitution = 0.9 },
			{ Kind = "Pulse", Radius = 5, Interval = 0.5 },
		}
		d.Triggers.OnTick = { { Payloads = { payload("Slow") } } }
		d.Triggers.OnExpire = { { Behavior = "Explode", Radius = 7, Payloads = { payload("Damage", { Amount = 9 }) } } }
	end)
	local ok3, r3 = validates(g3)
	check("G", "CAPABILITY", ok3, "G3 Ricochet Pulse validates: " .. tostring(r3))
	local bouncer = { Velocity = vec(0, 0, 40), Direction = vec(0, 0, 1), BounceCount = 0, Definition = g3 }
	local continued = ProjectileBehaviorExec.impact(bouncer, { Normal = vec(0, 0, -1), Position = vec(0, 0, 0) }, {
		TargetFromHit = function()
			return nil
		end,
		Now = 0,
	})
	check("G", "CAPABILITY", continued == true and bouncer.Velocity.Z < 0, "G3 Bounce reflects off world geometry")
	e = resetWorld({ vec(0, 0, 0) })
	emit(g3, "OnExpire", caster, vec(0, 0, 0), {}, 0)
	check("G", "CAPABILITY", totalDamageTo("Enemy1") == 9, "G3 OnExpire explosion damages")
end

---------------------------------------------------------------------------
-- Runtime counters
---------------------------------------------------------------------------
do
	local function rule(property, operator, value)
		return {
			Operator = "ALL",
			Conditions = { { Family = "SpellState", Property = property, Operator = operator, Value = value } },
		}
	end
	-- Cadence: a Field that only bites on every third pulse.
	local cadence = draft("Field", "Energy", function(d)
		d.Triggers = {
			OnTick = {
				{ Condition = rule("TriggerCount", "MultipleOf", 3), Payloads = { payload("Damage", { Amount = 7 }) } },
			},
		}
	end)
	local cadenceOk, cadenceReason = validates(cadence)
	check("COUNTERS", "CAPABILITY", cadenceOk, "TriggerCount MultipleOf 3 validates: " .. tostring(cadenceReason))
	local e = resetWorld({ vec(0, 0, 0) })
	local fieldRecord = {}
	for _ = 1, 7 do
		emit(cadence, "OnTick", caster, vec(0, 0, 0), { e[1] }, 0, nil, nil, fieldRecord)
	end
	check(
		"COUNTERS",
		"CAPABILITY",
		totalDamageTo("Enemy1") == 14,
		"7 pulses with MultipleOf 3 damage twice (pulses 3 and 6), got " .. totalDamageTo("Enemy1")
	)
	local otherField = {}
	emit(cadence, "OnTick", caster, vec(0, 0, 0), { e[1] }, 0, nil, nil, otherField)
	check("COUNTERS", "CAPABILITY", otherField.EventCounts.OnTick == 1, "each active effect keeps its own counts")

	-- Occupancy threshold (the audit's original Test F): when the third enemy
	-- enters, the Field spawns a displacing Wave.
	local burst = spec.defaultSpawnEffect("Wave")
	burst.Geometry = "Sphere"
	burst.Wave.Range = 10
	burst.Triggers = { OnCast = { { Payloads = { payload("Force", { Magnitude = 30 }) } } } }
	local crowd = draft("Field", "Energy", function(d)
		d.Triggers = {
			OnEnter = {
				{
					Condition = rule("AreaOccupants", ">=", 3),
					Behavior = "SpawnEffect",
					Payloads = {},
					Effect = burst,
				},
			},
		}
	end)
	local crowdOk, crowdReason = validates(crowd)
	check("COUNTERS", "CAPABILITY", crowdOk, "AreaOccupants >= 3 -> SpawnEffect validates: " .. tostring(crowdReason))
	e = resetWorld({ vec(0, 0, 0), vec(2, 0, 0), vec(4, 0, 0) })
	-- Like MagicService.updateAreaMembership: occupancy updates before OnEnter.
	local area = { PresentTargets = {} }
	local wavesAfter = {}
	for index, humanoid in ipairs(e) do
		area.PresentTargets[humanoid] = true
		emit(crowd, "OnEnter", caster, vec(0, 0, 0), { humanoid }, 0, nil, nil, area)
		wavesAfter[index] = count(function(x)
			return x.Op == "Spawn"
		end)
	end
	check(
		"COUNTERS",
		"CAPABILITY",
		wavesAfter[1] == 0 and wavesAfter[2] == 0 and wavesAfter[3] == 1,
		"the wave starts only when the third enemy enters"
	)
	check(
		"COUNTERS",
		"CAPABILITY",
		#e[1].Parent.Children.HumanoidRootPart.Impulses == 1 and #e[3].Parent.Children.HumanoidRootPart.Impulses == 1,
		"the wave displaces everyone inside"
	)

	-- EventTargets: a blast only when the impact resolved two or more targets.
	local cluster = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = {
			{
				Condition = rule("EventTargets", ">=", 2),
				Behavior = "Explode",
				Radius = 6,
				Payloads = { payload("Damage", { Amount = 3 }) },
			},
		}
	end)
	check("COUNTERS", "CAPABILITY", validates(cluster), "EventTargets condition validates")
	e = resetWorld({ vec(0, 0, 0), vec(2, 0, 0) })
	emit(cluster, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("COUNTERS", "CAPABILITY", damageOps == 0, "one event target: no blast")
	emit(cluster, "OnImpact", caster, vec(0, 0, 0), { e[1], e[2] }, 0)
	check("COUNTERS", "CAPABILITY", totalDamageTo("Enemy1") == 3, "two event targets: blast")

	check("COUNTERS", "CAPABILITY", not validates(draft("Field", "Energy", function(d)
		d.Triggers =
			{ OnTick = { { Condition = rule("TriggerCount", "MultipleOf", 0), Payloads = { payload("Damage") } } } }
	end)), "MultipleOf 0 is rejected")
	check("COUNTERS", "CAPABILITY", not validates(draft("Field", "Energy", function(d)
		d.Triggers =
			{ OnTick = { { Condition = rule("AreaOccupants", "MultipleOf", 2), Payloads = { payload("Damage") } } } }
	end)), "MultipleOf is only offered on TriggerCount")
end

---------------------------------------------------------------------------
-- Section 9: safety
---------------------------------------------------------------------------
do
	-- Self-recursive reaction: OnDamageDealt -> Explode(Damage) -> OnDamageDealt ...
	local d = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = { { Payloads = { payload("Damage", { Amount = 1 }) } } }
		d.Triggers.OnDamageDealt =
			{ { Behavior = "Explode", Radius = 10, Payloads = { payload("Damage", { Amount = 1 }) } } }
	end)
	check(
		"SAFETY",
		"LIMITATION",
		validates(d),
		"validator ACCEPTS a self-recursive OnDamageDealt->Explode->Damage spell"
	)
	local function run(targetCount)
		local positions = {}
		for i = 1, targetCount do
			positions[i] = vec(i * 0.5, 0, 0)
		end
		local e = resetWorld(positions, 1e9)
		emit(d, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
		return damageOps, count(function(x)
			return x.Op == "DepthCapped"
		end)
	end
	local ops1, capped1 = run(1)
	local ops3 = run(3)
	local exhausted3 = count(function(x)
		return x.Op == "BudgetExhausted"
	end)
	check(
		"SAFETY",
		"CAPABILITY",
		capped1 > 0,
		"MaxMagicEventDepth (" .. limits.MaxMagicEventDepth .. ") terminates recursion"
	)
	check(
		"SAFETY",
		"CAPABILITY",
		ops1 == limits.MaxMagicEventDepth + 1,
		"1 target: linear recursion, " .. ops1 .. " damage ops"
	)
	-- With N targets each explosion re-hits all N (~N^depth unbounded); the
	-- per-cascade operation budget caps the total work instead.
	check(
		"SAFETY",
		"CAPABILITY",
		ops3 <= limits.MaxOperationsPerCascade and exhausted3 == 1,
		"3 targets: "
			.. ops3
			.. " damage ops, capped by MaxOperationsPerCascade ("
			.. limits.MaxOperationsPerCascade
			.. "), exhaustion reported once"
	)
	local ops16 = run(16)
	check(
		"SAFETY",
		"CAPABILITY",
		ops16 <= limits.MaxOperationsPerCascade,
		"16 targets: " .. ops16 .. " damage ops (bounded)"
	)
	-- A separate root event gets a fresh budget, so repeating effects keep working.
	run(3)
	check("SAFETY", "CAPABILITY", damageOps > 0, "a new root event starts with a fresh budget")
	local stepCap = draft("Projectile", "Energy", function(d)
		local s = {}
		for i = 1, limits.MaxSteps + 1 do
			s[i] = { Payloads = { payload("Damage") } }
		end
		d.Triggers.OnImpact = s
	end)
	check("SAFETY", "CAPABILITY", not validates(stepCap), "more than MaxSteps steps per event rejected")
	local unknown = draft("Projectile", "Energy", function(d)
		d.Triggers.OnWhatever = { { Payloads = { payload("Damage") } } }
	end)
	check("SAFETY", "CAPABILITY", not validates(unknown), "unknown event names rejected")
	local hugeRadius = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact =
			{ { Behavior = "Explode", Radius = limits.MaxRadius * 10, Payloads = { payload("Damage") } } }
	end)
	check("SAFETY", "CAPABILITY", not validates(hugeRadius), "explosion radius above MaxRadius rejected")
	local badPayloadField = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = { { Payloads = { payload("Damage", { Script = "x" }) } } }
	end)
	check("SAFETY", "CAPABILITY", not validates(badPayloadField), "unknown payload fields rejected")
	-- SpawnEffect bounds are static: validation caps nesting, forbids
	-- summons, limits fan-out to Projectiles, and prices the child in.
	local function spawnStep(effect, extra)
		local step = { Behavior = "SpawnEffect", Payloads = {}, Effect = effect }
		for key, value in pairs(extra or {}) do
			step[key] = value
		end
		return step
	end
	local function nestedEffect(levels)
		local effect = spec.defaultSpawnEffect("Projectile")
		for _ = 2, levels do
			local outer = spec.defaultSpawnEffect("Projectile")
			outer.Triggers.OnImpact = { spawnStep(effect) }
			effect = outer
		end
		return effect
	end
	local function spawning(effect, extra)
		return draft("Projectile", "Energy", function(d)
			d.Triggers.OnImpact = { spawnStep(effect, extra) }
		end)
	end
	check(
		"SAFETY",
		"CAPABILITY",
		validates(spawning(nestedEffect(limits.MaxSpawnNesting))),
		"spawned effects may nest " .. limits.MaxSpawnNesting .. " levels"
	)
	check(
		"SAFETY",
		"CAPABILITY",
		not validates(spawning(nestedEffect(limits.MaxSpawnNesting + 1))),
		"nesting beyond MaxSpawnNesting is rejected"
	)
	local summoning = spec.defaultSpawnEffect("Field")
	summoning.Triggers = { OnCast = { { Payloads = { payload("Summon") } } } }
	check("SAFETY", "CAPABILITY", not validates(spawning(summoning)), "spawned effects cannot summon")
	check(
		"SAFETY",
		"CAPABILITY",
		not validates(spawning(spec.defaultSpawnEffect("Field"), { Count = 2 })),
		"only spawned Projectiles may spawn more than one"
	)
	check(
		"SAFETY",
		"CAPABILITY",
		not validates(spawning(spec.defaultSpawnEffect("Projectile"), { Count = limits.MaxSpawnCount + 1 })),
		"spawn count above MaxSpawnCount is rejected"
	)
	-- Every spawnable Form validates under every Principle that supports it,
	-- starting from defaultSpawnEffect; Manipulation is never spawnable.
	local spawnFailures = {}
	for _, principle in ipairs(schema.Principles) do
		for _, formName in ipairs(spec.SpawnForms) do
			if schema.supportsPrincipleForm(principle, formName) then
				local ok, reason = validates(draft("Projectile", principle, function(d)
					d.Triggers.OnImpact = { spawnStep(spec.defaultSpawnEffect(formName, principle)) }
				end))
				if not ok then
					table.insert(spawnFailures, principle .. "/" .. formName .. ": " .. tostring(reason))
				end
			end
		end
	end
	check(
		"SAFETY",
		"CAPABILITY",
		#spawnFailures == 0 and #spec.SpawnForms == 7,
		"all 7 spawnable Forms validate for every supporting Principle " .. table.concat(spawnFailures, "; ")
	)
	local manipulation = spec.defaultSpawnEffect("Field", "Matter")
	manipulation.Form = "Manipulation"
	manipulation.Field = nil
	check("SAFETY", "CAPABILITY", not validates(spawning(manipulation)), "Manipulation cannot be spawned")
	check(
		"SAFETY",
		"CAPABILITY",
		not validates(spawning(spec.defaultSpawnEffect("SelfEnhancement", "Body"))),
		"an Energy spell cannot spawn a SelfEnhancement (Principle/Form rules still apply)"
	)
	local cascade = spec.defaultSpawnEffect("Beam", "Energy")
	cascade.Beam.Pattern = "Cascade"
	check("SAFETY", "CAPABILITY", validates(spawning(cascade)), "a spawned Beam can use the Cascade pattern")
	local persistent = spec.defaultSpawnEffect("Construct", "Energy")
	persistent.Lifetime = { Mode = "Persistent" }
	check("SAFETY", "CAPABILITY", not validates(spawning(persistent)), "spawned Constructs cannot persist")
	local plainCost = spec.estimate(draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = { { Payloads = { payload("Damage") } } }
	end)).ManaDemand
	local spawnCost = spec.estimate(spawning(spec.defaultSpawnEffect("Projectile"), { Count = 3 })).ManaDemand
	check(
		"SAFETY",
		"CAPABILITY",
		spawnCost > plainCost * 2,
		"spawning three Projectiles costs more than twice a plain cast (" .. plainCost .. " -> " .. spawnCost .. ")"
	)
end

---------------------------------------------------------------------------
-- Section 8: event-specific filtering in dispatch (real module)
---------------------------------------------------------------------------
do
	local events = {}
	for name in pairs(schema.Forms.Projectile.Events) do
		table.insert(events, name)
	end
	table.sort(events)
	print("Projectile events: " .. table.concat(events, ", "))
	local fieldEvents = {}
	for name in pairs(schema.Forms.Field.Events) do
		table.insert(fieldEvents, name)
	end
	table.sort(fieldEvents)
	print("Field events: " .. table.concat(fieldEvents, ", "))
	local behaviors = {}
	for name in pairs(schema.Behaviors) do
		table.insert(behaviors, name)
	end
	table.sort(behaviors)
	check(
		"EVENTS",
		"CAPABILITY",
		table.concat(behaviors, ",") == "Explode,SpawnEffect",
		"trigger-step behaviors: " .. table.concat(behaviors, ",")
	)
end

---------------------------------------------------------------------------
-- Per-step conditions (branching)
---------------------------------------------------------------------------
do
	local function rule(family, property, operator, value)
		return { Family = family, Property = property, Operator = operator, Value = value }
	end
	local low = { Operator = "ALL", Conditions = { rule("Target", "HealthPercent", "<", 0.3) } }
	local notLow = { Operator = "NOT", Conditions = { rule("Target", "HealthPercent", "<", 0.3) } }
	-- Execute low-health targets, shove the rest: two branches on one event.
	local d = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = {
			{ Condition = low, Payloads = { payload("Damage", { Amount = 50 }) } },
			{ Condition = notLow, Payloads = { payload("Force", { Magnitude = 20 }) } },
		}
	end)
	local ok, reason = validates(d)
	check("STEPS", "CAPABILITY", ok, "two mutually exclusive conditional steps validate: " .. tostring(reason))
	local e = resetWorld({ vec(0, 0, 0), vec(2, 0, 0) }, 100)
	e[1].Health = 20
	emit(d, "OnImpact", caster, vec(0, 0, 0), { e[1], e[2] }, 0)
	check(
		"STEPS",
		"CAPABILITY",
		totalDamageTo("Enemy1") == 50
			and totalDamageTo("Enemy2") == 0
			and #e[1].Parent.Children.HumanoidRootPart.Impulses == 0
			and #e[2].Parent.Children.HumanoidRootPart.Impulses == 1,
		"each target takes exactly the branch its condition selects"
	)
	-- A conditional Explode is gated by the event target, then hits the sphere.
	local gated = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact =
			{ { Condition = low, Behavior = "Explode", Radius = 6, Payloads = { payload("Damage", { Amount = 5 }) } } }
	end)
	check("STEPS", "CAPABILITY", validates(gated), "Explode step accepts a Condition")
	e = resetWorld({ vec(0, 0, 0), vec(3, 0, 0) }, 100)
	emit(gated, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("STEPS", "CAPABILITY", damageOps == 0, "healthy impact target: conditional blast does not fire")
	e = resetWorld({ vec(0, 0, 0), vec(3, 0, 0) }, 100)
	e[1].Health = 10
	emit(gated, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check(
		"STEPS",
		"CAPABILITY",
		totalDamageTo("Enemy1") == 5 and totalDamageTo("Enemy2") == 5,
		"low impact target: blast fires and hits everyone in the sphere"
	)
	-- Target-less events evaluate once without a target.
	local expiry = draft("Projectile", "Energy", function(d)
		d.Triggers.OnExpire = {
			{
				Condition = { Operator = "ALL", Conditions = { rule("Caster", "IsAlive", "Is", true) } },
				Behavior = "Explode",
				Radius = 6,
				Payloads = { payload("Damage", { Amount = 3 }) },
			},
		}
	end)
	check("STEPS", "CAPABILITY", validates(expiry), "caster condition on a target-less event validates")
	e = resetWorld({ vec(0, 0, 0) })
	emit(expiry, "OnExpire", caster, vec(0, 0, 0), {}, 0)
	check(
		"STEPS",
		"CAPABILITY",
		totalDamageTo("Enemy1") == 3,
		"target-less event runs the step when the caster rule passes"
	)
	-- Fail closed without a condition adapter.
	local calls = 0
	Dispatch.execute(d, "OnImpact", { Targets = { e[1] } }, {
		execute = function()
			calls += 1
		end,
	}, BehaviorExec, Commands, TargetDeath)
	check("STEPS", "CAPABILITY", calls == 0, "conditional steps never run when no condition adapter is supplied")
	-- Editor-built branches: IF from ActionFlow.branchCondition and its
	-- OTHERWISE from ActionFlow.otherwise, exactly as the Lab creates them.
	local ActionFlow = load("src/shared/Modules/MagicActionFlow.luau")
	local ifCondition = ActionFlow.branchCondition()
	local otherwiseCondition = assert(ActionFlow.otherwise(ifCondition, 4))
	local editorPair = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = {
			{ Condition = ifCondition, Payloads = { payload("Damage", { Amount = 40 }) } },
			{ Condition = otherwiseCondition, Payloads = { payload("Force", { Magnitude = 15 }) } },
		}
	end)
	local pairOk, pairReason = validates(editorPair)
	check("STEPS", "CAPABILITY", pairOk, "editor-built IF/OTHERWISE pair validates: " .. tostring(pairReason))
	e = resetWorld({ vec(0, 0, 0), vec(2, 0, 0) }, 100)
	e[1].Health = 30
	emit(editorPair, "OnImpact", caster, vec(0, 0, 0), { e[1], e[2] }, 0)
	check(
		"STEPS",
		"CAPABILITY",
		totalDamageTo("Enemy1") == 40
			and #e[1].Parent.Children.HumanoidRootPart.Impulses == 0
			and totalDamageTo("Enemy2") == 0
			and #e[2].Parent.Children.HumanoidRootPart.Impulses == 1,
		"exactly one branch of the pair runs for each target"
	)
	-- Validation boundaries.
	local function withCondition(condition)
		return draft("Projectile", "Energy", function(d)
			d.Triggers.OnImpact = { { Condition = condition, Payloads = { payload("Damage") } } }
		end)
	end
	check(
		"STEPS",
		"CAPABILITY",
		not validates(withCondition({ Operator = "ALL", Conditions = { rule("Environment", "ClockTime", ">", 6) } })),
		"Environment family rejected for step conditions"
	)
	check(
		"STEPS",
		"CAPABILITY",
		not validates(
			withCondition({ Operator = "ALL", Conditions = { rule("Target", "HasLineOfSight", "Is", true) } })
		),
		"Target.HasLineOfSight rejected for step conditions"
	)
	check("STEPS", "CAPABILITY", not validates(withCondition({ "OnGround" })), "legacy list form rejected")
	check(
		"STEPS",
		"CAPABILITY",
		not validates(withCondition({ Operator = "ALL", Conditions = { rule("Target", "HealthPercent", "<", 5) } })),
		"out-of-range condition value rejected"
	)
	check(
		"STEPS",
		"CAPABILITY",
		not validates(withCondition({ Operator = "ALL", Conditions = { rule("Target", "Script", "Is", true) } })),
		"unknown condition property rejected"
	)
end

---------------------------------------------------------------------------
local kinds = { CAPABILITY = 0, LIMITATION = 0 }
---------------------------------------------------------------------------
-- Melee and damage-taken reactions: thorns and weapon imbues
---------------------------------------------------------------------------
do
	-- Thorns: an Enchantment that hurts whoever damages its holder.
	local thorns = draft("SelfEnhancement", "Body", function(d)
		d.Triggers = {
			OnDamageTaken = { { TargetFrom = "Attacker", Payloads = { payload("Damage", { Amount = 6 }) } } },
		}
	end)
	local thornsOk, thornsReason = validates(thorns)
	check(
		"MELEE",
		"CAPABILITY",
		thornsOk,
		"thorns (OnDamageTaken -> Attacker -> Damage) validates: " .. tostring(thornsReason)
	)
	local e = resetWorld({ vec(2, 0, 0) }, 100)
	emit(thorns, "OnDamageTaken", caster, vec(0, 0, -50), { casterHumanoid }, 0, { Attackers = { e[1] } })
	check("MELEE", "CAPABILITY", totalDamageTo("Enemy1") == 6, "thorns damages the attacker")
	check("MELEE", "CAPABILITY", totalDamageTo("Caster") == 0, "thorns never damages its holder")
	resetWorld({ vec(2, 0, 0) }, 100)
	emit(thorns, "OnDamageTaken", caster, vec(0, 0, -50), { casterHumanoid }, 0, { Attackers = {} })
	check(
		"MELEE",
		"CAPABILITY",
		damageOps == 0,
		"no eligible attacker (filtered out, or environment damage): step skipped"
	)
	-- Default TargetFrom (Holder) keeps acting on the holder.
	local guard = draft("SelfEnhancement", "Body", function(d)
		d.Triggers = { OnDamageTaken = { { Payloads = { payload("Shield", { Amount = 10 }) } } } }
	end)
	resetWorld({ vec(2, 0, 0) }, 100)
	emit(guard, "OnDamageTaken", caster, vec(0, 0, -50), { casterHumanoid }, 0, { Attackers = { enemies[1] } })
	check("MELEE", "CAPABILITY", count(function(x)
		return x.Op == "Status.shield" and x.Target == "Caster"
	end) == 1, "a Holder step still shields the holder")
	check("MELEE", "CAPABILITY", not validates(draft("SelfEnhancement", "Body", function(d)
		d.Triggers = { OnCast = { { TargetFrom = "Attacker", Payloads = { payload("Damage") } } } }
	end)), "TargetFrom is only accepted on OnDamageTaken")
	check("MELEE", "CAPABILITY", not validates(draft("SelfEnhancement", "Body", function(d)
		d.Triggers = { OnDamageTaken = { { TargetFrom = "Bystander", Payloads = { payload("Damage") } } } }
	end)), "TargetFrom must be Holder or Attacker")

	-- Lifesteal: OnDamageDealt -> Caster -> Heal 50% of the damage dealt.
	local lifesteal = draft("Projectile", "Body", function(d)
		d.Triggers.OnImpact = { { Payloads = { payload("Damage", { Amount = 20 }) } } }
		d.Triggers.OnDamageDealt = {
			{
				TargetFrom = "Caster",
				Payloads = { payload("Heal", { Amount = 50, Mode = "PercentDamageDealt" }) },
			},
		}
	end)
	local lifestealOk, lifestealReason = validates(lifesteal)
	check(
		"MELEE",
		"CAPABILITY",
		lifestealOk,
		"lifesteal (OnDamageDealt -> Caster -> Heal 50% of damage) validates: " .. tostring(lifestealReason)
	)
	local victims = resetWorld({ vec(2, 0, 0) }, 100)
	casterHumanoid.Health = 50
	emit(lifesteal, "OnImpact", caster, vec(0, 0, -50), { victims[1] }, 0)
	local dealt = totalDamageTo("Enemy1")
	local lifestealHeals = {}
	for _, entry in ipairs(log) do
		if entry.Op == "Status.heal" then
			table.insert(lifestealHeals, entry)
		end
	end
	check(
		"MELEE",
		"CAPABILITY",
		dealt > 0
			and #lifestealHeals == 1
			and lifestealHeals[1].Target == "Caster"
			and math.abs(lifestealHeals[1].Amount - dealt * 0.5) < 1e-6,
		"lifesteal heals the caster for half the damage the hit dealt"
	)
	casterHumanoid.Health = casterHumanoid.MaxHealth
	check("MELEE", "CAPABILITY", not validates(draft("Projectile", "Body", function(d)
		d.Triggers.OnImpact = { { Payloads = { payload("Heal", { Amount = 50, Mode = "PercentDamageDealt" }) } } }
	end)), "PercentDamageDealt is only accepted on OnDamageDealt")
	check("MELEE", "CAPABILITY", not validates(draft("SelfEnhancement", "Body", function(d)
		d.Triggers = { OnDamageTaken = { { TargetFrom = "Caster", Payloads = { payload("Heal") } } } }
	end)), "TargetFrom Caster is only accepted on OnDamageDealt")

	-- Overflow: a heal larger than the missing health shields the rest.
	local overheal = draft("SelfEnhancement", "Body", function(d)
		d.Triggers = {
			OnCast = { { Payloads = { payload("Heal", { Amount = 30, Overflow = "Shield" }) } } },
		}
	end)
	check("MELEE", "CAPABILITY", (validates(overheal)), "Heal with Overflow = Shield validates")
	resetWorld({}, 100)
	casterHumanoid.Health = casterHumanoid.MaxHealth - 10
	emit(overheal, "OnCast", caster, vec(0, 0, -50), { casterHumanoid }, 0)
	casterHumanoid.Health = casterHumanoid.MaxHealth
	local overflowShield
	for _, entry in ipairs(log) do
		if entry.Op == "Status.shield" then
			overflowShield = entry
		end
	end
	check(
		"MELEE",
		"CAPABILITY",
		overflowShield ~= nil
			and overflowShield.Amount == 20
			and overflowShield.Duration == limits.HealOverflowShieldDuration,
		"heal overflow becomes a short shield for the part that could not be healed"
	)

	-- Rush: the server's Dash calls OnImpact once per swept target and OnExpire
	-- at arrival (MagicService.stepRush); payloads resolve like any other Form.
	local dash = draft("Rush", "Energy", function(d)
		d.Rush.StopOnHit = false
		d.Triggers = {
			OnImpact = { { Payloads = { payload("Damage", { Amount = 7 }) } } },
			OnExpire = { { Payloads = { payload("Slow", { Multiplier = 0.5, Duration = 1 }) } } },
		}
	end)
	local dashOk, dashReason = validates(dash)
	check("RUSH", "CAPABILITY", dashOk, "dash with impact damage and arrival slow validates: " .. tostring(dashReason))
	local swept = resetWorld({ vec(0, 0, 4), vec(0, 0, 8) }, 100)
	for _, target in swept do
		emit(dash, "OnImpact", caster, vec(0, 0, 0), { target }, 0)
	end
	emit(dash, "OnExpire", caster, vec(0, 0, 10), { swept[2] }, 0)
	check(
		"RUSH",
		"CAPABILITY",
		totalDamageTo("Enemy1") == 7 and totalDamageTo("Enemy2") == 7 and totalDamageTo("Caster") == 0,
		"each swept target takes the dash's impact damage once; the caster takes none"
	)
	check("RUSH", "CAPABILITY", count(function(x)
		return x.Op == "Status.slow" and x.Target == "Enemy2"
	end) == 1, "arrival effects land on targets around the destination")
	local blink = draft("Rush", "Space", function(d)
		d.Rush.Mode = "Blink"
		d.Triggers = { OnExpire = { { Payloads = { payload("Damage", { Amount = 9 }) } } } }
	end)
	check("RUSH", "CAPABILITY", (validates(blink)), "blink-and-burst (Blink -> OnExpire damage) validates")
	check("RUSH", "CAPABILITY", not validates(draft("Rush", "Space", function(d)
		d.Rush.Mode = "Blink"
		d.Triggers = { OnImpact = { { Payloads = { payload("Damage") } } } }
	end)), "Blink never hits on the way")

	-- Recast: three stages on one active Field, branched on TriggerCount
	-- (MagicService.recastActive counts OnRecast on the effect's record).
	local function stage(n, amount)
		return {
			Condition = {
				Operator = "ALL",
				Conditions = { { Family = "SpellState", Property = "TriggerCount", Operator = "==", Value = n } },
			},
			Payloads = { payload("Damage", { Amount = amount }) },
		}
	end
	local staged = draft("Field", "Energy", function(d)
		d.Casting.MaxRecasts = 3
		d.Triggers = { OnRecast = { stage(1, 3), stage(2, 5), stage(3, 11) } }
	end)
	local stagedOk, stagedReason = validates(staged)
	check("RECAST", "CAPABILITY", stagedOk, "three-stage recast Field validates: " .. tostring(stagedReason))
	local inside = resetWorld({ vec(0, 0, 0) }, 100)
	local fieldRecord = {}
	local stageDamage = {}
	for _ = 1, 3 do
		local before = totalDamageTo("Enemy1")
		emit(staged, "OnRecast", caster, vec(0, 0, 0), { inside[1] }, 0, nil, nil, fieldRecord)
		table.insert(stageDamage, totalDamageTo("Enemy1") - before)
	end
	check(
		"RECAST",
		"CAPABILITY",
		stageDamage[1] == 3 and stageDamage[2] == 5 and stageDamage[3] == 11,
		"each recast runs only its own stage (3, 5, 11)"
	)
	local detonate = draft("Projectile", "Energy", function(d)
		d.Triggers = { OnRecast = { { Behavior = "Explode", Radius = 6, Payloads = { payload("Damage") } } } }
	end)
	check(
		"RECAST",
		"CAPABILITY",
		(validates(detonate)),
		"recast-to-detonate (Projectile OnRecast -> Explode) validates"
	)
	check("RECAST", "CAPABILITY", not validates(draft("Beam", "Energy", function(d)
		d.Triggers = { OnRecast = { { Payloads = { payload("Damage") } } } }
	end)), "instant Forms leave nothing to recast")
	check("RECAST", "CAPABILITY", not validates(draft("Field", "Energy", function(d)
		d.Casting.MaxRecasts = 4
		d.Triggers = { OnRecast = { stage(1, 3) } }
	end)), "MaxRecasts is at most 3")
	check("RECAST", "CAPABILITY", not validates(draft("Field", "Energy", function(d)
		d.Casting.Mode = "Channeled"
		d.Triggers = { OnRecast = { stage(1, 3) } }
	end)), "held spells cannot recast")

	-- Fire imbue: every melee hit marks the target with Fire; every third hit
	-- also bursts a Wave where it landed.
	local function rule(property, operator, value)
		return {
			Operator = "ALL",
			Conditions = { { Family = "SpellState", Property = property, Operator = operator, Value = value } },
		}
	end
	local burst = spec.defaultSpawnEffect("Wave")
	burst.Geometry = "Sphere"
	burst.Wave.Range = 6
	burst.Triggers = { OnCast = { { Payloads = { payload("Damage", { Amount = 4 }) } } } }
	local imbue = draft("SelfEnhancement", "Body", function(d)
		d.Element = "Fire"
		d.Triggers = {
			OnMeleeHit = {
				{ Payloads = { payload("ElementalMark", { Stacks = 1, Duration = 5 }) } },
				{
					Condition = rule("TriggerCount", "MultipleOf", 3),
					Behavior = "SpawnEffect",
					Payloads = {},
					Effect = burst,
				},
			},
		}
	end)
	local imbueOk, imbueReason = validates(imbue)
	check(
		"MELEE",
		"CAPABILITY",
		imbueOk,
		"fire imbue (OnMeleeHit mark + every 3rd hit Wave) validates: " .. tostring(imbueReason)
	)
	e = resetWorld({ vec(0, 0, 0) }, 1000)
	local enchantment = {}
	for _ = 1, 6 do
		emit(imbue, "OnMeleeHit", caster, vec(0, 0, 0), { e[1] }, 0, nil, nil, enchantment)
	end
	check("MELEE", "CAPABILITY", count(function(x)
		return x.Op == "Status.elementalMark" and x.Target == "Enemy1"
	end) == 6, "each of 6 melee hits applies a Fire mark")
	check("MELEE", "CAPABILITY", count(function(x)
		return x.Op == "Spawn" and x.Form == "Wave"
	end) == 2, "hits 3 and 6 burst a Wave")
	check("MELEE", "CAPABILITY", totalDamageTo("Enemy1") == 8, "both Waves damage the target (2 x 4)")
	-- Spell damage from an OnMeleeHit step is not a melee hit, so it never
	-- re-emits OnMeleeHit: only the 6 driven events appear.
	check("MELEE", "CAPABILITY", count(function(x)
		return x.Op == "Event" and x.Event == "OnMeleeHit"
	end) == 6, "Wave damage does not trigger OnMeleeHit again")

	-- Where OnMeleeHit is offered: Enchantment, Aura, and Fields that follow.
	check("MELEE", "CAPABILITY", schema.supportsEvent("Aura", "OnMeleeHit"), "Aura supports OnMeleeHit")
	check("MELEE", "CAPABILITY", not schema.supportsEvent("Projectile", "OnMeleeHit"), "Projectile does not")
	local stillField = draft("Field", "Energy", function(d)
		d.Triggers = { OnMeleeHit = { { Payloads = { payload("Damage") } } } }
	end)
	check("MELEE", "CAPABILITY", not validates(stillField), "a stationary Field cannot use OnMeleeHit")
	local followField = draft("Field", "Energy", function(d)
		d.Targeting = "EntityTarget"
		d.TargetPolicy = "LockOn"
		d.Field.FollowTarget = true
		d.Triggers = { OnMeleeHit = { { Payloads = { payload("Damage") } } } }
	end)
	local followOk, followReason = validates(followField)
	check("MELEE", "CAPABILITY", followOk, "a following Field can use OnMeleeHit: " .. tostring(followReason))
end

---------------------------------------------------------------------------
-- Enchantments on others: owner (caster) vs holder (the character it is on)
---------------------------------------------------------------------------
do
	local Enchantment = load("src/shared/Modules/MagicEnchantmentSpec.luau")
	-- MagicService emits holder-view events with the OWNER as caster, at the
	-- HOLDER's position, targeting the holder; this helper mirrors that.
	local function emitForHolder(definition, event, record, data)
		local holderRoot = record.Holder.Parent.Children.HumanoidRootPart
		emit(definition, event, record.Owner, holderRoot.Position, { record.Holder }, 0, data, nil, record)
	end
	local function marksOn(name)
		return count(function(x)
			return x.Op == "Status.elementalMark" and x.Target == name
		end)
	end

	-- Hex: on an enemy; when the hexed enemy takes damage, Poison-mark its neighbours.
	local hex = draft("SelfEnhancement", "Body", function(d)
		d.Element = "Poison"
		d.Targeting = "EntityTarget"
		d.TargetPolicy = "LockOn"
		d.TargetRules.Relationship = "Hostile"
		d.Triggers = {
			OnDamageTaken = {
				{
					Behavior = "Explode",
					Radius = 6,
					Payloads = { payload("ElementalMark", { Stacks = 1, Duration = 6 }) },
				},
			},
		}
	end)
	local hexOk, hexReason = validates(hex)
	check("ENCHANT", "CAPABILITY", hexOk, "hex (Enchantment on an enemy) validates: " .. tostring(hexReason))
	local e = resetWorld({ vec(0, 0, 0), vec(3, 0, 0), vec(30, 0, 0) }, 100)
	local hexRecord = { Owner = caster, Holder = e[1], ExpiresAt = 10, IsSelf = false }
	check(
		"ENCHANT",
		"CAPABILITY",
		hexRecord.Owner ~= hexRecord.Holder.Parent and Enchantment.key("Hex", "1", false) == "Hex@1",
		"owner and holder are different characters with a per-holder key"
	)
	emitForHolder(hex, "OnDamageTaken", hexRecord, { Attackers = {} })
	check("ENCHANT", "CAPABILITY", marksOn("Enemy2") == 1, "hexed enemy taking damage marks its neighbour")
	check("ENCHANT", "CAPABILITY", marksOn("Enemy3") == 0, "enemies outside the radius are not marked")
	check("ENCHANT", "CAPABILITY", marksOn("Caster") == 0, "the owner, far away, is not marked")

	-- Guardian: on an ally; when they drop below 30% health, shield them.
	local guardian = draft("SelfEnhancement", "Body", function(d)
		d.Targeting = "EntityTarget"
		d.TargetPolicy = "Aim"
		d.TargetRules.Relationship = "Ally"
		d.Triggers = {
			OnDamageTaken = {
				{
					Condition = {
						Operator = "ALL",
						Conditions = { { Family = "Target", Property = "HealthPercent", Operator = "<", Value = 0.3 } },
					},
					Payloads = { payload("Shield", { Amount = 25 }) },
				},
			},
		}
	end)
	local guardianOk, guardianReason = validates(guardian)
	check(
		"ENCHANT",
		"CAPABILITY",
		guardianOk,
		"guardian (Enchantment on an ally) validates: " .. tostring(guardianReason)
	)
	resetWorld({}, 100)
	local allyHumanoid = makeCharacter("Ally", vec(5, 0, 0), 100)
	local guardRecord = { Owner = caster, Holder = allyHumanoid, ExpiresAt = 10, IsSelf = false }
	local function shieldsOnAlly()
		return count(function(x)
			return x.Op == "Status.shield" and x.Target == "Ally"
		end)
	end
	allyHumanoid.Health = 50
	emitForHolder(guardian, "OnDamageTaken", guardRecord, { Attackers = {} })
	check("ENCHANT", "CAPABILITY", shieldsOnAlly() == 0, "no shield while the ally is above 30%")
	allyHumanoid.Health = 20
	emitForHolder(guardian, "OnDamageTaken", guardRecord, { Attackers = {} })
	check("ENCHANT", "CAPABILITY", shieldsOnAlly() == 1, "the ally is shielded once below 30%")
	check("ENCHANT", "CAPABILITY", count(function(x)
		return x.Op == "Status.shield" and x.Target == "Caster"
	end) == 0, "the owner is not the one shielded")

	-- Cleanup: holder death tells the owner (OnTargetDeath) and ends it (OnExpire);
	-- owner death ends it too; a self-caster respawning only expires.
	local alive = { Now = 1, HolderAlive = true, HolderPresent = true, OwnerAlive = true, OwnerPresent = true }
	local function with(overrides)
		local f = table.clone(alive)
		for key, value in pairs(overrides) do
			f[key] = value
		end
		return f
	end
	local holderDied = Enchantment.endReason(hexRecord, with({ HolderAlive = false }))
	local events = Enchantment.endEvents(holderDied, false)
	check(
		"ENCHANT",
		"CAPABILITY",
		holderDied == "HolderDeath" and events[1] == "OnTargetDeath" and events[2] == "OnExpire",
		"holder death fires OnTargetDeath for the owner, then OnExpire"
	)
	local ownerDied = Enchantment.endReason(hexRecord, with({ OwnerAlive = false }))
	events = Enchantment.endEvents(ownerDied, false)
	check(
		"ENCHANT",
		"CAPABILITY",
		ownerDied == "OwnerDeath" and events[1] == "OnCasterDeath" and events[2] == "OnExpire",
		"owner death ends the enchantment on the holder"
	)
	check(
		"ENCHANT",
		"CAPABILITY",
		Enchantment.endReason(hexRecord, with({})) == nil
			and Enchantment.endReason(hexRecord, with({ Now = 10 })) == "Duration",
		"it lasts until its duration ends while both are alive"
	)
	-- The holder-death events run the enchantment's own steps with the holder as target.
	local reporter = draft("SelfEnhancement", "Body", function(d)
		d.Element = "Poison"
		d.Targeting = "EntityTarget"
		d.TargetPolicy = "Aim"
		d.Triggers = {
			OnTargetDeath = { { Behavior = "Explode", Radius = 6, Payloads = { payload("ElementalMark") } } },
			OnExpire = { { Behavior = "Explode", Radius = 6, Payloads = { payload("Bind") } } },
		}
	end)
	local reporterOk, reporterReason = validates(reporter)
	check(
		"ENCHANT",
		"CAPABILITY",
		reporterOk,
		"OnTargetDeath/OnExpire on an Enchantment validate: " .. tostring(reporterReason)
	)
	e = resetWorld({ vec(0, 0, 0), vec(2, 0, 0) }, 100)
	local doomed = { Owner = caster, Holder = e[1], ExpiresAt = 10, IsSelf = false }
	e[1].Health = 0
	for _, event in Enchantment.endEvents(Enchantment.endReason(doomed, with({ HolderAlive = false })), false) do
		emitForHolder(reporter, event, doomed, { DeathCause = "DiedWhileAffected" })
	end
	check("ENCHANT", "CAPABILITY", marksOn("Enemy2") == 1, "holder death bursts on the neighbours (OnTargetDeath)")
	check("ENCHANT", "CAPABILITY", count(function(x)
		return x.Op == "Status.bind" and x.Target == "Enemy2"
	end) == 1, "and the enchantment's OnExpire still runs once (the dead holder is skipped)")

	-- Where an Enchantment may go.
	check("ENCHANT", "CAPABILITY", not validates(draft("SelfEnhancement", "Body", function(d)
		d.Targeting = "EntityTarget"
		d.TargetPolicy = "MaintainTarget"
	end)), "MaintainTarget is not an Enchantment policy")
	check("ENCHANT", "CAPABILITY", not validates(draft("SelfEnhancement", "Body", function(d)
		d.Targeting = "EntityTarget"
		d.TargetPolicy = "Aim"
		d.Triggers = { OnCast = { { Payloads = { payload("AerialMovement") } } } }
	end)), "Aerial movement stays self-only")
	check("ENCHANT", "CAPABILITY", not validates(draft("SelfEnhancement", "Body", function(d)
		d.Targeting = "EntityTarget"
		d.TargetPolicy = "Aim"
		d.Casting.Mode = "Channeled"
	end)), "a Channeled Enchantment can only be held on yourself")
	local selfDefault = draft("SelfEnhancement", "Body", function(d)
		d.Triggers = { OnCast = { { Payloads = { payload("Enhancement") } } } }
	end)
	check(
		"ENCHANT",
		"CAPABILITY",
		selfDefault.Targeting == "Self" and validates(selfDefault),
		"Self stays the default target"
	)
end

---------------------------------------------------------------------------
-- Scaling: ScaleBy and charge potency
---------------------------------------------------------------------------
do
	-- Consume all burn stacks for 10 damage each: the Damage step reads the
	-- Fire stacks first, then the same step consumes them.
	local markStacks = {}
	rawset(StatusDouble, "elementalMarkStacks", function(humanoid, element)
		local byElement = markStacks[humanoid]
		return byElement and byElement[element] or 0
	end)
	rawset(StatusDouble, "consumeElementalMark", function(humanoid, element, stacks)
		local byElement = markStacks[humanoid] or {}
		local consumed = math.min(byElement[element] or 0, stacks)
		byElement[element] = (byElement[element] or 0) - consumed
		markStacks[humanoid] = byElement
		record({ Op = "Status.consumeElementalMark", Target = humanoid.Parent.Name, Consumed = consumed })
		return consumed
	end)
	local detonate = draft("Projectile", "Energy", function(d)
		d.Element = "Fire"
		d.Triggers.OnImpact = {
			{
				Payloads = {
					payload("Damage", {
						Amount = 0,
						ScaleBy = { Source = "ElementalMarkStacks", Element = "Fire", PerUnit = 10, Max = 100 },
					}),
					payload("ConsumeElementalMark", { Stacks = limits.MaxElementalMarkStacks }),
				},
			},
		}
	end)
	local detonateOk, detonateReason = validates(detonate)
	check(
		"SCALE",
		"CAPABILITY",
		detonateOk,
		"burn detonation (ScaleBy mark stacks + consume) validates: " .. tostring(detonateReason)
	)
	local e = resetWorld({ vec(0, 0, 0) }, 1000)
	markStacks[e[1]] = { Fire = 4, Ice = 2 }
	emit(detonate, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check(
		"SCALE",
		"CAPABILITY",
		totalDamageTo("Enemy1") == 40,
		"4 burn stacks deal 40, got " .. totalDamageTo("Enemy1")
	)
	check(
		"SCALE",
		"CAPABILITY",
		markStacks[e[1]].Fire == 0 and markStacks[e[1]].Ice == 2,
		"all Fire stacks consumed, Ice kept"
	)
	log = {}
	emit(detonate, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("SCALE", "CAPABILITY", totalDamageTo("Enemy1") == 0, "with no stacks left it deals nothing")
	-- Execute: more damage the more health the target is missing.
	local execute = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = {
			{
				Payloads = {
					payload("Damage", {
						Amount = 10,
						ScaleBy = { Source = "TargetMissingHealthPercent", PerUnit = 0.5, Max = 30 },
					}),
				},
			},
		}
	end)
	check("SCALE", "CAPABILITY", validates(execute), "missing-health scaling validates")
	e = resetWorld({ vec(0, 0, 0) }, 100)
	e[1].Health = 60
	emit(execute, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("SCALE", "CAPABILITY", totalDamageTo("Enemy1") == 30, "40% missing: 10 + 20 = 30")
	e = resetWorld({ vec(0, 0, 0) }, 100)
	e[1].Health = 10
	emit(execute, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check(
		"SCALE",
		"CAPABILITY",
		totalDamageTo("Enemy1") == 40,
		"90% missing: the bonus is capped at 30, so 10 + 30 = 40"
	)
	-- ScaleBy is only offered on damage, damage over time, healing and shields.
	check("SCALE", "CAPABILITY", not validates(draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = {
			{ Payloads = { payload("Slow", { ScaleBy = { Source = "TriggerCount", PerUnit = 1, Max = 5 } }) } },
		}
	end)), "Slow cannot scale")
	-- Charge scaling is valid only on Charged / HoldAndRelease and priced at MaxPotency.
	local charged = draft("Projectile", "Energy", function(d)
		d.Casting.Mode = "Charged"
		d.Casting.MinimumCharge = 0.2
		d.Casting.MaximumCharge = 2
		d.Triggers.OnImpact = { { Payloads = { payload("Damage", { Amount = 20 }) } } }
	end)
	local base = spec.estimate(charged).ManaDemand
	charged.Casting.ChargeScaling = { MinPotency = 1, MaxPotency = 5 }
	local chargedOk, chargedReason = validates(charged)
	check("SCALE", "CAPABILITY", chargedOk, "5x charge scaling validates: " .. tostring(chargedReason))
	check("SCALE", "CAPABILITY", spec.estimate(charged).ManaDemand > base, "a 5x charge costs more than no scaling")
	-- Extra projectiles at full charge: priced at the full count, Projectile only.
	local fiveX = spec.estimate(charged).ManaDemand
	charged.Casting.ChargeScaling = { MinPotency = 1, MaxPotency = 5, MaxExtraProjectiles = limits.MaxSpawnCount }
	local volleyOk, volleyReason = validates(charged)
	check("SCALE", "CAPABILITY", volleyOk, "charged volley (extra projectiles) validates: " .. tostring(volleyReason))
	check("SCALE", "CAPABILITY", spec.estimate(charged).ManaDemand > fiveX, "extra projectiles raise the cost")
	charged.Casting.ChargeScaling.MaxExtraProjectiles = limits.MaxSpawnCount + 1
	check("SCALE", "CAPABILITY", not validates(charged), "extra projectiles respect the projectile count limit")
	check("SCALE", "CAPABILITY", not validates(draft("Field", "Energy", function(d)
		d.Casting.Mode = "Charged"
		d.Casting.MinimumCharge = 0.2
		d.Casting.MaximumCharge = 2
		d.Casting.ChargeScaling = { MinPotency = 1, MaxPotency = 1, MaxExtraProjectiles = 1 }
		d.Triggers.OnTick = { { Payloads = { payload("Damage") } } }
	end)), "only Projectiles can fire extra projectiles")
	check("SCALE", "CAPABILITY", not validates(draft("Projectile", "Energy", function(d)
		d.Casting.ChargeScaling = { MinPotency = 1, MaxPotency = 2 }
		d.Triggers.OnImpact = { { Payloads = { payload("Damage") } } }
	end)), "an Instant cast cannot use charge scaling")
end

---------------------------------------------------------------------------
-- Cleanse through the real executor: one pool, longest-lasting first
---------------------------------------------------------------------------
do
	local removed = {}
	local function candidate(id, polarity, remaining)
		return {
			Polarity = polarity,
			Remaining = remaining,
			AppliedAt = 0,
			Remove = function()
				table.insert(removed, id)
			end,
		}
	end
	rawset(StatusDouble, "cleanseCandidates", function()
		return { candidate("slow", "Bane", 2), candidate("dot", "Bane", 5), candidate("shield", "Boon", 9) }
	end)
	local purge = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = { { Payloads = { payload("Cleanse", { Remove = "Banes", Count = 2 }) } } }
	end)
	local purgeOk, purgeReason = validates(purge)
	check("CLEANSE", "CAPABILITY", purgeOk, "Cleanse Banes validates: " .. tostring(purgeReason))
	local e = resetWorld({ vec(0, 0, 0) }, 100)
	local ctx = makeContext(purge, caster, vec(0, 0, 0), { e[1] }, 0, nil)
	ctx.EnchantmentCandidates = function()
		return { candidate("hex", "Bane", math.huge), candidate("blessing", "Boon", math.huge) }
	end
	PayloadExec.execute(purge.Triggers.OnImpact[1].Payloads, ctx)
	check(
		"CLEANSE",
		"CAPABILITY",
		table.concat(removed, ",") == "hex,dot",
		"Count 2 removes the hex Enchantment, then the longest Bane status; got " .. table.concat(removed, ",")
	)
	table.clear(removed)
	local strip = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = { { Payloads = { payload("Cleanse", { Remove = "Boons", Count = 5 }) } } }
	end)
	PayloadExec.execute(strip.Triggers.OnImpact[1].Payloads, ctx)
	check(
		"CLEANSE",
		"CAPABILITY",
		table.concat(removed, ",") == "blessing,shield",
		"Remove Boons strips the Boon Enchantment and Boon statuses only"
	)
	rawset(StatusDouble, "cleanseCandidates", nil)
end

---------------------------------------------------------------------------
-- Elemental reactions (real executors; status doubles use the real rules)
---------------------------------------------------------------------------
do
	local Interactions = load("src/shared/Modules/MagicElementalInteractionSpec.luau")
	-- Marks and Frozen per target, kept by these doubles the way the status
	-- service keeps them: a reaction is checked before the new mark stacks.
	local marks, frozen = {}, {}
	local function has(humanoid)
		return function(name)
			if name == "Frozen" then
				return frozen[humanoid] == true
			end
			return (marks[humanoid] and marks[humanoid][name] or 0) > 0
		end
	end
	local function react(humanoid, incoming, allow)
		if allow == false then
			return nil
		end
		local reaction = Interactions.findReaction(incoming, has(humanoid))
		if not reaction then
			return nil
		end
		if reaction.Existing == "Frozen" then
			frozen[humanoid] = nil
		elseif reaction.ConsumeStacks then
			marks[humanoid][reaction.Existing] =
				math.max(0, marks[humanoid][reaction.Existing] - reaction.ConsumeStacks)
		end
		record({ Op = "Reaction", Name = reaction.Name, Target = humanoid.Parent.Name })
		return reaction
	end
	rawset(StatusDouble, "elementalMark", function(_, humanoid, _, element, stacks, _, allow)
		local reaction = react(humanoid, element, allow)
		marks[humanoid] = marks[humanoid] or {}
		marks[humanoid][element] = (marks[humanoid][element] or 0) + (stacks or 1)
		record({ Op = "Status.elementalMark", Target = humanoid.Parent.Name, Element = element })
		return true, reaction
	end)
	rawset(StatusDouble, "checkReaction", function(humanoid, incoming)
		return react(humanoid, incoming, true)
	end)
	rawset(StatusDouble, "hasElementalMark", function(humanoid, element)
		return has(humanoid)(element)
	end)
	rawset(StatusDouble, "addConcealment", function(position, radius, duration)
		record({ Op = "Status.addConcealment", Radius = radius, Duration = duration })
	end)
	rawset(StatusDouble, "stun", function(_, humanoid, spellId)
		if spellId == "Reaction:Freeze" then
			frozen[humanoid] = true
		end
		record({ Op = "Status.stun", Target = humanoid.Parent.Name, SpellId = spellId })
		return true
	end)
	local function markSpell(element)
		return draft("Projectile", "Energy", function(d)
			d.Element = element
			d.Triggers.OnImpact = { { Payloads = { payload("ElementalMark", { Stacks = 1, Duration = 4 }) } } }
		end)
	end
	local function setup(positions)
		local e = resetWorld(positions, 1000)
		table.clear(marks)
		table.clear(frozen)
		return e
	end
	local function ops(op, target)
		return count(function(x)
			return x.Op == op and (target == nil or x.Target == target)
		end)
	end
	local function reactions(name)
		return count(function(x)
			return x.Op == "Reaction" and x.Name == name
		end)
	end

	-- Conduct: Wet + Lightning chains 8 damage to other Wet targets within 10 studs.
	local e = setup({ vec(0, 0, 0), vec(4, 0, 0), vec(30, 0, 0) })
	marks[e[1]] = { Water = 1 }
	marks[e[2]] = { Water = 1 }
	marks[e[3]] = { Water = 1 }
	emit(markSpell("Lightning"), "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("REACT", "CAPABILITY", reactions("Conduct") == 1, "Wet + Lightning conducts")
	check("REACT", "CAPABILITY", totalDamageTo("Enemy2") == 8, "the hit chains to the Wet neighbour (8)")
	check("REACT", "CAPABILITY", totalDamageTo("Enemy3") == 0, "but not beyond 10 studs")
	check("REACT", "CAPABILITY", marks[e[1]].Water == 0, "Conduct consumes a Wet stack")
	check("REACT", "LIMITATION", reactions("Conduct") == 1, "chained hits never conduct again (no reaction chains)")

	-- Firestorm: Burning + Wind spawns a small burning Field.
	e = setup({ vec(0, 0, 0) })
	marks[e[1]] = { Fire = 1 }
	emit(markSpell("Wind"), "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("REACT", "CAPABILITY", reactions("Firestorm") == 1, "Burning + Wind becomes a firestorm")
	check("REACT", "CAPABILITY", count(function(x)
		return x.Op == "ReactionField" and x.Element == "Fire" and x.Radius == 6
	end) == 1, "a small burning Field is spawned")

	-- Freeze: Wet + Ice stuns for 1 s through Phase 6 Stun (DR and PvP cap apply there).
	e = setup({ vec(0, 0, 0) })
	marks[e[1]] = { Water = 1 }
	emit(markSpell("Ice"), "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("REACT", "CAPABILITY", reactions("Freeze") == 1, "Wet + Ice freezes")
	check("REACT", "CAPABILITY", count(function(x)
		return x.Op == "Status.stun" and x.SpellId == "Reaction:Freeze"
	end) == 1, "Freeze is a Stun tagged Reaction:Freeze")

	-- Shatter: Frozen + Earth, or Frozen + a Force hit: 15 Physical damage, ends the Freeze.
	emit(markSpell("Earth"), "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("REACT", "CAPABILITY", reactions("Shatter") == 1, "Frozen + Earth shatters")
	check("REACT", "CAPABILITY", count(function(x)
		return x.Op == "Damage" and x.Target == "Enemy1" and x.Amount == 15 and x.Channel == "Physical"
	end) == 1, "Shatter deals 15 Physical damage")
	check("REACT", "CAPABILITY", frozen[e[1]] == nil, "Shatter ends the Freeze")
	e = setup({ vec(0, 0, 0) })
	frozen[e[1]] = true
	local shove = draft("Projectile", "Energy", function(d)
		d.Triggers.OnImpact = { { Payloads = { payload("Force", { Magnitude = 20 }) } } }
	end)
	emit(shove, "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("REACT", "CAPABILITY", reactions("Shatter") == 1, "a Force spell shatters a Frozen target")
	-- Wind's own starter Force (a mark effect) must not shatter: no reaction chains.
	e = setup({ vec(0, 0, 0) })
	frozen[e[1]] = true
	emit(markSpell("Wind"), "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check(
		"REACT",
		"LIMITATION",
		reactions("Shatter") == 0 and frozen[e[1]] == true,
		"a mark's own Force effect never shatters"
	)

	-- Toxic smoke: Burning + Poison spawns a Field and a zone that blocks Reveal.
	e = setup({ vec(0, 0, 0) })
	marks[e[1]] = { Fire = 1 }
	emit(markSpell("Poison"), "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("REACT", "CAPABILITY", reactions("ToxicSmoke") == 1, "Burning + Poison makes toxic smoke")
	check("REACT", "CAPABILITY", ops("Status.addConcealment") == 1, "the smoke blocks Reveal")
	check("REACT", "CAPABILITY", count(function(x)
		return x.Op == "ReactionField" and x.Kind == "Smoke" and x.Radius == 8
	end) == 1, "and shows as an 8-stud Field")

	-- Mire: Earth + Water is a strong Slow.
	e = setup({ vec(0, 0, 0) })
	marks[e[1]] = { Earth = 1 }
	emit(markSpell("Water"), "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("REACT", "CAPABILITY", reactions("Mire") == 1, "Earth + Water mires")
	check("REACT", "CAPABILITY", ops("Status.slow", "Enemy1") >= 2, "Mire adds a Slow on top of Water's own")

	-- One reaction per landing, and the incoming mark still lands.
	e = setup({ vec(0, 0, 0) })
	marks[e[1]] = { Water = 1, Earth = 1 }
	emit(markSpell("Ice"), "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check(
		"REACT",
		"CAPABILITY",
		ops("Reaction") == 1 and marks[e[1]].Ice == 1,
		"one reaction per landing; the mark still stacks"
	)

	-- Starter effects are unchanged: a mark with nothing to react to applies only its starters.
	e = setup({ vec(0, 0, 0) })
	emit(markSpell("Fire"), "OnImpact", caster, vec(0, 0, 0), { e[1] }, 0)
	check("REACT", "CAPABILITY", ops("Reaction") == 0, "no reaction without an existing state")
	check(
		"REACT",
		"CAPABILITY",
		ops("Status.slow", "Enemy1") == 1 and ops("Status.modifyAttribute", "Enemy1") == 1,
		"Fire's starters still apply"
	)
end

for _, r in ipairs(results) do
	kinds[r.Kind] += 1
	print(string.format("[%s] %-8s %-10s %s", r.Ok and "ok" or "FAIL", r.Test, r.Kind, r.Message))
end
print(
	string.format(
		"%d checks (%d capability, %d limitation), %d failed",
		#results,
		kinds.CAPABILITY,
		kinds.LIMITATION,
		failures
	)
)
assert(failures == 0, "emergent magic audit checks failed")
