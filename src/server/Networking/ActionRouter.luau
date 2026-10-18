--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox"))
local Protocol = require(Shared:WaitForChild("Networking"):WaitForChild("Protocol"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local TargetConsent = require(Shared.Modules.MagicTargetConsentSpec)
local Services = script.Parent.Parent.Services
local Movement = require(Services.MovementService)
local Combat = require(Services.CombatService)
local Damage = require(Services.DamageService)
local Magic = require(Services.MagicService)
local Equipment = require(Services.EquipmentService)
local Inventory = require(Services.InventoryService)
local Summons = require(Services.SummonService)
local Telemetry = require(Services.TelemetryService)
local StudioSandbox = require(Shared.Configuration.DevelopmentSandbox)
local SandboxSpawn = require(Shared.Configuration.CombatBattleMap).Spawn
local Router = {}

local function playerReady(player: Player): boolean
	return player:GetAttribute("CharacterReady") == true or (RunService:IsStudio() and StudioSandbox.Enabled == true)
end

function Router.start()
	local folder = Shared:FindFirstChild(Protocol.Folder) :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Protocol.Folder
		folder.Parent = Shared
	end
	local function remote(name: string): RemoteEvent
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local event = Instance.new("RemoteEvent")
		event.Name, event.Parent = name, folder
		return event
	end
	local request = remote(Protocol.Request)
	local feedback = remote(Protocol.Feedback)
	local aerialControl = remote(Protocol.AerialControl)
	-- Publish core transport before optional services or the battlefield build;
	-- clients can start their camera and launcher even if later startup reports an error.
	Damage.Applied:Connect(function(_attacker: Model, target: Humanoid, amount: number)
		local model = target.Parent
		if model and model:IsA("Model") then
			feedback:FireAllClients({
				Kind = "ImpactNumber",
				Effect = "Damage",
				Amount = amount,
				Target = model,
			})
		end
	end)
	Inventory.start(folder)
	Equipment.start(feedback)

	local states: { [Player]: Types.PlayerState } = {}
	local limits: { [Player]: { Tokens: number, Updated: number, Sequence: number } } = {}
	local connections: { [Player]: { RBXScriptConnection } } = {}
	local aerialInputAt: { [Player]: number } = {}
	local function clearState(player: Player)
		local state = states[player]
		if state then
			Combat.reset(state)
			Movement.unbind(state)
			states[player] = nil
		end
		aerialInputAt[player] = nil
	end

	local function bind(player: Player)
		if player:GetAttribute(TargetConsent.Attribute) == nil then
			player:SetAttribute(TargetConsent.Attribute, false)
		end
		limits[player] = { Tokens = Config.Networking.Burst, Updated = os.clock(), Sequence = 0 }
		Magic.bind(player)
		Equipment.bind(player)
		local function characterAdded(character: Model)
			if player.Character ~= character then
				return
			end
			clearState(player)
			player:SetAttribute("CharacterReady", false)
			Magic.reset(player)
			local humanoid = character:WaitForChild("Humanoid", 10)
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if
				player.Character ~= character
				or not humanoid
				or not humanoid:IsA("Humanoid")
				or not root
				or not root:IsA("BasePart")
				or not limits[player]
			then
				return
			end
			-- CharacterAdded precedes parenting, rig scaling, and final spawn placement.
			-- Do not seed a movement anchor from the provisional character transform.
			local deadline = os.clock() + Config.Movement.CharacterReadyTimeout
			while not root:IsDescendantOf(workspace) do
				if player.Character ~= character or not limits[player] or humanoid.Health <= 0 then
					return
				end
				if os.clock() >= deadline then
					warn("Sandbox: character did not enter Workspace for " .. player.Name)
					return
				end
				RunService.Heartbeat:Wait()
			end
			if player.Character ~= character or not limits[player] or humanoid.Health <= 0 then
				return
			end
			local missionConfig = require(Shared.Configuration.DefendTheWalls)
			-- Defenders respawn behind the wall currently holding (it moves back as walls fall).
			local mission = workspace:FindFirstChild("DefendTheWalls")
			local fallback = mission and mission:GetAttribute("DefenderSpawn")
			local spawn = if player:GetAttribute("MissionDefender") == true
				then (if typeof(fallback) == "Vector3" then fallback else missionConfig.Defender)
				elseif player:GetAttribute("MissionSandbox") == true then SandboxSpawn
				else missionConfig.Hub
			character:PivotTo(CFrame.new(spawn))
			local now = workspace:GetServerTimeNow()
			humanoid.MaxHealth = Config.Player.MaxHealth
			humanoid.Health = Config.Player.MaxHealth
			humanoid.WalkSpeed = Config.Movement.WalkSpeed
			character:SetAttribute("MagicWalkSpeedBonus", 0)
			character:SetAttribute("MagicSpeedMultiplier", 1)
			character:SetAttribute("MagicJumpPowerBonus", 0)
			states[player] = {
				Character = character,
				Humanoid = humanoid,
				Root = root,
				Sprinting = false,
				MagicWalkSpeedBonus = 0,
				MagicSpeedMultiplier = 1,
				MagicSlowMultiplier = 1,
				MagicCastingMultiplier = 1,
				MagicRotationLocked = false,
				MagicCastingDirection = nil,
				MagicBaseJumpHeight = humanoid.JumpHeight,
				MagicJumpPowerBonus = 0,
				MagicAerialSpeed = 0,
				MagicAerialInput = Vector3.zero,
				MagicAerialInputExpiresAt = 0,
				MagicAerialAttachment = nil,
				MagicAerialVelocity = nil,
				DashUntil = 0,
				DashReadyAt = 0,
				DashCheckUntil = 0,
				DashOrigin = nil,
				LastPosition = root.Position,
				LastFramePosition = root.Position,
				LastCheck = now,
				DashAllowance = 0,
				CorrectionUntil = 0,
				SpawnGraceUntil = now + Config.Movement.SpawnValidationGrace,
				Combo = 0,
				ReadyAt = 0,
				ComboExpires = 0,
				Attack = nil,
				ActiveAt = 0,
				ActiveUntil = 0,
				HitTargets = {},
				Heavy = false,
				Blocking = false,
				AttackFacing = nil,
				DamageScale = 1,
				ParryBonusUntil = 0,
			}
			Movement.bind(states[player])
			character:SetAttribute("MagicSlowMultiplier", 1)
			character:SetAttribute("MagicCastingMultiplier", 1)
			character:SetAttribute("MagicCastingLocked", false)
			character:SetAttribute("MagicRotationLocked", false)
			Equipment.characterAdded(player, feedback)
			if require(Services.CombatSandboxService).enabled() then
				Equipment.chooseStarter(player, "Magic", feedback)
			end
			player:SetAttribute("CharacterReady", true)
			Telemetry.onboarding(player, "Spawned")
		end
		connections[player] = {
			player.CharacterAdded:Connect(characterAdded),
			player.CharacterRemoving:Connect(function(character)
				local state = states[player]
				if state and state.Character == character then
					clearState(player)
				end
			end),
		}
		if player.Character then
			task.spawn(characterAdded, player.Character)
		end
	end

	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		clearState(player)
		limits[player] = nil
		Magic.remove(player)
		Equipment.remove(player)
		for _, connection in connections[player] or {} do
			connection:Disconnect()
		end
		connections[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		bind(player)
	end

	aerialControl.OnServerEvent:Connect(function(player: Player, character: any, direction: any)
		local state = states[player]
		if
			not state
			or not playerReady(player)
			or character ~= state.Character
			or player.Character ~= state.Character
			or state.Humanoid.Health <= 0
			or not state.Root:IsDescendantOf(workspace)
		then
			return
		end
		local now = workspace:GetServerTimeNow()
		if now - (aerialInputAt[player] or 0) < 0.075 then
			return
		end
		aerialInputAt[player] = now
		if typeof(direction) == "Vector3" then
			Movement.aerialInput(state, direction, now)
		end
	end)

	request.OnServerEvent:Connect(function(player: Player, payload: any)
		local limit = limits[player]
		if not limit or not playerReady(player) then
			return
		end
		local clock = os.clock()
		limit.Tokens = math.min(
			Config.Networking.Burst,
			limit.Tokens + (clock - limit.Updated) * Config.Networking.RequestsPerSecond
		)
		limit.Updated = clock
		if limit.Tokens < 1 then
			return
		end
		limit.Tokens -= 1
		if typeof(payload) ~= "table" then
			return
		end
		local sequence = payload.Sequence
		if
			typeof(sequence) ~= "number"
			or sequence ~= sequence
			or sequence % 1 ~= 0
			or sequence <= limit.Sequence
			or sequence > Config.Networking.MaxSequence
		then
			return
		end
		limit.Sequence = sequence
		local action = payload.Action
		if
			action ~= Protocol.Sprint
			and action ~= Protocol.Dash
			and action ~= Protocol.Light
			and action ~= Protocol.Heavy
			and action ~= Protocol.BlockStart
			and action ~= Protocol.BlockEnd
			and action ~= Protocol.MagicStart
			and action ~= Protocol.MagicRelease
			and action ~= Protocol.MagicAimUpdate
			and action ~= Protocol.EquipmentSwitch
			and action ~= Protocol.EquipmentUse
			and action ~= Protocol.SummonCommand
			and action ~= Protocol.MagicConsent
		then
			return
		end
		local state = states[player]
		if
			not state
			or payload.Character ~= state.Character
			or state.Humanoid.Health <= 0
			or not state.Root:IsDescendantOf(workspace)
		then
			if payload.Character == player.Character then
				feedback:FireClient(player, {
					Kind = "Action",
					Action = action,
					Sequence = sequence,
					Character = player.Character,
					Accepted = false,
					Combo = 0,
					ReadyAt = 0,
					DashReadyAt = 0,
					Sprinting = false,
				})
			end
			return
		end
		local now = workspace:GetServerTimeNow()
		local accepted = false
		local validPosition = true
		if action == Protocol.Sprint and typeof(payload.Sprinting) == "boolean" then
			Movement.sprint(state, payload.Sprinting)
			accepted = true
		elseif action == Protocol.Light then
			validPosition = Movement.update(player, state, now, feedback)
			accepted = validPosition and Combat.request(state, now, Equipment.meleeLoadout(player), payload.Direction)
		elseif action == Protocol.Heavy then
			validPosition = Movement.update(player, state, now, feedback)
			accepted = validPosition and Combat.heavy(state, now, Equipment.meleeLoadout(player), payload.Direction)
		elseif action == Protocol.BlockStart then
			accepted = Combat.blockStart(player, state, now, Equipment.meleeLoadout(player), feedback)
		elseif action == Protocol.BlockEnd then
			accepted = Combat.blockEnd(state, now)
		elseif action == Protocol.Dash and validPosition then
			local direction = payload.Direction
			if
				typeof(direction) == "Vector3"
				and direction.X == direction.X
				and direction.Z == direction.Z
				and math.abs(direction.Y) < Config.Movement.DirectionEpsilon
				and direction.Magnitude > 0.9
				and direction.Magnitude < 1.1
			then
				Combat.blockEnd(state, now)
				accepted = Movement.dash(state, now)
				validPosition = Movement.update(player, state, now, feedback)
				accepted = accepted and validPosition
			end
		elseif action == Protocol.MagicStart and RunService:IsStudio() and StudioSandbox.Enabled then
			Magic.start(player, state, payload, feedback)
			accepted = true
		elseif action == Protocol.MagicRelease and RunService:IsStudio() and StudioSandbox.Enabled then
			Magic.release(player, state, payload, feedback)
			accepted = true
		elseif action == Protocol.MagicAimUpdate and RunService:IsStudio() and StudioSandbox.Enabled then
			accepted = Magic.updateAim(player, state, payload)
		elseif action == Protocol.MagicConsent and TargetConsent.valid(payload.AllowsTargetedSpells) then
			player:SetAttribute(TargetConsent.Attribute, payload.AllowsTargetedSpells)
			accepted = true
		elseif action == Protocol.EquipmentSwitch then
			Combat.blockEnd(state, now)
			accepted = Equipment.switch(player, payload.EquipmentSlot, feedback)
		elseif action == Protocol.SummonCommand then
			local commandAccepted, reason =
				Summons.command(player, payload.SummonMode, payload.TargetModel, payload.WorldPoint, payload.SummonId)
			accepted = commandAccepted
			feedback:FireClient(player, {
				Kind = "SummonCommand",
				Mode = payload.SummonMode,
				Accepted = commandAccepted,
				Reason = reason,
			})
		elseif action == Protocol.EquipmentUse and now >= state.DashUntil then
			local spellId, castContext = Equipment.magicCast(player, payload.EquipmentAction)
			if spellId then
				Magic.start(player, state, {
					SpellId = spellId,
					AimDirection = payload.AimDirection,
					WorldPoint = payload.WorldPoint,
					TargetModel = payload.TargetModel,
					TargetInstance = payload.TargetInstance,
				}, feedback, castContext)
				accepted = true
			end
		end
		feedback:FireClient(player, {
			Kind = "Action",
			Action = action,
			Sequence = sequence,
			Character = state.Character,
			Accepted = accepted,
			Combo = state.Combo,
			ReadyAt = state.ReadyAt,
			DashReadyAt = state.DashReadyAt,
			Sprinting = state.Sprinting,
			Blocking = state.Blocking,
		})
		if accepted and (action == Protocol.Light or action == Protocol.Heavy) and state.Attack then
			feedback:FireAllClients({
				Kind = "Swing",
				Character = state.Character,
				Combo = state.Combo,
				Heavy = state.Heavy,
				Size = state.Attack.Size,
				Offset = state.Attack.Offset,
				Duration = state.Attack.Startup + state.Attack.Active,
			})
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for player, state in states do
			if state.Humanoid.Health <= 0 or not state.Root:IsDescendantOf(workspace) then
				clearState(player)
			elseif Movement.update(player, state, now, feedback) then
				Combat.update(player, state, now, feedback)
			end
		end
	end)
	require(Services.MagicLabService).start(folder, function(player)
		return states[player]
	end, feedback)
	require(Services.TrainingDummyService).start(folder, function(player)
		return states[player]
	end)
	require(Services.MagicPresentation).start(folder)
	require(Services.SpellVFXRelay).start(folder)
	Summons.start(Magic.castSummonSpell, Magic.getCompanionSpellProfile, feedback, Magic.executeSummonCommand)
end

return Router
