-- Material-source compatibility for Matter Forms. This describes an explicit
-- source requirement and consumption, not material physics or terrain editing.
local Spec = {}

Spec.Profiles = {
	Earth = {
		Label = "Earth",
		Expression = "Earth",
		MaterialTargetForms = {
			Projectile = true,
			Beam = true,
			Wave = true,
			Field = true,
			Aura = true,
		},
		ManipulationForms = { Manipulation = true },
		ManipulationObjectTargetForms = { Manipulation = true, Projectile = true, Beam = true, Wave = true },
	},
	Metal = {
		Label = "Metal",
		Expression = "Earth",
		MaterialTargetForms = {
			Projectile = true,
			Beam = true,
			Wave = true,
			Field = true,
			Aura = true,
		},
		ManipulationForms = { Manipulation = true },
		ManipulationObjectTargetForms = { Manipulation = true, Projectile = true, Beam = true, Wave = true },
	},
	Wood = {
		Label = "Wood",
		Expression = "Earth",
		MaterialTargetForms = {
			Projectile = true,
			Beam = true,
			Wave = true,
			Field = true,
			Aura = true,
		},
		ManipulationForms = { Manipulation = true },
		ManipulationObjectTargetForms = { Manipulation = true, Projectile = true, Beam = true, Wave = true },
	},
	Water = {
		Label = "Water",
		Expression = "Water",
		MaterialTargetForms = {
			Projectile = true,
			Beam = true,
			Wave = true,
			Field = true,
			Aura = true,
		},
		ManipulationForms = {},
		ManipulationObjectTargetForms = {},
	},
}

Spec.MaterialOrder = { "Earth", "Metal", "Water", "Wood" }

function Spec.supports(principle, expression, form, targeting, material)
	local profile = Spec.Profiles[material]
	if principle ~= "Matter" or not profile or expression ~= profile.Expression then
		return false
	end

	if targeting == "MaterialTarget" then
		return profile.MaterialTargetForms[form] == true or profile.ManipulationForms[form] == true
	elseif targeting == "ObjectTarget" then
		return profile.ManipulationObjectTargetForms[form] == true
	end

	return false
end

function Spec.options(principle, expression, form, targeting)
	local options = {}
	for _, material in ipairs(Spec.MaterialOrder) do
		if Spec.supports(principle, expression, form, targeting, material) then
			table.insert(options, material)
		end
	end
	return options
end

function Spec.label(material)
	local profile = Spec.Profiles[material]
	return profile and profile.Label or material
end

return Spec
