local spec = assert(loadfile("src/shared/Modules/MagicObjectTargetSpec.luau", "t", _G))()

local movable = {
	InWorkspace = true,
	CanCollide = true,
	HasHumanoidAncestor = false,
	Tagged = true,
	Anchored = false,
	AssemblyMass = 12,
}

assert(spec.isValidInteractionTarget(movable, true, false), "Tagged movable objects should accept Force/Control")
assert(
	not spec.isValidInteractionTarget(movable, false, true),
	"Material Manipulation must require matching material and authorization"
)
assert(not spec.isValidInteractionTarget(movable, false, false), "Objects need a compatible interaction payload")
local authorizedMaterial = {}
for key, value in pairs(movable) do
	authorizedMaterial[key] = value
end
authorizedMaterial.MaterialMatches = true
authorizedMaterial.RaiseAuthorized = true
assert(
	spec.isValidInteractionTarget(authorizedMaterial, false, true),
	"Matching authorized material may accept Manipulation"
)

local function rejected(patch, hasPhysics, hasManipulation)
	local target = {}
	for key, value in pairs(movable) do
		target[key] = value
	end
	for key, value in pairs(patch) do
		target[key] = value
	end
	return not spec.isValidInteractionTarget(target, hasPhysics, hasManipulation)
end

assert(rejected({ InWorkspace = false }, true, false), "Objects outside Workspace must be rejected")
assert(rejected({ CanCollide = false }, true, false), "Non-collidable objects must be rejected")
assert(rejected({ HasHumanoidAncestor = true }, true, false), "Character parts must be rejected")
assert(rejected({ Tagged = false }, false, true), "Unmarked objects must be rejected")
assert(rejected({ Anchored = true }, true, false), "Force/Control require movable objects")
assert(rejected({ AssemblyMass = 0 }, true, false), "Zero-mass assemblies must be rejected")
assert(rejected({ AssemblyMass = math.huge }, true, false), "Infinite-mass assemblies must be rejected")
assert(rejected({ AssemblyMass = 0 / 0 }, true, false), "Non-finite-mass assemblies must be rejected")
assert(
	spec.isValidInteractionTarget({
		InWorkspace = true,
		CanCollide = true,
		HasHumanoidAncestor = false,
		Tagged = true,
		Anchored = true,
		MaterialMatches = true,
		RaiseAuthorized = true,
	}, false, true),
	"Authorized material operations may target anchored parts"
)
assert(
	spec.isSolidWorldSurfaceTarget({ InWorkspace = true, CanCollide = true, HasHumanoidAncestor = false }),
	"Solid world geometry may anchor Fields, Auras, and Constructs"
)
assert(
	not spec.isSolidWorldSurfaceTarget({ InWorkspace = true, CanCollide = false, HasHumanoidAncestor = false }),
	"Non-collidable surfaces cannot anchor area or Construct geometry"
)
assert(
	not spec.isSolidWorldSurfaceTarget({ InWorkspace = true, CanCollide = true, HasHumanoidAncestor = true }),
	"Character geometry cannot masquerade as a world surface"
)
local manipulationTarget = {
	InWorkspace = true,
	CanCollide = true,
	HasHumanoidAncestor = false,
	Tagged = true,
	Anchored = true,
	AssemblyMass = 8,
	MaterialMatches = true,
	RaiseAuthorized = true,
}
assert(
	spec.isValidManipulationTarget(manipulationTarget, true, false),
	"Authorized Raise may use an anchored material target"
)
assert(not spec.isValidManipulationTarget({
	InWorkspace = true,
	CanCollide = true,
	HasHumanoidAncestor = false,
	Tagged = true,
	Anchored = true,
	AssemblyMass = 8,
	MaterialMatches = false,
	RaiseAuthorized = true,
}, true, false), "Raise must match the authored material")
assert(not spec.isValidManipulationTarget({
	InWorkspace = true,
	CanCollide = true,
	HasHumanoidAncestor = false,
	Tagged = true,
	Anchored = true,
	AssemblyMass = 8,
	MaterialMatches = true,
	RaiseAuthorized = false,
}, true, false), "Raise must have explicit server authorization")
assert(
	not spec.isValidManipulationTarget(manipulationTarget, false, true),
	"Force/Control cannot move anchored objects"
)
manipulationTarget.Anchored = false
assert(
	spec.isValidManipulationTarget(manipulationTarget, false, true),
	"Force/Control may affect eligible movable objects without material authorization"
)

print("Magic ObjectTarget eligibility checks passed")
