--!strict
-- Canonical runtime data. Legacy registered definitions are normalized, not mutated.
local Limits = require(script.Parent.Parent.Configuration.MagicLab)
local Schema = require(script.Parent.Parent.Configuration.MagicSchema)
local ProjectileBehaviorSpec = require(script.Parent.ProjectileBehaviorSpec)
local ProjectileMotion = require(script.Parent.MagicProjectileMotion)
local ConditionSpec = require(script.Parent.MagicConditionSpec)
local LifetimeSpec = require(script.Parent.MagicLifetimeSpec)
local ProximitySpec = require(script.Parent.MagicProximitySpec)
local CastingSpec = require(script.Parent.MagicCastingSpec)
local InterceptionSpec = require(script.Parent.MagicInterceptionSpec)
local MaterialSpec = require(script.Parent.MagicMaterialSpec)
local AudioSpec = require(script.Parent.MagicAudioSpec)
local ConstructGeometrySpec = require(script.Parent.MagicConstructGeometrySpec)
local ConstructGrowthSpec = require(script.Parent.MagicConstructGrowthSpec)
local VisualSpec = require(script.Parent.MagicVisualSpec)
local AreaSpec = require(script.Parent.MagicAreaSpec)
local SummonLimits = require(script.Parent.Parent.Configuration.MagicSummons)
local LocusRequirementSpec = require(script.Parent.MagicLocusRequirementSpec)
local EnvironmentRequirementSpec = require(script.Parent.MagicEnvironmentRequirementSpec)
local SpecialResourceSpec = require(script.Parent.MagicSpecialResourceSpec)
local SpecialResources = require(script.Parent.Parent.Configuration.MagicLocus).SpecialResources
local SpellIdentitySpec = require(script.Parent.MagicSpellIdentitySpec)
local TriggerSpec = require(script.Parent.MagicTriggerSpec)
local AttributeSpec = require(script.Parent.MagicAttributeSpec)
local ScaleSpec = require(script.Parent.MagicScaleSpec)
local BloodCostSpec = require(script.Parent.MagicBloodCostSpec)
local Spec = {}
Spec.Principles = Schema.Principles
Spec.PresentationProfiles = Schema.PresentationProfiles
Spec.Elements = Schema.Elements
Spec.Forms = Schema.FormOrder
Spec.Events = {}
for form, definition in Schema.Forms do
	Spec.Events[form] = definition.Events
end
Spec.Schema = Schema
function Spec.copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for k, v in pairs(value) do
		result[k] = Spec.copy(v)
	end
	return result
end
function Spec.normalize(source)
	local d = Spec.copy(source)
	d.Version = 3
	d.Geometry = d.Geometry or (Schema.Forms[d.Form] and Schema.Forms[d.Form].Geometry)
	d.Element = d.Element or Schema.defaultElementForExpression(d.Source.Expression)
	d.Visual = d.Visual or { Color = Color3.fromRGB(180, 230, 255) }
	d.Visual.ProjectileScale = d.Visual.ProjectileScale or 1
	if d.Construct then
		d.Construct.Components = d.Construct.Components or {}
	end
	-- Interception charges follow the Before damage taken steps.
	local interceptSteps = d.Triggers and d.Triggers.OnBeforeDamageTaken
	if type(interceptSteps) == "table" and #interceptSteps > 0 then
		d.Interception = d.Interception or { Charges = 1 }
	else
		d.Interception = nil
	end
	d.Audio = d.Audio or Spec.copy(AudioSpec.Defaults)
	d.Cost = d.Cost or { ManaDemand = 0, Strain = 0, Complexity = 0 }
	d.Cost.SpecialResources = d.Cost.SpecialResources or {}
	d.Conditions = d.Conditions or {}
	d.LocusRequirements = d.LocusRequirements or {}
	d.EnvironmentRequirements = d.EnvironmentRequirements or {}
	d.TargetRules = d.TargetRules
		or {
			Range = (d.Beam and d.Beam.Range) or (d.Wave and d.Wave.Range) or 90,
			MaxTargets = 16,
			RequiresLineOfSight = true,
		}
	d.TargetRules.IncludeCaster = d.TargetRules.IncludeCaster or false
	d.TargetRules.Relationship = d.TargetRules.Relationship or "Any"
	d.TargetRules.RequiresConsent = d.TargetRules.RequiresConsent == true
	if d.Targeting == "EntityTarget" then
		d.TargetPolicy = d.TargetPolicy or "Aim"
	end
	d.Casting.CastTime = d.Casting.CastTime or 0
	d.Casting.RecoveryTime = d.Casting.RecoveryTime or 0
	d.Casting.InterruptOnDamage = d.Casting.InterruptOnDamage == true
	d.Casting.InterruptMoveDistance = d.Casting.InterruptMoveDistance or 0
	d.Casting.CanMoveWhileCasting = d.Casting.CanMoveWhileCasting ~= false
	d.Casting.MovementPenalty = d.Casting.MovementPenalty or 0
	d.Casting.CanRotateWhileCasting = d.Casting.CanRotateWhileCasting ~= false
	d.Casting.RequiresFreeHand = d.Casting.RequiresFreeHand == true
	if d.Projectile then
		d.Projectile.MaxDistance = d.Projectile.MaxDistance or d.Projectile.Speed * d.Lifetime.Duration
		d.Projectile.Gravity = d.Projectile.Gravity or 0
		d.Projectile.Acceleration = d.Projectile.Acceleration or 0
		d.Projectile.Behaviors = d.Projectile.Behaviors or {}
		d.Projectile.MotionPhases = d.Projectile.MotionPhases or {}
	end
	if d.Beam then
		d.Beam.Width = d.Beam.Width or 0
		d.Beam.Interval = d.Beam.Interval or 0.15
		d.Beam.Pattern = d.Beam.Pattern or "Single"
		d.Beam.StrikeCount = d.Beam.StrikeCount or 5
		d.Beam.SpreadRadius = d.Beam.SpreadRadius or 12
		d.Beam.DropHeight = d.Beam.DropHeight or 36
		d.Beam.StrikeInterval = d.Beam.StrikeInterval or 0.18
	end
	if d.Field then
		d.Field.Yaw = d.Field.Yaw or 0
	end
	if d.Aura then
		d.Aura.Yaw = d.Aura.Yaw or 0
	end
	local triggers = TriggerSpec.normalize(d.Triggers)
	if d.Wave then
		triggers.OnCast = triggers.OnCast or { { Payloads = d.Wave.Payloads } }
		d.Wave.Payloads = nil
	end
	d.Triggers = triggers
	return d
end
function Spec.createDraft(formName: string, principle: string)
	local form = Schema.Forms[formName]
	if not form or not Schema.supportsPrincipleForm(principle, formName) then
		return nil
	end
	local draft = {
		SpellId = "MagicLabDraft",
		Name = "Untitled Spell",
		Version = 3,
		Tags = {},
		Source = {
			Principle = principle,
			Expression = Schema.defaultExpression(principle),
		},
		Form = formName,
		Targeting = form.Draft.Targeting,
		-- Forms that start aimed at a character (Tether) start with the usual policy.
		TargetPolicy = if form.Draft.Targeting == "EntityTarget" then "Aim" else nil,
		Geometry = form.Geometry,
		Motion = form.Motion,
		Casting = {
			Mode = "Instant",
			Cooldown = 0.6,
			CastTime = 0,
			RecoveryTime = 0,
			InterruptOnDamage = false,
			InterruptMoveDistance = 0,
			CanMoveWhileCasting = true,
			MovementPenalty = 0,
			CanRotateWhileCasting = true,
			RequiresFreeHand = false,
		},
		Lifetime = Spec.copy(form.Draft.Lifetime),
		Cost = { ManaDemand = 0, Strain = 0, Complexity = 0, SpecialResources = {} },
		Visual = Spec.copy(VisualSpec.Defaults),
		Audio = Spec.copy(AudioSpec.Defaults),
		Element = "Neutral",
		Conditions = {},
		LocusRequirements = {},
		EnvironmentRequirements = {},
		TargetRules = {
			Range = 90,
			MaxTargets = 16,
			RequiresLineOfSight = true,
			IncludeCaster = false,
			Relationship = "Any",
			RequiresConsent = false,
		},
		Triggers = {},
	}
	local mechanics = Spec.copy(form.Draft.Mechanics)
	if next(mechanics) then
		draft[formName] = mechanics
	end
	if formName == "Projectile" then
		draft.Projectile.Behaviors = {}
		draft.Projectile.MotionPhases = {}
	end
	if ProximitySpec.SupportedForms[formName] then
		draft.Proximity = Spec.copy(ProximitySpec.Defaults)
	end
	if draft.Targeting == "MaterialTarget" or draft.Targeting == "ObjectTarget" then
		if draft.Targeting == "ObjectTarget" and formName == "Manipulation" then
			draft.Material = { SearchRadius = 12 }
		elseif
			draft.Targeting == "ObjectTarget"
			and (formName == "Projectile" or formName == "Beam" or formName == "Wave")
		then
			draft.Material = nil
		else
			draft.Material = Spec.copy(form.Draft.Material or { Material = "Earth", Amount = 1, SearchRadius = 12 })
			if formName ~= "Manipulation" then
				draft.Material.Amount = draft.Material.Amount or 1
			end
		end
	end
	return draft
end
local function finite(v)
	return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end
local function bounded(v, lo, hi)
	return finite(v) and v >= lo and v <= hi
end
local function keys(t, allowed)
	if type(t) ~= "table" then
		return false
	end
	for k in pairs(t) do
		if not allowed[k] then
			return false
		end
	end
	return true
end
local function array(t, max)
	if type(t) ~= "table" then
		return false
	end
	local count = 0
	for k in pairs(t) do
		if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > max then
			return false
		end
		count = count + 1
	end
	return count == #t and count <= max
