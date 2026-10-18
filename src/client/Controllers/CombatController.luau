--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox"))
local MeleeConfig = require(Shared:WaitForChild("Configuration"):WaitForChild("MeleeProfiles"))
local Protocol = require(Shared:WaitForChild("Networking"):WaitForChild("Protocol"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local Movement = require(script.Parent.MovementController)
local Debug = require(script.Parent.DebugController)
local Combat = {}
local Feel = MeleeConfig.Feel

local function swing(character: Model, size: Vector3, offset: number, duration: number, heavy: boolean)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local part = Instance.new("Part")
	part.Name = "SwingPreview"
	part.Size = size
	part.CFrame = root.CFrame * CFrame.new(0, 0, -offset)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = if heavy then Color3.fromRGB(255, 140, 90) else Color3.fromRGB(240, 195, 135)
	part.Transparency = Config.Debug.SwingTransparency
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = workspace
	Debris:AddItem(part, duration)
end

local function guardFlash(character: Model, parry: boolean)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local part = Instance.new("Part")
	part.Name = "GuardFlash"
	part.Shape = Enum.PartType.Ball
	part.Size = if parry then Vector3.new(6, 6, 6) else Vector3.new(4, 4, 4)
	part.CFrame = root.CFrame * CFrame.new(0, 0.5, -1.5)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.ForceField
	part.Color = if parry then Color3.fromRGB(255, 210, 90) else Color3.fromRGB(200, 220, 255)
	part.Parent = workspace
	Debris:AddItem(part, if parry then 0.35 else 0.18)
end

local function playSound(model: Model, soundId: string?)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not soundId or soundId == "" or not root or not root:IsA("BasePart") then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.6
	sound.PlaybackSpeed = 0.95 + math.random() * 0.1 -- Slight variation so repeated hits don't sound identical.
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 3)
end

-- Brief white flash on whatever was hit.
local function flashTarget(target: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = target
	Debris:AddItem(highlight, Feel.HitFlash)
end

local frozenUntil = 0
-- Hitstop: freezes the attacker's playing animations for a moment so a hit feels solid.
local function hitstop(character: Model, duration: number)
	local now = os.clock()
	if now < frozenUntil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if not animator then
		return
	end
	frozenUntil = now + duration
	for _, track in animator:GetPlayingAnimationTracks() do
		local speed = track.Speed
		track:AdjustSpeed(0)
		task.delay(duration, function()
			if track.IsPlaying then
				track:AdjustSpeed(speed)
			end
		end)
	end
end

local loadedTracks: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any
-- Plays the weapon's swing animation if one is configured in MeleeProfiles.Feel.Animations.
local function playSwingAnimation(character: Model, weapon: any, heavy: boolean, combo: number)
	local set = Feel.Animations[weapon.Archetype or ""]
	local animationId = if not set then nil elseif heavy then set.Heavy else set.Lights and set.Lights[combo]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if type(animationId) ~= "string" or not animator then
		return
	end
	local tracks = loadedTracks[animator]
	if not tracks then
		tracks = {}
		loadedTracks[animator] = tracks
	end
	local track = tracks[animationId]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId
		track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		tracks[animationId] = track
	end
	track:Play(0.05)
end

-- The flat direction the character faces right now, sent so the server swings where the player saw.
local function facing(character: Model): Vector3?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0.001 then flat.Unit else nil
end

function Combat.start(
	send: (string, Types.ActionOptions?) -> number,
	movement: Movement.Controller,
	debug: Debug.Controller,
	hud: any?,
	loadout: (() -> any?)?
)
	local player = Players.LocalPlayer
	local combo = 0
	local readyAt = 0
	local activeUntil = 0 -- End of the current swing's hit; recovery after it can be cancelled by blocking.
	local expires = 0
	local pending = 0
	local pendingSince = 0
	local bufferedUntil = 0
	local blocking = false
	local wantBlock = false -- Block is held, even if the guard couldn't go up yet.
	local blockRetryAt = 0
	local blockSequence = 0

	local function currentLoadout(): any?
		return if loadout then loadout() else nil
	end

	local function canAct(): (Model?, any?)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not character or not humanoid or humanoid.Health <= 0 or movement.IsDashing() or blocking then
			return nil, nil
		end
		local weapon = currentLoadout()
		return if weapon then character else nil, weapon
	end

	local function commit(character: Model, weapon: any, definition: any, heavy: boolean, now: number)
		activeUntil = now + definition.Startup + definition.Active
		readyAt = activeUntil + definition.Recovery
		bufferedUntil = 0
		swing(character, definition.Size, definition.Offset, definition.Startup + definition.Active, heavy)
		playSound(character, if heavy then Feel.HeavySwingSound else Feel.SwingSound)
		playSwingAnimation(character, weapon, heavy, combo)
		pending = send(if heavy then Protocol.Heavy else Protocol.Light, { Direction = facing(character) })
		pendingSince = now
	end

	local function attack()
		local character, weapon = canAct()
		if not character or not weapon then
			return
		end
		local now = workspace:GetServerTimeNow()
		if now < readyAt or pending ~= 0 then
			if readyAt - now <= Config.Combat.InputBuffer then
				bufferedUntil = now + Config.Combat.InputBuffer
			end
			return
		end
		combo = if now > expires or combo < 1 then 1 else combo % #weapon.Lights + 1
		local definition = weapon.Lights[combo]
		commit(character, weapon, definition, false, now)
		expires = readyAt + Config.Combat.ComboReset
	end

	local function heavy()
		local character, weapon = canAct()
		if not character or not weapon then
			return
		end
		local now = workspace:GetServerTimeNow()
		if now < readyAt or pending ~= 0 then
			return
		end
		combo = 0
		expires = 0
		commit(character, weapon, weapon.Heavy, true, now)
	end

	local function raiseGuard()
		local now = workspace:GetServerTimeNow()
		if
			blocking
			or not player.Character
			or not currentLoadout()
			or movement.IsDashing()
			or now < activeUntil
			or now < blockRetryAt
		then
			return
		end
		blocking = true
		bufferedUntil = 0
		-- Raising a guard cancels the rest of the swing's recovery and ends the light chain.
		readyAt = math.min(readyAt, now)
		combo = 0
		expires = 0
		blockSequence = send(Protocol.BlockStart, nil)
		if blockSequence == 0 then
			-- Not sent (the character isn't ready yet); try again while block is held.
			blocking = false
			blockRetryAt = now + 0.05
		end
	end

	local function block(active: boolean)
		wantBlock = active
		if active then
			raiseGuard()
		elseif blocking then
			blocking = false
			-- Mirrors the server's short recovery so the next click is buffered, not rejected.
			readyAt = math.max(readyAt, workspace:GetServerTimeNow() + Config.Combat.BlockReleaseRecovery)
			send(Protocol.BlockEnd, nil)
		end
	end

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		if pending ~= 0 and now - pendingSince > Config.Combat.PendingTimeout then
			pending = 0 -- The server never answered; stop waiting so melee and dash don't lock up.
		end
		if wantBlock and not blocking then
			raiseGuard()
		end
		if bufferedUntil >= now and pending == 0 and now >= readyAt then
			attack()
		end
		debug.Update(if now > expires then 0 else combo, movement.GetCooldown())
		if hud then
			hud.UpdateCombat(if now > expires then 0 else combo, movement.GetCooldown())
		end
	end)

	return {
		Attack = attack,
		Heavy = heavy,
		Block = block,
		IsBlocking = function(): boolean
			return blocking
		end,
		CanDash = function(): boolean
			return pending == 0 and workspace:GetServerTimeNow() >= readyAt
		end,
		Reset = function()
			combo = 0
			readyAt = 0
			activeUntil = 0
			expires = 0
			pending = 0
			bufferedUntil = 0
			blocking = false
			wantBlock = false
			blockRetryAt = 0
			blockSequence = 0
			debug.Reset()
			if hud then
				hud.Reset()
			end
		end,
		Feedback = function(message: any)
			if message.Kind == "Swing" then
				if
					typeof(message.Character) == "Instance"
					and message.Character:IsA("Model")
					and message.Character ~= player.Character
					and typeof(message.Size) == "Vector3"
					and type(message.Offset) == "number"
					and type(message.Duration) == "number"
				then
					swing(message.Character, message.Size, message.Offset, message.Duration, message.Heavy == true)
					playSound(
						message.Character,
						if message.Heavy == true then Feel.HeavySwingSound else Feel.SwingSound
					)
				end
			elseif message.Kind == "Guard" then
				if typeof(message.Character) == "Instance" and message.Character:IsA("Model") then
					guardFlash(message.Character, message.Result == "Parry")
				end
			elseif message.Kind == "Hit" then
				local target = if typeof(message.Target) == "Instance" and message.Target:IsA("Model")
					then message.Target
					else nil
				debug.Hit(message.Damage, target)
				if target then
					flashTarget(target)
					playSound(target, Feel.HitSound)
				end
				local character = player.Character
				if character then
					hitstop(character, if message.Heavy == true then Feel.HeavyHitstop else Feel.Hitstop)
				end
			elseif message.Kind == "Correction" then
				bufferedUntil = 0
			elseif message.Kind == "Action" then
				if
					(message.Action == Protocol.Light or message.Action == Protocol.Heavy)
					and message.Sequence == pending
				then
					pending = 0
					combo = message.Combo
					-- A guard raised while this reply was in flight already cancelled the recovery.
					readyAt = if blocking then math.min(readyAt, message.ReadyAt) else message.ReadyAt
					expires = if combo > 0 then readyAt + Config.Combat.ComboReset else 0
					if not message.Accepted then
						activeUntil = 0
						bufferedUntil = 0
					end
				elseif
					message.Action == Protocol.BlockStart
					and message.Sequence == blockSequence
					and not message.Accepted
					and blocking
				then
					-- The server still had the swing active; try again shortly while block is held.
					blocking = false
					blockRetryAt = workspace:GetServerTimeNow() + 0.05
				end
			end
		end,
	}
end

return Combat
