--!strict

-- Guard registry consulted by DamageService. CombatService raises and lowers
-- guards; this module only resolves frontal block and parry outcomes and has no
-- service dependencies so DamageService can require it without cycles.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MeleeConfig = require(Shared.Configuration.MeleeProfiles)

export type Guard = {
	StartedAt: number,
	Reduction: number,
	ParryWindow: number,
	FacingDot: number,
	OnParry: (attacker: Model) -> (),
	OnBlock: (attacker: Model, prevented: number) -> (),
}

local Defense = {}
local guards: { [Model]: Guard } = {}

function Defense.raise(character: Model, guard: Guard)
	guards[character] = guard
	character:SetAttribute("MeleeBlocking", true)
end

function Defense.lower(character: Model)
	guards[character] = nil
	character:SetAttribute("MeleeBlocking", nil)
end

function Defense.isGuarding(character: Model): boolean
	return guards[character] ~= nil
end

-- Returns the damage left after the guard, if the target is guarding and faces the attacker.
-- Any frontal hit can be blocked; only melee hits (canParry) can be parried.
function Defense.resolve(attacker: Model, target: Model, amount: number, canParry: boolean): number
	local guard = guards[target]
	if not guard or amount <= 0 then
		return amount
	end
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") or attacker.PrimaryPart
	if not targetRoot or not targetRoot:IsA("BasePart") or not attackerRoot or not attackerRoot:IsA("BasePart") then
		return amount
	end
	local delta = attackerRoot.Position - targetRoot.Position
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude > 0.001 and targetRoot.CFrame.LookVector:Dot(flat.Unit) < guard.FacingDot then
		return amount
	end
	local now = workspace:GetServerTimeNow()
	if canParry and now - guard.StartedAt <= guard.ParryWindow and delta.Magnitude <= MeleeConfig.ParryRange then
		task.spawn(guard.OnParry, attacker)
		return 0
	end
	local remaining = amount * (1 - guard.Reduction)
	task.spawn(guard.OnBlock, attacker, amount - remaining)
	return remaining
end

return Defense
