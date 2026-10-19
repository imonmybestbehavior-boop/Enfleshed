--!strict

-- Small registry for payload kinds the runtime currently supports. Context is
-- supplied by MagicService so executors remain neutral about spell identities.
local Damage = require(script.Parent.DamageService)
local Movement = require(script.Parent.MovementService)
local Status = require(script.Parent.MagicStatusEffectService)
local Control = require(script.Parent.MagicControlService)
local Ownership = require(script.Parent.MagicPhysicsOwnership)

local AttributeSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicAttributeSpec)
local MagicLab = require(game:GetService("ReplicatedStorage").Shared.Configuration.MagicLab)
local TemporalRate = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicTemporalRate)
local BodyRegion = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicBodyRegionSpec)
local ElementalInteractions = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicElementalInteractionSpec)
local CombatPolicy = require(game:GetService("ReplicatedStorage").Shared.Modules.CombatPolicy)
local StatCaps = require(game:GetService("ReplicatedStorage").Shared.Modules.SpellStatCaps)
local CapProfiles = require(game:GetService("ReplicatedStorage").Shared.Configuration.SpellStatCaps)
local Schema = require(game:GetService("ReplicatedStorage").Shared.Configuration.MagicSchema)
local ScaleSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicScaleSpec)
local Players = game:GetService("Players")
local Payloads = {}
local periodicEffects = {}
local RunService = game:GetService("RunService")

local function setPeriodicDeathCallback(effect, callback)
	if effect.DeathConnection then
		effect.DeathConnection:Disconnect()
		effect.DeathConnection = nil
	end
	effect.TargetDeathCallback = callback
	if callback then
		effect.DeathConnection = effect.Target.Died:Connect(function()
			local casterHumanoid = effect.Caster:FindFirstChildOfClass("Humanoid")
			local elapsed = math.max(0, os.clock() - (effect.LastUpdateAt or os.clock()))
			local remaining = TemporalRate.advance(effect.Remaining or 0, elapsed, Status.timeRate(effect.Target))
			if
				remaining <= 0
				or not casterHumanoid
				or casterHumanoid.Health <= 0
				or not effect.Caster:IsDescendantOf(workspace)
			then
				return
			end
			-- Let DamageService's synchronous KilledByThisSpell event claim this
			-- same death before the deferred DiedWhileAffected event is considered.
			task.defer(callback)
		end)
	end
end

local function removePeriodicEffect(index)
	local effect = periodicEffects[index]
	if effect and effect.DeathConnection then
		effect.DeathConnection:Disconnect()
		effect.DeathConnection = nil
	end
	table.remove(periodicEffects, index)
end

-- Brief server simulation for player-owned impulse targets; no control lock or stun.
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for i = #periodicEffects, 1, -1 do
		local effect = periodicEffects[i]
		local casterHumanoid = effect.Caster:FindFirstChildOfClass("Humanoid")
		if
			not effect.Caster:IsDescendantOf(workspace)
			or not casterHumanoid
			or casterHumanoid.Health <= 0
			or not effect.Target:IsDescendantOf(workspace)
			or effect.Target.Health <= 0
			or (
				effect.RequiredElementalMark
				and not Status.hasElementalMark(effect.Target, effect.RequiredElementalMark)
			)
		then
			removePeriodicEffect(i)
		else
			local elapsed = math.max(0, now - (effect.LastUpdateAt or now))
			local rate = Status.timeRate(effect.Target)
			effect.Remaining = TemporalRate.advance(effect.Remaining or 0, elapsed, rate)
			effect.UntilNext = TemporalRate.advance(effect.UntilNext or effect.Interval, elapsed, rate)
			effect.LastUpdateAt = now
			local due = effect.UntilNext <= 0
			if due and (effect.Remaining > 0 or -effect.Remaining <= effect.Interval * rate) then
				if effect.Kind == "DamageOverTime" then
					local dealt, absorbed =
						Damage.apply(effect.Caster, effect.Target, effect.Amount, effect.DamageContext)
					if dealt > 0 then
						effect.Feedback(effect.Target, dealt)
					end
					if absorbed > 0 then
						effect.EffectFeedback("Shield", effect.Target, absorbed)
					end
				else
					local restored = Status.heal(effect.Caster, effect.Target, effect.Amount)
					if restored > 0 then
						effect.EffectFeedback("Heal", effect.Target, restored)
					end
				end
			end
			if due then
				local overdue = math.max(0, -effect.UntilNext)
				effect.UntilNext += effect.Interval * (math.floor(overdue / effect.Interval) + 1)
			end
			if effect.Remaining <= 0 then
				removePeriodicEffect(i)
			end
		end
	end
