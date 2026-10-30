--!strict

-- Spells reacting with the world (Phase 11f), kept free of Roblox services so
-- the audit harness can drive it with doubles. Rules live in
-- MagicEnvironmentSpec; MagicService supplies the world through `deps`.
--
--   Wet conducts Lightning: Lightning damage on a Wet character hops to other
--     Wet characters. Hops are dealt like redirected damage (never chain again,
--     depth + 1, same cascade budget).
--   Fire burns Flammable parts: a small burning Field at the hit point.
--   Ice freezes water: a walkable, breakable ice platform on the surface.
local Shared = game:GetService("ReplicatedStorage").Shared
local EnvironmentSpec = require(Shared.Modules.MagicEnvironmentSpec)
local InterceptionSpec = require(Shared.Modules.MagicInterceptionSpec)
local Limits = require(Shared.Configuration.MagicLab)

local Environment = {}

-- Per-server state: when each part last ignited, and each caster's live
-- fires and platforms (oldest first).
function Environment.newState()
	return {
		Ignited = setmetatable({}, { __mode = "k" }),
		Fires = setmetatable({}, { __mode = "k" }),
		Platforms = setmetatable({}, { __mode = "k" }),
	}
end

export type ChainDeps = {
	IsWet: (any) -> boolean,
	Position: (any) -> any?,
	Nearby: (any, number) -> { any }, -- humanoids near a point
	CanDamage: (any, any) -> boolean, -- attacker, humanoid
	PvP: (any, any) -> any?, -- { MaxJumps, MaxFraction } between players who may fight
	Spend: (any, number) -> boolean, -- cascade budget
	Deal: (any, any, number, any) -> (), -- attacker, humanoid, amount, damage context
}

-- After a spell's damage lands. `hit` = { Attacker, Target, Amount, Context }.
-- Returns how many hops were dealt.
function Environment.chain(hit: any, deps: ChainDeps): number
	local context = hit.Context
	if
		type(context) ~= "table"
		or type(context.Depth) ~= "number"
		or context.Element ~= "Lightning"
		or context.IgnoreEnvironment == true
		or context.Chained == true
		or not InterceptionSpec.eligible(context) -- DoT ticks and redirected hits never chain
		or context.Depth + 1 >= Limits.MaxMagicEventDepth
		or hit.Amount <= 0
	then
		return 0
	end
	local before = context.WetBefore
	local function wet(humanoid: any): boolean
		return (before ~= nil and before[humanoid] == true) or deps.IsWet(humanoid)
	end
	local origin = deps.Position(hit.Target)
	if not origin or not wet(hit.Target) then
		return 0
	end
	local candidates = {}
	for _, humanoid in deps.Nearby(origin, Limits.WetChainRadius * Limits.WetChainJumps) do
		local position = deps.Position(humanoid)
		if humanoid ~= hit.Target and position then
			table.insert(candidates, {
				Id = humanoid,
				Position = position,
				Wet = wet(humanoid),
				Allowed = deps.CanDamage(hit.Attacker, humanoid),
				PvP = deps.PvP(hit.Attacker, humanoid),
			})
		end
	end
	local hops = EnvironmentSpec.chain({ Id = hit.Target, Position = origin }, candidates, {
		Hit = hit.Amount,
		Radius = Limits.WetChainRadius,
		Fraction = Limits.WetChainFraction,
		Jumps = Limits.WetChainJumps,
	})
	if #hops == 0 or (context.OperationBudget and not deps.Spend(context.OperationBudget, 1 + #hops)) then
		return 0
	end
	for _, hop in hops do
		deps.Deal(hit.Attacker, hop.Target.Id, hop.Amount, {
			Redirected = true,
			Chained = true,
			Depth = context.Depth + 1,
			OperationBudget = context.OperationBudget,
			DamageChannel = context.DamageChannel or "Elemental",
			Element = "Lightning",
		})
	end
	return #hops
end

export type ImpactDeps = {
	Now: () -> number,
	IsFlammable: (any) -> boolean,
	IsWater: (any, any) -> boolean, -- part, hit position
	Spend: (any, number) -> boolean,
	SpawnFire: (any) -> any?, -- position -> record
	SpawnPlatform: (any) -> any?, -- position -> record
	Alive: (any) -> boolean,
	End: (any) -> (),
}

local function admit(lists: any, owner: any, record: any, cap: number, deps: ImpactDeps)
	local list = lists[owner] or {}
	lists[owner] = list
	for index = #list, 1, -1 do
		if not deps.Alive(list[index]) then
			table.remove(list, index)
		end
	end
	local oldest = EnvironmentSpec.admit(list, record, cap)
	if oldest then
		deps.End(oldest)
	end
end

-- An impact of `definition` on `part` at `position`.
-- `impact` = { Definition, Caster, Part, Position, Depth, Budget }.
-- Returns "Burn", "Freeze" or nil.
function Environment.impact(state: any, impact: any, deps: ImpactDeps): string?
	local definition = impact.Definition
	if
		definition.IgnoreEnvironment == true
		or impact.Part == nil
		or (impact.Depth or 0) + 1 >= Limits.MaxMagicEventDepth
	then
		return nil
	end
	local element = definition.Element
	if element ~= "Fire" and element ~= "Ice" then
		return nil
	end
	local surface = {
		Flammable = element == "Fire" and deps.IsFlammable(impact.Part),
		Water = element == "Ice" and deps.IsWater(impact.Part, impact.Position),
	}
	local reaction = EnvironmentSpec.reactionFor(element, surface)
	if not reaction then
		return nil
	end
	local now = deps.Now()
	if
		reaction == "Burn" and not EnvironmentSpec.igniteAllowed(state.Ignited[impact.Part], now, Limits.IgniteCooldown)
	then
		return nil
	end
	if impact.Budget and not deps.Spend(impact.Budget, 1) then
		return nil
	end
	if reaction == "Burn" then
		state.Ignited[impact.Part] = now
		local fire = deps.SpawnFire(impact.Position)
		if fire then
			admit(state.Fires, impact.Caster, fire, Limits.MaxEnvironmentFires, deps)
		end
	else
		local platform = deps.SpawnPlatform(impact.Position)
		if platform then
			admit(state.Platforms, impact.Caster, platform, Limits.MaxIcePlatforms, deps)
		end
	end
	return reaction
end

-- SpawnEffect data for the reactions (MagicService passes it to spawnEffect).
function Environment.fireEffect()
	return {
		Form = "Field",
		Geometry = "Sphere",
		Element = "Fire",
		IgnoreEnvironment = true,
		Lifetime = { Mode = "FixedDuration", Duration = Limits.EnvironmentFireDuration },
		Field = { Radius = Limits.EnvironmentFireRadius, Interval = Limits.EnvironmentFireInterval },
		Triggers = {
			OnTick = {
				{
					Payloads = {
						{ Kind = "ElementalMark", Stacks = 1, Duration = 5 },
						{
							Kind = "DamageOverTime",
							Amount = Limits.EnvironmentFireBurn,
							Interval = 1,
							Duration = 2,
						},
					},
				},
			},
		},
	}
end

function Environment.platformEffect()
	return {
		Form = "Construct",
		Geometry = "Box",
		Element = "Ice",
		IgnoreEnvironment = true,
		Lifetime = { Mode = "FixedDuration", Duration = Limits.IcePlatformDuration },
		Construct = {
			Width = Limits.IcePlatformSize,
			Height = Limits.IcePlatformThickness,
			Depth = Limits.IcePlatformSize,
		},
		Triggers = {},
	}
end

return Environment
