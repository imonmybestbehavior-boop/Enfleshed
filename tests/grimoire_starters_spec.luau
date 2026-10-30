env.script = {
	Parent = {
		SpellSpec = "spec",
		MagicVisualSpec = "visualSpec",
		MagicSpellIdentitySpec = "identitySpec",
		Parent = { Configuration = { MagicSchema = "schema" } },
	},
}
env.require = function(value)
	if value == "spec" then
		return spec
	end
	if value == "schema" then
		return schema
	end
	if value == "visualSpec" then
		return visualSpec
	end
	if value == "identitySpec" then
		return identitySpec
	end
	error(value)
end
-- The builders skip (and warn about) any recipe that fails validation; this
-- suite treats a silent skip as a failure.
local skipped = {}
env.warn = function(message)
	table.insert(skipped, tostring(message))
end
local starters = load("src/shared/Modules/GrimoireStarters.luau")
local cost = load("src/shared/Modules/MagicLabCost.luau")
local library = load("src/shared/Modules/GrimoireLibrary.luau")

-- The three collections MagicLabService.seedCuratedCatalog seeds.
local collections = {
	{ Name = starters.ShowcaseCollection, Tag = starters.ShowcaseTag, Build = starters.buildShowcase },
	{
		Name = starters.ShowcaseExpansionCollection,
		Tag = starters.ShowcaseExpansionTag,
		Build = starters.buildShowcaseExpansion,
	},
	{ Name = starters.ShowcaseCollection, Tag = starters.ShowcaseTag, Build = starters.buildFeatureShowcase },
	{ Name = starters.CombatCollection, Tag = starters.CombatTag, Build = starters.buildCombatStarters },
}

local names = {}
local total = 0
local firstId
local catalog = library.empty()
for _, collection in ipairs(collections) do
	local built = collection.Build()
	assert(#built > 0, collection.Name .. " should build at least one spell")
	for _, template in ipairs(built) do
		local name = template.Definition.Name
		assert(not names[name], "Starter names should be distinct across collections: " .. name)
		names[name] = true
		assert(#template.Description > 12, name .. " needs a description")
		local valid, reason = spec.validate(template.Definition)
		assert(valid, name .. ": " .. tostring(reason))
		cost.refresh(template.Definition, spec.estimate, spec.copy)
		valid, reason = spec.validate(template.Definition)
		assert(valid, "After server cost refresh, " .. name .. ": " .. tostring(reason))
		local id = assert(library.add(catalog, template.Definition, spec.copy, 1))
		firstId = firstId or id
		catalog.Records[id].Collection = collection.Name
		catalog.Records[id].Tags = collection.Tag
	end
	if not table.find(catalog.Collections, collection.Name) then
		table.insert(catalog.Collections, collection.Name)
	end
	total += #built
end
assert(#skipped == 0, "Starter recipes were skipped as invalid:\n" .. table.concat(skipped, "\n"))
assert(total >= 20, "Starter collections should cover many archetypes")
assert(next(catalog.Assignments) == nil, "Seeding must not equip starter spells")

-- Legacy collection names must not collide with the live ones, because
-- seeding removes records that use them.
for _, collection in ipairs(collections) do
	assert(collection.Name ~= starters.LegacyCollection, "Live collections must not reuse the legacy name")
	assert(
		collection.Name ~= starters.LegacyShowcaseExpansionCollection,
		"Live collections must not reuse the legacy expansion name"
	)
end

local tagged, tagReason = library.mutate(catalog, "Tags", { Id = firstId, Tags = "quick" }, spec.copy, 2)
assert(tagged, "Seeded spells can be retagged: " .. tostring(tagReason))
assert(library.labels(catalog.Records[firstId]) == "quick")
assert(
	string.find(catalog.Records[firstId].Tags, starters.ShowcaseTag, 1, true),
	"Editing labels must keep the system tag seeding uses to recognise curated spells"
)
local duplicated, duplicateReason = library.mutate(catalog, "Duplicate", { Id = firstId }, spec.copy, 2)
assert(duplicated, "Seeded spells can be duplicated: " .. tostring(duplicateReason))
assert(catalog.Records[tostring(catalog.NextId - 1)].Collection == "Unfiled")
assert(
	catalog.Records[tostring(catalog.NextId - 1)].Tags == "quick",
	"A duplicate is player-owned: user labels only, no system tags"
)
print("Validated", total, "starter spells across", #collections, "collections")
