--!strict

local Damage = {}

function Damage.apply(attacker: Model, target: Humanoid, amount: number): number
	if target.Parent == attacker or target.Health <= 0 or not target:IsDescendantOf(workspace) then
		return 0
	end
	local before = target.Health
	target:TakeDamage(amount)
	return math.max(0, before - target.Health)
end

return Damage
