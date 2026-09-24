--!strict

-- Small server-owned interpreter for registered spell data. It intentionally
-- implements only the V1 component subset, rather than a final spell engine.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sandbox = require(Shared.Configuration.Sandbox)
local Definitions = require(Shared.Configuration.Spells)
local Generated = require(Shared.Configuration.GeneratedSpellStress)
local Validator = require(Shared.Modules.SpellDefinitionValidator)
local HitDetection = require(script.Parent.HitDetectionService)
local Behaviors = require(script.Parent.MagicBehaviorExecutors)
local Forms = require(script.Parent.MagicFormExecutors)
local Payloads = require(script.Parent.MagicPayloadExecutors)
local Movement = require(script.Parent.MovementService)
local Magic = {}

type State = { Character: Model, Humanoid: Humanoid, Root: BasePart }
type Charge = { SpellId: string, BeganAt: number }
type CastContext = { Origin: Vector3 }?
type Active = {
	SpellId: string,
	Caster: Model,
	Age: number,
	CurrentPhase: string,
	TargetsHit: { [Humanoid]: boolean },
	RemainingLifetime: number,
	Definition: any,
	Position: Vector3,
	Direction: Vector3,
	Visual: BasePart,
	Player: Player,
	Remote: RemoteEvent,
}

local playerData: { [Player]: { Mana: number, Strain: number, Ready: { [string]: number }, Charge: Charge? } } = {}
local active: { any } = {}
local enhancements: {
	[Player]: {
		[string]: {
			State: State,
			ExpiresAt: number,
			WalkSpeedBonus: number,
			JumpPowerBonus: number,
			SpeedMultiplier: number,
		},
	},
} =
	{}

local function feedback(remote: RemoteEvent, player: Player, result: string, spell: any?, data: { [string]: any }?)
	remote:FireClient(player, {
		Kind = "Magic",
		Result = result,
		SpellId = if spell then spell.SpellId else nil,
		Name = if spell then spell.Name else nil,
		Mana = data and data.Mana or nil,
		Strain = data and data.Strain or nil,
		Complexity = data and data.Complexity or nil,
		Reason = data and data.Reason or nil,
		Damage = data and data.Damage or nil,
	})
end

local function validVector(value: any): boolean
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
end

local function getDefinition(id: any): any?
	if typeof(id) ~= "string" then
		return nil
	end
	return Definitions[id] or Generated.Definitions[id]
end

local function findMaterial(definition: any, point: Vector3): Instance?
	local requirement = definition.Material
	if not requirement then
		return nil
	end
	local closest: Instance? = nil
	local closestDistance = math.huge
	for _, source in CollectionService:GetTagged("MagicMaterialSource") do
		local position = if source:IsA("BasePart")
			then source.Position
			elseif source:IsA("Model") then source:GetPivot().Position
			else nil
		if
			position
			and source:GetAttribute("MagicMaterial") == requirement.Material
			and (source:GetAttribute("AvailableAmount") or 0) >= requirement.Amount
			and (position - point).Magnitude <= requirement.SearchRadius
			and (position - point).Magnitude < closestDistance
		then
			closest, closestDistance = source, (position - point).Magnitude
		end
	end
	return closest
end

local function findManipulable(definition: any, point: Vector3): BasePart?
	local closest: BasePart? = nil
	local closestDistance = math.huge
	for _, source in CollectionService:GetTagged("MagicManipulable") do
		if
			source:IsA("BasePart")
			and source:GetAttribute("MagicMaterial") == definition.Material.Material
			and source:GetAttribute("MagicRaise") == true
			and (source.Position - point).Magnitude <= definition.Material.SearchRadius
			and (source.Position - point).Magnitude < closestDistance
		then
			closest, closestDistance = source, (source.Position - point).Magnitude
		end
	end
	return closest
end

local function costs(definition: any, charge: number): (number, number, number)
	local scale = 1 + charge * Sandbox.Magic.ChargeCostScale
	return definition.Cost.ManaDemand * scale / Sandbox.Magic.Player.Efficiency,
		definition.Cost.Strain * scale / Sandbox.Magic.Player.StrainTolerance * 30,
		definition.Cost.Complexity
