--!strict

-- Bounded V1 status effects shared by player and NPC Humanoids.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Limits = require(game:GetService("ReplicatedStorage").Shared.Configuration.MagicLab)
local ShieldPool = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicShieldPool)
local AttributeSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicAttributeSpec)
local MovementEffects = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicMovementEffects)
local RevealSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicRevealSpec)
local TemporalRate = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicTemporalRate)
local TransformationSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicTransformationSpec)
local EffectSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicStatusEffectSpec)
local ElementalMarkSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicElementalMarkSpec)
local Interactions = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicElementalInteractionSpec)
local DamageRules = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicDamageRules)
local Movement = require(script.Parent.MovementService)
local CrowdControl = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicCrowdControlSpec)
local ControlState = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicControlStateSpec)
local Schema = require(game:GetService("ReplicatedStorage").Shared.Configuration.MagicSchema)
TemporalRate.configure(Limits.MinTimeRate, Limits.MaxTimeRate)

type Effect = {
	Kind: string,
	Attribute: string?,
	Caster: Model,
	SpellId: string,
	Polarity: string,
	ExpiresAt: number,
	Remaining: number?,
	LastUpdateAt: number?,
	Amount: number?,
	Multiplier: number?,
	OnBreak: ((Humanoid) -> ())?,
	ViewerUserId: number?,
	Color: Color3?,
	OnTargetDeath: ((Humanoid) -> ())?,
	Element: string?,
	Stacks: number?,
	RequiredElementalMark: string?,
}
type TargetState = {
	Humanoid: Humanoid,
	Effects: { Effect },
	Connections: { RBXScriptConnection },
	RevealAttributes: { [string]: boolean },
	TransformModel: Model?,
	OriginalScale: number?,
	AppliedScale: number?,
}

local Status = {}

-- Payload kinds that never become a timed status here, and where they live.
-- Listed so every Schema.Payloads kind is accounted for (test_magic_registry_parity).
Status.HandledElsewhere = {
	Damage = "DamageService",
	DamageOverTime = "MagicPayloadExecutors periodic effects",
	ConsumeElementalMark = "Status.consumeElementalMark (removes marks, adds none)",
	Force = "MagicPayloadExecutors applyForce",
	Heal = "Status.heal (instant)",
	Restoration = "MagicPayloadExecutors periodic effects",
	Control = "MagicControlService",
	Displacement = "MagicPayloadExecutors displaceTarget",
	Enhancement = "MagicService (context.ApplyEnhancement)",
	AerialMovement = "MagicService (context.ApplyAerialMovement)",
	Manipulation = "MagicService (context.ApplyManipulation)",
	Summon = "MagicService (context.Summon)",
	DrainResource = "MagicService (context.TransferResource), players only",
	RestoreResource = "MagicService (context.TransferResource), players only",
	Cleanse = "Status.cleanseCandidates / removeWhere here; MagicPayloadExecutors adds periodic effects and Enchantments",
	Dispel = "MagicSpellTargets (acts on spells, never on a character)",
}
local targets: { [Humanoid]: TargetState } = setmetatable({}, { __mode = "k" }) :: any
-- Extra walk-speed factors from outside the timed statuses (Polymorph, via
-- MagicTransformService.setSpeedFactor); folded into the slow multiplier.
local speedFactors: { [Humanoid]: number } = setmetatable({}, { __mode = "k" }) :: any
local active: { TargetState } = {}
local lastSweep = 0

-- Boon/Bane/Neutral from the payload registry; stored on each effect for later
-- cleanse/purge and UI grouping. It does not change how the effect behaves.
local function polarityOf(kind: string): string
	local definition = Schema.Payloads[kind]
	return if definition and definition.Polarity then definition.Polarity else "Neutral"
end

local function setAttribute(humanoid: Humanoid, model: Model?, name: string, value: any)
	humanoid:SetAttribute(name, value)
	if model then
		model:SetAttribute(name, value)
	end
end

local function captureTransformBaseline(state: TargetState, model: Model): boolean
	if state.TransformModel == model and state.OriginalScale then
		return true
	end
	local ok, scale = pcall(function()
		return model:GetScale()
	end)
	if not ok or type(scale) ~= "number" then
		return false
	end
	state.TransformModel = model
	state.OriginalScale = scale
	state.AppliedScale = scale
	return true
end

local function restoreTransform(state: TargetState)
	local model = state.TransformModel
	local scale = state.OriginalScale
	-- A live model may be moved out of Workspace before cleanup runs. Restore
	-- its authored size while it still exists so reparenting it later cannot
	-- preserve an expired transformation.
	if model and scale and model.Parent ~= nil then
		pcall(function()
			model:ScaleTo(scale)
		end)
	end
	state.TransformModel = nil
	state.OriginalScale = nil
	state.AppliedScale = nil
end