end)
local function applyForce(root, velocity)
	if root.Anchored or root.AssemblyMass == math.huge then
		return
	end
	local token = {}
	Ownership.claim(root, token)
	task.delay(0.2, function()
		Ownership.release(root, token)
	end)
	Movement.allowMagicImpulse(root, velocity)
	root:ApplyImpulse(velocity * root.AssemblyMass)
end

-- Authored amount -> ScaleBy (per target) -> potency (Locus x charge). Final
-- caps come later: DamageService for damage, Status.heal for healing.
local function scaledAmount(payload, context, humanoid): number
	local amount = payload.Amount
	if payload.ScaleBy and context.ScaleRead then
		local units = ScaleSpec.units(payload.ScaleBy, function(source, element)
			return context.ScaleRead(source, humanoid, element)
		end)
		amount = ScaleSpec.amount(amount, payload.ScaleBy, units)
	end
	return amount * context.Potency
end

local function payloadDamageContext(payload, context, target)
	if not context.DamageContext then
		return nil
	end
	local damageContext = table.clone(context.DamageContext)
	damageContext.DamageChannel = payload.DamageChannel or "Elemental"
	local targetModel = target and target.Parent
	local hitPart = damageContext.HitPart
	if
		typeof(hitPart) ~= "Instance"
		or not hitPart:IsA("BasePart")
		or not targetModel
		or not hitPart:IsDescendantOf(targetModel)
	then
		hitPart = targetModel and targetModel:FindFirstChild("HumanoidRootPart") or nil
	end
	local region, multiplier = BodyRegion.multiplier(payload, hitPart and hitPart.Name)
	damageContext.HitPart = hitPart
	damageContext.DamageRegion = region
	damageContext.RegionMultiplier = multiplier
	-- PvP per-tick cap for damage over time, applied last in DamageService.
	if payload.Kind == "DamageOverTime" and context.CapProfile then
		damageContext.PerHitCap = context.CapProfile.MaxDotPerTick
	end
	return damageContext
end

local function displacementDirection(payload, context, targetRoot)
	local casterRoot = context.Caster:FindFirstChild("HumanoidRootPart")
	local direction
	if payload.Mode == "TowardCaster" or payload.Mode == "AwayFromCaster" then
		if not casterRoot or not casterRoot:IsA("BasePart") then
			return nil
		end
		direction = casterRoot.Position - targetRoot.Position
		if payload.Mode == "AwayFromCaster" then
			direction = -direction
		end
	else
		direction = context.Direction
		if payload.Mode == "AgainstAim" then
			direction = -direction
		end
	end
	if typeof(direction) ~= "Vector3" then
		return nil
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	return if direction.Magnitude > 0.001 then direction.Unit else nil
end

