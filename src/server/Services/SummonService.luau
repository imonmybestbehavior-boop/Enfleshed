--!strict

-- Bounded owner/lifetime manager for magic summons. The first archetype is a
-- non-colliding protector familiar; command behavior stays in this focused service.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Configuration.MagicSummons)
local Damage = require(script.Parent.DamageService)
local Presentation = require(script.Parent.MagicPresentation)
local Conditions = require(script.Parent.MagicConditions)
local CommandSpec = require(script.Parent.MagicCommandSpec)
local RolePolicy = require(Shared.Modules.MagicSummonRolePolicy)
local Placement = require(script.Parent.MagicSummonPlacement)

type SummonRecord = {
	Owner: Player,
	Caster: Model,
	SpellId: string,
	Archetype: string,
	Role: string,
	Index: number,
	Id: number,
	SpellSlot: number?,
	Color: Color3,
	SpawnPosition: Vector3?,
	Model: Model?,
	Humanoid: Humanoid?,
	NextTargetScan: number,
	NextAttack: number,
	Target: Model?,
	HoldPosition: Vector3?,
	MoveOffset: Vector3,
	Command: string?,
	CommandTarget: Model?,
	CommandPosition: Vector3?,
	PatrolPoints: { Vector3 }?,
	PatrolIndex: number,
	DeathConnection: RBXScriptConnection?,
	HealthConnection: RBXScriptConnection?,
	ModelAncestryConnection: RBXScriptConnection?,
	SpellProfile: any?,
	SpellProfileReason: string?,
	SpellStatus: string?,
	SpellStatusReason: string?,
	TargetSearchReason: string?,
	SpellCastUntil: number,
	CommandIssued: boolean,
}

type SummonGroup = {
	Owner: Player,
	Caster: Model,
	SpellId: string,
	Archetype: string,
	Role: string,
	SpawnAt: string,
	Color: Color3,
	Slots: { SummonRecord },
	Command: string,
	CommandIssued: boolean,
	CommandTarget: Model?,
	CommandPosition: Vector3?,
	PatrolPoints: { Vector3 }?,
	ExpiresAt: number,
	PersistAcrossRespawn: boolean,
	RespawnDeadline: number?,
	LastCapacityNotice: number,
	SourceDefinition: any,
	SourceRemote: RemoteEvent,
	SourceDirection: Vector3,
	SourcePotency: number,
	CasterDeathConnection: RBXScriptConnection?,
}
type CompanionCaster = (
	Player,
	Model,
	number,
	number,
	Model,
	RemoteEvent
) -> (boolean, number, boolean, string?, number?)
type CompanionProfileGetter = (Player, number) -> (any?, string?)
type CommandExecutor = (Player, Model, any, RemoteEvent, Vector3, number, string, { Humanoid }) -> ()

local Summons = {}
local groups: { SummonGroup } = {}
local dismissedGroups: { [Player]: { [string]: boolean } } = {}
local dismissAllUntilCast: { [Player]: boolean } = {}
local rearmedAfterDismiss: { [Player]: { [string]: boolean } } = {}
local folder: Folder?
local started = false
local nextRecordId = 0
local castCompanionSpell: ((Player, Model, number, number, Model) -> (boolean, number, boolean, string?, number?))? =
	nil
local getCompanionProfile: CompanionProfileGetter? = nil
local executeCommandEvent: CommandExecutor? = nil

local function setSpellStatus(record: SummonRecord, status: string, reason: string?)
	local model = record.Model
	if not model or not model.Parent then
		return
	end
	if record.SpellStatus ~= status or record.SpellStatusReason ~= reason then
		record.SpellStatus = status
		record.SpellStatusReason = reason
		model:SetAttribute("MagicSummonSpellStatus", status)
		model:SetAttribute("MagicSummonSpellReason", reason or "")
	end
	if model:GetAttribute("MagicSummonSpellSlot") ~= (record.SpellSlot or 0) then
		model:SetAttribute("MagicSummonSpellSlot", record.SpellSlot or 0)
	end
	if record.Target and record.Target.Parent then
		if model:GetAttribute("MagicSummonSpellTarget") ~= record.Target.Name then
			model:SetAttribute("MagicSummonSpellTarget", record.Target.Name)
		end
	else
		if model:GetAttribute("MagicSummonSpellTarget") ~= "" then
			model:SetAttribute("MagicSummonSpellTarget", "")
		end
	end
end

local function liveCount(owner: Player?): number
	local count = 0
	for _, group in groups do
		if not owner or group.Owner == owner then
			for _, record in group.Slots do
				if record.Model and record.Model:IsDescendantOf(workspace) then
					count += 1
				end
			end
		end
	end
	return count
end

local function refreshOwnerCount(owner: Player)
	if owner.Parent == Players then
		owner:SetAttribute("ActiveMagicSummons", liveCount(owner))
	end
end

local findGroup: (Player, string) -> (SummonGroup?, number?)

local function removeModel(record: SummonRecord)
	if record.ModelAncestryConnection then
		record.ModelAncestryConnection:Disconnect()
		record.ModelAncestryConnection = nil
	end
	if record.DeathConnection then
		record.DeathConnection:Disconnect()
		record.DeathConnection = nil
	end
	if record.HealthConnection then
		record.HealthConnection:Disconnect()
		record.HealthConnection = nil
	end
	if record.Model then
		record.Model:Destroy()
		record.Model = nil
		record.Humanoid = nil
	end
end

local function removeGroupAt(index: number)
	local group = table.remove(groups, index)
	if not group then
		return
	end
	if group.CasterDeathConnection then
		group.CasterDeathConnection:Disconnect()
		group.CasterDeathConnection = nil
	end
	for _, record in group.Slots do
		removeModel(record)
	end
	refreshOwnerCount(group.Owner)
end

local function bindGroupToCharacter(group: SummonGroup, caster: Model, now: number)
	if group.CasterDeathConnection then
		group.CasterDeathConnection:Disconnect()
		group.CasterDeathConnection = nil
	end
	group.Caster = caster
	group.RespawnDeadline = nil
	for _, record in group.Slots do
		record.Caster = caster
		record.Target = nil
		record.NextTargetScan = now
		record.NextAttack = now
		record.SpellCastUntil = 0
		setSpellStatus(record, if record.SpellSlot then "SEARCHING" else "UNASSIGNED", nil)
	end
	if not group.PersistAcrossRespawn then
		local humanoid = caster:FindFirstChildOfClass("Humanoid")
		if humanoid then
			group.CasterDeathConnection = humanoid.Died:Connect(function()
				local _, index = findGroup(group.Owner, group.SpellId)
				if index then
					removeGroupAt(index)
				end
			end)
		end
	end
