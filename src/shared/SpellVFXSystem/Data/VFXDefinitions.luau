-- Allowlisted, asset-free authored presets. All use the shared composition grammar.
local presets = {
	FireBurst = { Element = "Fire", Form = "Field", Phase = "Impact", Duration = 1 },
	FireProjectile = { Element = "Fire", Form = "Projectile" },
	FrostCharge = { Element = "Ice", Form = "Aura", Phase = "Gather", Duration = 1.2 },
	FrostProjectile = { Element = "Ice", Form = "Projectile" },
	ArcaneTrail = { Element = "Neutral", Form = "Aura" },
	ArcaneProjectile = { Element = "Neutral", Form = "Projectile" },
}
local definitions = {}
for id, config in pairs(presets) do
	config.Preset = id
	definitions[id] = { Effects = { { Type = "Composition", Config = config } } }
end
return definitions