local function displaceTarget(payload, context, humanoid)
	local model = humanoid.Parent
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if
		not model
		or not model:IsA("Model")
		or not root
		or not root:IsA("BasePart")
		or humanoid.Health <= 0
		or root.Anchored
		or not model:IsDescendantOf(workspace)
	then
		return false
	end
	local direction = displacementDirection(payload, context, root)
	if not direction then
		return false
	end
	local distance = math.clamp(payload.Distance * context.Potency, 1, MagicLab.MaxDisplacementDistance)
	local displacement = direction * distance
	local destinationXZ = root.Position + displacement
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { context.Caster, model }
	rayParams.RespectCanCollide = true
	if workspace:Raycast(root.Position, displacement, rayParams) then
		return false
	end
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	groundParams.FilterDescendantsInstances = { context.Caster, model }
	groundParams.RespectCanCollide = true
	local ground = workspace:Raycast(destinationXZ + Vector3.new(0, 8, 0), Vector3.new(0, -24, 0), groundParams)
	if not ground or ground.Normal.Y < 0.55 then
		return false
	end
	local currentFloorY = root.Position.Y - humanoid.HipHeight - root.Size.Y * 0.5
	local verticalChange = ground.Position.Y - currentFloorY
	if math.abs(verticalChange) > 4 then
		return false
	end
	local destination =
		Vector3.new(destinationXZ.X, ground.Position.Y + humanoid.HipHeight + root.Size.Y * 0.5, destinationXZ.Z)
	local _, extents = model:GetBoundingBox()
	local clearanceSize =
		Vector3.new(math.clamp(extents.X, 2, 8), math.clamp(extents.Y, 4, 12), math.clamp(extents.Z, 2, 8))
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { context.Caster, model }
	overlap.RespectCanCollide = true
	if #workspace:GetPartBoundsInBox(CFrame.new(destination), clearanceSize, overlap) > 0 then
		return false
	end
	local ownershipToken = {}
	if not Ownership.claim(root, ownershipToken) then
		return false
	end
	local ok = pcall(function()
		model:PivotTo(model:GetPivot() + (destination - root.Position))
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
	end)
	task.delay(0.2, function()
		Ownership.release(root, ownershipToken)
	end)
	if ok then
		context.EffectFeedback("Displacement", humanoid, distance)
	end
	return ok
end

local function targetModel(target: Instance): Instance?
	return if target:IsA("Humanoid") then target.Parent else target:FindFirstAncestorOfClass("Model")
end

-- Payload metadata stays beside the executor registry so cross-cutting runtime
-- behavior does not need to grow a payload-kind conditional list.
Payloads.Metadata = {
	Damage = { TracksHumanoidTargets = true },
	DamageOverTime = { TracksHumanoidTargets = true },
	Heal = { TracksHumanoidTargets = true },
	Restoration = { TracksHumanoidTargets = true },
	Shield = { TracksHumanoidTargets = true },
	ModifyAttribute = { TracksHumanoidTargets = true },
	Transformation = { TracksHumanoidTargets = true },
	Slow = { TracksHumanoidTargets = true },
	Bind = { TracksHumanoidTargets = true },
	Reveal = { TracksHumanoidTargets = true },
	Control = { TracksHumanoidTargets = true },
	Force = { TracksHumanoidTargets = true },
	Displacement = { TracksHumanoidTargets = true },
	TimeDilation = { TracksHumanoidTargets = true },
	Enhancement = { TracksHumanoidTargets = true },
	ElementalMark = { TracksHumanoidTargets = true },
	ConsumeElementalMark = { TracksHumanoidTargets = true },
}

