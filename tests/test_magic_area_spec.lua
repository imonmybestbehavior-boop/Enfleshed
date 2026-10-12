local Area = assert(loadfile("src/shared/Modules/MagicAreaSpec.luau"))()
local common = { Interval = 0.6, Yaw = 0 }

local function test(form, shape, dimensions)
	local area = {}
	for key, value in pairs(common) do
		area[key] = value
	end
	for key, value in pairs(dimensions) do
		area[key] = value
	end
	if form == "Field" then
		area.DebugHeight = 0.2
	end
	local ok, reason = Area.validate(form, shape, area, 20, 0.1)
	assert(ok, string.format("%s %s should validate: %s", form, shape, tostring(reason)))
	return area
end

for _, form in ipairs({ "Field", "Aura" }) do
	test(form, "Sphere", { Radius = 6 })
	local staticSphere = test(form, "Sphere", { Radius = 6 })
	staticSphere.GrowthStartScale, staticSphere.GrowthEndScale, staticSphere.GrowthDuration = 0, 0, 0
	assert(Area.validate(form, "Sphere", staticSphere, 20, 0.1), "All-zero optional expansion settings mean static")
	test(form, "Capsule", { Radius = 2, Height = 8 })
	test(form, "Cylinder", { Radius = 6, Height = 4 })
	test(form, "Box", { Width = 8, Height = 4, Depth = 6 })
	local plane = test(form, "Plane", { Width = 8, Height = 10, Thickness = 1 })
	plane.Thickness = 4.1
	assert(not Area.validate(form, "Plane", plane, 20, 0.1), "Plane depth must remain bounded")
	test(form, "Cone", { Range = 10, Angle = 60, Height = 5 })
	test(form, "Line", { Width = 4, Height = 6, Range = 16 })
	local line = test(form, "Line", { Width = 4, Height = 6, Range = 16 })
	line.Depth = 4
	assert(not Area.validate(form, "Line", line, 20, 0.1), "Line must reject unrelated depth settings")
	local ring = test(form, "Ring", { InnerRadius = 3, OuterRadius = 8, Height = 5 })
	ring.InnerRadius = ring.OuterRadius
	assert(not Area.validate(form, "Ring", ring, 20, 0.1), "Ring must leave a strict safe center")
	ring = test(form, "Ring", { InnerRadius = 3, OuterRadius = 8, Height = 5 })
	ring.OuterRadius = 20.1
	assert(not Area.validate(form, "Ring", ring, 20, 0.1), "Ring bounds must respect the area safety limit")
	ring = test(form, "Ring", { InnerRadius = 3, OuterRadius = 8, Height = 5 })
	ring.GrowthStartScale, ring.GrowthEndScale, ring.GrowthDuration = 0.5, 2, 4
	assert(Area.validate(form, "Ring", ring, 20, 0.1), "Bounded area expansion should validate")
	ring.GrowthDuration = nil
	assert(not Area.validate(form, "Ring", ring, 20, 0.1), "Expansion settings must be provided together")
	ring.GrowthDuration, ring.GrowthEndScale = 4, 2.1
	assert(not Area.validate(form, "Ring", ring, 20, 0.1), "Expansion scales must be bounded")
	ring.GrowthEndScale, ring.OuterRadius = 2, 11
	assert(not Area.validate(form, "Ring", ring, 20, 0.1), "Expanded dimensions must remain inside the area limit")
	ring = test(form, "Ring", { InnerRadius = 3, OuterRadius = 8, Height = 5 })
	ring.Unrelated = true
	assert(not Area.validate(form, "Ring", ring, 20, 0.1), "Ring must reject fields from other geometries")
end
local capsule = { Radius = 3, Height = 5, Interval = 0.6, Yaw = 0, DebugHeight = 0.2 }
assert(not Area.validate("Field", "Capsule", capsule, 20, 0.1), "Capsule height must contain both rounded ends")
capsule.Height = 6
assert(
	Area.validate("Field", "Capsule", capsule, 20, 0.1),
	"Capsule geometry should validate when overall height is at least its diameter"
)

local attached = test("Field", "Sphere", { Radius = 6, FollowTarget = true })
assert(attached.FollowTarget, "Field attachment should remain represented in shared area data")
attached.FollowTarget = "yes"
assert(not Area.validate("Field", "Sphere", attached, 20, 0.1), "FollowTarget must be a boolean")
assert(
	not Area.validate("Aura", "Sphere", { Radius = 6, Interval = 0.6, Yaw = 0, FollowTarget = true }, 20, 0.1),
	"FollowTarget belongs only to Field because Aura already follows its anchor"
)

assert(not Area.validate("Wave", "Ring", {}, 20, 0.1), "Ring must only apply to Field/Aura area forms")
print("Magic area spec: Field/Aura geometry and Ring safety validation passed")