end

local function validate(
	player: Player,
	state: State,
	intent: any,
	definition: any,
	charge: number
): (string, string?, Instance?, Vector3?)
	if not definition or not validVector(intent.AimDirection) then
		return "IMPOSSIBLE", "Invalid spell or aim"
	end
	local direction = intent.AimDirection
	if direction.Magnitude < 0.9 or direction.Magnitude > 1.1 then
		return "IMPOSSIBLE", "Invalid aim direction"
	end
	direction = direction.Unit
	local worldPoint = intent.WorldPoint
	local material: Instance? = nil
	if definition.Targeting == "WorldPoint" then
		if
			not validVector(worldPoint)
			or (worldPoint - state.Root.Position).Magnitude > Sandbox.Magic.MaxAimDistance
		then
			return "IMPOSSIBLE", "Invalid world target"
		end
		local aimedDelta = worldPoint - (state.Root.Position + Vector3.new(0, 1.5, 0))
		if aimedDelta.Magnitude > 0 and direction:Dot(aimedDelta.Unit) < Sandbox.Magic.MinimumWorldAimDot then
			return "IMPOSSIBLE", "World target is outside aim direction"
		end
	elseif definition.Targeting == "MaterialTarget" then
		if
			not validVector(worldPoint)
			or (worldPoint - state.Root.Position).Magnitude > Sandbox.Magic.MaxAimDistance
		then
			return "IMPOSSIBLE", "Invalid material target"
		end
		-- Use a server-known spell origin for the anti-spoof comparison rather than
		-- trusting a client-provided camera position. This preserves camera pitch.
		local aimedDelta = worldPoint - (state.Root.Position + Vector3.new(0, 1.5, 0))
		if aimedDelta.Magnitude > 0 and direction:Dot(aimedDelta.Unit) < Sandbox.Magic.MinimumWorldAimDot then
			return "IMPOSSIBLE", "Material target is outside aim direction"
		end
		material = if definition.Form == "Manipulation"
			then findManipulable(definition, worldPoint)
			else findMaterial(definition, worldPoint)
		if not material then
			return "IMPOSSIBLE", "No valid Earth target nearby"
		end
	end
	local mana, strain, complexity = costs(definition, charge)
	local stats = playerData[player]
	if not stats or mana > stats.Mana then
		return "IMPOSSIBLE", "Insufficient mana"
	end
	if complexity > Sandbox.Magic.Player.ComplexityCapacity then
		return "IMPOSSIBLE", "Complexity exceeds capacity"
	end
	if mana > Sandbox.Magic.Player.SafeManaDemand or strain > Sandbox.Magic.Player.SafeStrain then
		return "UNSAFE", "Above safe Locus threshold", material, direction
	end
	return "VALID", nil, material, direction
end

local function applyPayloads(
	caster: Model,
	origin: CFrame,
	targets: { Humanoid },
	payloads: { any },
	direction: Vector3,
	remote: RemoteEvent,
	player: Player
)
	Payloads.execute(payloads, {
		Caster = caster,
		Targets = targets,
		Direction = direction,
		Potency = Sandbox.Magic.Player.Potency,
		HitFeedback = function(humanoid: Humanoid, dealt: number)
			feedback(remote, player, "HIT", nil, { Reason = humanoid.Parent and humanoid.Parent.Name, Damage = dealt })
		end,
	})
end

