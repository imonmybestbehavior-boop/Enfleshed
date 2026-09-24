--!strict

-- Development-only deterministic data generator. It creates definitions only;
-- MagicService remains the sole executor and clients receive IDs, never data.
local Config = require(script.Parent.Sandbox).DevelopmentSpellStress
local Validator = require(script.Parent.Parent.Modules.SpellDefinitionValidator)

local Generator = {}

local function rng(seed)
	local state = seed
	return function()
		state = (state * 48271) % 2147483647
		return state
	end
end

local function number(nextValue, minimum, maximum)
	return minimum + nextValue() % (maximum - minimum + 1)
end

local function color(nextValue)
	return Color3.fromRGB(number(nextValue, 90, 235), number(nextValue, 90, 235), number(nextValue, 90, 235))
end

function Generator.generate(seed, count)
	local nextValue = rng(seed)
	local definitions = {}
	local order = {}
	local descriptions = {}
	for index = 1, count do
		local id = string.format("GeneratedSpell_%02d", index)
		local charged = index % 3 == 0
		local projectile = index % 2 == 1
		local material = projectile and index % 5 == 0
		local casting
		if charged then
			casting = {
				Mode = "Charged",
				MinimumCharge = 0.1 + number(nextValue, 0, 10) / 100,
				MaximumCharge = 0.7 + number(nextValue, 0, 8) / 10,
				Cooldown = number(nextValue, 3, 12) / 10,
			}
		else
			casting = { Mode = "Instant", Cooldown = number(nextValue, 2, 10) / 10 }
		end
		local definition
		if projectile then
			local payload = { Kind = "Damage", Amount = number(nextValue, 8, 24) }
			local impact = { { Payloads = { payload } } }
			local explode = nextValue() % 2 == 0
			if explode then
				table.insert(impact, {
					Behavior = "Explode",
					Radius = number(nextValue, 4, 8),
					Payloads = { { Kind = "Damage", Amount = number(nextValue, 6, 16) } },
				})
			end
			local source = { Principle = "Energy", Expression = "Unawakened" }
			local targeting = "AimDirection"
			if material then
				source = { Principle = "Matter", Expression = "Earth" }
				targeting = "MaterialTarget"
			end
			definition = {
				SpellId = id,
				Name = id,
				Version = 1,
				Tags = { "DevelopmentGenerated" },
				Source = source,
				Form = "Projectile",
				Targeting = targeting,
				Geometry = "Sphere",
				Motion = "Linear",
				Casting = casting,
				Lifetime = { Mode = "FixedDuration", Duration = number(nextValue, 12, 28) / 10 },
				Cost = {
					ManaDemand = number(nextValue, 5, 22),
					Strain = number(nextValue, 2, 16),
					Complexity = number(nextValue, 1, 4),
				},
				Projectile = { Speed = number(nextValue, 48, 120), Radius = number(nextValue, 3, 12) / 10 },
				Visual = { Color = color(nextValue) },
				Triggers = { OnImpact = impact },
			}
			if material then
				definition.Material = { Material = "Earth", Amount = 1, SearchRadius = 12 }
			end
			local behavior = ""
			if explode then
				behavior = "+ Explode"
			end
			descriptions[id] = string.format(
				"%s / Projectile / Damage%s / %s | dmg %d speed %d radius %.1f life %.1f cd %.1f mana %d strain %d complexity %d",
				definition.Source.Principle,
				behavior,
				casting.Mode,
				payload.Amount,
				definition.Projectile.Speed,
				definition.Projectile.Radius,
				definition.Lifetime.Duration,
				casting.Cooldown,
				definition.Cost.ManaDemand,
				definition.Cost.Strain,
				definition.Cost.Complexity
			)
		else
			local payloads = { { Kind = "Damage", Amount = number(nextValue, 10, 22) } }
			if nextValue() % 2 == 0 then
				table.insert(
					payloads,
					{ Kind = "Force", Magnitude = number(nextValue, 25, 65), Upward = number(nextValue, 0, 14) }
				)
			end
			definition = {
				SpellId = id,
				Name = id,
				Version = 1,
				Tags = { "DevelopmentGenerated" },
				Source = { Principle = "Body", Expression = "BodyEnhancement" },
				Form = "Wave",
				Targeting = "Self",
				Geometry = "Cone",
				Motion = "Stationary",
				Casting = casting,
				Lifetime = { Mode = "Instantaneous" },
				Cost = {
					ManaDemand = number(nextValue, 8, 24),
					Strain = number(nextValue, 3, 16),
					Complexity = number(nextValue, 1, 4),
				},
				Wave = {
					Range = number(nextValue, 6, 12),
					Dot = number(nextValue, -8, 5) / 10,
					DebugDuration = 0.18,
					Payloads = payloads,
				},
				Visual = { Color = color(nextValue) },
				Triggers = { OnCast = true },
			}
			local payloadDescription = "Damage"
			if #payloads == 2 then
				payloadDescription = "Damage+Force"
			end
			descriptions[id] = string.format(
				"Body / Wave / %s / %s | range %d dot %.1f cd %.1f mana %d strain %d complexity %d",
				payloadDescription,
				casting.Mode,
				definition.Wave.Range,
				definition.Wave.Dot,
				casting.Cooldown,
				definition.Cost.ManaDemand,
				definition.Cost.Strain,
				definition.Cost.Complexity
			)
		end
		local valid, reason = Validator.validate(definition)
		assert(valid, "Generated invalid spell " .. id .. ": " .. tostring(reason))
		definitions[id] = definition
		table.insert(order, id)
	end
	return { Definitions = definitions, Order = order, Descriptions = descriptions }
end

local generated = { Definitions = {}, Order = {}, Descriptions = {} }
if Config.Enabled then
	generated = Generator.generate(Config.SpellTestSeed, Config.GeneratedSpellCount)
end
generated.Generate = Generator.generate
return generated