local function getState(humanoid: Humanoid, create: boolean): TargetState?
	local state = targets[humanoid]
	if state or not create or #active >= Limits.MaxEffectTargets then
		return state
	end
	local model = humanoid.Parent
	if not model or not model:IsA("Model") or not humanoid:IsDescendantOf(workspace) then
		return nil
	end
	state = { Humanoid = humanoid, Effects = {}, Connections = {}, RevealAttributes = {} }
	targets[humanoid] = state
	table.insert(active, state)
	state.Connections = {
		humanoid.Died:Connect(function()
			local callbacks = {}
			local seen = {}
			local now = os.clock()
			for _, effect in state.Effects do
				local casterHumanoid = effect.Caster:FindFirstChildOfClass("Humanoid")
				local casterAlive = effect.Caster:IsDescendantOf(workspace)
					and (not casterHumanoid or casterHumanoid.Health > 0)
				local viewerPresent = not effect.ViewerUserId or Players:GetPlayerByUserId(effect.ViewerUserId) ~= nil
				if
					effect.OnTargetDeath
					and not EffectSpec.isExpired(
						effect.Kind,
						effect.ExpiresAt,
						effect.Remaining,
						now,
						casterAlive,
						viewerPresent
					)
				then
					local sourceSpells = seen[effect.Caster]
					if not sourceSpells then
						sourceSpells = {}
						seen[effect.Caster] = sourceSpells
					end
					if not sourceSpells[effect.SpellId] then
						sourceSpells[effect.SpellId] = true
						table.insert(callbacks, effect.OnTargetDeath)
					end
				end
			end
			for _, callback in callbacks do
				task.defer(callback, humanoid)
			end
			Status.clear(humanoid)
		end),
		humanoid.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				Status.clear(humanoid)
			end
		end),
	}
	return state
end

local function removeState(state: TargetState)
	if targets[state.Humanoid] ~= state then
		return
	end
	targets[state.Humanoid] = nil
	for i = #active, 1, -1 do
		if active[i] == state then
			table.remove(active, i)
			break
		end
	end
	for _, connection in state.Connections do
		connection:Disconnect()
	end
	restoreTransform(state)
	local model = state.Humanoid.Parent
	if model and model:IsA("Model") then
		for attribute in state.RevealAttributes do
			model:SetAttribute(attribute, nil)
			model:SetAttribute(string.gsub(attribute, "Until", "Color"), nil)
		end
		if next(state.RevealAttributes) then
			CollectionService:RemoveTag(model, "MagicRevealedTarget")
		end
	end
	Movement.setMagicSlow(state.Humanoid, speedFactors[state.Humanoid] or 1)
	setAttribute(state.Humanoid, if model and model:IsA("Model") then model else nil, "MagicShield", 0)
	for _, attribute in AttributeSpec.Order do
		if AttributeSpec.requiresElement(attribute) then
			for _, element in AttributeSpec.Elements do
				setAttribute(
					state.Humanoid,
					if model and model:IsA("Model") then model else nil,
					AttributeSpec.attributeName(attribute, element),
					0
				)
			end
		else
			setAttribute(
				state.Humanoid,
				if model and model:IsA("Model") then model else nil,
				AttributeSpec.attributeName(attribute),
				0
			)
		end
	end
	setAttribute(state.Humanoid, if model and model:IsA("Model") then model else nil, "MagicMovementBound", false)
	setAttribute(state.Humanoid, if model and model:IsA("Model") then model else nil, "MagicStunned", false)
	setAttribute(state.Humanoid, if model and model:IsA("Model") then model else nil, "MagicSilenced", false)
	setAttribute(state.Humanoid, if model and model:IsA("Model") then model else nil, "MagicStealthed", false)
	if model and model:IsA("Model") then
		local forced = model:FindFirstChild("MagicForcedTarget")
		if forced then
			forced:Destroy()
		end
		model:SetAttribute("MagicForcedTargetUntil", nil)
		model:SetAttribute("MagicFearSource", nil)
		model:SetAttribute("MagicFearUntil", nil)
	end
	setAttribute(state.Humanoid, if model and model:IsA("Model") then model else nil, "MagicShieldExpiresAt", nil)
	setAttribute(
		state.Humanoid,
		if model and model:IsA("Model") then model else nil,
		"MagicSlowMultiplier",
		speedFactors[state.Humanoid] or 1
	)
	setAttribute(state.Humanoid, if model and model:IsA("Model") then model else nil, "MagicTimeRate", 1)
	setAttribute(state.Humanoid, if model and model:IsA("Model") then model else nil, "MagicElementalMarks", nil)
end