Payloads.Executors = {
	ElementalMark = function(payload: any, context: any)
		local element = context.DamageContext and context.DamageContext.Element
		if type(element) ~= "string" or element == "Neutral" then
			return
		end
		for _, target in context.Targets or {} do
			if
				Status.elementalMark(context.Caster, target, context.SpellId, element, payload.Stacks, payload.Duration)
			then
				for _, effect in ElementalInteractions.effectsFor(element, payload.Duration) do
					local executor = Payloads.Executors[effect.Kind]
					if executor then
						local effectContext = table.clone(context)
						effectContext.Targets = { target }
						effectContext.RequiredElementalMark = effect.RequiresElementalMark
						effect.Element = effect.Element or element
						executor(effect, effectContext)
					end
				end
			end
		end
	end,
	ConsumeElementalMark = function(payload: any, context: any)
		local element = payload.Element or (context.DamageContext and context.DamageContext.Element)
		if type(element) ~= "string" or element == "Neutral" then
			return
		end
		for _, target in context.Targets or {} do
			Status.consumeElementalMark(target, element, payload.Stacks)
		end
	end,
	DamageOverTime = function(payload, context)
		local now = os.clock()
		for _, target in context.Targets or {} do
			local damageContext = payloadDamageContext(payload, context, target)
			local existing
			local casterCount = 0
			for _, effect in periodicEffects do
				if effect.Caster == context.Caster then
					casterCount += 1
					if
						effect.Target == target
						and effect.SpellId == context.SpellId
						and effect.Kind == "DamageOverTime"
						and effect.RequiredElementalMark == context.RequiredElementalMark
					then
						existing = effect
					end
				end
			end
			if existing then
				-- Refresh duration/strength, never postpone the already scheduled next tick.
				existing.Remaining = payload.Duration
				existing.LastUpdateAt = now
				existing.Amount = scaledAmount(payload, context, target)
				existing.Interval = payload.Interval
				existing.Feedback = context.HitFeedback
				existing.EffectFeedback = context.EffectFeedback
				existing.DamageContext = damageContext
				existing.RequiredElementalMark = context.RequiredElementalMark
				setPeriodicDeathCallback(existing, context.TargetDeathCallback and context.TargetDeathCallback(target))
			elseif
				#periodicEffects < MagicLab.MaxPeriodicEffectsGlobal
				and casterCount < MagicLab.MaxPeriodicEffectsPerCaster
			then
				local effect = {
					Kind = "DamageOverTime",
					Caster = context.Caster,
					Target = target,
					SpellId = context.SpellId,
					Polarity = Schema.Payloads.DamageOverTime.Polarity,
					Amount = scaledAmount(payload, context, target),
					Interval = payload.Interval,
					UntilNext = payload.Interval,
					Remaining = payload.Duration,
					LastUpdateAt = now,
					Feedback = context.HitFeedback,
					EffectFeedback = context.EffectFeedback,
					DamageContext = damageContext,
					RequiredElementalMark = context.RequiredElementalMark,
				}
				setPeriodicDeathCallback(effect, context.TargetDeathCallback and context.TargetDeathCallback(target))
				table.insert(periodicEffects, effect)
			end
		end
	end,
	Restoration = function(payload: any, context: any)
		local now = os.clock()
		for _, target in context.Targets or {} do
			local existing
			local casterCount = 0
			for _, effect in periodicEffects do
				if effect.Caster == context.Caster then
					casterCount += 1
					if
						effect.Target == target
						and effect.SpellId == context.SpellId
						and effect.Kind == "Restoration"
					then
						existing = effect
					end
				end
			end
			if existing then
				existing.Remaining = payload.Duration
				existing.LastUpdateAt = now
				existing.Amount = payload.Amount * context.Potency
				existing.Interval = payload.Interval
				existing.EffectFeedback = context.EffectFeedback
				setPeriodicDeathCallback(existing, context.TargetDeathCallback and context.TargetDeathCallback(target))
			elseif
				#periodicEffects < MagicLab.MaxPeriodicEffectsGlobal
				and casterCount < MagicLab.MaxPeriodicEffectsPerCaster
			then
				local effect = {
					Kind = "Restoration",
					Caster = context.Caster,
					Target = target,
					SpellId = context.SpellId,
					Polarity = Schema.Payloads.Restoration.Polarity,
					Amount = payload.Amount * context.Potency,
					Interval = payload.Interval,
					UntilNext = payload.Interval,
					Remaining = payload.Duration,
					LastUpdateAt = now,
					EffectFeedback = context.EffectFeedback,
				}
				setPeriodicDeathCallback(effect, context.TargetDeathCallback and context.TargetDeathCallback(target))
				table.insert(periodicEffects, effect)
			end
		end
	end,
	Damage = function(payload: any, context: any)
		for _, humanoid in context.Targets or {} do
			local damageContext = payloadDamageContext(payload, context, humanoid)
			local dealt, absorbed =
				Damage.apply(context.Caster, humanoid, scaledAmount(payload, context, humanoid), damageContext)
			if dealt > 0 then
				context.HitFeedback(humanoid, dealt)
			end
			if absorbed > 0 then
				context.EffectFeedback("Shield", humanoid, absorbed)
			end
		end
	end,
	Heal = function(payload: any, context: any)
		for _, humanoid in context.Targets or {} do
			local restored = Status.heal(
				context.Caster,
				humanoid,
				scaledAmount(payload, context, humanoid),
				context.CapProfile and context.CapProfile.MaxHealPerHit
			)
			if restored > 0 then
				context.EffectFeedback("Heal", humanoid, restored)
			end
		end
	end,
	Shield = function(payload: any, context: any)
		for _, humanoid in context.Targets or {} do
			local onBreak = if context.DamageContext
				then function(target)
					context.DamageContext.EmitEvent("OnBreak", target)
				end
				else nil
			local amount = scaledAmount(payload, context, humanoid)
			local shieldCap = context.CapProfile and context.CapProfile.MaxShield
			if shieldCap then
				amount = math.min(amount, shieldCap)
			end
			local added = Status.shield(
				context.Caster,
				humanoid,
				context.SpellId,
				amount,
				payload.Duration,
				onBreak,
				context.TargetDeathCallback and context.TargetDeathCallback(humanoid)
			)
			if added then
				context.EffectFeedback("Shield", humanoid, amount)
			end
		end
	end,
	ModifyAttribute = function(payload: any, context: any)
		for _, humanoid in context.Targets or {} do
			local amount = AttributeSpec.clamp(payload.Attribute, payload.Amount * context.Potency)
			if
				amount ~= nil
				and Status.modifyAttribute(
					context.Caster,
					humanoid,
					context.SpellId,
					payload.Attribute,
					amount,
					payload.Duration,
					context.TargetDeathCallback and context.TargetDeathCallback(humanoid),
					context.RequiredElementalMark,
					payload.Element
				)
			then
				context.EffectFeedback(payload.Attribute, humanoid, amount)
			end
		end
	end,
	Transformation = function(payload: any, context: any)
		if payload.Mode ~= "Scale" then
			return
		end
		for _, humanoid in context.Targets or {} do
			local multiplier = 1 + (payload.Multiplier - 1) * context.Potency
			if
				Status.transform(
					context.Caster,
					humanoid,
					context.SpellId,
					multiplier,
					payload.Duration,
					context.TargetDeathCallback and context.TargetDeathCallback(humanoid)
				)
			then
				context.EffectFeedback("Transformation", humanoid, multiplier)
			end
		end
	end,
	Slow = function(payload: any, context: any)
		for _, humanoid in context.Targets or {} do
			local multiplier = 1 - (1 - payload.Multiplier) * context.Potency
			if
				Status.slow(
					context.Caster,
					humanoid,
					context.SpellId,
					multiplier,
					payload.Duration,
					context.TargetDeathCallback and context.TargetDeathCallback(humanoid),
					context.RequiredElementalMark
				)
			then
				context.EffectFeedback("Slow", humanoid, multiplier)
			end
		end
	end,
	Bind = function(payload: any, context: any)
		for _, humanoid in context.Targets or {} do
			if
				Status.bind(
					context.Caster,
					humanoid,
					context.SpellId,
					payload.Duration,
					context.TargetDeathCallback and context.TargetDeathCallback(humanoid)
				)
			then
				context.EffectFeedback("Bind", humanoid, payload.Duration)
			end
		end
	end,
	Reveal = function(payload: any, context: any)
		for _, humanoid in context.Targets or {} do
			if
				context.Player
				and Status.reveal(
					context.Player,
					context.Caster,
					humanoid,
					context.SpellId,
					payload.Duration,
					context.Color,
					context.TargetDeathCallback and context.TargetDeathCallback(humanoid)
				)
			then
				context.EffectFeedback("Reveal", humanoid, payload.Duration)
			end
		end
	end,
	Control = function(payload: any, context: any)
		for _, target in context.Targets or {} do
			local applied, started
			if target:IsA("Humanoid") then
				applied, started = Control.apply(
					context.Caster,
					target,
					context.SpellId,
					payload,
					context.Potency,
					context.TargetDeathCallback and context.TargetDeathCallback(target)
				)
			elseif target:IsA("BasePart") then
				applied, started =
					Control.applyObject(context.Caster, target, context.SpellId, payload, context.Potency)
			end
			if applied and started then
				context.EffectFeedback("Control", target, payload.Acceleration * context.Potency)
			end
		end
	end,
	Force = function(payload: any, context: any)
		for _, target in context.Targets or {} do
			local root = if target:IsA("Humanoid")
				then target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
				else target
			if root and root:IsA("BasePart") and not root.Anchored then
				local direction = context.Direction
				if direction.Magnitude < 0.001 then
					local delta = root.Position - context.Origin
					direction = if delta.Magnitude > 0.001 then delta.Unit else Vector3.yAxis
				end
				applyForce(root, direction * payload.Magnitude + Vector3.new(0, payload.Upward or 0, 0))
			end
		end
	end,
	Displacement = function(payload: any, context: any)
		for _, humanoid in context.Targets or {} do
			displaceTarget(payload, context, humanoid)
		end
	end,
	TimeDilation = function(payload: any, context: any)
		for _, humanoid in context.Targets or {} do
			local rate = TemporalRate.clamp(payload.Rate)
			if
				Status.temporalRate(
					context.Caster,
					humanoid,
					context.SpellId,
					rate,
					payload.Duration,
					context.TargetDeathCallback and context.TargetDeathCallback(humanoid)
				)
			then
				context.EffectFeedback("TimeDilation", humanoid, rate)
			end
		end
	end,
	Enhancement = function(payload: any, context: any)
		context.ApplyEnhancement(payload)
	end,
	AerialMovement = function(payload: any, context: any)
		context.ApplyAerialMovement(payload)
	end,
	Manipulation = function(payload: any, context: any)
		context.ApplyManipulation(payload)
	end,
	Summon = function(payload: any, context: any)
		context.Summon(payload)
	end,
}

