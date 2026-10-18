-- Visual authoring is separate from hit geometry and spell execution.
local Spec = {}

Spec.Materials = { "Auto", "Neon", "ForceField", "Glass", "SmoothPlastic", "Slate" }
Spec.CoreShapes = { "Sphere", "Block", "Crystal", "Wedge", "Cylinder" }
Spec.ParticleStyles = { "Sparks", "Smoke", "Embers", "None" }
Spec.TrailStyles = { "Ribbon", "Particles", "None" }
Spec.ImpactStyles = { "Burst", "Ring", "Pulse", "Cross", "None" }
Spec.CastingStyles = { "HandGlow", "GroundSigil", "None" }
Spec.SurfaceBehaviors = { "None", "Pulse" }
Spec.EnvironmentalVisuals = { "None", "Motes", "GroundMist" }
Spec.VFXDefinitions =
	{ "None", "FireBurst", "FireProjectile", "FrostCharge", "FrostProjectile", "ArcaneTrail", "ArcaneProjectile" }
Spec.Palettes = { "Origin", "Ember", "Tide", "Verdant", "Soulfire", "Rift", "Chronal", "LegacyCustom" }
-- Palette presentation is cosmetic metadata. Keep it separate from the dormant
-- discovery rules so the authoring UI does not depend on progression state.
Spec.PaletteDefinitions = {
	Origin = {
		Label = "Origin",
		Colors = { Color3.fromRGB(180, 230, 255), Color3.fromRGB(100, 190, 255), Color3.new(1, 1, 1) },
	},
	Ember = {
		Label = "Ember",
		Colors = { Color3.fromRGB(255, 104, 45), Color3.fromRGB(205, 45, 23), Color3.fromRGB(255, 217, 105) },
	},
	Tide = {
		Label = "Tide",
		Colors = { Color3.fromRGB(61, 183, 207), Color3.fromRGB(48, 103, 180), Color3.fromRGB(178, 239, 237) },
	},
	Verdant = {
		Label = "Verdant",
		Colors = { Color3.fromRGB(119, 194, 105), Color3.fromRGB(49, 119, 75), Color3.fromRGB(218, 225, 129) },
	},
	Soulfire = {
		Label = "Soulfire",
		Colors = { Color3.fromRGB(219, 114, 244), Color3.fromRGB(120, 70, 193), Color3.fromRGB(255, 190, 228) },
	},
	Rift = {
		Label = "Rift",
		Colors = { Color3.fromRGB(237, 187, 100), Color3.fromRGB(173, 99, 58), Color3.fromRGB(255, 232, 174) },
	},
	Chronal = {
		Label = "Chronal",
		Colors = { Color3.fromRGB(124, 225, 197), Color3.fromRGB(62, 140, 143), Color3.fromRGB(209, 255, 227) },
	},
}

local expressionMaterials = {
	Matter = { Earth = "Slate", Water = "Glass" },
	Energy = { Fire = "Neon", Lightning = "ForceField", Force = "SmoothPlastic" },
	Body = { BodyEnhancement = "ForceField" },
	Soul = { Spirit = "Glass" },
	Space = { SpatialFold = "ForceField" },
	Time = { TemporalShift = "Glass" },
}

function Spec.autoMaterial(principle, expression, form)
	if form == "Construct" then
		return "Slate"
	end
	local byExpression = expressionMaterials[principle]
	return (byExpression and byExpression[expression]) or "Neon"
end

Spec.Defaults = {
	Color = Color3.fromRGB(180, 230, 255),
	SecondaryColor = Color3.fromRGB(100, 190, 255),
	AccentColor = Color3.new(1, 1, 1),
	Palette = "Origin",
	Profile = "Auto",
	ProjectileScale = 1,
	CoreShape = "Sphere",
	MaterialAppearance = "Auto",
	Opacity = 0.85,
	Emission = 0.8,
	ParticleStyle = "Sparks",
	TrailStyle = "Ribbon",
	ImpactStyle = "Burst",
	CastingStyle = "HandGlow",
	SurfaceBehavior = "None",
	EnvironmentalVisual = "None",
	Distortion = 0,
	VFXDefinition = "None",
}

local allowed = {}
for key in pairs(Spec.Defaults) do
	allowed[key] = true
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function contains(values, value)
	for _, item in ipairs(values) do
		if item == value then
			return true
		end
	end
	return false
end

function Spec.validate(visual)
	if type(visual) ~= "table" then
		return false, "Visual settings must be a table"
	end
	for key in pairs(visual) do
		if not allowed[key] then
			return false, "Unsupported visual setting"
		end
	end
	if typeof(visual.Color) ~= "Color3" then
		return false, "Primary visual color must be a Color3"
	end
	for _, key in ipairs({ "SecondaryColor", "AccentColor" }) do
		if visual[key] ~= nil and typeof(visual[key]) ~= "Color3" then
			return false, "Secondary and accent colors must be Color3 values"
		end
	end
	if
		visual.ProjectileScale ~= nil
		and (not finite(visual.ProjectileScale) or visual.ProjectileScale < 1 or visual.ProjectileScale > 4)
	then
		return false, "Projectile appearance scale must be between 1 and 4"
	end
	if visual.Opacity ~= nil and (not finite(visual.Opacity) or visual.Opacity < 0.2 or visual.Opacity > 1) then
		return false, "Visual opacity must be between 0.2 and 1 so core effects remain readable"
	end
	if visual.Emission ~= nil and (not finite(visual.Emission) or visual.Emission < 0 or visual.Emission > 1) then
		return false, "Visual emission must be between 0 and 1"
	end
	if
		visual.Distortion ~= nil and (not finite(visual.Distortion) or visual.Distortion < 0 or visual.Distortion > 1)
	then
		return false, "Camera distortion must be between 0 and 1"
	end
	local options = {
		CoreShape = Spec.CoreShapes,
		MaterialAppearance = Spec.Materials,
		ParticleStyle = Spec.ParticleStyles,
		TrailStyle = Spec.TrailStyles,
		ImpactStyle = Spec.ImpactStyles,
		CastingStyle = Spec.CastingStyles,
		SurfaceBehavior = Spec.SurfaceBehaviors,
		EnvironmentalVisual = Spec.EnvironmentalVisuals,
		VFXDefinition = Spec.VFXDefinitions,
		Palette = Spec.Palettes,
	}
	for key, values in pairs(options) do
		if visual[key] ~= nil and not contains(values, visual[key]) then
			return false, "Unsupported visual option: " .. key
		end
	end
	return true
end

return Spec
