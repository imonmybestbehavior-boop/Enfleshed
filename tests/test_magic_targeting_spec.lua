local spec = assert(loadfile("src/shared/Modules/MagicTargetingSpec.luau"))()

local function definition(form, targetingRange, formRange)
	local result = { Form = form, TargetRules = { Range = targetingRange } }
	if form == "Projectile" then
		result.Projectile = { MaxDistance = formRange }
	elseif form == "Beam" then
		result.Beam = { Range = formRange }
	elseif form == "Wave" then
		result.Wave = { Range = formRange }
	elseif form == "Construct" then
		result.Construct = { Distance = formRange }
	end
	return result
end

assert(spec.entityRange(definition("Projectile", 200, 80)) == 80)
assert(spec.entityRange(definition("Beam", 60, 100)) == 60)
assert(spec.entityRange(definition("Wave", 100, 12)) == 12)
assert(spec.entityRange(definition("Construct", 100, 20)) == 20)
assert(spec.entityRange(definition("Aura", 50)) == 50)

print("Magic targeting spec: entity range respects both target rules and Form reach")
