local config = assert(loadfile("src/shared/Configuration/Sandbox.luau", "t", {
	math = math,
	Vector3 = {
		new = function(x, y, z)
			return { X = x, Y = y, Z = z }
		end,
	},
}))()
local selector = assert(loadfile("src/server/Services/NascentAttackSelector.luau"))()
local n = config.Enemy.Nascent
assert(config.Enemy.Health > 80 and config.Enemy.Health <= 240)
assert(n.RushingStrike.Travel > 0 and n.PredatoryLunge.Travel > n.RushingStrike.Travel)
assert(n.FrenziedChain.Count >= 3 and n.MaulingCombination.Count == 3)
assert(n.FrenziedChain.TrackingTurnRate > 0)
assert(#n.FrenziedChain.TrackingByStrike == n.FrenziedChain.Count)
assert(n.FrenziedChain.TrackingByStrike[1] > n.FrenziedChain.TrackingByStrike[n.FrenziedChain.Count])
assert(n.FrenziedChain.TrackingEscapeRange > n.FrenziedChain.Range)
assert(config.Enemy.Turning.CloseCombatTurnRate > config.Enemy.Turning.MidRangeTurnRate)
assert(config.Enemy.Turning.VeryCloseTurnRate > config.Enemy.Turning.CloseCombatTurnRate)
assert(n.RushingStrike.TelegraphTurnRate > n.RushingStrike.CommitTurnRate)
assert(n.PredatoryLunge.TelegraphTurnRate > n.PredatoryLunge.CommitTurnRate)
assert(n.MaulingCombination.TrackingByStrike[1] > n.MaulingCombination.TrackingByStrike[3])
assert(n.PredatoryLunge.MissRecovery > n.PredatoryLunge.Recovery)
assert(selector.choose(n, 3, "", 0, false) == "MaulingCombination")
assert(selector.choose(n, 12, "", 0, false) == "PredatoryLunge")
assert(selector.choose(n, 5, "RushingStrike", 1, false) == "FrenziedChain")
assert(selector.choose(n, 7, "FrenziedChain", 2, false) == "RushingStrike")
assert(selector.choose(n, 5, "RushingStrike", 2, true) == "FrenziedChain")
assert(selector.choose(n, 30, "", 0, false) == nil)
assert(config.Enemy.Reactions.Minor.Flinch == 0)
assert(config.Enemy.Reactions.Major.Flinch > config.Enemy.Reactions.Significant.Flinch)
print("PASS: Nascent state-based attack tuning and anti-stunlock reaction contract")