local function refreshAttributes(state: TargetState)
	local now = os.clock()
	for index = #state.Effects, 1, -1 do
		local effect = state.Effects[index]
		if
			effect.RequiredElementalMark
			and ElementalMarkSpec.stackCount(state.Effects, effect.RequiredElementalMark, now) <= 0
		then
			table.remove(state.Effects, index)
		end
	end
	local shield = 0
	local timeRate = TemporalRate.combine(state.Effects, now)
	local slow = MovementEffects.multiplier(state.Effects, now) * (speedFactors[state.Humanoid] or 1)
	local movementMultiplier = math.clamp(slow * timeRate, 0, TemporalRate.Maximum)
	local bound = movementMultiplier <= 0
	local earliestShield: number? = nil
	local reveals = RevealSpec.aggregate(state.Effects, now)
	local elementalMarks = ElementalMarkSpec.encode(state.Effects, now)
	local transformScale = TransformationSpec.aggregate(state.Effects, now)
	for _, effect in state.Effects do
		if effect.Kind == "Shield" then
			shield += effect.Amount or 0
			earliestShield = if earliestShield then math.min(earliestShield, effect.ExpiresAt) else effect.ExpiresAt
		end
	end
	local model = state.Humanoid.Parent
	local parentModel = if model and model:IsA("Model") then model else nil
	if state.TransformModel and state.OriginalScale and state.TransformModel:IsDescendantOf(workspace) then
		local targetScale = state.OriginalScale * transformScale
		if math.abs(targetScale - (state.AppliedScale or state.OriginalScale)) > 0.001 then
			local ok = pcall(function()
				state.TransformModel:ScaleTo(targetScale)
			end)
			if ok then
				state.AppliedScale = targetScale
			end
		end
	end
	local currentRevealAttributes: { [string]: boolean } = {}
	if parentModel then
		for userId, reveal in reveals do
			local untilAttribute, colorAttribute = RevealSpec.attributeNames(userId)
			local serverExpiry = workspace:GetServerTimeNow() + reveal.ExpiresAt - now
			local currentExpiry = parentModel:GetAttribute(untilAttribute)
			if type(currentExpiry) ~= "number" or math.abs(currentExpiry - serverExpiry) > 0.05 then
				parentModel:SetAttribute(untilAttribute, serverExpiry)
			end
			if parentModel:GetAttribute(colorAttribute) ~= reveal.Color then
				parentModel:SetAttribute(colorAttribute, reveal.Color)
			end
			currentRevealAttributes[untilAttribute] = true
		end
		for attribute in state.RevealAttributes do
			if not currentRevealAttributes[attribute] then
				parentModel:SetAttribute(attribute, nil)
				parentModel:SetAttribute(string.gsub(attribute, "Until", "Color"), nil)
			end
		end
		if next(currentRevealAttributes) then
			CollectionService:AddTag(parentModel, "MagicRevealedTarget")
		else
			CollectionService:RemoveTag(parentModel, "MagicRevealedTarget")
		end
		state.RevealAttributes = currentRevealAttributes
	end
	setAttribute(state.Humanoid, parentModel, "MagicShield", shield)
	-- Every ModifyAttribute bonus, e.g. MagicArmorBonus, CastSpeedBonus, MagicResistanceFireBonus.
	for _, attribute in AttributeSpec.Order do
		if AttributeSpec.requiresElement(attribute) then
			for _, element in AttributeSpec.Elements do
				setAttribute(
					state.Humanoid,
					parentModel,
					AttributeSpec.attributeName(attribute, element),
					AttributeSpec.aggregate(state.Effects, attribute, now, element)
				)
			end
		else
			setAttribute(
				state.Humanoid,
				parentModel,
				AttributeSpec.attributeName(attribute),
				AttributeSpec.aggregate(state.Effects, attribute, now)
			)
		end
	end
	setAttribute(state.Humanoid, parentModel, "MagicMovementBound", bound)
	-- Read by ActionRouter (player melee and casts), EnemyService, SummonService
	-- and MagicService (channel cancel); see MagicCrowdControlSpec.blocks.
	local stunned, silenced, stealthed = false, false, false
	for _, effect in state.Effects do
		if effect.ExpiresAt > now then
			stunned = stunned or effect.Kind == "Stun"
			silenced = silenced or effect.Kind == "Silence"
			stealthed = stealthed or effect.Kind == "Stealth"
		end
	end
	-- Read by EnemyService's target scan (MagicStealthSpec) and the client.
	setAttribute(state.Humanoid, parentModel, "MagicStealthed", stealthed)
	setAttribute(state.Humanoid, parentModel, "MagicStunned", stunned)
	setAttribute(state.Humanoid, parentModel, "MagicSilenced", silenced)
	-- Taunt / Fear: NPCs only, written on the model for EnemyService
	-- (MagicControlStateSpec). The longest-lasting effect of each kind decides.
	if parentModel and not Players:GetPlayerFromCharacter(parentModel) then
		local taunts, fears = {}, {}
		for _, effect in state.Effects do
			if effect.Kind == "Taunt" then
				table.insert(taunts, effect)
			elseif effect.Kind == "Fear" then
				table.insert(fears, effect)
			end
		end
		local serverNow = workspace:GetServerTimeNow()
		local taunt = ControlState.strongest(taunts, now)
		local forced = parentModel:FindFirstChild("MagicForcedTarget")
		if taunt then
			if not forced or not forced:IsA("ObjectValue") then
				forced = Instance.new("ObjectValue")
				forced.Name = "MagicForcedTarget"
				forced.Parent = parentModel
			end
			(forced :: ObjectValue).Value = taunt.Caster
			parentModel:SetAttribute("MagicForcedTargetUntil", serverNow + taunt.ExpiresAt - now)
		else
			if forced then
				forced:Destroy()
			end
			parentModel:SetAttribute("MagicForcedTargetUntil", nil)
		end
		local fear = ControlState.strongest(fears, now)
		if fear then
			local root = fear.Caster:FindFirstChild("HumanoidRootPart")
			parentModel:SetAttribute("MagicFearSource", if root and root:IsA("BasePart") then root.Position else nil)
			parentModel:SetAttribute("MagicFearUntil", serverNow + fear.ExpiresAt - now)
		else
			parentModel:SetAttribute("MagicFearSource", nil)
			parentModel:SetAttribute("MagicFearUntil", nil)
		end
	end
	local expiresAt = if earliestShield then workspace:GetServerTimeNow() + earliestShield - os.clock() else nil
	setAttribute(state.Humanoid, parentModel, "MagicShieldExpiresAt", expiresAt)
	setAttribute(state.Humanoid, parentModel, "MagicSlowMultiplier", slow)
	setAttribute(state.Humanoid, parentModel, "MagicTimeRate", timeRate)
	setAttribute(state.Humanoid, parentModel, "MagicElementalMarks", elementalMarks)
	Movement.setMagicSlow(state.Humanoid, movementMultiplier)
