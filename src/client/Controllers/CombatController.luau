--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox"))
local Protocol = require(Shared:WaitForChild("Networking"):WaitForChild("Protocol"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local Movement = require(script.Parent.MovementController)
local Debug = require(script.Parent.DebugController)
local Combat = {}

local function swing(character: Model, step: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	local attack = Config.Combat.Attacks[step]
	if not root or not root:IsA("BasePart") or not attack then
		return
	end
	local part = Instance.new("Part")
	part.Name = "SwingPreview"
	part.Size = attack.Size
	part.CFrame = root.CFrame * CFrame.new(0, 0, -attack.Offset)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(240, 195, 135)
	part.Transparency = Config.Debug.SwingTransparency
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = workspace
	Debris:AddItem(part, attack.Startup + attack.Active)
end

function Combat.start(
	send: (string, Types.ActionOptions?) -> number,
	movement: Movement.Controller,
	debug: Debug.Controller
)
	local player = Players.LocalPlayer
	local combo = 0
	local readyAt = 0
	local expires = 0
	local pending = 0
	local bufferedUntil = 0

	local function attack()
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not character or not humanoid or humanoid.Health <= 0 or movement.IsDashing() then
			return
		end
		local now = workspace:GetServerTimeNow()
		if now < readyAt or pending ~= 0 then
			if readyAt - now <= Config.Combat.InputBuffer then
				bufferedUntil = now + Config.Combat.InputBuffer
			end
			return
		end
		combo = if now > expires then 1 else combo % #Config.Combat.Attacks + 1
		local definition = Config.Combat.Attacks[combo]
		readyAt = now + definition.Startup + definition.Active + definition.Recovery
		expires = readyAt + Config.Combat.ComboReset
		bufferedUntil = 0
		swing(character, combo)
		pending = send(Protocol.Light, nil)
	end

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		if bufferedUntil >= now and pending == 0 and now >= readyAt then
			attack()
		end
		debug.Update(if now > expires then 0 else combo, movement.GetCooldown())
	end)

	return {
		Attack = attack,
		CanDash = function(): boolean
			return pending == 0 and workspace:GetServerTimeNow() >= readyAt
		end,
		Reset = function()
			combo = 0
			readyAt = 0
			expires = 0
			pending = 0
			bufferedUntil = 0
			debug.Reset()
		end,
		Feedback = function(message: any)
			if message.Kind == "Swing" then
				if
					typeof(message.Character) == "Instance"
					and message.Character:IsA("Model")
					and message.Character ~= player.Character
				then
					swing(message.Character, message.Combo)
				end
			elseif message.Kind == "Hit" then
				debug.Hit(message.Damage)
			elseif message.Kind == "Correction" then
				bufferedUntil = 0
			elseif message.Kind == "Action" and message.Action == Protocol.Light and message.Sequence == pending then
				pending = 0
				combo = message.Combo
				readyAt = message.ReadyAt
				expires = readyAt + Config.Combat.ComboReset
				if not message.Accepted then
					bufferedUntil = 0
				end
			end
		end,
	}
end

return Combat