end
local function safeTree(v, depth, budget)
	budget[1] = budget[1] + 1
	-- Sized for a spell plus Limits.MaxSpawnNesting levels of compact
	-- spawned effects (each level adds about seven table levels).
	if budget[1] > 700 or depth > 18 then
		return false
	end
	if type(v) == "table" then
		for k, x in pairs(v) do
			if
				(type(k) ~= "string" and type(k) ~= "number")
				or (type(k) == "string" and #k > 64)
				or not safeTree(x, depth + 1, budget)
			then
				return false
			end
		end
	elseif type(v) == "number" then
		return finite(v)
	elseif type(v) == "string" then
		return #v <= 100
	elseif type(v) ~= "boolean" and typeof(v) ~= "Color3" then
		return false
	end
	return true
end

local function hasPayload(d, kind)
	if type(d.Triggers) ~= "table" then
		return false
	end
	for _, steps in pairs(d.Triggers) do
		if type(steps) == "table" then
			for _, step in ipairs(steps) do
				if type(step) == "table" and type(step.Payloads) == "table" then
					for _, payload in ipairs(step.Payloads) do
						if type(payload) == "table" and payload.Kind == kind then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

local function hasOnlyObjectInteractionPayloads(d)
	if d.Form == "Projectile" and #(d.Projectile.Behaviors or {}) > 0 then
		return false
	end
	if type(d.Triggers) ~= "table" then
		return false
	end
	local count = 0
	local effectiveCount = 0
	for event, steps in pairs(d.Triggers) do
		local runtimeEvent = if event == "OnInterval" then "OnTick" else event
		if type(steps) ~= "table" then
			return false
		end
		for _, step in ipairs(steps) do
			if type(step) ~= "table" or step.Behavior ~= nil or type(step.Payloads) ~= "table" then
				return false
			end
			for _, payload in ipairs(step.Payloads) do
				local definition = type(payload) == "table" and Schema.Payloads[payload.Kind]
				-- Target-independent payloads (Summon) may run on timings that
				-- never resolve the object, matching Schema.eventsForEffects.
				local targetIndependent = definition
					and definition.TargetIndependent == true
					and Schema.TargetIndependentEvents[runtimeEvent] == true
				if
					type(payload) ~= "table"
					or (
						not targetIndependent
						and payload.Kind ~= "Force"
						and payload.Kind ~= "Control"
						and payload.Kind ~= "Manipulation"
					)
				then
					return false
				end
				count += 1
				if
					targetIndependent
					or (d.Form == "Manipulation" and runtimeEvent == "OnCast")
					or (d.Form == "Projectile" and runtimeEvent == "OnImpact")
					or ((d.Form == "Beam" or d.Form == "Wave") and runtimeEvent == "OnCast")
					or (
						(d.Form == "Beam" or d.Form == "Wave")
						and d.Casting.Mode == "Channeled"
						and runtimeEvent == "OnTick"
					)
				then
					effectiveCount += 1
				end
			end
		end
	end
	return count > 0 and effectiveCount > 0
end

-- Spawned effects ----------------------------------------------------------
-- A SpawnEffect step carries a compact effect: its Form, that Form's settings,
-- a lifetime, and its own triggers. The server expands it into a full spell
-- definition from a fresh draft, inheriting the parent's Principle, Element,
-- presentation, and target relationship, then validates that recursively.
-- Manipulation is excluded: it needs a specific selected object, which an
-- event point does not provide.
Spec.SpawnForms = { "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement" }
local spawnEffectKeys = {
	Form = true,
	Geometry = true,
	Lifetime = true,
	Triggers = true,
	Element = true, -- optional override (e.g. a burning Field from a Wind spell)
}
for _, formName in Spec.SpawnForms do
	spawnEffectKeys[formName] = true
end

-- A valid starting effect for `formName`: Damage where the Form and Principle
-- support it at the default timing, otherwise the first supported payload.
function Spec.defaultSpawnEffect(formName: string, principle: string?)
	local form = Schema.Forms[formName]
	if not form or not table.find(Spec.SpawnForms, formName) then
		return nil
	end
	principle = principle or "Energy"
	-- Constructs have no default timing; their effects resolve on approach.
	local event = form.DefaultEvent or "OnProximity"
	local kind = if Schema.supportsPayload("Damage", formName, event, principle) then "Damage" else nil
	if not kind then
		for _, candidate in Schema.PayloadOrder do
			if candidate ~= "Summon" and Schema.supportsPayload(candidate, formName, event, principle) then
				kind = candidate
				break
			end
		end
	end
	local effect = {
		Form = formName,
		Geometry = form.Geometry,
		Lifetime = Spec.copy(form.Draft.Lifetime),
		Triggers = {},
	}
	if kind then
		local first = Spec.copy(Schema.Payloads[kind].Defaults or {})
		first.Kind = kind
		effect.Triggers[event] = { { Payloads = { first } } }
	end
	if form.Draft.Mechanics and next(form.Draft.Mechanics) then
		effect[formName] = Spec.copy(form.Draft.Mechanics)
	end
	if formName == "Projectile" then
		effect.Projectile.Behaviors = {}
		effect.Projectile.MotionPhases = {}
	end
	return effect
end

function Spec.expandSpawnEffect(parent, effect)
	if type(effect) ~= "table" or not table.find(Spec.SpawnForms, effect.Form) then
		return nil, "Spawned effects must be a Projectile, Field, or Wave"
	end
	if not keys(effect, spawnEffectKeys) then
		return nil, "Spawned effect has unsupported settings"
	end
	for _, formName in Spec.SpawnForms do
		if effect[formName] ~= nil and formName ~= effect.Form then
			return nil, "Spawned effect settings must match its Form"
		end
	end
	if
		type(parent) ~= "table"
		or type(parent.Source) ~= "table"
		or type(parent.Visual) ~= "table"
		or type(parent.TargetRules) ~= "table"
	then
		return nil, "Spawned effects need a valid parent spell"
	end
	local child = Spec.createDraft(effect.Form, parent.Source.Principle)
	if not child then
		return nil, "This Principle cannot spawn a " .. tostring(effect.Form)
	end
	child.SpellId = string.sub(tostring(parent.SpellId), 1, 56) .. "Spawned"
	child.Name = parent.Name
	child.Tags = Spec.copy(parent.Tags or {})
	child.Source = Spec.copy(parent.Source)
	if effect.Element ~= nil and not AttributeSpec.validElement(effect.Element) then
		return nil, "Spawned effect has an unknown element"
	end
	child.Element = effect.Element or parent.Element
	child.Visual = Spec.copy(parent.Visual)
	if type(parent.Audio) == "table" then
		child.Audio = Spec.copy(parent.Audio)
	end
	if effect.Geometry ~= nil then
		child.Geometry = effect.Geometry
	end
	if type(effect[effect.Form]) == "table" then
		for key, value in pairs(effect[effect.Form]) do
			child[effect.Form][key] = Spec.copy(value)
		end
	end
	if effect.Lifetime ~= nil then
		child.Lifetime = Spec.copy(effect.Lifetime)
	end
	child.Triggers = Spec.copy(effect.Triggers or {})
	child.TargetRules.Relationship = parent.TargetRules.Relationship
	child.TargetRules.RequiresConsent = parent.TargetRules.RequiresConsent
	child.TargetRules.RequiresLineOfSight = parent.TargetRules.RequiresLineOfSight
	return Spec.normalize(child)
end

local function validateSpawnStep(d, step, spawnNesting: number): (boolean, string?)
	if spawnNesting >= Limits.MaxSpawnNesting then
		return false, "Spawned effects can only nest " .. tostring(Limits.MaxSpawnNesting) .. " levels deep"
	end
	local child, reason = Spec.expandSpawnEffect(d, step.Effect)
	if not child then
		return false, reason
	end
	if child.Lifetime.Mode ~= "FixedDuration" and child.Lifetime.Mode ~= "Instantaneous" then
		return false, "Spawned effects need a fixed or instantaneous lifetime"
	end
	if child.Form == "Field" and child.Field.FollowTarget then
		return false, "Spawned Fields stay where they start"
	end
	if hasPayload(child, "Summon") then
		return false, "Spawned effects cannot summon"
	end
	if (step.Count or 1) > 1 and child.Form ~= "Projectile" then
		return false, "Only spawned Projectiles can spawn more than one"
	end
	local valid, childReason = Spec.validate(child, spawnNesting + 1)
	if not valid then
		return false, "Spawned " .. child.Form .. ": " .. tostring(childReason)
	end
	return true
end

-- spawnNesting is internal: how many SpawnEffect levels enclose `d`.
function Spec.validate(d, spawnNesting: number?)
	if not safeTree(d, 0, { 0 }) then
		return false, "Malformed or oversized SpellSpec"
	end
	if
		not keys(d, {
			SpellId = true,
			Name = true,
			Version = true,
			Tags = true,
			Source = true,
			Form = true,
			Targeting = true,
			TargetPolicy = true,
			Geometry = true,
			Motion = true,
			Casting = true,
			Lifetime = true,
			Cost = true,
			LocusRequirements = true,
			EnvironmentRequirements = true,
			Visual = true,
			Audio = true,
			Element = true,
			Triggers = true,
			Conditions = true,
			TargetRules = true,
			Projectile = true,
			Aura = true,
			Construct = true,
			Beam = true,
			Field = true,
			Wave = true,
			Rush = true,
			Tether = true,
			Interception = true,
			Material = true,
			Proximity = true,
		})
	then
		return false, "Unknown SpellSpec field"
	end
	if type(d.SpellId) ~= "string" then
		return false, "Missing spell identity"
	end
	local nameValid, nameReason = SpellIdentitySpec.validateName(d.Name)
	if not nameValid then
		return false, nameReason
	end
	if not keys(d.Source, { Principle = true, Expression = true }) then
		return false, "Invalid source"
	end
	if d.Version ~= 3 or type(d.Source.Expression) ~= "string" or not array(d.Tags, SpellIdentitySpec.MaxTags) then
		return false, "Invalid version, expression, or tags"
	end
	local validTags, tagReason = SpellIdentitySpec.validateTags(d.Tags)
	if not validTags then
		return false, tagReason
	end
	local elementKnown = false
	for _, element in ipairs(Spec.Elements) do
		if d.Element == element then
			elementKnown = true
		end
	end
	if not elementKnown then
		return false, "Unknown element"
	end
	local known = false
	for _, p in ipairs(Spec.Principles) do
		if d.Source.Principle == p then
			known = true
		end
	end
	if not known then
		return false, "Unknown Principle"
	end
	if not Schema.expressionMatches(d.Source.Principle, d.Source.Expression) then
		return false, "UNSUPPORTED expression for " .. d.Source.Principle
	end
	if not Spec.Events[d.Form] then
		return false, "UNSUPPORTED Form: " .. tostring(d.Form)
	end
	local principle = d.Source.Principle
	if not Schema.supportsPrincipleForm(principle, d.Form) then
		return false, "UNSUPPORTED Body/Form combination"
	end
	-- Which Principles may use SelfEnhancement is owned by MagicPrincipleSpec
	-- (checked above). An Enchantment sits on its caster (Self) or on an aimed
	-- character (EntityTarget), its holder.
	if d.Form == "SelfEnhancement" then
		if d.Targeting ~= "Self" and d.Targeting ~= "EntityTarget" then
			return false, "An Enchantment targets yourself or an aimed character"
		end
		if d.Targeting == "EntityTarget" then
			if d.TargetPolicy == "MaintainTarget" then
				return false, "Enchantments use Aim, LockOn or AimOrLockOn to choose their holder"
			end
			if d.Casting and d.Casting.Mode == "Channeled" then
				return false, "Channeled Enchantments can only be held on yourself"
			end
			if hasPayload(d, "AerialMovement") then
				return false, "Aerial movement only works on yourself"
			end
		end
	end
	if d.Form == "Manipulation" and d.Source.Expression ~= "Earth" then
		return false, "UNSUPPORTED Manipulation expression: Earth is required for current material interaction"
	end
	if
		d.Form == "Manipulation"
		and (principle ~= "Matter" or (d.Targeting ~= "MaterialTarget" and d.Targeting ~= "ObjectTarget"))
	then
		return false, "Manipulation requires Matter and a material or object target"
	end
	local formSchema = Schema.Forms[d.Form]
	local geometrySupported = d.Geometry == formSchema.Geometry
	for _, option in ipairs(formSchema.GeometryOptions or {}) do
		if option == d.Geometry then
			geometrySupported = true
			break
		end
	end
	if not geometrySupported or d.Motion ~= formSchema.Motion then
		return false, "Geometry or Motion does not match Form"
	end
	if not formSchema.Targeting[d.Targeting] then
		return false, "Unsupported targeting mode for Form"
	end
	if d.Targeting == "EntityTarget" then
		local policyKnown = false
		for _, policy in ipairs(Schema.TargetPolicyOrder) do
			if d.TargetPolicy == policy then
				policyKnown = true
				break
			end
		end
		if not policyKnown then
			return false, "Unsupported entity target policy"
		end
		if d.TargetPolicy == "MaintainTarget" then
			local hasHoming = false
			local behaviors = if d.Projectile and type(d.Projectile.Behaviors) == "table"
				then d.Projectile.Behaviors
				else {}
			for _, behavior in ipairs(behaviors) do
				if type(behavior) == "table" and behavior.Kind == "Homing" then
					hasHoming = true
					break
				end
			end
			if not hasHoming then
				return false, "Maintain target requires a homing Projectile"
			end
		end
	elseif d.TargetPolicy ~= nil then
		return false, "Target policy requires EntityTarget"
	end
	for _, f in ipairs({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "Rush", "Tether" }) do
		if d[f] and f ~= d.Form then
			return false, f .. " mechanics do not apply to " .. d.Form
		end
	end
	-- Interception (OnBeforeDamageTaken): charges are required with its steps.
	local interceptSteps = d.Triggers and d.Triggers.OnBeforeDamageTaken
	local intercepts = type(interceptSteps) == "table" and #interceptSteps > 0
	if d.Interception ~= nil or intercepts then
		local interception = d.Interception
		if
			not intercepts
			or type(interception) ~= "table"
			or not keys(interception, { Charges = true, EndWhenSpent = true })
			or not bounded(interception.Charges, 1, Limits.MaxInterceptionCharges)
			or interception.Charges % 1 ~= 0
			or (interception.EndWhenSpent ~= nil and type(interception.EndWhenSpent) ~= "boolean")
		then
			return false, "Before damage taken needs Interception charges (1-" .. Limits.MaxInterceptionCharges .. ")"
		end
	end
	local c = d.Casting
	if
		not keys(c, {
			Mode = true,
			Cooldown = true,
			CastTime = true,
			RecoveryTime = true,
			MinimumCharge = true,
			MaximumCharge = true,
			ChargeScaling = true,
			ManaUpkeepPerSecond = true,
			StrainPerSecond = true,
			InterruptOnDamage = true,
			InterruptMoveDistance = true,
			CanMoveWhileCasting = true,
			MovementPenalty = true,
			CanRotateWhileCasting = true,
			RequiresFreeHand = true,
			MaxRecasts = true,
		})
		or not bounded(c.Cooldown, Limits.MinCooldown, 30)
		or not bounded(c.CastTime, 0, 3)
		or not bounded(c.RecoveryTime, 0, 3)
	then
		return false, "Invalid casting timing (cooldown minimum 0.15s)"
	end
	-- Recast: pressing the slot again while the effect is active runs OnRecast.
	local recastSteps = d.Triggers and d.Triggers.OnRecast
	local hasRecast = type(recastSteps) == "table" and #recastSteps > 0
	if c.MaxRecasts ~= nil and (not bounded(c.MaxRecasts, 1, Limits.MaxRecasts) or c.MaxRecasts % 1 ~= 0) then
		return false, "Recasts must be a whole number from 1 to " .. Limits.MaxRecasts
	end
	if hasRecast then
		if CastingSpec.isHeldMode(c.Mode) then
			return false, "Held spells end when released; they cannot be recast"
		end
		if d.Lifetime and d.Lifetime.Mode == "UntilToggledOff" then
			return false, "Pressing a toggled spell again turns it off; it cannot also recast"
		end
	end
	if
		(c.InterruptOnDamage ~= nil and type(c.InterruptOnDamage) ~= "boolean")
		or (c.InterruptMoveDistance ~= nil and not bounded(c.InterruptMoveDistance, 0, 20))
		or (c.CanMoveWhileCasting ~= nil and type(c.CanMoveWhileCasting) ~= "boolean")
		or (c.MovementPenalty ~= nil and not bounded(c.MovementPenalty, 0, Limits.MaxCastingMovementPenalty))
		or (c.CanRotateWhileCasting ~= nil and type(c.CanRotateWhileCasting) ~= "boolean")
		or (c.RequiresFreeHand ~= nil and type(c.RequiresFreeHand) ~= "boolean")
	then
		return false, "Invalid casting movement or interruption rules"
	end
	if
		c.Mode ~= "Instant"
		and c.Mode ~= "Charged"
		and c.Mode ~= "HoldAndRelease"
		and c.Mode ~= "Channeled"
		and c.Mode ~= "Toggle"
		and c.Mode ~= "CommandCast"
		and c.Mode ~= "Sustained"
	then
		return false, "Unsupported casting mode"
	end
	if c.Mode == "Toggle" and (not CastingSpec.supportsToggle(d.Form) or d.Lifetime.Mode ~= "UntilToggledOff") then
		return false, "Toggle casting requires a Form that supports UntilToggledOff lifetime"
	end
	if c.Mode == "CommandCast" and not CastingSpec.supportsCommandCast(d.Form) then
		return false, "CommandCast requires a Projectile, Beam, Wave, Field, or Aura assigned to a summon"
	end
	if c.Mode == "Sustained" and not CastingSpec.supportsSustained(d.Form) then
		return false, "Sustained casting requires a Construct that can be maintained while held"
	end
	if
		CastingSpec.isChargeMode(c.Mode)
		and (not bounded(c.MinimumCharge, 0.05, 3) or not bounded(c.MaximumCharge, c.MinimumCharge, 3))
	then
		return false, "Invalid charge time"
	end
	if not CastingSpec.isChargeMode(c.Mode) and (c.MinimumCharge ~= nil or c.MaximumCharge ~= nil) then
		return false, "Charge timing is only valid for Charged or HoldAndRelease casting"
	end
	local chargeScalingOk, chargeScalingReason =
		ScaleSpec.validateChargeScaling(c.ChargeScaling, CastingSpec.isChargeMode(c.Mode), d.Form, Limits.MaxSpawnCount)
	if not chargeScalingOk then
		return false, chargeScalingReason
	end
	if c.Mode == "Channeled" or c.Mode == "Sustained" then
		if
			(c.Mode == "Channeled" and not CastingSpec.supportsChannel(d.Form))
			or (c.Mode == "Sustained" and not CastingSpec.supportsSustained(d.Form))
			or not bounded(c.ManaUpkeepPerSecond, 0.01, Limits.MaxManaUpkeepPerSecond)
		then
			return false, "Held casting requires a supported Form and positive mana upkeep"
		end
	elseif c.ManaUpkeepPerSecond ~= nil and not bounded(c.ManaUpkeepPerSecond, 0, Limits.MaxManaUpkeepPerSecond) then
		return false, "Ongoing mana upkeep must be 0–100 per second"
	end
	if c.StrainPerSecond ~= nil and not bounded(c.StrainPerSecond, 0, Limits.MaxStrainPerSecond) then
		return false, "Ongoing strain must be 0–100 per second"
	end
	local life = d.Lifetime
	if not keys(life, { Mode = true, Duration = true, EndWhen = true }) then
		return false, "Invalid lifetime"
	end
	if not LifetimeSpec.supports(d.Form, life.Mode) then
		return false, "Unsupported lifetime mode for this Form"
	elseif
		not LifetimeSpec.supportsTargeting(
			d.Form,
			life.Mode,
			d.Targeting,
			d.Form == "Field" and type(d.Field) == "table" and d.Field.FollowTarget == true,
			d.TargetPolicy == "MaintainTarget"
		)
	then
		return false, "UntilTargetLost requires an entity or object target"
	elseif
		life.Mode == "UntilResourceDepleted"
		and not bounded(c.ManaUpkeepPerSecond, 0.01, Limits.MaxManaUpkeepPerSecond)
	then
		return false, "UntilResourceDepleted requires positive ongoing mana upkeep"
	elseif
		CastingSpec.isHeldMode(c.Mode)
		and life.Mode ~= "FixedDuration"
		and not (c.Mode == "Channeled" and life.Mode == "UntilConditionFails" and life.Duration ~= nil)
	then
		return false, "Held effects require a fixed maximum duration or a bounded keep-alive condition"
	elseif
		d.Form == "Beam"
		and life.Mode ~= (if c.Mode == "Channeled" then "FixedDuration" else "Instantaneous")
		and not (c.Mode == "Channeled" and life.Mode == "UntilConditionFails")
	then
		return false, "Instant Beams are instantaneous; Channeled Beams need a bounded active lifetime"
	elseif
		d.Form == "Wave"
		and life.Mode ~= (if c.Mode == "Channeled" then "FixedDuration" else "Instantaneous")
		and not (c.Mode == "Channeled" and life.Mode == "UntilConditionFails")
	then
		return false, "Instant Waves resolve once; Channeled Waves need a bounded active lifetime"
	elseif life.Mode == "FixedDuration" then
		if not bounded(life.Duration, 0.1, Limits.MaxDuration) then
			return false, "Duration exceeds development safety limit"
		end
	end
	if life.Mode == "Persistent" then
		if
			d.Form ~= "Construct"
			or c.Mode ~= "Instant"
			or life.Duration ~= nil
			or life.EndWhen ~= nil
			or (c.ManaUpkeepPerSecond or 0) > 0
			or (c.StrainPerSecond or 0) > 0
			-- Proximity settings are inert without an OnProximity trigger, and
			-- the trigger check below already forbids every trigger.
			or (d.Construct and d.Construct.GrowthDuration ~= nil and d.Construct.GrowthDuration > 0)
			or next(d.Triggers) ~= nil
		then
			return false,
				"Persistent Constructs must be static Instant placements without upkeep, active triggers, or timed end rules"
		end
	end
	if life.EndWhen ~= nil then
		if life.Mode == "Instantaneous" then
			return false, "Lifetime end conditions require an active Form lifetime"
		end
		local validEndWhen, endWhenReason =
			ConditionSpec.validateForFamilies(life.EndWhen, ConditionSpec.EndConditionFamilies)
		if not validEndWhen then
			return false, endWhenReason
		end
	end
	if life.Mode == "UntilConditionFails" and life.EndWhen == nil then
		return false, "UntilConditionFails requires a condition to remain true while the effect is active"
	end
	if
		life.Mode == "UntilConditionFails"
		and not LifetimeSpec.validConditionDuration(d.Form, life.Duration, Limits.MaxDuration)
	then
		return false, "Condition-bound effects need a valid optional maximum duration; Projectiles require one"
	end
	if life.Mode == "UntilConditionFails" and CastingSpec.isHeldMode(c.Mode) and life.Duration == nil then
		return false, "Condition-bound channels require a bounded maximum duration"
	end
	if life.Mode == "UntilConditionFails" and d.Form == "Projectile" then
		if not bounded(life.Duration, 0.1, Limits.MaxDuration) then
			return false, "Condition-bound Projectiles require a bounded maximum flight time"
		end
	end
	if life.Mode == "Instantaneous" and ((c.ManaUpkeepPerSecond or 0) > 0 or (c.StrainPerSecond or 0) > 0) then
		return false, "Ongoing resource upkeep requires an active lifetime"
	end
	local rules = d.TargetRules
	if
		not keys(rules, {
			Range = true,
			MaxTargets = true,
			RequiresLineOfSight = true,
			IncludeCaster = true,
			Relationship = true,
			RequiresConsent = true,
		})
		or not bounded(rules.Range, 1, Limits.MaxRange)
		or not bounded(rules.MaxTargets, 1, Limits.MaxTargets)
		or rules.MaxTargets % 1 ~= 0
		or type(rules.RequiresLineOfSight) ~= "boolean"
		or type(rules.IncludeCaster) ~= "boolean"
		or type(rules.RequiresConsent) ~= "boolean"
		or not table.find(Schema.TargetRelationshipOrder, rules.Relationship)
	then
		return false, "Invalid targeting limits"
	end
	if
		d.Form == "Wave"
		-- Incomplete growth settings are rejected by the Wave growth check below.
		and type(d.Wave.GrowthStartScale) == "number"
		and type(d.Wave.GrowthEndScale) == "number"
		and d.Wave.Range * math.max(d.Wave.GrowthStartScale, d.Wave.GrowthEndScale) > rules.Range
	then
		return false, "Expanded Wave reach cannot exceed its targeting maximum range"
	end
	if
		d.Form == "Beam"
		-- Incomplete growth settings are rejected by the Beam growth check below.
		and type(d.Beam.GrowthStartScale) == "number"
		and type(d.Beam.GrowthEndScale) == "number"
		and d.Beam.Range * math.max(d.Beam.GrowthStartScale, d.Beam.GrowthEndScale) > rules.Range
	then
		return false, "Expanded Beam reach cannot exceed its targeting maximum range"
	end
	local conditionsValid, conditionsReason = ConditionSpec.validate(d.Conditions)
	if not conditionsValid then
		return false, conditionsReason
	end
	if d.Conditions.Operator == nil then
		for _, condition in ipairs(d.Conditions) do
			local definition
			for _, candidate in Schema.Conditions do
				if candidate.Id == condition then
					definition = candidate
					break
				end
			end
			if not definition and condition ~= "TargetIsHumanoid" then
				return false, "UNSUPPORTED condition: " .. tostring(condition)
			end
			if definition and not definition.Forms[d.Form] then
				return false, "Condition is not supported for this Form: " .. tostring(condition)
			end
			if condition == "TargetIsSelf" and d.Form ~= "SelfEnhancement" then
				return false, "TargetIsSelf requires SelfEnhancement"
			end
		end
	end
	if d.Form == "Aura" then
		local validArea, areaReason =
			AreaSpec.validate("Aura", d.Geometry, d.Aura, Limits.MaxRadius, Limits.MinInterval)
		if not validArea then
			return false, areaReason
		end
	elseif d.Form == "Construct" then
		if
			not keys(d.Construct, {
				Width = true,
				Height = true,
				Depth = true,
				Distance = true,
				GrowthStartScale = true,
				GrowthEndScale = true,
				GrowthDuration = true,
				Components = true,
				Interval = true,
				Health = true,
			})
		then
			return false, "Invalid Construct"
		end
		local pulses = (d.Triggers.OnTick and #d.Triggers.OnTick > 0)
			or (d.Triggers.OnInterval and #d.Triggers.OnInterval > 0)
		if
			d.Construct.Interval ~= nil
			and not bounded(d.Construct.Interval, Limits.MinInterval, Limits.MaxConstructInterval)
		then
			return false,
				"Construct pulse interval must be "
					.. Limits.MinInterval
					.. "–"
					.. Limits.MaxConstructInterval
					.. " seconds"
		end
		if pulses and d.Construct.Interval == nil then
			return false, "Set the Construct's pulse interval to use On each pulse"
		end
		if d.Construct.Health ~= nil and not bounded(d.Construct.Health, 1, Limits.MaxConstructHealth) then
			return false, "Construct health must be 1–" .. Limits.MaxConstructHealth
		end
		if d.Triggers.OnDestroyed and #d.Triggers.OnDestroyed > 0 and d.Construct.Health == nil then
			return false, "Give the Construct health to use On destroyed"
		end
		for _, axis in ipairs({ "Width", "Height", "Depth" }) do
			if not bounded(d.Construct[axis], 0.5, 20) then
				return false, "Construct dimensions must be 0.5–20 studs"
			end
		end
		if not bounded(d.Construct.Distance, 4, 40) then
			return false, "Construct distance must be 4–40 studs"
		end
		if d.Construct.Width * d.Construct.Height * d.Construct.Depth > 2000 then
			return false, "Construct volume exceeds 2000 cubic studs"
		end
		local validConstructGrowth, growthReason = ConstructGrowthSpec.validate(d.Construct)
		if not validConstructGrowth then
			return false, growthReason
		end
		if d.Geometry ~= "Custom" and d.Construct.Components and next(d.Construct.Components) then
			return false, "Custom component data requires Custom Construct geometry"
		end
		local components = ConstructGeometrySpec.components(
			d.Geometry,
			d.Construct.Width,
			d.Construct.Height,
			d.Construct.Depth,
			d.Construct.Components
		)
		if not components or #components > 5 then
			return false, "Construct geometry is missing or exceeds the component limit"
		end
		if life.Mode == "Persistent" then
			for _, component in ipairs(components) do
				if component.Duration ~= nil then
					return false, "Persistent Constructs cannot contain expiring components"
				end
			end
		end
	elseif d.Form == "Projectile" then
		local p = d.Projectile
		if
			not keys(p, {
				Speed = true,
				Radius = true,
				MaxDistance = true,
				Gravity = true,
				Acceleration = true,
				ChannelInterval = true,
				Behaviors = true,
				MotionPhases = true,
			})
			or not bounded(p.Speed, 1, Limits.MaxSpeed)
			or not bounded(p.Radius, 0.1, Limits.MaxRadius)
			or not bounded(p.MaxDistance, 1, Limits.MaxRange)
			or not bounded(p.Gravity, 0, Limits.MaxGravity)
			or not bounded(p.Acceleration, -Limits.MaxAcceleration, Limits.MaxAcceleration)
			or (p.ChannelInterval ~= nil and not bounded(p.ChannelInterval, Limits.MinInterval, 1))
		then
			return false, "Invalid projectile speed/radius/distance/gravity/acceleration safety limit"
		end
		if not array(p.Behaviors, Limits.MaxProjectileBehaviors) then
			return false, "Projectile supports at most three composed behaviors"
		end
		local validMotion, motionReason = ProjectileMotion.validate(p.MotionPhases or {}, d.Lifetime.Duration, p.Radius)
		if not validMotion then
			return false, motionReason
		end
		local behaviorKinds = {}
		for _, behavior in ipairs(p.Behaviors) do
			if type(behavior) ~= "table" or type(behavior.Kind) ~= "string" or behaviorKinds[behavior.Kind] then
				return false, "Invalid or duplicate projectile behavior"
			end
			behaviorKinds[behavior.Kind] = true
			local validBehavior, behaviorReason = ProjectileBehaviorSpec.validate(behavior)
			if not validBehavior then
				return false, behaviorReason
			end
			if behavior.Kind == "Return" and behavior.ReturnAtDistance > p.MaxDistance then
				return false, "Return distance cannot exceed projectile maximum distance"
			end
		end
		for _, phase in ipairs(p.MotionPhases or {}) do
			if phase.Mode == "Attached" and not behaviorKinds.Linger then
				return false, "Attached motion requires the Linger projectile behavior"
			end
		end
		if behaviorKinds.Linger and (behaviorKinds.Bounce or behaviorKinds.Pierce or behaviorKinds.Split) then
			return false, "Linger cannot combine with Bounce, Pierce, or Split impact behavior"
		end
		if behaviorKinds.Return and (behaviorKinds.Homing or behaviorKinds.Linger or behaviorKinds.Split) then
			return false, "Return cannot combine with Homing, Linger, or Split"
		end
	elseif d.Form == "Beam" then
		local beamPattern = d.Beam.Pattern or "Single"
		local strikeCount = d.Beam.StrikeCount or 5
		local spreadRadius = d.Beam.SpreadRadius or 12
		local dropHeight = d.Beam.DropHeight or 36
		local strikeInterval = d.Beam.StrikeInterval or 0.18
		if
			not keys(d.Beam, {
				Range = true,
				Width = true,
				DebugDuration = true,
				Interval = true,
				Pattern = true,
				StrikeCount = true,
				SpreadRadius = true,
				DropHeight = true,
				StrikeInterval = true,
				GrowthStartScale = true,
				GrowthEndScale = true,
				GrowthDuration = true,
			})
			or not bounded(d.Beam.Range, 1, Limits.MaxRange)
			or not bounded(d.Beam.Width, 0, 10)
			or not bounded(d.Beam.DebugDuration, 0.05, 1)
			or (d.Beam.Interval ~= nil and not bounded(d.Beam.Interval, 0.05, 1))
			or (d.Beam.Pattern ~= nil and beamPattern ~= "Single" and beamPattern ~= "Cascade")
			or (d.Beam.StrikeCount ~= nil and (not bounded(strikeCount, 2, 8) or strikeCount % 1 ~= 0))
			or (d.Beam.SpreadRadius ~= nil and not bounded(spreadRadius, 0, 30))
			or (d.Beam.DropHeight ~= nil and not bounded(dropHeight, 5, 80))
			or (d.Beam.StrikeInterval ~= nil and not bounded(strikeInterval, 0.1, 1))
		then
			return false, "Invalid beam range/width"
		end
		if beamPattern == "Cascade" then
			if c.Mode ~= "Instant" then
				return false, "Beam Cascade requires an Instant cast"
			end
			if d.Targeting ~= "AimDirection" and d.Targeting ~= "EntityTarget" then
				return false, "Beam Cascade requires aim-direction or aimed-entity targeting"
			end
			if dropHeight + 8 > math.min(d.Beam.Range, d.TargetRules.Range) then
				return false, "Beam range must reach from the Cascade drop height to its impact surface"
			end
		end
		local hasGrowth = (d.Beam.GrowthStartScale ~= nil and d.Beam.GrowthStartScale ~= 0)
			or (d.Beam.GrowthEndScale ~= nil and d.Beam.GrowthEndScale ~= 0)
			or (d.Beam.GrowthDuration ~= nil and d.Beam.GrowthDuration ~= 0)
		if hasGrowth then
			if
				c.Mode ~= "Channeled"
				or not bounded(d.Beam.GrowthStartScale, 0.1, 2)
				or not bounded(d.Beam.GrowthEndScale, 0.1, 2)
				or not bounded(d.Beam.GrowthDuration, 0.1, 30)
			then
				return false, "Beam expansion requires a Channeled Beam and bounded start/end/time values"
			end
			local maximumScale = math.max(d.Beam.GrowthStartScale, d.Beam.GrowthEndScale)
			if d.Beam.Range * maximumScale > Limits.MaxRange or d.Beam.Width * maximumScale > 10 then
				return false, "Expanded Beam dimensions exceed the configured range or width"
			end
		end
	elseif d.Form == "Field" then
		local validArea, areaReason =
			AreaSpec.validate("Field", d.Geometry, d.Field, Limits.MaxRadius, Limits.MinInterval)
		if not validArea then
			return false, areaReason
		end
		if d.Field.FollowTarget == true and d.Targeting ~= "EntityTarget" and d.Targeting ~= "ObjectTarget" then
			return false, "Following Fields require an entity or object target"
		end
		-- Field lens: changes projectiles crossing the Field (MagicSpellLensSpec).
		local lens = d.Field.AffectsSpells
		if lens ~= nil then
			if
				type(lens) ~= "table"
				or not keys(lens, { Who = true, AddMark = true, ScalePotency = true, Slow = true })
				or not table.find(Schema.LensWho, lens.Who)
				or (lens.AddMark ~= nil and (not table.find(Schema.Elements, lens.AddMark) or lens.AddMark == "Neutral"))
				or (lens.ScalePotency ~= nil and not bounded(lens.ScalePotency, 0.5, 1.5))
				or (lens.Slow ~= nil and not bounded(lens.Slow, 0.3, 1))
				or (lens.AddMark == nil and lens.ScalePotency == nil and lens.Slow == nil)
			then
				return false, "A lens needs Who and at least one of: mark element, potency 0.5-1.5, slow 0.3-1"
			end
		end
		local field = d.Field
		if
			(field.ArmDelay ~= nil and not bounded(field.ArmDelay, 0, Limits.MaxTrapArmDelay))
			or (field.Hidden ~= nil and type(field.Hidden) ~= "boolean")
			or (field.ConsumeOnTrigger ~= nil and type(field.ConsumeOnTrigger) ~= "boolean")
		then
			return false, "Invalid trap options (arm delay, hidden, ends when triggered)"
		end
		if field.Hidden == true then
			local grows = (field.GrowthStartScale ~= nil and field.GrowthStartScale ~= 0)
				or (field.GrowthEndScale ~= nil and field.GrowthEndScale ~= 0)
				or (field.GrowthDuration ~= nil and field.GrowthDuration ~= 0)
			if field.FollowTarget == true or grows then
				return false, "A hidden Field cannot follow a target or grow"
			end
			if d.Lifetime.Mode == "UntilDestroyed" then
				return false, "A hidden Field needs a duration"
			end
		end
	elseif d.Form == "Tether" then
		local tether = d.Tether
		if
			type(tether) ~= "table"
			or not keys(tether, {
				Anchors = true,
				MaxLength = true,
				BreakOnLineOfSight = true,
				Interval = true,
				Pull = true,
				ShareDamage = true,
			})
			or (tether.Anchors ~= "CasterToTarget" and tether.Anchors ~= "TargetToTarget")
			or not bounded(tether.MaxLength, Limits.MinTetherLength, Limits.MaxTetherLength)
			or type(tether.BreakOnLineOfSight) ~= "boolean"
			or not bounded(tether.Interval, Limits.MinInterval, Limits.MaxTetherInterval)
			or type(tether.Pull) ~= "boolean"
			or (tether.ShareDamage ~= nil and not bounded(tether.ShareDamage, 10, 90))
		then
			return false, "Invalid Tether links, length, interval, pull or shared damage"
		end
		if c.Mode ~= "Instant" then
			return false, "A Tether is cast instantly"
		end
		if d.Lifetime.Mode ~= "FixedDuration" then
			return false, "A Tether lasts a set duration"
		end
	elseif d.Form == "Rush" then
		local rush = d.Rush
		if
			type(rush) ~= "table"
			or not keys(rush, { Mode = true, Distance = true, Speed = true, Radius = true, StopOnHit = true })
			or (rush.Mode ~= "Dash" and rush.Mode ~= "Blink")
			or not bounded(rush.Distance, 2, Limits.MaxRushDistance)
			or not bounded(rush.Speed, 20, Limits.MaxRushSpeed)
			or not bounded(rush.Radius, 0.5, Limits.MaxRushRadius)
			or (rush.StopOnHit ~= nil and type(rush.StopOnHit) ~= "boolean")
		then
			return false, "Invalid Rush mode, distance, speed or radius"
		end
		if c.Mode ~= "Instant" then
			return false, "Rush requires an Instant cast"
		end
		if d.Lifetime.Mode ~= "Instantaneous" then
			return false, "Rush lasts as long as its movement"
		end
		if rush.Mode == "Blink" and d.Triggers.OnImpact and #d.Triggers.OnImpact > 0 then
			return false, "Blink hits nothing on the way; use On cast or On expire"
		end
	elseif d.Form == "Wave" then
		if
			not keys(d.Wave, {
				Range = true,
				Dot = true,
				Interval = true,
				DebugDuration = true,
				GrowthStartScale = true,
				GrowthEndScale = true,
				GrowthDuration = true,
			})
			or not bounded(d.Wave.Range, 1, Limits.MaxRadius)
			or not bounded(d.Wave.Dot, -1, 1)
			or (d.Wave.Interval ~= nil and not bounded(d.Wave.Interval, Limits.MinInterval, 1))
			or not bounded(d.Wave.DebugDuration, 0.05, 1)
		then
			return false, "Invalid wave range/angle"
		end
		local hasGrowth = (d.Wave.GrowthStartScale ~= nil and d.Wave.GrowthStartScale ~= 0)
			or (d.Wave.GrowthEndScale ~= nil and d.Wave.GrowthEndScale ~= 0)
			or (d.Wave.GrowthDuration ~= nil and d.Wave.GrowthDuration ~= 0)
		if hasGrowth then
			if
				c.Mode ~= "Channeled"
				or not bounded(d.Wave.GrowthStartScale, 0.1, 2)
				or not bounded(d.Wave.GrowthEndScale, 0.1, 2)
				or not bounded(d.Wave.GrowthDuration, 0.1, 30)
			then
				return false, "Wave expansion requires a Channeled Wave and bounded start/end/time values"
			end
			if d.Wave.Range * math.max(d.Wave.GrowthStartScale, d.Wave.GrowthEndScale) > Limits.MaxRadius then
				return false, "Expanded Wave reach exceeds the configured maximum radius"
			end
		end
	end
	if
		hasPayload(d, "Manipulation")
		and (d.Form == "Projectile" or d.Form == "Beam" or d.Form == "Wave")
		and d.Targeting ~= "ObjectTarget"
	then
		return false, "Projectile, Beam, and Wave material Manipulation requires ObjectTarget"
	end
	if d.Targeting == "ObjectTarget" and (d.Form == "Construct" or d.Form == "Field" or d.Form == "Aura") then
		if d.Material ~= nil then
			return false, "This object-targeted Form does not use a material requirement"
		end
	elseif d.Targeting == "ObjectTarget" and (d.Form == "Projectile" or d.Form == "Beam" or d.Form == "Wave") then
		if not hasOnlyObjectInteractionPayloads(d) then
			return false,
				"Object-targeted Projectiles, Beams, and Waves require Force, Control, or authorized Manipulation on a resolving event"
		end
		if hasPayload(d, "Manipulation") then
			if
				not keys(d.Material, { Material = true, SearchRadius = true })
				or not MaterialSpec.supports(
					d.Source.Principle,
					d.Source.Expression,
					d.Form,
					d.Targeting,
					d.Material.Material
				)
				or not bounded(d.Material.SearchRadius, 1, 30)
			then
				return false, "Material Manipulation requires a matching tagged source and bounded object reach"
			end
		elseif d.Material ~= nil then
			if not keys(d.Material, { SearchRadius = true }) or not bounded(d.Material.SearchRadius, 1, 30) then
				return false, "Invalid object-target reach"
			end
		end
	elseif
		d.Targeting == "ObjectTarget"
		and d.Form == "Manipulation"
		and not hasPayload(d, "Manipulation")
		and hasOnlyObjectInteractionPayloads(d)
	then
		if d.Material ~= nil then
			if
				not keys(d.Material, { Material = true, SearchRadius = true })
				or (d.Material.Material ~= nil and not MaterialSpec.supports(
					d.Source.Principle,
					d.Source.Expression,
					d.Form,
					d.Targeting,
					d.Material.Material
				))
				or not bounded(d.Material.SearchRadius, 1, 30)
			then
				return false, "Invalid optional object-target settings"
			end
		end
	elseif d.Targeting == "MaterialTarget" or d.Targeting == "ObjectTarget" then
		if
			not keys(d.Material, { Material = true, Amount = true, SearchRadius = true })
			or not MaterialSpec.supports(
				d.Source.Principle,
				d.Source.Expression,
				d.Form,
				d.Targeting,
				d.Material.Material
			)
			or not bounded(d.Material.SearchRadius, 1, 30)
			or (d.Form ~= "Manipulation" and not bounded(d.Material.Amount, 0.1, 10))
			or (d.Form == "Manipulation" and d.Material.Amount ~= nil)
		then
			return false, "Invalid or unsupported material source requirement"
		end
	elseif d.Material then
		return false, "Material data requires a material or object target"
	end
	local validVisual, visualReason = VisualSpec.validate(d.Visual)
	if not validVisual then
		return false, visualReason
	end
	if d.Audio ~= nil then
		local validAudio, audioReason = AudioSpec.validate(d.Audio)
		if not validAudio then
			return false, audioReason
		end
	end
	if d.Visual.Profile then
		local supported = false
		for _, profile in ipairs(Spec.PresentationProfiles) do
			if profile == d.Visual.Profile then
				supported = true
			end
		end
		if not supported then
			return false, "Unsupported presentation profile"
		end
	end
	for _, color in ipairs({ d.Visual.Color, d.Visual.SecondaryColor, d.Visual.AccentColor }) do
		if color and (not bounded(color.R, 0, 1) or not bounded(color.G, 0, 1) or not bounded(color.B, 0, 1)) then
			return false, "Invalid presentation color"
		end
	end
	if
		not keys(d.Cost, {
			ManaDemand = true,
			Strain = true,
			Complexity = true,
			SpecialResources = true,
			Health = true,
			HealthForMana = true,
			HealthPerSecond = true,
		})
	then
		return false, "Invalid cost data"
	end
	-- Blood magic: health as a cost (MagicBloodCostSpec). Upkeep in health only
	-- for spells that stay active while held or toggled.
	local bloodValid, bloodReason = BloodCostSpec.validate(d.Cost, Limits)
	if not bloodValid then
		return false, bloodReason
	end
	if
		d.Cost.HealthPerSecond ~= nil
		and not CastingSpec.isHeldMode(c.Mode)
		and not (d.Lifetime and d.Lifetime.Mode == "UntilToggledOff")
	then
		return false, "Health per second needs a channelled, sustained or toggled spell"
	end
	for key, v in pairs(d.Cost) do
		if key == "SpecialResources" or key == "Health" or key == "HealthForMana" or key == "HealthPerSecond" then
			continue
		end
		if not bounded(v, 0, 100000) then
			return false, "Invalid cost value"
		end
	end
	local specialCostsValid, specialCostsReason = SpecialResourceSpec.validateCosts(
		d.Cost.SpecialResources,
		SpecialResources,
		Limits.MaxSpecialResourceCostTypes,
		Limits.MaxSpecialResourceCost
	)
	if not specialCostsValid then
		return false, specialCostsReason
	end
	local locusRequirementsValid, locusRequirementsReason = LocusRequirementSpec.validate(d.LocusRequirements)
	if not locusRequirementsValid then
		return false, locusRequirementsReason
	end
	local environmentRequirementsValid, environmentRequirementsReason =
		EnvironmentRequirementSpec.validate(d.EnvironmentRequirements)
	if not environmentRequirementsValid then
		return false, environmentRequirementsReason
	end
	if type(d.Triggers) ~= "table" then
		return false, "Invalid triggers"
	end
	local hasShieldSource = false
	local hasTransformSource = false
	local hasSummonSource = false
	local hasProjectileLinger = false
	local hasProjectilePulse = false
	local hasProjectileProximity = false
	if d.Proximity ~= nil then
		if
			d.Form == "Projectile"
			or not ProximitySpec.SupportedForms[d.Form]
			or not keys(d.Proximity, { Radius = true, Interval = true, MaxTargets = true })
			or not ProximitySpec.validate(d.Proximity, Limits.MaxRadius, Limits.MinInterval, Limits.MaxTargets)
		then
			return false, "Invalid active Form proximity settings"
		end
	end
	if d.Form == "Projectile" then
		for _, behavior in ipairs(d.Projectile.Behaviors) do
			if behavior.Kind == "Linger" then
				hasProjectileLinger = true
			elseif behavior.Kind == "Pulse" then
				hasProjectilePulse = true
			elseif behavior.Kind == "Proximity" then
				hasProjectileProximity = true
			end
		end
	end
	for event, steps in pairs(d.Triggers) do
		if event ~= "OnBreak" and type(steps) == "table" then
			for _, step in pairs(steps) do
				if type(step) == "table" and type(step.Payloads) == "table" then
					for _, payload in pairs(step.Payloads) do
						if type(payload) == "table" and payload.Kind == "Shield" then
							hasShieldSource = true
						end
						if
							event ~= "OnTransformEnd"
							and type(payload) == "table"
							and payload.Kind == "Transformation"
							and (payload.Mode == "Polymorph" or payload.Mode == "Shapeshift")
						then
							hasTransformSource = true
						end
						if event ~= "OnCommand" and type(payload) == "table" and payload.Kind == "Summon" then
							hasSummonSource = true
						end
					end
				end
			end
		end
	end
	local total = 0
	local single = {}
	for event, steps in pairs(d.Triggers) do
		if not Schema.supportsEvent(d.Form, event, d.Casting.Mode) or not array(steps, Limits.MaxSteps) then
			return false, "UNSUPPORTED trigger: " .. tostring(event)
		end
		if event == "OnTick" and d.Form == "Projectile" and not hasProjectileLinger and not hasProjectilePulse then
			return false, "Projectile OnTick requires Pulse while traveling or Linger after impact"
		end
		if event == "OnProximity" and d.Form == "Projectile" and not hasProjectileProximity then
			return false, "Projectile OnProximity requires the Proximity behavior"
		end
		if event == "OnProximity" and d.Form ~= "Projectile" and not d.Proximity then
			return false, "Active Form OnProximity requires valid proximity settings"
		end
		if event == "OnCommand" and not hasSummonSource then
			return false, "OnCommand requires a Summon payload on another trigger"
		end
		if event == "OnTransformEnd" and not hasTransformSource then
			return false, "When the transformation ends needs a Polymorph or Shapeshift on another trigger"
		end
		-- On a Tether, OnBreak is the snap and needs no shield.
		if event == "OnBreak" and not hasShieldSource and d.Form ~= "Tether" then
			return false, "OnBreak requires a Shield payload on another trigger"
		end
		if
			event == "OnMeleeHit"
			and d.Form == "Field"
			and not (type(d.Field) == "table" and d.Field.FollowTarget == true)
		then
			-- At runtime it also fires only while the Field follows its own caster.
			return false, "OnMeleeHit on a Field requires a Field that follows you"
		end
		local usedThresholds = {}
		for _, step in ipairs(steps) do
			if type(step) ~= "table" then
				return false, "Invalid trigger step"
			end
			local behavior = if step.Behavior then Schema.Behaviors[step.Behavior] else nil
			local stepFields = { Payloads = true }
			if event == "OnThreshold" then
				stepFields.HealthPercent = true
				if
					not bounded(step.HealthPercent, 1, 99)
					or step.HealthPercent % 1 ~= 0
					or usedThresholds[step.HealthPercent]
				then
					return false, "Threshold steps need a unique integer health percentage from 1 to 99"
				end
				usedThresholds[step.HealthPercent] = true
			end
			if event == "OnCommand" then
				stepFields.Command = true
				if step.Command ~= nil and not table.find(Schema.CommandOrder, step.Command) then
					return false, "OnCommand has an unsupported command filter"
				end
			end
			local targetFromOptions = Schema.TargetFromByEvent[event]
			if targetFromOptions then
				stepFields.TargetFrom = true
				if step.TargetFrom ~= nil and not table.find(targetFromOptions, step.TargetFrom) then
					return false, event .. " target must be " .. table.concat(targetFromOptions, " or ")
				end
			end
			for _, p in ipairs(type(step.Payloads) == "table" and step.Payloads or {}) do
				if type(p) == "table" and p.Mode == "PercentDamageDealt" and event ~= "OnDamageDealt" then
					return false, "Percent of damage dealt only works On damage dealt"
				end
			end
			if event == "OnTargetDeath" then
				stepFields.DeathMode = true
				if step.DeathMode ~= nil and not table.find(Schema.TargetDeathModes, step.DeathMode) then
					return false, "OnTargetDeath has an unsupported death-cause filter"
				end
			end
			-- Tether steps may act on one end (A, B) or both (default).
			if d.Form == "Tether" then
				stepFields.Anchor = true
				if step.Anchor ~= nil and not table.find(Schema.TetherAnchors, step.Anchor) then
					return false, "A Tether step acts on end A, end B or both"
				end
			end
			if event == "OnBeforeDamageTaken" then
				stepFields.Intercept = true
				local intercept = step.Intercept
				if intercept ~= nil then
					local range = type(intercept) == "table" and Schema.InterceptPercentRange[intercept.Action]
					if
						type(intercept) ~= "table"
						or not keys(intercept, { Action = true, Percent = true, To = true })
						or not table.find(Schema.InterceptActions, intercept.Action)
						or (intercept.Action == "Negate" and (intercept.Percent ~= nil or intercept.To ~= nil))
						or (range and not bounded(intercept.Percent, range[1], range[2]))
						or (intercept.Action == "Reduce" and intercept.To ~= nil)
						or (intercept.Action == "Redirect" and not table.find(Schema.InterceptTargets, intercept.To))
					then
						return false, "Interception: Negate, Reduce 1-90% or Redirect 10-100% to Owner or Attacker"
					end
				end
			end
			-- Spells as targets: only Dispel and Force act on spells, and Dispel
			-- only there.
			stepFields.TargetKind = true
			stepFields.SpellRelationship = true
			if step.TargetKind ~= nil and not table.find(Schema.TargetKinds, step.TargetKind) then
				return false, "Unknown target kind"
			end
			if step.SpellRelationship ~= nil then
				if step.TargetKind ~= "Spell" or not table.find(Schema.SpellRelationships, step.SpellRelationship) then
					return false, "Spell relationship needs Target spells (Hostile, Allied or Any)"
				end
			end
			if step.TargetKind == "Spell" and step.Behavior ~= nil and step.Behavior ~= "Explode" then
				return false, "A step that targets spells can only use Explode (its radius is the reach)"
			end
			if step.TargetKind == "Spell" and step.Condition ~= nil then
				return false, "Conditions check characters; a step that targets spells cannot have one"
			end
			for _, spellPayload in ipairs(type(step.Payloads) == "table" and step.Payloads or {}) do
				local kind = type(spellPayload) == "table" and spellPayload.Kind
				if step.TargetKind == "Spell" and not Schema.SpellTargetPayloads[kind] then
					return false, "Only Dispel and Force can act on spells"
				end
				if step.TargetKind ~= "Spell" and kind == "Dispel" then
					return false, "Dispel acts on spells: turn on Target spells for this step"
				end
			end
			stepFields.Condition = true
			if step.Condition ~= nil then
				local conditionValid, conditionReason =
					ConditionSpec.validateStep(step.Condition, event == "OnBeforeDamageTaken")
				if not conditionValid then
					return false, conditionReason
				end
			end
			if behavior then
				stepFields.Behavior = true
				for _, field in behavior.Fields or {} do
					stepFields[field.Key] = true
				end
				if step.Behavior == "SpawnEffect" then
					stepFields.Effect = true
				end
			elseif step.Behavior then
				return false, "Unsupported behavior: " .. tostring(step.Behavior)
			end
			if
				not keys(step, stepFields)
				or not array(step.Payloads, Limits.MaxPayloads)
				-- An Intercept action is the step's effect, so it needs no payloads.
				or #step.Payloads
					< (if behavior or step.Intercept ~= nil then (behavior and behavior.MinimumPayloads) or 0 else 1)
			then
				return false, "Invalid trigger step"
			end
			if behavior then
				if not Schema.supportsBehavior(step.Behavior, d.Form, event) then
					return false, "Behavior is not supported for this Form and trigger"
				end
				for _, field in behavior.Fields or {} do
					local value = step[field.Key]
					if value == nil then
						if field.Required then
							return false, "Missing behavior setting: " .. field.Label
						end
					elseif field.Options then
						if not table.find(field.Options, value) then
							return false, "Invalid behavior setting: " .. field.Label
						end
					elseif not bounded(value, field.Min, field.Max) or (field.Integer and value % 1 ~= 0) then
						return false, "Behavior setting is outside its safety limit: " .. field.Label
					end
				end
				if step.Behavior == "SpawnEffect" then
					local spawnValid, spawnReason = validateSpawnStep(d, step, spawnNesting or 0)
					if not spawnValid then
						return false, spawnReason
					end
					-- A spawned effect counts as one of the spell's effects.
					total = total + 1
				end
			end
			for _, p in ipairs(step.Payloads) do
				if type(p) ~= "table" or type(p.Kind) ~= "string" then
					return false, "Invalid payload"
				end
				total = total + 1
				local definition = Schema.Payloads[p.Kind]
				if not definition then
					return false, "Unsupported payload: " .. tostring(p.Kind)
				end
				if behavior and not table.find(behavior.PayloadKinds or {}, p.Kind) then
					return false, "Payload is not supported by this behavior"
				end
				local allowedFields = { Kind = true, ScaleBy = ScaleSpec.ScalableKinds[p.Kind] == true }
				for _, field in definition.Fields do
					allowedFields[field.Key] = true
				end
				if not keys(p, allowedFields) then
					return false, "Unsupported payload fields"
				end
				local payloadEventSupported = Schema.supportsPayload(p.Kind, d.Form, event, d.Source.Principle)
				local behaviorPayloadSupported = behavior ~= nil
					and definition.Forms[d.Form] == true
					and (definition.Principle == nil or definition.Principle == d.Source.Principle)
				if not payloadEventSupported and not behaviorPayloadSupported then
					return false, "Payload is not supported for this Form and trigger"
				end
				for _, field in definition.Fields do
					local value = p[field.Key]
					if value == nil then
						if field.Required then
							return false, "Missing payload setting: " .. field.Label
						end
					elseif field.Options or field.OptionsByPrinciple then
						local options = field.Options
						if field.OptionsByPrinciple then
							options = field.OptionsByPrinciple[d.Source.Principle] or options
						end
						if not table.find(options, value) then
							return false, "Invalid payload setting: " .. field.Label
						end
					elseif field.Boolean then
						if type(value) ~= "boolean" then
							return false, "Invalid payload setting: " .. field.Label
						end
					elseif not bounded(value, field.Min, field.Max) or (field.Integer and value % 1 ~= 0) then
						return false, "Payload setting is outside its safety limit: " .. field.Label
					end
				end
				if p.Kind == "Dispel" and p.Mode == "Shorten" and p.Seconds == nil then
					return false, "Shorten needs the time it removes"
				end
				if p.Kind == "Dispel" and p.Mode == "End" and p.Seconds ~= nil then
					return false, "End removes the spell; it has no time setting"
				end
				-- Transformation: settings and limits per mode.
				if p.Kind == "Transformation" then
					local mode = p.Mode
					if mode == "Scale" then
						if
							p.Multiplier == nil
							or p.Duration > Limits.MaxDuration
							or p.BreakOnDamage ~= nil
							or p.Profile ~= nil
						then
							return false, "Scale needs a multiplier and lasts at most " .. Limits.MaxDuration .. " s"
						end
					elseif mode == "Polymorph" then
						if
							p.Multiplier ~= nil
							or p.Profile ~= nil
							or not bounded(p.Duration, Limits.MinPolymorphDuration, Limits.MaxPolymorphDuration)
						then
							return false, "Polymorph lasts 1-8 s and has no size or melee style"
						end
					elseif mode == "Shapeshift" then
						if
							p.Multiplier ~= nil
							or p.BreakOnDamage ~= nil
							or p.Profile == nil
							or not bounded(p.Duration, Limits.MinShapeshiftDuration, Limits.MaxShapeshiftDuration)
						then
							return false, "Shapeshift lasts 5-60 s and needs a melee style"
						end
						if d.Form ~= "SelfEnhancement" or d.Targeting ~= "Self" then
							return false, "Shapeshift only works on yourself (an Enchantment on you)"
						end
					end
				end
				if (p.Kind == "ElementalMark" or p.Kind == "ConsumeElementalMark") and d.Element == "Neutral" then
					return false, "Elemental marks require a non-neutral selected Element"
				end
				local scaleOk, scaleReason =
					ScaleSpec.validateScaleBy(p.ScaleBy, p.Kind, Limits.MaxScaleBonus, AttributeSpec.validElement)
				if not scaleOk then
					return false, scaleReason
				end
				if p.Kind == "ModifyAttribute" then
					-- Element is required for Resistance and rejected for every other attribute;
					-- Amount must sit inside the chosen attribute's own range.
					local attribute = AttributeSpec.Definitions[p.Attribute]
					if AttributeSpec.requiresElement(p.Attribute) then
						if p.Element == nil then
							return false, "Missing payload setting: Resistance element"
						end
					elseif p.Element ~= nil then
						return false, "Only Resistance uses an element"
					end
					if not bounded(p.Amount, attribute.Minimum, attribute.Maximum) then
						return false, "Payload setting is outside its safety limit: Modifier amount"
					end
				end
				if p.Kind == "Summon" then
					local lifetimeMode = p.LifetimeMode or "FixedDuration"
					if not table.find(SummonLimits.LifetimeModes, lifetimeMode) then
						return false, "Invalid payload setting: Summon lifetime"
					end
					if
						lifetimeMode == "FixedDuration"
						and not bounded(p.Duration, SummonLimits.MinDuration, SummonLimits.MaxDuration)
					then
						return false, "Fixed-duration summons need a valid duration"
					elseif lifetimeMode == "UntilCommanded" and p.Duration ~= nil then
						return false, "Until-commanded summons cannot include a duration"
					end
					local respawnPolicy = p.RespawnPolicy or "DismissOnDeath"
					if not table.find(SummonLimits.RespawnPolicies, respawnPolicy) then
						return false, "Invalid payload setting: Summon owner death behavior"
					end
					if respawnPolicy == "PersistUntilDismissed" and lifetimeMode ~= "UntilCommanded" then
						return false, "Only Until-commanded summons can persist across owner respawn"
					end
				end
				if
					p.Kind == "Enhancement"
					or p.Kind == "Manipulation"
					or p.Kind == "ModifyAttribute"
					or p.Kind == "Transformation"
				then
					-- One Transformation per mode (Shapeshift may sit beside a Scale).
					local slot = if p.Kind == "Transformation" then p.Kind .. tostring(p.Mode) else p.Kind
					if single[slot] then
						return false, "Only one movement/material/attribute modifier is supported per spell"
					end
					single[slot] = true
				end
				if
					p.Kind == "Enhancement"
					and p.SpeedMultiplier == nil
					and p.WalkSpeedBonus == nil
					and p.JumpPowerBonus == nil
				then
					return false, "Empty enhancement"
				end
				if p.Kind == "DamageOverTime" or p.Kind == "Restoration" then
					if p.Interval > p.Duration or p.Amount * math.floor(p.Duration / p.Interval) > 500 then
						return false,
							"Invalid periodic payload: interval must fit duration and total base amount must not exceed 500"
					end
				end
				if p.Kind == "TimeDilation" and math.abs(p.Rate - 1) < 0.001 then
					return false, "Time dilation must differ from the normal rate"
				end
				if p.DamageChannel == "Soul" and d.Source.Principle ~= "Soul" then
					return false, "Soul damage requires the Soul Principle"
				end
				if p.DamageChannel == "Physical" and d.Source.Principle ~= "Body" then
					return false, "Physical damage requires the Body Principle"
				end
			end
		end
	end
	-- An Interception action (Negate/Reduce/Redirect) is an effect on its own.
	if (total == 0 and d.Form ~= "Construct" and not intercepts) or total > 8 then
		return false, "Specify 1–8 payloads across triggers"
	end
	return true
end
function Spec.estimate(d)
	local waveScale = if d.Wave then math.max(d.Wave.GrowthStartScale or 1, d.Wave.GrowthEndScale or 1) else 1
	local beamScale = if d.Beam then math.max(d.Beam.GrowthStartScale or 1, d.Beam.GrowthEndScale or 1) else 1
	local radius = (d.Projectile and d.Projectile.Radius)
		or (d.Aura and d.Aura.Radius)
		or (d.Field and d.Field.Radius)
		or (d.Wave and d.Wave.Range * waveScale)
		or 0
	if d.Beam and d.Beam.Pattern == "Cascade" then
		radius = math.max(radius, d.Beam.SpreadRadius or 12)
	end
	local range = (d.Projectile and d.Projectile.MaxDistance)
		or (d.Beam and d.Beam.Range * beamScale)
		or d.TargetRules.Range
	local speed = d.Projectile and d.Projectile.Speed or 0
	local duration = d.Lifetime.Duration or (d.Lifetime.Mode ~= "FixedDuration" and 15 or 1)
	local strength, count, behaviors, constructComponents, additionalBehaviorTargets = 0, 0, 0, 0, 0
	local chargeScaling = d.Casting and d.Casting.ChargeScaling
	-- Priced at full charge: MaxPotency and every extra projectile.
	local chargePotency = (
		if type(chargeScaling) == "table" and type(chargeScaling.MaxPotency) == "number"
			then chargeScaling.MaxPotency
			else 1
	) * (1 + ScaleSpec.extraProjectiles(chargeScaling, 1))
	local burstStrength, controlWeight = 0, 0
	local environmentRequirementCount = 0
	local environmentRequirements = d.EnvironmentRequirements or {}
	if environmentRequirements.RequireGrounded then
		environmentRequirementCount += 1
	end
	if environmentRequirements.ClockTime then
		environmentRequirementCount += 1
	end
	if environmentRequirements.ZoneTags then
		for _, tag in ipairs(environmentRequirements.ZoneTags.Required or {}) do
			if tag then
				environmentRequirementCount += 1
			end
		end
		for _, tag in ipairs(environmentRequirements.ZoneTags.Forbidden or {}) do
			if tag then
				environmentRequirementCount += 1
			end
		end
	end
	if d.Construct then
		local constructScale = math.max(d.Construct.GrowthStartScale or 1, d.Construct.GrowthEndScale or 1)
		strength = d.Construct.Width * d.Construct.Height * d.Construct.Depth * constructScale ^ 3 * 0.1
		local components = ConstructGeometrySpec.components(
			d.Geometry,
			d.Construct.Width,
			d.Construct.Height,
			d.Construct.Depth,
			d.Construct.Components
		)
		constructComponents = components and #components or 0
		strength += math.max(0, constructComponents - 1) * 3
	end
	local interceptCharges = d.Interception and d.Interception.Charges or 1
	for _, steps in pairs(d.Triggers) do
		for _, step in ipairs(steps) do
			if step.Behavior then
				behaviors = behaviors + 1
				radius = math.max(radius, step.Radius or 0)
			end
			-- Interception: priced per charge, Negate highest.
			if step.Intercept then
				controlWeight += InterceptionSpec.costWeight(step.Intercept) * interceptCharges
			end
			for _, p in ipairs(step.Payloads) do
				count = count + 1
				-- Priced at the strongest outcome: the full ScaleBy bonus (charge is
				-- applied to the whole spell below).
				local pricedAmount = math.abs(p.Amount or 0)
					+ (if type(p.ScaleBy) == "table" then math.abs(p.ScaleBy.Max or 0) else 0)
				if p.Kind == "Damage" or p.Kind == "Heal" or p.Kind == "Shield" then
					burstStrength += pricedAmount
				elseif p.Kind == "Bind" or p.Kind == "Control" or p.Kind == "TimeDilation" then
					controlWeight += 4 + (p.Duration or 0)
				elseif p.Kind == "Slow" then
					controlWeight += (1 - (p.Multiplier or 1)) * 10 * (p.Duration or 1)
				elseif p.Kind == "Stun" then
					controlWeight += 6 + (p.Duration or 0) * 2
				elseif p.Kind == "Silence" then
					controlWeight += 4 + (p.Duration or 0)
				elseif p.Kind == "Cleanse" then
					controlWeight += 2 * (p.Count or 1)
				end
				local amountWeight = if ScaleSpec.ScalableKinds[p.Kind] then pricedAmount else math.abs(p.Amount or 0)
				local attribute = p.Kind == "ModifyAttribute" and AttributeSpec.Definitions[p.Attribute]
				if attribute then
					-- Weigh every attribute on the same 0-100 scale as armor, so a full
					-- Resistance (1.0) or DamageTaken (50%) costs like full armor.
					amountWeight = amountWeight / math.max(math.abs(attribute.Minimum), attribute.Maximum) * 100
				end
				strength = strength
					+ amountWeight * ((p.Kind == "DamageOverTime" or p.Kind == "Restoration") and math.floor(
						p.Duration / p.Interval
					) or 1)
					+ (p.Magnitude or 0) * 0.5
					+ math.abs((p.SpeedMultiplier or 1) - 1) * 15
					+ (p.Distance or 0) * 2
			end
		end
	end
	for _, behavior in ipairs(d.Projectile and d.Projectile.Behaviors or {}) do
		behaviors += 1
		if behavior.Kind == "Chain" then
			radius = math.max(radius, behavior.Radius)
			additionalBehaviorTargets += behavior.MaxJumps
		elseif behavior.Kind == "Propagate" then
			radius = math.max(radius, behavior.Radius)
			additionalBehaviorTargets += behavior.MaxTargets
		end
	end
	local motionPhaseCount = #(d.Projectile and d.Projectile.MotionPhases or {})
	local curvedPhaseCount = 0
	for _, phase in ipairs(d.Projectile and d.Projectile.MotionPhases or {}) do
		if phase.Mode == "Bezier" then
			curvedPhaseCount += 1
		end
	end
	-- Charge (MaxPotency x every extra projectile) scales everything the spell
	-- does, including control such as a charged volley of Slows.
	strength *= chargePotency
	burstStrength *= chargePotency
	controlWeight *= chargePotency
	local area = d.Field or d.Aura
	local ticks = area and duration / area.Interval or 1
	local beamExtraStrikes = if d.Beam and d.Beam.Pattern == "Cascade"
		then math.max(0, (d.Beam.StrikeCount or 5) - 1)
		else 0
	local fanout = math.max(1, d.TargetRules.MaxTargets + additionalBehaviorTargets + beamExtraStrikes)
	local cost = math.ceil(
		2
			+ radius * 0.8
			+ range * 0.03
			+ speed * 0.02
			+ duration * 0.3
			+ strength * 0.2 * math.sqrt(ticks)
			+ strength * 0.08 * (math.sqrt(fanout) - 1)
			+ controlWeight * math.sqrt(fanout) * 0.5
			+ count * 2
			+ behaviors * 4
			+ additionalBehaviorTargets * 0.5
			+ environmentRequirementCount * 2
			+ motionPhaseCount * 2
			+ curvedPhaseCount * 2
			+ beamExtraStrikes * 2.5
			+ d.TargetRules.MaxTargets * 0.2
	)
	-- A spawned effect costs what it would as its own spell, once per spawn.
	-- (Strain follows from the combined mana cost below.)
	local spawnedMana, spawnedComplexity = 0, 0
	for _, steps in pairs(d.Triggers) do
		for _, step in ipairs(steps) do
			if step.Behavior == "SpawnEffect" then
				local child = Spec.expandSpawnEffect(d, step.Effect)
				if child then
					local childCost = Spec.estimate(child)
					local spawned = step.Count or 1
					spawnedMana += childCost.ManaDemand * spawned
					spawnedComplexity += childCost.Complexity
				end
			end
		end
	end
	cost += spawnedMana
	-- Blood magic: ManaDemand stays the full price (rank limits, Locus safety);
	-- ManaPaid is what is spent in mana once health replaces its share.
	local manaPaid, healthFromMana = BloodCostSpec.split(cost, d.Cost and d.Cost.HealthForMana, Limits.HealthPerMana)
	return {
		ManaDemand = cost,
		ManaPaid = manaPaid,
		HealthFromMana = healthFromMana,
		HealthCost = d.Cost and d.Cost.Health,
		HealthPerSecond = d.Cost and d.Cost.HealthPerSecond or 0,
		Strain = math.ceil(cost * 0.28 + burstStrength * math.sqrt(fanout) * 0.12 + controlWeight * 0.6),
		Complexity = spawnedComplexity + math.ceil(
			1
				+ count
				+ behaviors
				+ motionPhaseCount
				+ curvedPhaseCount
				+ math.ceil(beamExtraStrikes / 2)
				+ environmentRequirementCount
				+ math.ceil(additionalBehaviorTargets / 2)
				+ math.sqrt(radius) / 3
				+ math.max(0, constructComponents - 1)
		),
		ManaUpkeepPerSecond = d.Casting.ManaUpkeepPerSecond or 0,
		StrainPerSecond = d.Casting.StrainPerSecond or 0,
	}
end
return Spec
