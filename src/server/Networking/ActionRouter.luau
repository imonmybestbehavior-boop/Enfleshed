--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox"))
local Protocol = require(Shared:WaitForChild("Networking"):WaitForChild("Protocol"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local Services = script.Parent.Parent.Services
local Movement = require(Services.MovementService)
local Combat = require(Services.CombatService)
local Magic = require(Services.MagicService)
local Equipment = require(Services.EquipmentService)
local Router = {}

function Router.start()
	local folder = Instance.new("Folder")
	folder.Name = Protocol.Folder
	local request = Instance.new("RemoteEvent")
	request.Name = Protocol.Request
	request.Parent = folder
	local feedback = Instance.new("RemoteEvent")
	feedback.Name = Protocol.Feedback
	feedback.Parent = folder

	local states: { [Player]: Types.PlayerState } = {}
	local limits: { [Player]: { Tokens: number, Updated: number, Sequence: number } } = {}
	local connections: { [Player]: { RBXScriptConnection } } = {}

	local function bind(player: Player)
		limits[player] = { Tokens = Config.Networking.Burst, Updated = os.clock(), Sequence = 0 }
		Magic.bind(player)
		Equipment.bind(player)
		local function characterAdded(character: Model)
			if player.Character ~= character then
				return
			end
			states[player] = nil
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
			local now = workspace:GetServerTimeNow()
			humanoid.MaxHealth = Config.Player.MaxHealth
			humanoid.Health = Config.Player.MaxHealth
			humanoid.WalkSpeed = Config.Movement.WalkSpeed
			states[player] = {
				Character = character,
				Humanoid = humanoid,
				Root = root,
				Sprinting = false,
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
			}
			Equipment.characterAdded(player, feedback)
		end
		connections[player] = {
			player.CharacterAdded:Connect(characterAdded),
			player.CharacterRemoving:Connect(function(character)
				local state = states[player]
				if state and state.Character == character then
					states[player] = nil
				end
			end),
		}
		if player.Character then
			task.spawn(characterAdded, player.Character)
		end
	end

	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
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

	request.OnServerEvent:Connect(function(player: Player, payload: any)
		local limit = limits[player]
		if not limit then
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
			and action ~= Protocol.MagicStart
			and action ~= Protocol.MagicRelease
			and action ~= Protocol.EquipmentSwitch
			and action ~= Protocol.EquipmentUse
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
			accepted = validPosition and Equipment.meleeActive(player) and Combat.request(state, now)
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
				accepted = Movement.dash(state, now)
				validPosition = Movement.update(player, state, now, feedback)
				accepted = accepted and validPosition
			end
		elseif action == Protocol.MagicStart then
			Magic.start(player, state, payload, feedback)
			accepted = true
		elseif action == Protocol.MagicRelease then
			Magic.release(player, state, payload, feedback)
			accepted = true
		elseif action == Protocol.EquipmentSwitch then
			accepted = Equipment.switch(player, payload.EquipmentSlot, feedback)
		elseif action == Protocol.EquipmentUse and now >= state.DashUntil then
			local spellId = Equipment.magicSpell(player, payload.EquipmentAction)
			if spellId then
				Magic.start(player, state, {
					SpellId = spellId,
					AimDirection = payload.AimDirection,
					WorldPoint = payload.WorldPoint,
				}, feedback)
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
		})
		if accepted and action == Protocol.Light then
			feedback:FireAllClients({ Kind = "Swing", Character = state.Character, Combo = state.Combo })
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for player, state in states do
			if state.Humanoid.Health <= 0 or not state.Root:IsDescendantOf(workspace) then
				states[player] = nil
			elseif Movement.update(player, state, now, feedback) then
				Combat.update(player, state, now, feedback)
			end
		end
	end)
	-- Publish only after listeners are connected.
	folder.Parent = Shared
end

return Router
