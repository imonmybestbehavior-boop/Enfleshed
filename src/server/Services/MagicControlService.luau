--!strict

-- A bounded maintained horizontal influence. This is intentionally physical
-- control, not a stun, movement lock, or one-shot Force impulse.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Limits = require(ReplicatedStorage.Shared.Configuration.MagicLab)
local Ownership = require(script.Parent.MagicPhysicsOwnership)
local MassSpec = require(ReplicatedStorage.Shared.Modules.MagicControlMassSpec)

local Control = {}
local states: { [BasePart]: any } = setmetatable({}, { __mode = "k" }) :: any
local controlledMassByCaster: any = setmetatable({}, { __mode = "k" })
local activeTargets = 0

local function setControlledMass(effect: any, mass: number)
	local previous = effect.ControlledMass or 0
	if previous ~= mass then
		MassSpec.adjust(controlledMassByCaster, effect.Caster, effect.SpellId, mass - previous)
		effect.ControlledMass = mass
	end
end

local function release(root: BasePart, state: any)
	for _, effect in state.Effects do
		setControlledMass(effect, 0)
	end
	if state.Force then
		state.Force:Destroy()
	end
	if state.Attachment then
		state.Attachment:Destroy()
	end
	Ownership.release(root, state.Token)
	states[root] = nil
	activeTargets = math.max(0, activeTargets - 1)
end

local function dispatchTargetDeath(state: any)
	local humanoid = state.Humanoid
	if not humanoid or humanoid.Health > 0 then
		return
	end
	local callbacks = {}
	local seen = {}
	local now = os.clock()
	for _, effect in state.Effects do
		local casterHumanoid = effect.Caster:FindFirstChildOfClass("Humanoid")
		if
			effect.OnTargetDeath
			and effect.Expires > now
			and effect.Caster:IsDescendantOf(workspace)
			and casterHumanoid
			and casterHumanoid.Health > 0
		then
			local spells = seen[effect.Caster]
			if not spells then
				spells = {}
				seen[effect.Caster] = spells
			end
			if not spells[effect.SpellId] then
				spells[effect.SpellId] = true
				table.insert(callbacks, effect.OnTargetDeath)
			end
		end
	end
	for _, callback in callbacks do
		task.defer(callback, humanoid)
	end
end

local function rootOf(model: Instance?): BasePart?
	local root = model and model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for targetRoot, state in states do
		local target = state.Humanoid
		if
			not targetRoot:IsDescendantOf(workspace)
			or (target and (target.Health <= 0 or not target:IsDescendantOf(workspace)))
			or (
				state.ObjectTarget
				and (state.ObjectTarget.Anchored or not state.ObjectTarget:IsDescendantOf(workspace))
			)
		then
			dispatchTargetDeath(state)
			release(targetRoot, state)
			continue
		end

		local acceleration = Vector3.zero
		state.ControlledMass = targetRoot.AssemblyMass
		local speedCap = Limits.MaxSpeed
		for index = #state.Effects, 1, -1 do
			local effect = state.Effects[index]
			local casterRoot = rootOf(effect.Caster)
			if
				effect.Expires <= now
				or not effect.CasterHumanoid
				or effect.CasterHumanoid.Health <= 0
				or not casterRoot
				or not casterRoot:IsDescendantOf(workspace)
				or not MassSpec.allows(targetRoot.AssemblyMass, effect.MaxMass)
			then
				setControlledMass(effect, 0)
				table.remove(state.Effects, index)
			else
				setControlledMass(effect, targetRoot.AssemblyMass)
				speedCap = math.min(speedCap, effect.MaxSpeed)
				local offset = Vector3.new(
					targetRoot.Position.X - casterRoot.Position.X,
					0,
					targetRoot.Position.Z - casterRoot.Position.Z
				)
				if offset.Magnitude > 0.1 then
					local direction = offset.Unit * (if effect.Mode == "Pull" then -1 else 1)
					acceleration += direction * effect.Acceleration
				end
			end
		end

		if #state.Effects == 0 then
			release(targetRoot, state)
			continue
		end

		local horizontalVelocity =
			Vector3.new(targetRoot.AssemblyLinearVelocity.X, 0, targetRoot.AssemblyLinearVelocity.Z)
		if horizontalVelocity.Magnitude >= speedCap or targetRoot.AssemblyMass <= 0 then
			state.Force.Force = Vector3.zero
		else
			local maxAcceleration = Limits.MaxAcceleration
			if acceleration.Magnitude > maxAcceleration then
				acceleration = acceleration.Unit * maxAcceleration
			end
			state.Force.Force = acceleration * targetRoot.AssemblyMass
		end
	end