end

findGroup = function(owner: Player, spellId: string): (SummonGroup?, number?)
	for index, group in groups do
		if group.Owner == owner and group.SpellId == spellId then
			return group, index
		end
	end
	return nil, nil
end

local function setNoCollision(part: BasePart, canQuery: boolean)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = canQuery
	part.Massless = true
end

local function makeSummonModel(record: SummonRecord, position: Vector3, archetype)
	local model = Instance.new("Model")
	model.Name = archetype.ModelName
	model:SetAttribute("MagicSummon", true)
	model:SetAttribute("MagicSummonId", record.Id)
	model:SetAttribute("MagicSummonArchetype", record.Archetype)
	model:SetAttribute("MagicSummonRole", record.Role)
	model:SetAttribute("MagicSummonOwnerUserId", record.Owner.UserId)
	model:SetAttribute("MagicSummonSpellId", record.SpellId)
	model:SetAttribute("MagicSummonSpellSlot", record.SpellSlot or 0)
	model:SetAttribute("MagicSummonSpellStatus", if record.SpellSlot then "SEARCHING" else "UNASSIGNED")
	model:SetAttribute("MagicSummonSpellReason", "")
	model:SetAttribute("MagicSummonSpellTarget", "")
	CollectionService:AddTag(model, "MagicAllyTarget")
	model:SetAttribute("SandboxAlignment", "Ally")

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.CFrame = CFrame.new(position)
	setNoCollision(root, false)
	root.Parent = model
	model.PrimaryPart = root

	local core = Instance.new("Part")
	core.Name = archetype.CorePartName
	core.Shape = Enum.PartType[archetype.CoreShape]
	core.Size = Vector3.one * archetype.CoreSize
	core.CFrame = root.CFrame
	core.Material = Enum.Material[archetype.CoreMaterial] or Enum.Material.Neon
	core.Color = record.Color
	core.Transparency = 0.08
	setNoCollision(core, true)
	core.Parent = model
	for index = 1, archetype.ArmorPlateCount do
		local angle = (index - 1) * math.pi * 2 / archetype.ArmorPlateCount
		local plate = Instance.new("Part")
		plate.Name = "SummonArmorPlate"
		plate.Size = Vector3.new(archetype.ArmorPlateThickness, archetype.ArmorPlateHeight, archetype.ArmorPlateWidth)
		plate.CFrame = root.CFrame
			* CFrame.new(
				math.cos(angle) * archetype.ArmorPlateDistance,
				0,
				math.sin(angle) * archetype.ArmorPlateDistance
			)
			* CFrame.Angles(0, -angle, math.rad(7))
		plate.Material = Enum.Material.Metal
		plate.Color = record.Color:Lerp(Color3.fromRGB(42, 47, 56), 0.48)
		setNoCollision(plate, false)
		plate.Parent = model
	end
	local light = Instance.new("PointLight")
	light.Color = record.Color
	light.Range = archetype.LightRange
	light.Brightness = archetype.LightBrightness
	light.Parent = core
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SummonSparks"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(record.Color)
	emitter.LightEmission = 0.8
	emitter.Lifetime = NumberRange.new(0.3, 0.7)
	emitter.Speed = NumberRange.new(0.3, 1.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
	emitter.Rate = archetype.ParticleRate
	emitter.Parent = core

	for index = 1, archetype.MoteCount do
		local angle = (index - 1) * math.pi * 2 / archetype.MoteCount
		local mote = Instance.new("Part")
		mote.Name = "SummonMote"
		mote.Shape = Enum.PartType.Ball
		mote.Size = Vector3.one * archetype.MoteSize
		mote.CFrame = root.CFrame
			* CFrame.new(math.cos(angle) * archetype.MoteDistance, 0, math.sin(angle) * archetype.MoteDistance)
		mote.Material = Enum.Material.Neon
		mote.Color = Color3.new(1, 1, 1)
		setNoCollision(mote, false)
		mote.Parent = model
		mote:SetAttribute("OrbitIndex", index)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = archetype.Health
	humanoid.Health = archetype.Health
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Name = "SummonNameplate"
	gui.Adornee = core
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffset = Vector3.new(0, 1.35, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 100
	gui.Parent = core
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(214, 235, 255)
	label.TextStrokeTransparency = 0.35
	label.Text = string.upper(archetype.Label)
	label.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "HealthFill"
	fill.Position = UDim2.fromOffset(22, 24)
	fill.Size = UDim2.new(1, -44, 0, 5)
	fill.BackgroundColor3 = Color3.fromRGB(39, 48, 59)
	fill.BorderSizePixel = 0
	fill.Parent = gui
	local health = Instance.new("Frame")
	health.Name = "CurrentHealth"
	health.Size = UDim2.fromScale(1, 1)
	health.BackgroundColor3 = Color3.fromRGB(110, 192, 255)
	health.BorderSizePixel = 0
	health.Parent = fill
	record.HealthConnection = humanoid.HealthChanged:Connect(function(value)
		health.Size = UDim2.fromScale(math.clamp(value / humanoid.MaxHealth, 0, 1), 1)
	end)

	model.Parent = folder
	model:PivotTo(CFrame.new(position))
	record.Model = model
	record.Humanoid = humanoid
	record.ModelAncestryConnection = model.AncestryChanged:Connect(function()
		if record.Model == model and not model:IsDescendantOf(workspace) then
			-- External removal must release health/death listeners immediately. Keep
			-- the slot empty until group expiry so repeated pulses cannot respawn it.
			removeModel(record)
			refreshOwnerCount(record.Owner)
		end
	end)
	record.DeathConnection = humanoid.Died:Connect(function()
		-- Keep the slot reserved until expiry; repeated Field/Aura pulses must not
		-- turn one cast into an unlimited respawn loop.
		removeModel(record)
		refreshOwnerCount(record.Owner)
	end)
end

local function canSee(record: SummonRecord, target: Model, from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { record.Model, record.Caster }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(from, to - from, params)
	return not hit or hit.Instance:IsDescendantOf(target)
end

local function isHostileTarget(candidate: Model): boolean
	return CollectionService:HasTag(candidate, "Enfleshed") or CollectionService:HasTag(candidate, "MagicHostileTarget")
end

local function scanSupportTarget(record: SummonRecord, core: BasePart, archetype, profile: any): Model?
	local best: Model? = nil
	local bestScore = math.huge
	local candidates: { Model } = {}
	local seen: { [Model]: boolean } = {}
	local function addCandidate(candidate: Model?)
		if candidate and not seen[candidate] then
			seen[candidate] = true
			table.insert(candidates, candidate)
		end
	end
	for _, player in Players:GetPlayers() do
		addCandidate(player.Character)
	end
	for _, candidate in CollectionService:GetTagged("MagicAllyTarget") do
		if candidate:IsA("Model") then
			addCandidate(candidate)
		end
	end
	for _, candidate in candidates do
		local humanoid = candidate and candidate:FindFirstChildOfClass("Humanoid")
		local root = candidate and candidate:FindFirstChild("HumanoidRootPart")
		if
			candidate
			and candidate:IsDescendantOf(workspace)
			and humanoid
			and humanoid.Health > 0
			and root
			and root:IsA("BasePart")
			and Conditions.relationshipMatches(record.Model, candidate, "Ally")
		then
			local distance = (root.Position - core.Position).Magnitude
			local missingHealth = profile.CanHeal and humanoid.Health < humanoid.MaxHealth
			local shield = humanoid:GetAttribute("MagicShield")
			local needsShield = profile.CanShield and (type(shield) ~= "number" or shield < profile.ShieldAmount)
			local armorBase = humanoid:GetAttribute("MagicArmor")
			local armorBonus = humanoid:GetAttribute("MagicArmorBonus")
			local armor = (if type(armorBase) == "number" then armorBase else 0)
				+ (if type(armorBonus) == "number" then armorBonus else 0)
			local needsArmor = profile.CanModifyAttribute and armor < profile.ArmorAmount
			local currentTimeRate = humanoid:GetAttribute("MagicTimeRate")
			-- Boon Enchantments go to allies that hold no Boon yet (recasts refresh).
			local enchantments = candidate:GetAttribute("MagicEnchantments")
			local needsEnchantment = profile.CanEnchant == true
				and not (type(enchantments) == "string" and string.find(enchantments, "Boon:", 1, true))
			local needsTimeDilation = profile.CanTimeDilation
				and math.abs((if type(currentTimeRate) == "number" then currentTimeRate else 1) - profile.TimeRate)
					> 0.05
			if
				distance
					<= RolePolicy.targetScanRange(profile.Range, archetype.SearchRadius, Config.CommandChaseRange)
				and (missingHealth or needsShield or needsArmor or needsTimeDilation or needsEnchantment)
				and canSee(record, candidate, core.Position, root.Position)
			then
				local healthRatio = humanoid.Health / math.max(1, humanoid.MaxHealth)
				local score = if missingHealth
					then healthRatio
					elseif needsArmor then 0.9
					elseif needsTimeDilation then 1
					elseif needsShield then 1.1
					else 1.2
				if score < bestScore then
					best, bestScore = candidate, score
				end
			end
		end
	end
	return best
end

local function scanTarget(
	record: SummonRecord,
	group: SummonGroup,
	now: number,
	archetype,
	ownerRoot: BasePart,
	profile: any?
): (Model?, string?)
	if now < record.NextTargetScan then
		return record.Target, record.TargetSearchReason
	end
	record.NextTargetScan = now + Config.TargetScanInterval
	local model = record.Model
	local coreName = archetype.CorePartName
	local core = model and model:FindFirstChild(coreName)
	if not core or not core:IsA("BasePart") then
		record.TargetSearchReason = "Summon core is unavailable"
		return nil, record.TargetSearchReason
	end
	local command = record.Command or group.Command
	local commandTarget = if record.Command ~= nil then record.CommandTarget else group.CommandTarget
	if command == "Hold" or command == "Move" or command == "Patrol" then
		record.Target = nil
		record.TargetSearchReason = nil
		return nil, nil
	end
	local role = Config.Roles[group.Role] or Config.Roles[Config.DefaultRole]
	local targetMode = RolePolicy.targetMode(role, command, profile and profile.Mode)
	if targetMode == "Ally" then
		record.Target = scanSupportTarget(record, core, archetype, profile)
		record.TargetSearchReason = if record.Target then nil else "No visible ally currently needs this support spell"
		return record.Target, record.TargetSearchReason
	end
	if targetMode == "None" then
		record.Target = nil
		record.TargetSearchReason = nil
		return record.Target, nil
	end
	if command == "Follow" then
		record.Target = nil
		record.TargetSearchReason = nil
		return nil, nil
	elseif command == "Attack" then
		local target = commandTarget
		local humanoid = target and target:FindFirstChildOfClass("Humanoid")
		local root = target and target:FindFirstChild("HumanoidRootPart")
		if
			target
			and target:IsDescendantOf(workspace)
			and isHostileTarget(target)
			and humanoid
			and humanoid.Health > 0
			and root
			and root:IsA("BasePart")
		then
			local distance = (root.Position - core.Position).Magnitude
			if distance <= Config.CommandChaseRange and canSee(record, target, core.Position, root.Position) then
				record.Target = target
				record.TargetSearchReason = nil
				return target, nil
			end
			record.Target = nil
			record.TargetSearchReason = if distance > Config.CommandChaseRange
				then "Marked hostile is beyond summon command range"
				else "Marked hostile is blocked from view"
			return nil, record.TargetSearchReason
		end
		if record.Command ~= nil then
			record.Command = "Protect"
			record.CommandTarget = nil
		else
			group.Command = "Protect"
			group.CommandTarget = nil
			for _, slot in group.Slots do
				slot.Target = nil
			end
		end
	end
	local best, bestDistance =
		nil, RolePolicy.targetScanRange(profile and profile.Range, archetype.SearchRadius, Config.CommandChaseRange)
	local hasTaggedHostile = false
	local hasLivingHostile = false
	local hasHostileInGuardRadius = false
	local hasHostileInScanRange = false
	local hasVisibleHostile = false
	local candidates = CollectionService:GetTagged("Enfleshed")
	for _, candidate in CollectionService:GetTagged("MagicHostileTarget") do
		table.insert(candidates, candidate)
	end
	for _, candidate in candidates do
		if
			candidate:IsA("Model")
			and candidate ~= record.Caster
			and candidate:IsDescendantOf(workspace)
			and isHostileTarget(candidate)
		then
			hasTaggedHostile = true
			local humanoid = candidate:FindFirstChildOfClass("Humanoid")
			local root = candidate:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				hasLivingHostile = true
				local distance = (root.Position - core.Position).Magnitude
				local protectingDistance = (root.Position - ownerRoot.Position).Magnitude
				local insideGuardRadius = not RolePolicy.requiresOwnerProtectionRadius(role)
					or protectingDistance <= Config.GuardRadius
				if insideGuardRadius then
					hasHostileInGuardRadius = true
				end
				if distance <= bestDistance then
					hasHostileInScanRange = true
					if insideGuardRadius and canSee(record, candidate, core.Position, root.Position) then
						hasVisibleHostile = true
						if distance < bestDistance then
							best, bestDistance = candidate, distance
						end
					end
				end
			end
		end
	end
	record.Target = best
	local reason = if best
		then nil
		else RolePolicy.noHostileTargetReason(role, {
			HasTaggedHostile = hasTaggedHostile,
			HasLivingHostile = hasLivingHostile,
			WithinGuardRadius = hasHostileInGuardRadius,
			WithinScanRange = hasHostileInScanRange,
			Visible = hasVisibleHostile,
		}, Config.GuardRadius)
	record.TargetSearchReason = reason
	return best, reason
end

local function updateRecord(record: SummonRecord, group: SummonGroup, now: number, delta: number, archetype)
	local model = record.Model
	local humanoid = record.Humanoid
	local casterHumanoid = record.Caster:FindFirstChildOfClass("Humanoid")
	local ownerRoot = record.Caster:FindFirstChild("HumanoidRootPart")
	local role = Config.Roles[record.Role] or Config.Roles[Config.DefaultRole]
	if
		not model
		or not model:IsDescendantOf(workspace)
		or not humanoid
		or humanoid.Health <= 0
		or not casterHumanoid
		or casterHumanoid.Health <= 0
		or group.Owner.Character ~= record.Caster
		or not ownerRoot
		or not ownerRoot:IsA("BasePart")
	then
		return
	end
	local core = model:FindFirstChild(archetype.CorePartName)
	if not core or not core:IsA("BasePart") then
		return
	end
	local angle = now * Config.OrbitRate + (record.Index - 1) * math.pi
	local bob = math.sin(now * archetype.BobRate + record.Index) * archetype.BobHeight
	local offset = Vector3.new(
		math.cos(angle) * archetype.FollowDistance,
		archetype.HoverHeight + bob,
		math.sin(angle) * archetype.FollowDistance
	)
	if now >= record.NextTargetScan then
		if record.SpellSlot and getCompanionProfile then
			record.SpellProfile, record.SpellProfileReason = getCompanionProfile(record.Owner, record.SpellSlot)
		else
			record.SpellProfile, record.SpellProfileReason = nil, nil
		end
	end
	local profile = record.SpellProfile
	local command = record.Command or group.Command
	local commandIssued = if record.Command ~= nil then record.CommandIssued else group.CommandIssued
	local commandPosition = if record.Command ~= nil then record.CommandPosition else group.CommandPosition
	local patrolPoints = if record.Command ~= nil then record.PatrolPoints else group.PatrolPoints
	local roleRequirementError: string? = nil
	if role.RequiredCapability and (not profile or profile[role.RequiredCapability] ~= true) then
		roleRequirementError = if role.RequiredCapability == "CanControl"
			then "Controller needs an assigned hostile spell with Slow, Bind, Control, or Displacement"
			else "Assigned companion spell does not meet this role's requirement"
	end
	local commandCastWaiting = profile
		and not CommandSpec.canExecuteCompanionSpell(profile.RequiresCommand, commandIssued, command)
	local target: Model? = nil
	local targetSearchReason: string? = nil
	if roleRequirementError or commandCastWaiting then
		target = nil
		targetSearchReason = nil
	else
		target, targetSearchReason = scanTarget(record, group, now, archetype, ownerRoot, profile)
	end
	local current = model:GetPivot().Position
	local goal = if command == "Hold"
		then record.HoldPosition or current
		elseif command == "Move" and commandPosition then commandPosition + record.MoveOffset + Vector3.new(
			0,
			archetype.HoverHeight + bob,
			0
		)
		elseif command == "Patrol" and patrolPoints and #patrolPoints > 0 then patrolPoints[record.PatrolIndex]
			+ record.MoveOffset
			+ Vector3.new(0, archetype.HoverHeight + bob, 0)
		elseif group.SpawnAt == "Event" and command == "Protect" then (record.SpawnPosition or ownerRoot.Position)
			+ Vector3.new(math.cos(angle) * 1.5, archetype.HoverHeight + bob, math.sin(angle) * 1.5)
		else ownerRoot.CFrame:PointToWorldSpace(offset)
	if command == "Attack" and target then
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot and targetRoot:IsA("BasePart") then
			goal = targetRoot.Position
				+ Vector3.new(math.cos(angle) * 7, archetype.HoverHeight + bob, math.sin(angle) * 7)
		end
	end
	local alpha = 1 - math.exp(-delta * Config.FollowResponsiveness)
	local nextPosition = current:Lerp(goal, alpha)
	model:PivotTo(CFrame.new(nextPosition))
	if command == "Patrol" and patrolPoints and #patrolPoints > 1 and (goal - current).Magnitude <= 2.5 then
		record.PatrolIndex = if record.PatrolIndex == 1 then 2 else 1
	end

	if not target then
		local status = if roleRequirementError
			then "INVALID SPELL"
			elseif commandCastWaiting then "COMMAND REQUIRED"
			elseif command == "Move" then "MOVING"
			elseif command == "Patrol" then if patrolPoints and #patrolPoints > 1
				then "PATROLLING"
				else "PATROL SET"
			elseif command == "Hold" then "HOLDING"
			elseif command == "Follow" then "FOLLOWING"
			elseif role.TargetMode == "AllySupport" and (not profile or profile.Mode ~= "Ally") then "INVALID SPELL"
			elseif record.SpellSlot and not profile and record.SpellProfileReason then "INVALID SPELL"
			elseif record.SpellSlot then "SEARCHING"
			else "UNASSIGNED"
		local statusReason = if commandCastWaiting
			then "Issue an Attack or Support order to activate this companion spell"
			elseif status == "SEARCHING" or status == "UNASSIGNED" then targetSearchReason
			elseif status ~= "INVALID SPELL" then nil
			elseif roleRequirementError then roleRequirementError
			elseif
				role.TargetMode == "AllySupport" and not record.SpellProfileReason
			then "Medic requires a compatible Ally support spell"
			else record.SpellProfileReason
		setSpellStatus(record, status, statusReason)
		return
	end
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetHumanoid or targetHumanoid.Health <= 0 or not targetRoot or not targetRoot:IsA("BasePart") then
		record.Target = nil
		return
	end
	local distance = (targetRoot.Position - core.Position).Magnitude
	local castRange = RolePolicy.castRange(profile and profile.Range, archetype.AttackRange, Config.CommandChaseRange)
	if distance > castRange then
		setSpellStatus(record, "OUT OF RANGE", "Target is beyond summon attack range")
		return
	end
	if not canSee(record, target, core.Position, targetRoot.Position) then
		setSpellStatus(record, "BLOCKED", "A world obstacle blocks line of sight")
		return
	end
	if now < record.NextAttack then
		if record.SpellStatus == "CASTING" and now < record.SpellCastUntil then
			setSpellStatus(record, "CASTING", record.SpellStatusReason)
			return
		end
		setSpellStatus(
			record,
			if profile then "COOLDOWN" else "MELEE",
			if profile then string.format("Ready in %ds", math.ceil(record.NextAttack - now)) else nil
		)
		return
	end
	if record.SpellSlot and castCompanionSpell then
		local casted, cooldown, assignedSpellUsable, reason, castDuration =
			castCompanionSpell(record.Owner, model, record.SpellSlot, record.Id, target)
		if casted then
			-- MagicService owns spell cooldown progression, including local time rate.
			-- This is only a short retry throttle so summons do not poll every frame.
			record.NextAttack = now + math.max(0.25, Config.TargetScanInterval)
			record.SpellCastUntil = now + (castDuration or 0)
			setSpellStatus(record, "CASTING", "Server cast accepted")
			return
		elseif assignedSpellUsable then
			local lowered = string.lower(reason or "")
			record.NextAttack = now
				+ if string.find(lowered, "cool", 1, true)
					then math.max(0.25, Config.TargetScanInterval)
					else math.max(0.25, cooldown)
			local status = if string.find(lowered, "range", 1, true)
				then "OUT OF RANGE"
				elseif
					string.find(lowered, "cast", 1, true) or string.find(lowered, "channel", 1, true)
				then "OWNER BUSY"
				elseif string.find(lowered, "mana", 1, true) or string.find(lowered, "strain", 1, true) or string.find(
					lowered,
					"complexity",
					1,
					true
				) then "RESOURCE LIMIT"
				elseif string.find(lowered, "obstruct", 1, true) then "BLOCKED"
				elseif string.find(lowered, "cool", 1, true) then "COOLDOWN"
				else "REJECTED"
			setSpellStatus(record, status, reason)
			return
		end
	end
	if not RolePolicy.canMelee(role, profile and profile.Mode) then
		record.NextAttack = now + math.max(0.25, archetype.AttackInterval)
		setSpellStatus(
			record,
			"REJECTED",
			if role.TargetMode == "AllySupport"
				then "Medic requires a compatible Ally support spell"
				else "Assigned support spell could not be cast"
		)
		return
	end
	record.NextAttack = now + archetype.AttackInterval
	setSpellStatus(record, "MELEE", if record.SpellSlot and not profile then record.SpellProfileReason else nil)
	Presentation.beam(core.Position, targetRoot.Position, archetype.BeamWidth, record.Color, archetype.BeamDuration)
	Damage.apply(model, targetHumanoid, archetype.AttackDamage)
end

function Summons.start(
	castSpell: CompanionCaster?,
	getProfile: CompanionProfileGetter?,
	remote: RemoteEvent,
	commandExecutor: CommandExecutor?
)
	if started then
		return
	end
	started = true
	castCompanionSpell = if castSpell
		then function(owner, caster, slot, summonId, target)
			return castSpell(owner, caster, slot, summonId, target, remote)
		end
		else nil
	getCompanionProfile = getProfile
	executeCommandEvent = commandExecutor
	local existing = workspace:FindFirstChild("MagicSummons")
	if existing and existing:IsA("Folder") then
		folder = existing
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MagicSummons"
		folder.Parent = workspace
	end
	Players.PlayerRemoving:Connect(function(player)
		Summons.clearOwner(player)
	end)
	RunService.Heartbeat:Connect(function(delta)
		local now = os.clock()
		for index = #groups, 1, -1 do
			local group = groups[index]
			local casterHumanoid = group.Caster:FindFirstChildOfClass("Humanoid")
			local ownerCharacter = group.Owner.Character
			local ownerHumanoid = ownerCharacter and ownerCharacter:FindFirstChildOfClass("Humanoid")
			local ownerAlive = ownerCharacter ~= nil
				and ownerCharacter:IsDescendantOf(workspace)
				and ownerHumanoid ~= nil
				and ownerHumanoid.Health > 0
			if now >= group.ExpiresAt or group.Owner.Parent ~= Players then
				removeGroupAt(index)
			elseif
				group.Owner.Character ~= group.Caster
				or not group.Caster:IsDescendantOf(workspace)
				or not casterHumanoid
				or casterHumanoid.Health <= 0
			then
				if not group.PersistAcrossRespawn then
					removeGroupAt(index)
				else
					group.RespawnDeadline = group.RespawnDeadline or (now + Config.RespawnGracePeriod)
					if now >= group.RespawnDeadline then
						removeGroupAt(index)
					elseif ownerAlive and ownerCharacter then
						bindGroupToCharacter(group, ownerCharacter, now)
						local archetype = Config.Archetypes[group.Archetype]
						for _, record in group.Slots do
							updateRecord(record, group, now, delta, archetype)
						end
					else
						for _, record in group.Slots do
							setSpellStatus(record, "WAITING FOR OWNER", "Party resumes when you respawn")
						end
					end
				end
			else
				local archetype = Config.Archetypes[group.Archetype]
				for _, record in group.Slots do
					updateRecord(record, group, now, delta, archetype)
				end
			end
		end
	end)
end

function Summons.apply(
	owner: Player,
	caster: Model,
	spellId: string,
	payload: any,
	color: Color3,
	sourceDefinition: any,
	sourceRemote: RemoteEvent,
	sourceDirection: Vector3,
	sourcePotency: number,
	eventPosition: Vector3?
): (boolean, number, string?)
	if
		dismissedGroups[owner] and dismissedGroups[owner][spellId]
		or (dismissAllUntilCast[owner] and not (rearmedAfterDismiss[owner] and rearmedAfterDismiss[owner][spellId]))
	then
		return false, liveCount(owner), "Summon dismissed · recast the spell to summon again"
	end
	local archetype = Config.Archetypes[payload.Archetype]
	local role = Config.Roles[payload.Role or Config.DefaultRole]
	local spawnAt = payload.SpawnAt or "Caster"
	local casterHumanoid = caster:FindFirstChildOfClass("Humanoid")
	if
		not started
		or not folder
		or not archetype
		or not role
		or owner.Parent ~= Players
		or owner.Character ~= caster
		or not caster:IsDescendantOf(workspace)
		or not casterHumanoid
		or casterHumanoid.Health <= 0
	then
		return false, liveCount(owner), "Summon is unavailable for this character"
	end
	local casterRoot = caster:FindFirstChild("HumanoidRootPart")
	local casterPosition = if casterRoot and casterRoot:IsA("BasePart")
		then casterRoot.Position
		else caster:GetPivot().Position
	local spawnPosition = casterPosition
	if spawnAt == "Event" then
		if
			typeof(eventPosition) ~= "Vector3"
			or not CommandSpec.validPointCoordinates(eventPosition.X, eventPosition.Y, eventPosition.Z)
			or (eventPosition - casterPosition).Magnitude > Config.MaxEventSpawnRange
		then
			return false, liveCount(owner), "Trigger point is outside the allowed summon placement range"
		end
		-- Trigger locations are often surface impact points. Spawn the core just
		-- behind the incoming cast so it does not begin embedded in the surface.
		spawnPosition = Placement.behindImpact(eventPosition, sourceDirection, archetype.CoreSize * 0.5 + 0.75)
	elseif spawnAt ~= "Caster" then
		return false, liveCount(owner), "Unknown summon placement"
	end
	local now = os.clock()
	local group = findGroup(owner, spellId)
	if
		group
		and (
			group.Archetype ~= payload.Archetype
			or group.Role ~= (payload.Role or Config.DefaultRole)
			or group.SpawnAt ~= spawnAt
		)
	then
		local _, index = findGroup(owner, spellId)
		if index then
			removeGroupAt(index)
		end
		group = nil
	end
	if not group then
		group = {
			Owner = owner,
			Caster = caster,
			SpellId = spellId,
			Archetype = payload.Archetype,
			Role = payload.Role or Config.DefaultRole,
			SpawnAt = spawnAt,
			Color = color,
			Slots = {},
			Command = Config.DefaultCommand,
			CommandIssued = false,
			CommandTarget = nil,
			CommandPosition = nil,
			PatrolPoints = nil,
			ExpiresAt = if payload.LifetimeMode == "UntilCommanded" then math.huge else now + payload.Duration,
			PersistAcrossRespawn = payload.LifetimeMode == "UntilCommanded"
				and payload.RespawnPolicy == "PersistUntilDismissed",
			RespawnDeadline = nil,
			LastCapacityNotice = 0,
			SourceDefinition = sourceDefinition,
			SourceRemote = sourceRemote,
			SourceDirection = sourceDirection,
			SourcePotency = sourcePotency,
			CasterDeathConnection = nil,
		}
		table.insert(groups, group)
		bindGroupToCharacter(group, caster, now)
	else
		group.ExpiresAt = if payload.LifetimeMode == "UntilCommanded" then math.huge else now + payload.Duration
		if spawnAt == "Caster" then
			group.CommandIssued = false
		end
		group.PersistAcrossRespawn = payload.LifetimeMode == "UntilCommanded"
			and payload.RespawnPolicy == "PersistUntilDismissed"
		if not group.PersistAcrossRespawn then
			group.RespawnDeadline = nil
		end
		group.Color = color
		group.Role = payload.Role or Config.DefaultRole
		group.SpawnAt = spawnAt
		group.SourceDefinition = sourceDefinition
		group.SourceRemote = sourceRemote
		group.SourceDirection = sourceDirection
		group.SourcePotency = sourcePotency
		if group.Caster ~= caster then
			bindGroupToCharacter(group, caster, now)
		end
	end
	local spellSlot = tonumber(payload.SpellSlot)
	local countPerTrigger = math.clamp(payload.Count, 1, math.min(Config.MaxActivePerSpell, Config.MaxCountPerCast))
	local requestedCount = if spawnAt == "Event"
		then math.min(Config.MaxActivePerSpell, #group.Slots + countPerTrigger)
		else countPerTrigger
	while spawnAt == "Caster" and #group.Slots > requestedCount do
		local record = table.remove(group.Slots)
		if record then
			removeModel(record)
		end
	end
	local created = false
	if spawnAt == "Caster" then
		-- A dead or externally removed Caster summon keeps its bounded group slot
		-- until expiry. Recasting should refill that slot instead of silently
		-- leaving the group empty because its slot array is already at capacity.
		for index, record in group.Slots do
			if index > requestedCount then
				break
			end
			if
				not record.Model
				and liveCount(owner) < Config.MaxActivePerPlayer
				and liveCount(nil) < Config.MaxActiveGlobal
			then
				record.Caster = caster
				record.SpawnPosition = spawnPosition
				record.NextTargetScan = now
				record.NextAttack = now + (archetype.AttackInterval or 0)
				record.Target = nil
				record.HoldPosition = nil
				local angle = now * Config.OrbitRate + (record.Index - 1) * math.pi
				local initialOffset = Vector3.new(
					math.cos(angle) * archetype.FollowDistance,
					archetype.HoverHeight,
					math.sin(angle) * archetype.FollowDistance
				)
				makeSummonModel(record, record.SpawnPosition + initialOffset, archetype)
				created = true
			end
		end
	end
	for _, record in group.Slots do
		if record.SpellSlot ~= spellSlot then
			record.SpellSlot = spellSlot
			record.Target = nil
			record.SpellProfile = nil
			record.SpellProfileReason = nil
			record.SpellStatus = nil
			record.SpellStatusReason = nil
			record.SpellCastUntil = 0
			record.NextTargetScan = 0
			record.NextAttack = now
			setSpellStatus(record, if spellSlot then "SEARCHING" else "UNASSIGNED", nil)
		end
	end
	while #group.Slots < requestedCount do
		if liveCount(owner) >= Config.MaxActivePerPlayer or liveCount(nil) >= Config.MaxActiveGlobal then
			if now - group.LastCapacityNotice >= 5 then
				group.LastCapacityNotice = now
				refreshOwnerCount(owner)
				local message = if created
					then archetype.Label .. " summoned; remaining summon capacity is full"
					else "Summon capacity reached"
				return created, liveCount(owner), message
			end
			break
		end
		local index = #group.Slots + 1
		local recordSpawnPosition = spawnPosition
		if spawnAt == "Event" then
			local angle = index * 2.4
			recordSpawnPosition += Vector3.new(math.cos(angle) * 2, 0, math.sin(angle) * 2)
		end
		nextRecordId += 1
		local record: SummonRecord = {
			Owner = owner,
			Caster = caster,
			SpellId = spellId,
			Archetype = payload.Archetype,
			Role = payload.Role or Config.DefaultRole,
			Index = index,
			Id = nextRecordId,
			SpellSlot = spellSlot,
			Color = color,
			SpawnPosition = recordSpawnPosition,
			Model = nil,
			Humanoid = nil,
			NextTargetScan = now + (index - 1) * 0.09,
			NextAttack = now + archetype.AttackInterval,
			Target = nil,
			HoldPosition = nil,
			MoveOffset = Vector3.zero,
			PatrolPoints = nil,
			PatrolIndex = 1,
			DeathConnection = nil,
			HealthConnection = nil,
			ModelAncestryConnection = nil,
			SpellProfile = nil,
			SpellProfileReason = nil,
			SpellStatus = nil,
			SpellStatusReason = nil,
			TargetSearchReason = nil,
			SpellCastUntil = 0,
			CommandIssued = false,
		}
		local initialPosition = if spawnAt == "Caster"
			then recordSpawnPosition + Vector3.new(
				math.cos(now * Config.OrbitRate + (index - 1) * math.pi) * archetype.FollowDistance,
				archetype.HoverHeight,
				math.sin(now * Config.OrbitRate + (index - 1) * math.pi) * archetype.FollowDistance
			)
			else recordSpawnPosition + Vector3.new(0, archetype.HoverHeight + 1, 0)
		makeSummonModel(record, initialPosition, archetype)
		table.insert(group.Slots, record)
		created = true
	end
	refreshOwnerCount(owner)
	if created then
		return true, liveCount(owner), string.format("%s summoned · %d active", archetype.Label, liveCount(owner))
	end
	if spawnAt == "Event" and #group.Slots >= Config.MaxActivePerSpell and now - group.LastCapacityNotice >= 5 then
		group.LastCapacityNotice = now
		return false, liveCount(owner), "Per-spell summon limit reached"
	end
	return false, liveCount(owner), nil
end

function Summons.command(owner: Player, mode: any, target: any, worldPoint: any?, selectedId: any?): (boolean, string)
	if not table.find(Config.CommandOrder, mode) then
		return false, "Unknown summon command"
	end
	local character = owner.Character
	local ownerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local ownerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		owner.Parent ~= Players
		or not character
		or not ownerRoot
		or not ownerRoot:IsA("BasePart")
		or not ownerHumanoid
		or ownerHumanoid.Health <= 0
	then
		return false, "Character is not ready"
	end
	local selectedRecord: SummonRecord? = nil
	local selectedGroup: SummonGroup? = nil
	if selectedId ~= nil and mode ~= "Dismiss" then
		if not CommandSpec.validSelectionId(selectedId) then
			return false, "Invalid summon selection"
		end
		for _, group in groups do
			if group.Owner == owner and group.Caster == character then
				for _, record in group.Slots do
					if
						CommandSpec.matchesSelection(record.Id, selectedId)
						and record.Model
						and record.Model:IsDescendantOf(workspace)
						and record.Humanoid
						and record.Humanoid.Health > 0
					then
						selectedRecord = record
						selectedGroup = group
						break
					end
				end
			end
			if selectedRecord then
				break
			end
		end
		if not selectedRecord then
			return false, "Selected summon is no longer active"
		end
	end
	local function matchesCommandGroup(group: SummonGroup): boolean
		return group.Owner == owner
			and group.Caster == character
			and (selectedRecord == nil or table.find(group.Slots, selectedRecord) ~= nil)
	end
	local activeGroups = 0
	for _, group in groups do
		if matchesCommandGroup(group) then
			if mode == "Dismiss" then
				activeGroups += 1
				continue
			end
			for _, record in group.Slots do
				if
					record.Model
					and record.Model:IsDescendantOf(workspace)
					and record.Humanoid
					and record.Humanoid.Health > 0
				then
					activeGroups += 1
					break
				end
			end
		end
	end
	if activeGroups == 0 and mode ~= "Dismiss" then
		return false, "No active summons to command"
	end
	if mode == "Attack" then
		for _, group in groups do
			if matchesCommandGroup(group) then
				local role = Config.Roles[group.Role] or Config.Roles[Config.DefaultRole]
				if role.TargetMode == "AllySupport" then
					return false, "Medic summons only accept Follow, Protect, Hold, or Support orders"
				end
			end
		end
	end
	if mode == "Support" then
		local hasSupportSpell = false
		for _, group in groups do
			if matchesCommandGroup(group) then
				for _, record in group.Slots do
					local profile = (not selectedRecord or record == selectedRecord)
						and record.SpellSlot
						and getCompanionProfile
						and getCompanionProfile(owner, record.SpellSlot)
					if profile and profile.Mode == "Ally" then
						hasSupportSpell = true
						break
					end
				end
			end
			if hasSupportSpell then
				break
			end
		end
		if not hasSupportSpell then
			return false, "Assign a valid Ally-targeting support spell to the summon’s companion spell slot first"
		end
	end

	local attackTarget: Model? = nil
	local movePosition: Vector3? = nil
	local selectedPatrolPoints: { Vector3 }? = nil
	if mode == "Attack" then
		if
			typeof(target) ~= "Instance"
			or not target:IsA("Model")
			or target == character
			or not target:IsDescendantOf(workspace)
			or not isHostileTarget(target)
		then
			return false, "Aim at a living hostile to order an attack"
		end
		local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if not targetHumanoid or targetHumanoid.Health <= 0 or not targetRoot or not targetRoot:IsA("BasePart") then
			return false, "Attack target is not a living character"
		end
		local delta = targetRoot.Position - ownerRoot.Position
		if delta.Magnitude > Config.MaxCommandRange then
			return false, "Attack target is outside command range"
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.RespectCanCollide = true
		local obstruction = workspace:Raycast(ownerRoot.Position, delta, params)
		if obstruction and not obstruction.Instance:IsDescendantOf(target) then
			return false, "Attack target is obstructed"
		end
		attackTarget = target
	end
	if mode == "Move" or mode == "Patrol" then
		if
			typeof(worldPoint) ~= "Vector3"
			or not CommandSpec.validPointCoordinates(worldPoint.X, worldPoint.Y, worldPoint.Z)
		then
			return false,
				if mode == "Patrol"
					then "Aim at a visible surface to set a patrol waypoint"
					else "Aim at a reachable surface to move summons"
		end
		local delta = worldPoint - ownerRoot.Position
		if delta.Magnitude < 2 or delta.Magnitude > Config.MaxMoveOrderRange then
			return false, "Command point is outside move range"
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, folder }
		params.RespectCanCollide = true
		local hit = workspace:Raycast(ownerRoot.Position, delta, params)
		if not hit then
			return false, "Command point must be on a visible solid surface"
		end
		movePosition = hit.Position
		if mode == "Patrol" and selectedRecord and selectedGroup then
			local previous = if selectedRecord.Command ~= nil
				then if selectedRecord.Command == "Patrol" then selectedRecord.PatrolPoints else nil
				else if selectedGroup.Command == "Patrol" then selectedGroup.PatrolPoints else nil
			if
				previous
				and #previous == 1
				and (previous[1] - movePosition).Magnitude < Config.MinPatrolWaypointDistance
			then
				return false, "Patrol waypoints need more separation"
			end
			selectedPatrolPoints = CommandSpec.nextPatrolRoute(previous, movePosition)
		elseif mode == "Patrol" then
			for _, group in groups do
				if
					matchesCommandGroup(group)
					and group.Command == "Patrol"
					and group.PatrolPoints
					and #group.PatrolPoints == 1
					and (group.PatrolPoints[1] - movePosition).Magnitude < Config.MinPatrolWaypointDistance
				then
					return false, "Patrol waypoints need more separation"
				end
			end
		end
	end

	local commandEvents = {}
	local patrolComplete = false
	if selectedPatrolPoints then
		patrolComplete = #selectedPatrolPoints > 1
	end
	for _, group in groups do
		if matchesCommandGroup(group) then
			if selectedRecord then
				selectedRecord.Command = mode
				selectedRecord.CommandIssued = true
				selectedRecord.CommandTarget = attackTarget
				selectedRecord.CommandPosition = if mode == "Move" then movePosition else nil
				selectedRecord.PatrolPoints = selectedPatrolPoints
				selectedRecord.PatrolIndex = 1
			else
				local patrolPoints = if mode == "Patrol"
					then CommandSpec.nextPatrolRoute(
						if group.Command == "Patrol" then group.PatrolPoints else nil,
						movePosition
					)
					else nil
				if patrolPoints and #patrolPoints > 1 then
					patrolComplete = true
				end
				group.Command = mode
				group.CommandIssued = true
				group.CommandTarget = attackTarget
				group.CommandPosition = if mode == "Move" then movePosition else nil
				group.PatrolPoints = patrolPoints
			end
			local commandTargets = {}
			for _, record in group.Slots do
				if selectedRecord then
					if record == selectedRecord then
						record.Target = attackTarget
						record.HoldPosition = if mode == "Hold" and record.Model
							then record.Model:GetPivot().Position
							else nil
						record.MoveOffset = Vector3.zero
						record.PatrolIndex = 1
						record.NextTargetScan = 0
					end
				else
					record.Command = nil
					record.CommandTarget = nil
					record.CommandPosition = nil
					record.PatrolPoints = nil
					record.PatrolIndex = 1
					record.Target = attackTarget
					record.HoldPosition = if mode == "Hold" and record.Model
						then record.Model:GetPivot().Position
						else nil
					record.MoveOffset = if mode == "Move" or mode == "Patrol"
						then Vector3.new(
							math.cos(record.Index * math.pi / 2) * 2.5,
							0,
							math.sin(record.Index * math.pi / 2) * 2.5
						)
						else Vector3.zero
					record.NextTargetScan = 0
				end
				if
					(not selectedRecord or record == selectedRecord)
					and not attackTarget
					and record.Humanoid
					and record.Humanoid.Health > 0
					and record.Humanoid:IsDescendantOf(workspace)
				then
					table.insert(commandTargets, record.Humanoid)
				end
			end
			if attackTarget then
				local targetHumanoid = attackTarget:FindFirstChildOfClass("Humanoid")
				if targetHumanoid and not table.find(commandTargets, targetHumanoid) then
					table.insert(commandTargets, targetHumanoid)
				end
			end
			if #commandTargets > 0 then
				table.insert(commandEvents, { Group = group, Targets = commandTargets })
			end
		end
	end
	if executeCommandEvent then
		for _, event in commandEvents do
			local group = event.Group
			executeCommandEvent(
				owner,
				group.Caster,
				group.SourceDefinition,
				group.SourceRemote,
				group.SourceDirection,
				group.SourcePotency,
				mode,
				event.Targets
			)
		end
	end
	if mode == "Dismiss" then
		dismissAllUntilCast[owner] = true
		rearmedAfterDismiss[owner] = nil
		local ownerDismissed = dismissedGroups[owner]
		if not ownerDismissed then
			ownerDismissed = {}
			dismissedGroups[owner] = ownerDismissed
		end
		for index = #groups, 1, -1 do
			local group = groups[index]
			if group.Owner == owner and group.Caster == character then
				ownerDismissed[group.SpellId] = true
				removeGroupAt(index)
			end
		end
		refreshOwnerCount(owner)
		return true, "Summons dismissed until their spells are cast again"
	end
	local text = if attackTarget then "Attack " .. attackTarget.Name elseif movePosition then "Move order" else mode
	local recipient = if selectedRecord then "selected summon" else tostring(activeGroups) .. " summon group(s)"
	if mode == "Patrol" then
		return true,
			if patrolComplete
				then "Two-waypoint patrol started for " .. recipient
				else "Patrol waypoint set; issue Patrol again to set the return point"
	end
	return true, text .. " order set for " .. recipient
end

function Summons.clearSpell(owner: Player, spellId: string)
	if dismissedGroups[owner] then
		dismissedGroups[owner][spellId] = nil
		if next(dismissedGroups[owner]) == nil then
			dismissedGroups[owner] = nil
		end
	end
	local _, index = findGroup(owner, spellId)
	if index then
		removeGroupAt(index)
	end
end

function Summons.clearDismissal(owner: Player, spellId: string)
	if dismissAllUntilCast[owner] then
		local rearmed = rearmedAfterDismiss[owner]
		if not rearmed then
			rearmed = {}
			rearmedAfterDismiss[owner] = rearmed
		end
		rearmed[spellId] = true
	end
	local ownerDismissed = dismissedGroups[owner]
	if not ownerDismissed then
		return
	end
	ownerDismissed[spellId] = nil
	if next(ownerDismissed) == nil then
		dismissedGroups[owner] = nil
	end
end

function Summons.clearOwner(owner: Player)
	dismissedGroups[owner] = nil
	dismissAllUntilCast[owner] = nil
	rearmedAfterDismiss[owner] = nil
	for index = #groups, 1, -1 do
		if groups[index].Owner == owner then
			removeGroupAt(index)
		end
	end
	if owner.Parent == Players then
		owner:SetAttribute("ActiveMagicSummons", 0)
	end
end

return Summons