end

-- Reaction state for a target: element marks, and "Frozen" (an active Stun
-- applied by the Freeze reaction).
local FROZEN_SPELL = "Reaction:Freeze"
local function hasReactionState(state: TargetState, name: string, now: number): boolean
	if name == "Frozen" then
		for _, effect in state.Effects do
			if effect.Kind == "Stun" and effect.SpellId == FROZEN_SPELL and effect.ExpiresAt > now then
				return true
			end
		end
		return false
	end
	return ElementalMarkSpec.stackCount(state.Effects, name, now) > 0
end

-- Finds the reaction `incoming` (an element, or "Force") triggers on this
-- target, consumes what it uses (Existing stacks, or the Freeze for Shatter)
-- and records it for the Status.Reaction condition. Returns the reaction or nil.
function Status.checkReaction(humanoid: Humanoid, incoming: string): any?
	local state = targets[humanoid]
	if not state then
		return nil
	end
	local now = os.clock()
	local reaction = Interactions.findReaction(incoming, function(name)
		return hasReactionState(state, name, now)
	end)
	if not reaction then
		return nil
	end
	if reaction.Existing == "Frozen" then
		for index = #state.Effects, 1, -1 do
			local effect = state.Effects[index]
			if effect.Kind == "Stun" and effect.SpellId == FROZEN_SPELL then
				table.remove(state.Effects, index)
			end
		end
	elseif reaction.ConsumeStacks then
		ElementalMarkSpec.consume(state.Effects, reaction.Existing, reaction.ConsumeStacks, now)
	end
	local model = humanoid.Parent
	setAttribute(humanoid, if model and model:IsA("Model") then model else nil, "MagicLastReaction", reaction.Name)
	setAttribute(
		humanoid,
		if model and model:IsA("Model") then model else nil,
		"MagicLastReactionAt",
		workspace:GetServerTimeNow()
	)
	-- Refresh only: elementalMark may still stack onto this state. An empty
	-- state is cleared by the regular sweep.
	refreshAttributes(state)
	return reaction
end

-- Toxic smoke: areas where Reveal cannot land.
local concealments: { { Position: Vector3, Radius: number, ExpiresAt: number } } = {}

function Status.addConcealment(position: Vector3, radius: number, duration: number)
	local now = os.clock()
	for index = #concealments, 1, -1 do
		if concealments[index].ExpiresAt <= now then
			table.remove(concealments, index)
		end
	end
	table.insert(concealments, { Position = position, Radius = radius, ExpiresAt = now + duration })
end

function Status.isConcealed(humanoid: Humanoid): boolean
	local model = humanoid.Parent
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local now = os.clock()
	for _, zone in concealments do
		if zone.ExpiresAt > now and (root.Position - zone.Position).Magnitude <= zone.Radius then
			return true
		end
	end
	return false
end