local function visual(definition: any, position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = "MagicProjectile"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(
		definition.Projectile.Radius * 2,
		definition.Projectile.Radius * 2,
		definition.Projectile.Radius * 2
	)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = definition.Visual.Color
	part.Parent = workspace
	return part
end

-- Projectile sweeps query character limbs as well as solid world geometry, then
-- skip only cosmetic/non-solid query parts. This avoids high-speed tunnelling
-- without allowing a non-colliding decoration to shield a wall behind it.
local function isProjectileImpact(instance: Instance, caster: Model): boolean
	local model = instance:FindFirstAncestorOfClass("Model")
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and model ~= caster then
		return true
	end
	if instance:IsA("BasePart") then
		return instance.CanCollide
	end
	return instance:IsA("Terrain")
end

local function sweepProjectile(start: Vector3, delta: Vector3, caster: Model, visualPart: BasePart): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { caster, visualPart }
	params.RespectCanCollide = false
	local endpoint = start + delta
	local origin = start
	for _ = 1, 16 do
		local remaining = endpoint - origin
		if remaining.Magnitude <= 0.001 then
			return nil
		end
		local result = workspace:Raycast(origin, remaining, params)
		if not result then
			return nil
		end
		if isProjectileImpact(result.Instance, caster) then
			return result
		end
		table.insert(params.FilterDescendantsInstances, result.Instance)
		origin = result.Position + remaining.Unit * 0.01
	end
	return nil
end

local function debugMarker(name: string, position: Vector3, size: Vector3, color: Color3, duration: number?): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = size
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.Transparency, part.Material, part.Color = 0.55, Enum.Material.Neon, color
	part.Parent = workspace
	if duration then
		Debris:AddItem(part, duration)
	end
	return part
end

local function updateEnhancement(player: Player, fallbackState: any?)
	local walkSpeedBonus, jumpPowerBonus = 0, 0
	local multiplier = 1
	for _, effect in enhancements[player] or {} do
		walkSpeedBonus += effect.WalkSpeedBonus
		jumpPowerBonus += effect.JumpPowerBonus
		multiplier = math.max(multiplier, effect.SpeedMultiplier)
	end
	local _, effect = next(enhancements[player] or {})
	if effect then
		Movement.setMagicEnhancement(effect.State, walkSpeedBonus, jumpPowerBonus, multiplier)
	elseif fallbackState then
		Movement.setMagicEnhancement(fallbackState, 0, 0, 1)
	end
end

local function execute(
	player: Player,
	state: State,
	remote: RemoteEvent,
	definition: any,
	intent: any,
	charge: number,
	material: Instance?,
	direction: Vector3,
	result: string,
	castContext: CastContext
)
	local stats = playerData[player]
	local mana, strain, complexity = costs(definition, charge)
	stats.Mana -= mana
	stats.Strain += strain
	stats.Ready[definition.SpellId] = workspace:GetServerTimeNow() + definition.Casting.Cooldown
	if material and definition.Material.Amount then
		material:SetAttribute(
			"AvailableAmount",
			(material:GetAttribute("AvailableAmount") or 0) - definition.Material.Amount
		)
	end
	feedback(remote, player, result, definition, { Mana = stats.Mana, Strain = stats.Strain, Complexity = complexity })
	if definition.Form ~= "Projectile" and definition.Form ~= "Wave" then
		local executed = Forms.execute(definition.Form, definition, {
			ExecuteBeam = function(beamDefinition: any)
				local origin = state.Root.Position + Vector3.new(0, 1.5, 0)
				if castContext then
					origin = castContext.Origin
				end
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { state.Character }
				params.RespectCanCollide = true
				local resultRay = workspace:Raycast(origin, direction * beamDefinition.Beam.Range, params)
				local endpoint = if resultRay
					then resultRay.Position
					else origin + direction * beamDefinition.Beam.Range
				local line = Instance.new("Part")
				line.Name = "MagicBeamDebug"
				line.Anchored, line.CanCollide, line.CanTouch, line.CanQuery = true, false, false, false
				line.Material, line.Color = Enum.Material.Neon, Color3.fromRGB(180, 230, 255)
				line.Size = Vector3.new(0.16, 0.16, (endpoint - origin).Magnitude)
				line.CFrame = CFrame.lookAt((origin + endpoint) / 2, endpoint)
				line.Parent = workspace
				Debris:AddItem(line, beamDefinition.Beam.DebugDuration)
				local model = if resultRay then resultRay.Instance:FindFirstAncestorOfClass("Model") else nil
				local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
				if humanoid and model ~= state.Character then
					applyPayloads(
						state.Character,
						CFrame.new(origin),
						{ humanoid },
						beamDefinition.Triggers.OnCast,
						direction,
						remote,
						player
					)
				end
			end,
			CreateField = function(fieldDefinition: any)
				local point = intent.WorldPoint :: Vector3
				local marker = debugMarker(
					"MagicFieldDebug",
					point,
					Vector3.new(
						fieldDefinition.Field.Radius * 2,
						fieldDefinition.Field.DebugHeight,
						fieldDefinition.Field.Radius * 2
					),
					fieldDefinition.Visual.Color
				)
				table.insert(active, {
					Kind = "Field",
					Caster = state.Character,
					Player = player,
					Remote = remote,
					Definition = fieldDefinition,
					Position = point,
					RemainingLifetime = fieldDefinition.Lifetime.Duration,
					NextInterval = 0,
					Visual = marker,
				})
			end,
			ApplySelf = function(selfDefinition: any)
				Payloads.execute(selfDefinition.Triggers.OnCast, {
					ApplyEnhancement = function(payload: any)
						local activeEffects = enhancements[player] or {}
						enhancements[player] = activeEffects
						activeEffects[selfDefinition.SpellId] = {
							State = state,
							ExpiresAt = if selfDefinition.Lifetime.Mode == "UntilToggledOff"
								then math.huge
								else workspace:GetServerTimeNow() + selfDefinition.Lifetime.Duration,
							WalkSpeedBonus = payload.WalkSpeedBonus or 0,
							JumpPowerBonus = payload.JumpPowerBonus or 0,
							SpeedMultiplier = payload.SpeedMultiplier or 1,
						}
						updateEnhancement(player)
					end,
				})
			end,
			ApplyManipulation = function(payload: any)
				if payload.Triggers then
					Payloads.execute(payload.Triggers.OnCast, {
						ApplyManipulation = function(operation: any)
							local target = material
							if target and target:IsA("BasePart") and operation.Operation == "Raise" then
								target.Position += Vector3.new(0, operation.Distance, 0)
							end
						end,
					})
				end
			end,
		})
		if executed then
			return
		end
	end
	if definition.Form == "Wave" then
		-- Waves deliberately stay ground-relative in V1. Projectile directions are
		-- left fully 3D; this form-specific projection does not affect validation.
		local horizontal = Vector3.new(direction.X, 0, direction.Z)
		local waveDirection = if horizontal.Magnitude > 0 then horizontal.Unit else state.Root.CFrame.LookVector
		local castFrame = CFrame.lookAt(state.Root.Position, state.Root.Position + waveDirection)
		local targets = HitDetection.findCone(state.Character, castFrame, definition.Wave.Range, definition.Wave.Dot, {
			OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
			RequireLineOfSight = true,
		})
		applyPayloads(state.Character, castFrame, targets, definition.Wave.Payloads, waveDirection, remote, player)
		local marker = Instance.new("Part")
		marker.Name = "MagicWaveDebug"
		marker.Shape = Enum.PartType.Ball
		marker.Size = Vector3.new(definition.Wave.Range * 2, 0.15, definition.Wave.Range * 2)
		marker.CFrame = castFrame * CFrame.new(0, -2.7, -definition.Wave.Range / 2)
		marker.Anchored, marker.CanCollide, marker.CanQuery = true, false, false
		marker.Transparency, marker.Material, marker.Color = 0.6, Enum.Material.Neon, Color3.fromRGB(170, 255, 170)
		marker.Parent = workspace
		Debris:AddItem(marker, definition.Wave.DebugDuration)
		return
	end
	local start = state.Root.Position + Vector3.new(0, 1.5, 0) + direction * 2
	if castContext then
		start = castContext.Origin
		if validVector(intent.WorldPoint) then
			local targetDelta = intent.WorldPoint - start
			if targetDelta.Magnitude > 0 then
				direction = targetDelta.Unit
			end
		end
	end
	table.insert(active, {
		SpellId = definition.SpellId,
		Caster = state.Character,
		Age = 0,
		CurrentPhase = "Travel",
		TargetsHit = {},
		RemainingLifetime = definition.Lifetime.Duration,
		Definition = definition,
		Position = start,
		Direction = direction,
		Visual = visual(definition, start),
		Player = player,
		Remote = remote,
	})
end

function Magic.start(player: Player, state: State, intent: any, remote: RemoteEvent, castContext: CastContext)
	local definition = getDefinition(intent.SpellId)
	if not definition then
		feedback(remote, player, "IMPOSSIBLE", nil, { Reason = "Unknown spell" })
		return
	end
	local definitionValid, definitionReason = Validator.validate(definition)
	if not definitionValid then
		feedback(remote, player, "IMPOSSIBLE", definition, { Reason = definitionReason })
		return
	end
	local stats = playerData[player]
	-- Turning an existing toggle OFF must not require mana, aim validation or
	-- waiting for its activation cooldown. The router still validates ownership,
	-- life state and request rate before reaching this handler.
	local effects = enhancements[player]
	if
		definition.Form == "SelfEnhancement"
		and definition.Lifetime.Mode == "UntilToggledOff"
		and effects
		and effects[definition.SpellId]
	then
		effects[definition.SpellId] = nil
		updateEnhancement(player, state)
		feedback(remote, player, "OFF", definition, nil)
		return
	end
	if not stats or workspace:GetServerTimeNow() < (stats.Ready[definition.SpellId] or 0) then
		feedback(remote, player, "IMPOSSIBLE", definition, { Reason = "Spell is cooling down" })
		return
	end
	if definition.Casting.Mode == "Charged" then
		if stats.Charge then
			feedback(remote, player, "IMPOSSIBLE", definition, { Reason = "A spell is already charging" })
			return
		end
		stats.Charge = { SpellId = definition.SpellId, BeganAt = workspace:GetServerTimeNow() }
		feedback(
			remote,
			player,
			"CHARGING",
			definition,
			{ Mana = stats.Mana, Strain = stats.Strain, Complexity = definition.Cost.Complexity }
		)
		return
	end
	local result, reason, material, direction = validate(player, state, intent, definition, 0)
	if result == "IMPOSSIBLE" or not direction then
		feedback(remote, player, "IMPOSSIBLE", definition, { Reason = reason })
		return
	end
	execute(player, state, remote, definition, intent, 0, material, direction, result, castContext)
end

function Magic.release(player: Player, state: State, intent: any, remote: RemoteEvent)
	local stats = playerData[player]
	local charge = if stats then stats.Charge else nil
	if not charge then
		feedback(remote, player, "IMPOSSIBLE", nil, { Reason = "No spell is charging" })
		return
	end
	stats.Charge = nil
	local definition = getDefinition(charge.SpellId)
	if not definition then
		return
	end
	local definitionValid, definitionReason = Validator.validate(definition)
	if not definitionValid then
		feedback(remote, player, "IMPOSSIBLE", definition, { Reason = definitionReason })
		return
	end
	local elapsed = math.clamp(workspace:GetServerTimeNow() - charge.BeganAt, 0, definition.Casting.MaximumCharge)
	if elapsed < definition.Casting.MinimumCharge then
		feedback(remote, player, "IMPOSSIBLE", definition, { Reason = "Charge was released too early" })
		return
	end
	local result, reason, material, direction = validate(player, state, intent, definition, elapsed)
	if result == "IMPOSSIBLE" or not direction then
		feedback(remote, player, "IMPOSSIBLE", definition, { Reason = reason })
		return
	end
	execute(player, state, remote, definition, intent, elapsed, material, direction, result, nil)
end

function Magic.bind(player: Player)
	playerData[player] =
		{ Mana = math.min(Sandbox.Magic.Player.Mana, Sandbox.Magic.Player.Capacity), Strain = 0, Ready = {} }
end

function Magic.reset(player: Player)
	for _, effect in enhancements[player] or {} do
		Movement.setMagicEnhancement(effect.State, 0, 0)
	end
	enhancements[player] = nil
	local stats = playerData[player]
	if stats then
		stats.Charge = nil
		stats.Mana = math.min(Sandbox.Magic.Player.Mana, Sandbox.Magic.Player.Capacity)
		stats.Strain = 0
		table.clear(stats.Ready)
	end
end

function Magic.remove(player: Player)
	playerData[player] = nil
	for _, effect in enhancements[player] or {} do
		Movement.setMagicEnhancement(effect.State, 0, 0)
	end
	enhancements[player] = nil
end

RunService.Heartbeat:Connect(function(delta)
	local now = workspace:GetServerTimeNow()
	for _, stats in playerData do
		stats.Mana =
			math.min(Sandbox.Magic.Player.Capacity, stats.Mana + Sandbox.Magic.Player.ManaRegenerationPerSecond * delta)
		stats.Strain = math.max(0, stats.Strain - Sandbox.Magic.Player.StrainRecoveryPerSecond * delta)
	end
	for index = #active, 1, -1 do
		local spell = active[index]
		if not spell.Caster:IsDescendantOf(workspace) then
			spell.Visual:Destroy()
			table.remove(active, index)
			continue
		end
		if spell.Kind == "Field" then
			spell.RemainingLifetime -= delta
			if spell.RemainingLifetime <= 0 then
				spell.Visual:Destroy()
				table.remove(active, index)
				continue
			end
			if now >= spell.NextInterval then
				spell.NextInterval = now + spell.Definition.Field.Interval
				local targets =
					HitDetection.findSphere(spell.Caster, CFrame.new(spell.Position), spell.Definition.Field.Radius, {
						OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
						RequireLineOfSight = true,
					})
				applyPayloads(
					spell.Caster,
					CFrame.new(spell.Position),
					targets,
					spell.Definition.Triggers.OnInterval,
					Vector3.zero,
					spell.Remote,
					spell.Player
				)
			end
			continue
		end
		spell.Age += delta
		spell.RemainingLifetime -= delta
		local definition = spell.Definition
		local previous = spell.Position
		local nextPosition = previous + spell.Direction * definition.Projectile.Speed * delta
		local impact = sweepProjectile(previous, nextPosition - previous, spell.Caster, spell.Visual)
		spell.Position = if impact then impact.Position else nextPosition
		spell.Visual.Position = spell.Position
		if impact then
			local hitModel = if impact then impact.Instance:FindFirstAncestorOfClass("Model") else nil
			local hitHumanoid = if hitModel then hitModel:FindFirstChildOfClass("Humanoid") else nil
			for _, trigger in definition.Triggers.OnImpact or {} do
				if trigger.Payloads and hitHumanoid and hitModel ~= spell.Caster then
					applyPayloads(
						spell.Caster,
						CFrame.new(spell.Position),
						{ hitHumanoid },
						trigger.Payloads,
						spell.Direction,
						spell.Remote,
						spell.Player
					)
				end
				if trigger.Behavior then
					Behaviors.execute(trigger.Behavior, {
						ApplySpherePayloads = function(radius: number, payloads: { any })
							local targets = HitDetection.findSphere(spell.Caster, CFrame.new(spell.Position), radius, {
								OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
								RequireLineOfSight = true,
							})
							applyPayloads(
								spell.Caster,
								CFrame.new(spell.Position),
								targets,
								payloads,
								spell.Direction,
								spell.Remote,
								spell.Player
							)
						end,
					}, trigger)
				end
			end
			spell.Visual:Destroy()
			table.remove(active, index)
		elseif spell.RemainingLifetime <= 0 then
			-- Expiration is not an impact: a bolt that reaches its maximum range
			-- simply vanishes and cannot apply delayed damage or an explosion.
			spell.Visual:Destroy()
			table.remove(active, index)
		end
	end
	for player, effects in enhancements do
		local changed = false
		local expiredState: State? = nil
		for spellId, effect in effects do
			if
				now >= effect.ExpiresAt
				or effect.State.Character ~= player.Character
				or effect.State.Humanoid.Health <= 0
			then
				expiredState = effect.State
				effects[spellId] = nil
				changed = true
			end
		end
		if changed then
			if next(effects) then
				updateEnhancement(player)
			elseif expiredState then
				Movement.setMagicEnhancement(expiredState, 0, 0)
			end
		end
	end
end)

return Magic
