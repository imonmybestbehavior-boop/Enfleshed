env.script = { Parent = { SpellSpec = "spec", MagicVisualSpec = "visualSpec", Parent = { Configuration = { MagicSchema = "schema" } } } }
env.require = function(value)
	if value == "spec" then return spec end
	if value == "schema" then return schema end
	if value == "visualSpec" then return visualSpec end
	error(value)
end
local starters = load("src/shared/Modules/GrimoireStarters.luau")
local cost = load("src/shared/Modules/MagicLabCost.luau")
local library = load("src/shared/Modules/GrimoireLibrary.luau")
local built = starters.build()
assert(#built >= 20, "Starter collection should cover many archetypes")
local names = {}
for _, template in ipairs(built) do
	assert(not names[template.Definition.Name], "Starter names should be distinct")
	names[template.Definition.Name] = true
	assert(#template.Description > 12)
	local valid, reason = spec.validate(template.Definition)
	assert(valid, template.Definition.Name .. ": " .. tostring(reason))
	cost.refresh(template.Definition, spec.estimate, spec.copy)
	valid, reason = spec.validate(template.Definition)
	assert(valid, "After server cost refresh, " .. template.Definition.Name .. ": " .. tostring(reason))
end
local catalog = library.empty()
table.insert(catalog.Collections, starters.Collection)
for _, template in ipairs(built) do
	local id = assert(library.add(catalog, template.Definition, spec.copy, 1))
	catalog.Records[id].Collection = starters.Collection
	catalog.Records[id].Tags = starters.Tag
end
assert(#library.query(catalog, { Status = "Starter templates" }) == #built)
assert(next(catalog.Assignments) == nil, "Seeding must not equip starter spells")
assert(library.labels(catalog.Records["1"]) == "")
assert(library.mutate(catalog, "Tags", { Id = "1", Tags = "quick" }, spec.copy, 2))
assert(library.labels(catalog.Records["1"]) == "quick")
assert(#library.query(catalog, { Status = "Starter templates" }) == #built)
assert(library.mutate(catalog, "Duplicate", { Id = "1" }, spec.copy, 2))
assert(catalog.Records[tostring(catalog.NextId - 1)].Collection == "Unfiled")
assert(catalog.Records[tostring(catalog.NextId - 1)].Tags == "quick")
print("Validated", #built, "starter spells")