function Status.elementalMark(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	element: string,
	stacks: number,
	duration: number,
	allowReaction: boolean?
): (boolean, any?)
	if
		not DamageRules.KnownElements[element]
		or element == "Neutral"
		or type(stacks) ~= "number"
		or stacks ~= stacks
		or stacks % 1 ~= 0
		or stacks < 1
		or type(duration) ~= "number"
		or duration ~= duration
		or humanoid.Health <= 0
		or not humanoid:IsDescendantOf(workspace)
		or not caster:IsDescendantOf(workspace)
	then
		return false
	end
	local state = getState(humanoid, true)
	if not state then
		return false
	end
	local now = os.clock()
	-- Reactions are checked when the mark lands, before it stacks. One per
	-- landing; marks applied by a reaction pass allowReaction = false.
	local reaction = if allowReaction == false then nil else Status.checkReaction(humanoid, element)
	for index = #state.Effects, 1, -1 do
		local effect = state.Effects[index]
		if
			effect.Kind == "ElementalMark"
			and ElementalMarkSpec.stackCount({ effect }, effect.Element or "", now) == 0
		then
			table.remove(state.Effects, index)
		end
	end
	local safeDuration = math.clamp(duration, 0.1, Limits.MaxDuration)
	local timeRate = TemporalRate.combine(state.Effects, now)
	local expiresAt = now + TemporalRate.worldDuration(safeDuration, timeRate)
	local candidate: Effect = {
		Kind = "ElementalMark",
		Element = element,
		Stacks = stacks,
		Caster = caster,
		SpellId = spellId,
		Polarity = polarityOf("ElementalMark"),
		ExpiresAt = expiresAt,
		Remaining = safeDuration,
		LastUpdateAt = now,
	}
	if
		not ElementalMarkSpec.apply(
			state.Effects,
			candidate,
			Limits.MaxElementalMarkStacks,
			now,
			Limits.MaxEffectsPerTarget
		)
	then
		if #state.Effects == 0 then
			removeState(state)
		end
		return false, reaction
	end
	refreshAttributes(state)
	return true, reaction
end

function Status.consumeElementalMark(humanoid: Humanoid, element: string, stacks: number): number
	local state = targets[humanoid]
	if not state or not DamageRules.KnownElements[element] or element == "Neutral" then
		return 0
	end
	local consumed = ElementalMarkSpec.consume(state.Effects, element, math.max(0, math.floor(stacks)), os.clock())
	if consumed > 0 then
		refreshAttributes(state)
		if #state.Effects == 0 then
			removeState(state)
		end
	end
	return consumed
end

function Status.elementalMarkStacks(humanoid: Humanoid, element: string?): number
	local state = targets[humanoid]
	if not state or type(element) ~= "string" then
		return 0
	end
	return ElementalMarkSpec.stackCount(state.Effects, element, os.clock())
end

function Status.hasElementalMark(humanoid: Humanoid, element: string): boolean
	local state = targets[humanoid]
	return state ~= nil and ElementalMarkSpec.stackCount(state.Effects, element, os.clock()) > 0
end

local function sameSource(effect: Effect, caster: Model, spellId: string, kind: string, attribute: string?): boolean
	return effect.Caster == caster
		and effect.SpellId == spellId
		and effect.Kind == kind
		and effect.Attribute == attribute
end

local function putEffect(
	humanoid: Humanoid,
	caster: Model,
	spellId: string,
	kind: string,
	duration: number,
	amount: number?,
	multiplier: number?,
	onBreak: ((Humanoid) -> ())?,
	attribute: string?,
	viewerUserId: number?,
	color: Color3?,
	onTargetDeath: ((Humanoid) -> ())?,
	requiredElementalMark: string?,
	element: string?
): boolean
	if humanoid.Health <= 0 or not humanoid:IsDescendantOf(workspace) or not caster:IsDescendantOf(workspace) then
		return false
	end
	local state = getState(humanoid, true)
	if not state then
		return false
	end
	local now = os.clock()
	local safeDuration = math.clamp(duration, 0.1, Limits.MaxDuration)
	local timeRate = TemporalRate.combine(state.Effects, now)
	local expiresAt = now
		+ if kind == "TimeDilation" then safeDuration else TemporalRate.worldDuration(safeDuration, timeRate)
	for index, effect in state.Effects do
		if
			sameSource(effect, caster, spellId, kind, attribute)
			and effect.RequiredElementalMark == requiredElementalMark
		then
			effect.ExpiresAt = expiresAt
			effect.Remaining = if kind == "TimeDilation" then nil else safeDuration
			effect.LastUpdateAt = if kind == "TimeDilation" then nil else now
			if kind == "Shield" then
				effect.OnBreak = onBreak
				local otherShield = 0
				for _, other in state.Effects do
					if other ~= effect and other.Kind == "Shield" then
						otherShield += other.Amount or 0
					end
				end
				effect.Amount = math.min(
					math.max(effect.Amount or 0, amount or 0),
					math.max(0, Limits.MaxShieldPerTarget - otherShield)
				)
				if (effect.Amount or 0) <= 0 then
					table.remove(state.Effects, index)
					if #state.Effects == 0 then
						removeState(state)
					else
						refreshAttributes(state)
					end
					return false
				end
			elseif kind == "ModifyAttribute" then
				effect.Amount = amount
				effect.Attribute = attribute
				effect.Element = element
			elseif kind == "Transformation" then
				effect.Multiplier = multiplier
			elseif kind == "Reveal" then
				effect.ViewerUserId = viewerUserId
				effect.Color = color
			else
				effect.Multiplier = multiplier
			end
			effect.OnTargetDeath = onTargetDeath
			refreshAttributes(state)
			return true
		end
	end
	if #state.Effects >= Limits.MaxEffectsPerTarget then
		return false
	end
	if kind == "Transformation" then
		local model = humanoid.Parent
		if not model or not model:IsA("Model") or not captureTransformBaseline(state, model) then
			return false
		end
	end
	local totalShield = 0
	for _, effect in state.Effects do
		if effect.Kind == "Shield" then
			totalShield += effect.Amount or 0
		end
	end
	if kind == "Shield" then
		amount = math.min(amount or 0, math.max(0, Limits.MaxShieldPerTarget - totalShield))
		if amount <= 0 then
			return false
		end
	end
	table.insert(state.Effects, {
		Kind = kind,
		Attribute = attribute,
		Caster = caster,
		SpellId = spellId,
		Polarity = polarityOf(kind),
		ExpiresAt = expiresAt,
		Remaining = if kind == "TimeDilation" then nil else safeDuration,
		LastUpdateAt = if kind == "TimeDilation" then nil else now,
		Amount = amount,
		Multiplier = multiplier,
		OnBreak = onBreak,
		ViewerUserId = viewerUserId,
		Color = color,
		OnTargetDeath = onTargetDeath,
		RequiredElementalMark = requiredElementalMark,
		Multiplier = multiplier,
		Element = element,
	})
	refreshAttributes(state)
	return true