function Payloads.execute(payloads: { any }, context: any)
	local casterOwner = CombatPolicy.owner(context.Caster, Players)
	for _, payload in payloads do
		local executor = Payloads.Executors[payload.Kind]
		if not executor then
			continue
		end
		-- Partition targets by stat-cap profile; hostile effects also drop
		-- player-owned targets the caster may not attack.
		local hostile = CombatPolicy.isHostilePayload(payload)
		local groups: { [string]: { Instance } } = {}
		local allowed: { Instance } = {}
		local split = false
		for _, target in context.Targets or {} do
			local owner = CombatPolicy.owner(targetModel(target), Players)
			if not hostile or CombatPolicy.allows(casterOwner, owner) then
				local profile = StatCaps.profileName(casterOwner, owner)
				groups[profile] = groups[profile] or {}
				table.insert(groups[profile], target)
				table.insert(allowed, target)
				split = split or profile ~= "PvE"
			end
		end
		local metadata = Payloads.Metadata[payload.Kind]
		if metadata and metadata.TracksHumanoidTargets and context.TrackAffected then
			for _, target in allowed do
				context.TrackAffected(target)
			end
		end
		if not context.Targets or (not split and #allowed == #context.Targets) then
			executor(payload, context) -- common case: no PvP targets, nothing filtered
		else
			for profile, targets in groups do
				local groupContext = table.clone(context)
				groupContext.Targets = targets
				-- Final per-hit caps for this target group (damage over time, heal, shield).
				groupContext.CapProfile = CapProfiles[profile]
				executor(StatCaps.payload(payload, CapProfiles[profile], context.Potency), groupContext)
			end
		end
	end
end

return Payloads
