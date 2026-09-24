-- Run from the repository root with: lua tests/test_sandbox_tuning.lua
-- Execute the actual configuration using a data-only Vector3 substitute.
-- This checks tuning contracts, not Roblox physics or Luau gameplay execution.
local config = assert(loadfile("src/shared/Configuration/Sandbox.luau", "t", {
	Vector3 = {
		new = function(x, y, z)
			return { X = x, Y = y, Z = z }
		end,
	},
}))()

local totalTime, totalDamage = 0, 0
local duration = {}
for index, attack in ipairs(config.Combat.Attacks) do
	assert(attack.Startup > 0 and attack.Active > 0 and attack.Recovery > 0, "Attack phases must be positive")
	duration[index] = attack.Startup + attack.Active + attack.Recovery
	totalTime = totalTime + duration[index]
	totalDamage = totalDamage + attack.Damage
	print(
		string.format(
			"Hit %d: %.2f + %.2f + %.2f = %.2fs; damage %d",
			index,
			attack.Startup,
			attack.Active,
			attack.Recovery,
			duration[index],
			attack.Damage
		)
	)
end
assert(#duration == 3 and totalTime < 1, "Stress-test combo should finish within one second")
assert(duration[3] > duration[1] and duration[3] > duration[2], "Finisher should remain more committal")
assert(totalDamage >= config.Enemy.Health, "A full combo should defeat a basic enemy")
assert(
	totalDamage - config.Combat.Attacks[3].Damage < config.Enemy.Health,
	"The enemy should survive the first two hits"
)
assert(
	config.Enemy.LightHitFlinch > 0 and config.Enemy.LightHitFlinch < math.min(duration[1], duration[2]),
	"Flinch should be brief"
)
assert(config.Player.MaxHealth > 20 * config.Enemy.Damage, "Allow mistakes against a full wave")
assert(config.Movement.DashCooldown < 1.1, "Stress-test dash cooldown should be shorter")
assert(config.StressTest.EnemyCollisions, "Keep existing enemy body-blocking enabled")
assert(config.Enemy.Navigation.AgentHeight >= config.Enemy.CollisionHull.Height, "Path agent must fit the hull height")
assert(
	config.Enemy.Navigation.AgentRadius * 2 >= config.Enemy.CollisionHull.Diameter,
	"Path agent must fit the hull width"
)
local hullBottom = config.StressTest.SpawnCenter.Y
	+ config.Enemy.CollisionHull.CenterOffsetY
	- config.Enemy.CollisionHull.Height / 2
assert(hullBottom >= 0 and hullBottom <= 0.1, "Spawn hull should rest above the baseplate, not inside it")
print(
	string.format(
		"PASS: combo %.2fs / %d damage; flinch %.2fs; player %d HP",
		totalTime,
		totalDamage,
		config.Enemy.LightHitFlinch,
		config.Player.MaxHealth
	)
)