end

-- `cap` (optional): a final per-hit cap such as the PvP MaxHealPerHit.
function Status.heal(caster: Model, humanoid: Humanoid, amount: number, cap: number?): number
	if humanoid.Health <= 0 or not humanoid:IsDescendantOf(workspace) or not caster:IsDescendantOf(workspace) then
		return 0
	end
	local before = humanoid.Health
	-- HealingReceived scales every heal, including Restoration ticks.
	local received = amount * AttributeSpec.multiplier(humanoid, "HealingReceived")
	local limit = if cap then math.min(cap, Limits.MaxHeal) else Limits.MaxHeal
	humanoid.Health = math.min(humanoid.MaxHealth, before + math.clamp(received, 0, limit))
	return math.max(0, humanoid.Health - before)
end

function Status.shield(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	amount: number,
	duration: number,
	onBreak: ((Humanoid) -> ())?,
	onTargetDeath: ((Humanoid) -> ())?
): boolean
	return putEffect(
		humanoid,
		caster,
		spellId,
		"Shield",
		duration,
		math.clamp(amount, 0, Limits.MaxShield),
		nil,
		onBreak,
		nil,
		nil,
		nil,
		onTargetDeath
	)
end

function Status.slow(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	multiplier: number,
	duration: number,
	onTargetDeath: ((Humanoid) -> ())?,
	requiredElementalMark: string?
): boolean
	return putEffect(
		humanoid,
		caster,
		spellId,
		"Slow",
		duration,
		nil,
		math.clamp(multiplier, Limits.MinSlowMultiplier, 1),
		nil,
		nil,
		nil,
		nil,
		onTargetDeath,
		requiredElementalMark
	)
end

function Status.temporalRate(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	multiplier: number,
	duration: number,
	onTargetDeath: ((Humanoid) -> ())?
): boolean
	return putEffect(
		humanoid,
		caster,
		spellId,
		"TimeDilation",
		duration,
		nil,
		TemporalRate.clamp(multiplier),
		nil,
		nil,
		nil,
		nil,
		onTargetDeath
	)
end

function Status.timeRate(humanoid: Humanoid): number
	local state = targets[humanoid]
	return if state then TemporalRate.combine(state.Effects, os.clock()) else 1
end

function Status.bind(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	duration: number,
	onTargetDeath: ((Humanoid) -> ())?
): boolean
	return putEffect(
		humanoid,
		caster,
		spellId,
		"Bind",
		math.min(duration, Limits.MaxBindDuration),
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		onTargetDeath
	)
end

-- Stun diminishing returns per target (MagicCrowdControlSpec.applyStun).
local stunHistory: { [Humanoid]: any } = setmetatable({}, { __mode = "k" }) :: any

function Status.stun(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	duration: number,
	onTargetDeath: ((Humanoid) -> ())?,
	requiredElementalMark: string?
): boolean
	if humanoid.Health <= 0 then
		return false
	end
	local history = stunHistory[humanoid]
	if not history then
		history = CrowdControl.newHistory()
		stunHistory[humanoid] = history
	end
	local effective = CrowdControl.applyStun(history, os.clock(), math.min(duration, Limits.MaxStunDuration))
	if effective <= 0 then
		return false -- immune (third stun inside the window)
	end
	return putEffect(
		humanoid,
		caster,
		spellId,
		"Stun",
		effective,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		onTargetDeath,
		requiredElementalMark
	)
end

-- Shared diminishing returns for Stun-like crowd control (Polymorph): returns
-- the duration to apply, 0 when the target is immune.
function Status.diminish(humanoid: Humanoid, duration: number): number
	local history = stunHistory[humanoid]
	if not history then
		history = CrowdControl.newHistory()
		stunHistory[humanoid] = history
	end
	return CrowdControl.applyStun(history, os.clock(), duration)
