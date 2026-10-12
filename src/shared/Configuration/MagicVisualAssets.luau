-- Modular, reusable presentation building blocks for the spell creator.
-- Asset entries describe combinations of existing visual controls; they do not
-- add gameplay behavior or require spell-specific authored geometry.
local Assets = {}

Assets.Groups = {
	{
		Id = "core",
		Label = "Core shapes",
		Slot = "CoreShape",
		Options = { "Sphere", "Block", "Crystal", "Wedge", "Cylinder" },
	},
	{
		Id = "surface",
		Label = "Surface finishes",
		Slot = "MaterialAppearance",
		Options = { "Neon", "ForceField", "Glass", "SmoothPlastic", "Slate" },
	},
	{
		Id = "particles",
		Label = "Particles and textures",
		Slot = "ParticleStyle",
		Options = { "Sparks", "Smoke", "Embers", "None" },
	},
	{ Id = "motion", Label = "Trails", Slot = "TrailStyle", Options = { "Ribbon", "Particles", "None" } },
	{ Id = "impact", Label = "Impacts", Slot = "ImpactStyle", Options = { "Burst", "Ring", "Pulse", "Cross", "None" } },
	{ Id = "cast", Label = "Casting accents", Slot = "CastingStyle", Options = { "HandGlow", "GroundSigil", "None" } },
	{
		Id = "ambient",
		Label = "Ambient layers",
		Slot = "EnvironmentalVisual",
		Options = { "Motes", "GroundMist", "None" },
	},
}

-- Named presets are starting points, not fixed spell identities. Applying a
-- preset only changes listed slots, so users can layer/replace components.
Assets.Presets = {
	{
		Id = "bright-trail",
		Label = "Bright trail",
		Description = "Readable luminous core, particle wake, and crisp burst.",
		Visual = {
			CoreShape = "Sphere",
			MaterialAppearance = "Neon",
			ParticleStyle = "Sparks",
			TrailStyle = "Ribbon",
			ImpactStyle = "Burst",
			CastingStyle = "HandGlow",
		},
	},
	{
		Id = "soft-drift",
		Label = "Soft drift",
		Description = "Diffuse haze with a restrained pulse and floating motes.",
		Visual = {
			CoreShape = "Sphere",
			MaterialAppearance = "Glass",
			ParticleStyle = "Smoke",
			TrailStyle = "Particles",
			ImpactStyle = "Pulse",
			EnvironmentalVisual = "Motes",
		},
	},
	{
		Id = "shard-spray",
		Label = "Shard spray",
		Description = "Angular crystal silhouette, ember texture, and crossing impact lines.",
		Visual = {
			CoreShape = "Crystal",
			MaterialAppearance = "ForceField",
			ParticleStyle = "Embers",
			TrailStyle = "Ribbon",
			ImpactStyle = "Cross",
			CastingStyle = "HandGlow",
		},
	},
	{
		Id = "grounded-ripple",
		Label = "Grounded ripple",
		Description = "Solid material, broad ring impact, and low ground mist.",
		Visual = {
			CoreShape = "Cylinder",
			MaterialAppearance = "Slate",
			ParticleStyle = "Smoke",
			TrailStyle = "None",
			ImpactStyle = "Ring",
			CastingStyle = "GroundSigil",
			EnvironmentalVisual = "GroundMist",
		},
	},
	{
		Id = "clean-beam",
		Label = "Clean beam",
		Description = "Simple high-contrast beam presentation with minimal particles.",
		Visual = {
			CoreShape = "Wedge",
			MaterialAppearance = "Neon",
			ParticleStyle = "None",
			TrailStyle = "None",
			ImpactStyle = "Pulse",
			CastingStyle = "HandGlow",
		},
	},
}

local valid = {}
for _, group in ipairs(Assets.Groups) do
	local options = {}
	for _, option in ipairs(group.Options) do
		options[option] = true
	end
	valid[group.Slot] = options
end

function Assets.apply(visual, presetId)
	if type(visual) ~= "table" then
		return nil, "Visual settings must be a table"
	end
	for _, preset in ipairs(Assets.Presets) do
		if preset.Id == presetId then
			local result = {}
			for key, value in pairs(visual) do
				result[key] = value
			end
			for key, value in pairs(preset.Visual) do
				result[key] = value
			end
			return result
		end
	end
	return nil, "Unknown visual asset preset"
end

function Assets.set(visual, slot, value)
	if type(visual) ~= "table" then
		return nil, "Visual settings must be a table"
	end
	if not valid[slot] or not valid[slot][value] then
		return nil, "Unsupported visual asset component"
	end
	local result = {}
	for key, current in pairs(visual) do
		result[key] = current
	end
	result[slot] = value
	return result
end

return Assets