end)

local function applyToRoot(
	caster: Model,
	targetRoot: BasePart,
	humanoid: Humanoid?,
	objectTarget: BasePart?,
	spellId: string,
	payload: any,
	potency: number,
	onTargetDeath: ((Humanoid) -> ())?
): (boolean, boolean)
	local casterRoot = rootOf(caster)
	local casterHumanoid = caster:FindFirstChildOfClass("Humanoid")
	if
		not casterRoot
		or not casterHumanoid
		or casterHumanoid.Health <= 0
		or (humanoid and humanoid.Health <= 0)
		or targetRoot == casterRoot
		or targetRoot.Anchored
		or targetRoot.AssemblyMass <= 0
		or not MassSpec.allows(targetRoot.AssemblyMass, payload.MaxMass)
		or (payload.Mode ~= "Pull" and payload.Mode ~= "Push")
	then
		return false
	end

	local state = states[targetRoot]
	if not state then
		if activeTargets >= Limits.MaxEffectTargets then
			return false
		end
		local token = {}
		if not Ownership.claim(targetRoot, token) then
			return false
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "MagicControlAttachment"
		attachment.Parent = targetRoot
		local force = Instance.new("VectorForce")
		force.Name = "MagicControlForce"
		force.ApplyAtCenterOfMass = true
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.Attachment0 = attachment
		force.Force = Vector3.zero
		force.Parent = targetRoot
		state = {
			Humanoid = humanoid,
			ObjectTarget = objectTarget,
			Effects = {},
			Token = token,
			Attachment = attachment,
			Force = force,
		}
		states[targetRoot] = state
		activeTargets += 1
	elseif objectTarget and state.Humanoid then
		return false
	elseif humanoid and state.ObjectTarget then
		return false
	end

	local now = os.clock()
	local existing
	for _, effect in state.Effects do
		if effect.Caster == caster and effect.SpellId == spellId then
			existing = effect
			break
		end
	end
	if not existing and #state.Effects >= Limits.MaxEffectsPerTarget then
		return false
	end
	local effect = existing or { Caster = caster, CasterHumanoid = casterHumanoid, SpellId = spellId }
	effect.Mode = payload.Mode
	effect.Acceleration = math.clamp(payload.Acceleration * potency, 0, Limits.MaxAcceleration)
	effect.MaxSpeed = payload.MaxSpeed
	effect.MaxMass = payload.MaxMass
	effect.Expires = now + payload.Duration
	effect.OnTargetDeath = onTargetDeath
	if not existing then
		table.insert(state.Effects, effect)
	end
	setControlledMass(effect, targetRoot.AssemblyMass)
	return true, existing == nil
end

function Control.apply(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	payload: any,
	potency: number,
	onTargetDeath: ((Humanoid) -> ())?
): (boolean, boolean)
	local targetModel = humanoid.Parent
	local targetRoot = rootOf(targetModel)
	if not targetRoot or humanoid.Health <= 0 then
		return false
	end
	return applyToRoot(caster, targetRoot, humanoid, nil, spellId, payload, potency, onTargetDeath)
end

function Control.applyObject(
	caster: Model,
	target: BasePart,
	spellId: string,
	payload: any,
	potency: number
): (boolean, boolean)
	if
		not target:IsDescendantOf(workspace)
		or target.Anchored
		or target.AssemblyMass <= 0
		or target:FindFirstAncestorOfClass("Model")
			and target:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid")
	then
		return false
	end
	local targetRoot = target.AssemblyRootPart or target
	return applyToRoot(caster, targetRoot, nil, target, spellId, payload, potency, nil)
end

function Control.controlledMass(caster: Model, spellId: string): number
	return MassSpec.total(controlledMassByCaster, caster, spellId)
end

return Control