end

-- A walk-speed factor kept beside the timed statuses (1 or nil clears it).
function Status.setSpeedFactor(humanoid: Humanoid, factor: number?)
	speedFactors[humanoid] = if factor and factor ~= 1 then factor else nil
	local state = targets[humanoid]
	if state then
		refreshAttributes(state)
	else
		local model = humanoid.Parent
		Movement.setMagicSlow(humanoid, speedFactors[humanoid] or 1)
		setAttribute(
			humanoid,
			if model and model:IsA("Model") then model else nil,
			"MagicSlowMultiplier",
			speedFactors[humanoid] or 1
		)
	end
end

-- Taunt / Fear: creatures only; a player target is never affected.
local function npcControl(
	kind: string,
	limit: number,
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	duration: number,
	onTargetDeath: ((Humanoid) -> ())?,
	requiredElementalMark: string?
): boolean
	local model = humanoid.Parent
	if not model or Players:GetPlayerFromCharacter(model) then
		return false
	end
	return putEffect(
		humanoid,
		caster,
		spellId,
		kind,
		math.min(duration, limit),
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		onTargetDeath,
		requiredElementalMark
	)
end

function Status.taunt(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	duration: number,
	onTargetDeath: ((Humanoid) -> ())?,
	requiredElementalMark: string?
): boolean
	return npcControl(
		"Taunt",
		Limits.MaxTauntDuration,
		caster,
		humanoid,
		spellId,
		duration,
		onTargetDeath,
		requiredElementalMark
	)
end

function Status.fear(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	duration: number,
	onTargetDeath: ((Humanoid) -> ())?,
	requiredElementalMark: string?
): boolean
	return npcControl(
		"Fear",
		Limits.MaxFearDuration,
		caster,
		humanoid,
		spellId,
		duration,
		onTargetDeath,
		requiredElementalMark
	)
end

function Status.stealth(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	duration: number,
	onTargetDeath: ((Humanoid) -> ())?,
	requiredElementalMark: string?
): boolean
	return putEffect(
		humanoid,
		caster,
		spellId,
		"Stealth",
		math.min(duration, Limits.MaxStealthDuration),
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		onTargetDeath,
		requiredElementalMark
	)
end

-- Stealth ends early when the holder deals damage or is Revealed.
function Status.breakStealth(humanoid: Humanoid): boolean
	return Status.removeWhere(humanoid, function(effect)
		return effect.Kind == "Stealth"
	end) > 0
end

function Status.silence(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	duration: number,
	onTargetDeath: ((Humanoid) -> ())?,
	requiredElementalMark: string?
): boolean
	return putEffect(
		humanoid,
		caster,
		spellId,
		"Silence",
		math.min(duration, Limits.MaxSilenceDuration),
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		onTargetDeath,
		requiredElementalMark
	)
end

-- Cleanse candidates among this target's timed statuses, in the shape
-- MagicCrowdControlSpec.select expects; Remove() takes one off.
function Status.cleanseCandidates(humanoid: Humanoid): { any }
	local state = targets[humanoid]
	local candidates = {}
	if not state then
		return candidates
	end
	local now = os.clock()
	for _, effect in state.Effects do
		if effect.ExpiresAt > now then
			table.insert(candidates, {
				Source = "Status",
				Polarity = effect.Polarity,
				Element = effect.Element,
				Remaining = effect.ExpiresAt - now,
				AppliedAt = effect.LastUpdateAt or 0,
				Remove = function()
					Status.removeWhere(humanoid, function(candidate)
						return candidate == effect
					end, 1)
				end,
			})
		end
	end
	return candidates
end

-- Removes up to `count` timed statuses for which `predicate(effect)` is true,
-- then refreshes the target's replicated attributes. Returns how many.
function Status.removeWhere(humanoid: Humanoid, predicate: (Effect) -> boolean, count: number?): number
	local state = targets[humanoid]
	if not state then
		return 0
	end
	local removed = 0
	for index = #state.Effects, 1, -1 do
		if count and removed >= count then
			break
		end
		if predicate(state.Effects[index]) then
			table.remove(state.Effects, index)
			removed += 1
		end
	end
	if removed > 0 then
		if #state.Effects == 0 then
			removeState(state)
		else
			refreshAttributes(state)
		end
	end
	return removed
end

function Status.reveal(
	viewer: Player,
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	duration: number,
	color: Color3,
	onTargetDeath: ((Humanoid) -> ())?
): boolean
	if Status.isConcealed(humanoid) then
		return false -- inside Toxic smoke
	end
	Status.breakStealth(humanoid) -- a Reveal ends Stealth
	return putEffect(
		humanoid,
		caster,
		spellId,
		"Reveal",
		math.min(duration, Limits.MaxRevealDuration, Limits.MaxDuration),
		nil,
		nil,
		nil,
		nil,
		viewer.UserId,
		color,
		onTargetDeath
	)
end

