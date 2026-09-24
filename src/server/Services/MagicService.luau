--!strict

-- Small server-owned interpreter for registered spell data. It intentionally
-- implements only the V1 component subset, rather than a final spell engine.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sandbox = require(Shared.Configuration.Sandbox)
local Definitions = require(Shared.Configuration.Spells)
local HitDetection = require(script.Parent.HitDetectionService)
local Damage = require(script.Parent.DamageService)
local Behaviors = require(script.Parent.MagicBehaviorExecutors)
local Magic = {}

type State = { Character: Model, Humanoid: Humanoid, Root: BasePart }
type Charge = { SpellId: string, BeganAt: number }
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
local active: { Active } = {}

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
	return Definitions[id]
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
	local direction = Vector3.new(intent.AimDirection.X, 0, intent.AimDirection.Z)
	if direction.Magnitude < 0.9 or direction.Magnitude > 1.1 then
		return "IMPOSSIBLE", "Invalid aim direction"
	end
	direction = direction.Unit
	local worldPoint = intent.WorldPoint
	local material: Instance? = nil
	if definition.Targeting == "MaterialTarget" then
		if
			not validVector(worldPoint)
			or (worldPoint - state.Root.Position).Magnitude > Sandbox.Magic.MaxAimDistance
		then
			return "IMPOSSIBLE", "Invalid material target"
		end
		local aimedDelta = worldPoint - state.Root.Position
		local aimedHorizontal = Vector3.new(aimedDelta.X, 0, aimedDelta.Z)
		if aimedHorizontal.Magnitude > 0 and direction:Dot(aimedHorizontal.Unit) < Sandbox.Magic.MinimumWorldAimDot then
			return "IMPOSSIBLE", "Material target is outside aim direction"
		end
		material = findMaterial(definition, worldPoint)
		if not material then
			return "IMPOSSIBLE", "No Earth material source nearby"
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
	for _, humanoid in targets do
		for _, payload in payloads do
			if payload.Kind == "Damage" then
				local dealt = Damage.apply(caster, humanoid, payload.Amount * Sandbox.Magic.Player.Potency)
				if dealt > 0 then
					feedback(
						remote,
						player,
						"HIT",
						nil,
						{ Reason = humanoid.Parent and humanoid.Parent.Name, Damage = dealt }
					)
				end
			elseif payload.Kind == "Force" then
				local root = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					root.AssemblyLinearVelocity += direction * payload.Magnitude + Vector3.new(
						0,
						payload.Upward or 0,
						0
					)
				end
			end
		end
	end
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

local function execute(
	player: Player,
	state: State,
	remote: RemoteEvent,
	definition: any,
	intent: any,
	charge: number,
	material: Instance?,
	direction: Vector3,
	result: string
)
	local stats = playerData[player]
	local mana, strain, complexity = costs(definition, charge)
	stats.Mana -= mana
	stats.Strain += strain
	stats.Ready[definition.SpellId] = workspace:GetServerTimeNow() + definition.Casting.Cooldown
	if material then
		material:SetAttribute(
			"AvailableAmount",
			(material:GetAttribute("AvailableAmount") or 0) - definition.Material.Amount
		)
	end
	feedback(remote, player, result, definition, { Mana = stats.Mana, Strain = stats.Strain, Complexity = complexity })
	if definition.Form == "Wave" then
		local castFrame = CFrame.lookAt(state.Root.Position, state.Root.Position + direction)
		local targets = HitDetection.findCone(state.Character, castFrame, definition.Wave.Range, definition.Wave.Dot, {
			OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
			RequireLineOfSight = true,
		})
		applyPayloads(state.Character, castFrame, targets, definition.Wave.Payloads, direction, remote, player)
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

function Magic.start(player: Player, state: State, intent: any, remote: RemoteEvent)
	local definition = getDefinition(intent.SpellId)
	if not definition then
		feedback(remote, player, "IMPOSSIBLE", nil, { Reason = "Unknown spell" })
		return
	end
	local stats = playerData[player]
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
	execute(player, state, remote, definition, intent, 0, material, direction, result)
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
	execute(player, state, remote, definition, intent, elapsed, material, direction, result)
end

function Magic.bind(player: Player)
	playerData[player] =
		{ Mana = math.min(Sandbox.Magic.Player.Mana, Sandbox.Magic.Player.Capacity), Strain = 0, Ready = {} }
end

function Magic.reset(player: Player)
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
end

RunService.Heartbeat:Connect(function(delta)
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
		spell.Age += delta
		spell.RemainingLifetime -= delta
		local definition = spell.Definition
		local previous = spell.Position
		local nextPosition = previous + spell.Direction * definition.Projectile.Speed * delta
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { spell.Caster, spell.Visual }
		-- Query non-colliding character parts too; this is logical projectile hit detection.
		ray.RespectCanCollide = false
		local impact = workspace:Raycast(previous, nextPosition - previous, ray)
		spell.Position = if impact then impact.Position else nextPosition
		spell.Visual.Position = spell.Position
		if impact or spell.RemainingLifetime <= 0 then
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
		end
	end
end)

return Magic