function Status.modifyAttribute(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	attribute: string,
	amount: number,
	duration: number,
	onTargetDeath: ((Humanoid) -> ())?,
	requiredElementalMark: string?,
	element: string?
): boolean
	local safeAmount = AttributeSpec.clamp(attribute, amount)
	if safeAmount == nil then
		return false
	end
	-- Resistance needs a real element; every other attribute must not carry one.
	if AttributeSpec.requiresElement(attribute) then
		if not AttributeSpec.validElement(element) then
			return false
		end
	else
		element = nil
	end
	return putEffect(
		humanoid,
		caster,
		spellId,
		"ModifyAttribute",
		duration,
		safeAmount,
		nil,
		nil,
		attribute,
		nil,
		nil,
		onTargetDeath,
		requiredElementalMark,
		element
	)
end

function Status.transform(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	multiplier: number,
	duration: number,
	onTargetDeath: ((Humanoid) -> ())?
): boolean
	local scale = TransformationSpec.clampScale(multiplier)
	if scale == nil then
		return false
	end
	local model = humanoid.Parent
	if not model or not model:IsA("Model") then
		return false
	end
	local state = getState(humanoid, true)
	if not state or not captureTransformBaseline(state, model) then
		return false
	end
	return putEffect(
		humanoid,
		caster,
		spellId,
		"Transformation",
		duration,
		nil,
		scale,
		nil,
		nil,
		nil,
		nil,
		nil,
		onTargetDeath
	)
end

function Status.absorb(humanoid: Humanoid, amount: number): (number, number, { Effect })
	local state = targets[humanoid]
	if not state or amount <= 0 then
		return amount, 0, {}
	end
	local now = os.clock()
	for i = #state.Effects, 1, -1 do
		if state.Effects[i].ExpiresAt <= now then
			table.remove(state.Effects, i)
		end
	end
	-- Spend the soonest-expiring shield first so refreshes remain intuitive.
	table.sort(state.Effects, function(a, b)
		if a.Kind ~= "Shield" then
			return false
		elseif b.Kind ~= "Shield" then
			return true
		end
		return a.ExpiresAt < b.ExpiresAt
	end)
	local remaining, absorbed, broken = ShieldPool.consume(state.Effects, amount)
	for i = #state.Effects, 1, -1 do
		local effect = state.Effects[i]
		if effect.Kind == "Shield" and (effect.Amount or 0) <= 0 then
			table.remove(state.Effects, i)
		end
	end
	refreshAttributes(state)
	if #state.Effects == 0 then
		removeState(state)
	end
	return remaining, absorbed, broken
end

function Status.clear(humanoid: Humanoid)
	local state = targets[humanoid]
	if state then
		removeState(state)
	end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastSweep < 0.2 then
		return
	end
	lastSweep = now
	for i = #active, 1, -1 do
		local state = active[i]
		local humanoid = state.Humanoid
		if not humanoid:IsDescendantOf(workspace) or humanoid.Health <= 0 then
			removeState(state)
		else
			for j = #state.Effects, 1, -1 do
				local effect = state.Effects[j]
				if effect.Kind == "TimeDilation" then
					local casterHumanoid = effect.Caster:FindFirstChildOfClass("Humanoid")
					local casterAlive = effect.Caster:IsDescendantOf(workspace)
						and (not casterHumanoid or casterHumanoid.Health > 0)
					local viewerPresent = not effect.ViewerUserId
						or Players:GetPlayerByUserId(effect.ViewerUserId) ~= nil
					if
						EffectSpec.isExpired(
							effect.Kind,
							effect.ExpiresAt,
							effect.Remaining,
							now,
							casterAlive,
							viewerPresent
						)
					then
						table.remove(state.Effects, j)
					end
				end
			end
			local timeRate = TemporalRate.combine(state.Effects, now)
			for j = #state.Effects, 1, -1 do
				local effect = state.Effects[j]
				local casterAlive = effect.Caster:IsDescendantOf(workspace)
				local casterHumanoid = effect.Caster:FindFirstChildOfClass("Humanoid")
				if casterHumanoid and casterHumanoid.Health <= 0 then
					casterAlive = false
				end
				local viewerPresent = not effect.ViewerUserId or Players:GetPlayerByUserId(effect.ViewerUserId) ~= nil
				if effect.Kind ~= "TimeDilation" then
					local elapsed = math.max(0, now - (effect.LastUpdateAt or now))
					effect.Remaining = TemporalRate.advance(effect.Remaining or 0, elapsed, timeRate)
					effect.LastUpdateAt = now
					effect.ExpiresAt = now + TemporalRate.worldDuration(effect.Remaining, timeRate)
				end
				if
					EffectSpec.isExpired(
						effect.Kind,
						effect.ExpiresAt,
						effect.Remaining,
						now,
						casterAlive,
						viewerPresent
					)
				then
					table.remove(state.Effects, j)
				end
			end
			if #state.Effects == 0 then
				removeState(state)
			else
				refreshAttributes(state)
			end
		end
	end
end)

return Status
