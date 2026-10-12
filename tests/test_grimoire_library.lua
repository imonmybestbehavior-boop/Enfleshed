local Library = assert(loadfile("src/shared/Modules/GrimoireLibrary.luau"))()
local Profile = assert(loadfile("src/shared/Modules/MagicLibraryProfile.luau"))()
local Slots = assert(loadfile("src/shared/Modules/MagicSlots.luau"))()
local function clone(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[k] = clone(x)
	end
	return out
end
local function equal(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not equal(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end
local function spell(name)
	return {
		Name = name,
		SpellId = "MagicLabSlot1",
		Form = "Projectile",
		Element = "Fire",
		Cost = { ManaDemand = 12 },
		Valid = true,
		Triggers = { OnImpact = { { Payloads = { { Kind = "Damage", Amount = 20 } } } } },
	}
end
local function validate(d)
	return type(d) == "table" and d.Valid == true
end
local legacy = { Version = 1, Slots = { ["1"] = spell("Bolt"), ["9"] = spell("Other") } }
local slots, safe = Profile.decode(legacy, 9, Slots.id, validate, clone)
assert(safe)
local catalog = assert(Library.decode(legacy, slots, clone, validate))
assert(catalog.Assignments["1"] == "1" and catalog.Assignments["9"] == "2")
assert(equal(catalog.Records["1"].Definition, legacy.Slots["1"]), "Migration must preserve spell rules")
local original = clone(catalog.Records["1"].Definition)
local function mutate(action, args)
	local ok, reason = Library.mutate(catalog, action, args, clone, 100)
	assert(ok, reason)
end
mutate("Collection", { Name = "Support" })
assert(not Library.mutate(catalog, "Collection", { Name = "support" }, clone, 100))
mutate("Move", { Id = "1", Collection = "Support" })
mutate("Tags", { Id = "1", Tags = "starter, easy" })
mutate("Favorite", { Id = "1" })
assert(equal(original, catalog.Records["1"].Definition), "Organization cannot change combat")
local revised = spell("Revised bolt")
revised.Triggers.OnImpact[1].Payloads[1].Amount = 27
assert(Library.update(catalog, "1", revised, clone, 103))
assert(catalog.Records["1"].Definition.Name == "Revised bolt")
assert(catalog.Records["1"].Definition.Triggers.OnImpact[1].Payloads[1].Amount == 27)
assert(catalog.Assignments["1"] == "1" and catalog.Assignments["9"] == "2")
assert(not Library.update(catalog, "missing", revised, clone, 103))
assert(#Library.query(catalog, { Status = "Favorites", Search = "damage", Collection = "Support" }) == 1)
assert(#Library.query(catalog, { Status = "Active", Search = "OnImpact", Form = "Projectile", Element = "Fire" }) == 2)
assert(#Library.query(catalog, { Status = "Active", Search = "[literal pattern]" }) == 0)
mutate("Duplicate", { Id = "1" })
assert(catalog.Records["3"].Definition.Name == "Revised bolt (copy)")
catalog.Records["3"].Definition.Triggers.OnImpact[1].Payloads[1].Amount = 33
assert(
	original.Triggers.OnImpact[1].Payloads[1].Amount == 20
		and catalog.Records["1"].Definition.Triggers.OnImpact[1].Payloads[1].Amount == 27
)
assert(not Library.mutate(catalog, "Archive", { Id = "1" }, clone, 100), "Cannot archive an equipped spell")
mutate("Archive", { Id = "3" })
assert(#Library.query(catalog, { Status = "Archived" }) == 1)
mutate("Restore", { Id = "3" })
assert(not Library.mutate(catalog, "Delete", { Id = "3" }, clone, 100))
mutate("Rename", { Id = "3", Name = "Duplicate name allowed" })
mutate("Archive", { Id = "3" })
mutate("Delete", { Id = "3" })
assert(catalog.Records["3"] == nil)
mutate("DismissHelp", {})
local snapshot = { Version = 2, Slots = clone(legacy.Slots), Catalog = clone(catalog) }
local reopened = assert(Library.decode(snapshot, slots, clone, validate))
assert(equal(reopened, catalog), "Roundtrip must preserve collections, labels, favorites and help state")
for _, damage in ipairs({
	function(x)
		x.Catalog.NextId = 0
	end,
	function(x)
		x.Catalog.Collections = { "Missing default" }
	end,
	function(x)
		x.Catalog.Records["1"].Definition.Valid = false
	end,
	function(x)
		x.Catalog.Assignments["10"] = "1"
	end,
	function(x)
		x.Catalog.Records["1"].Archived = true
	end,
	function(x)
		x.Future = true
	end,
	function(x)
		x.Catalog.Records["1"].Unknown = true
	end,
	function(x)
		x.Catalog.Records["1"].UpdatedAt = math.huge
	end,
}) do
	local broken = clone(snapshot)
	damage(broken)
	assert(not Library.decode(broken, slots, clone, validate), "Unsafe save must not be writable")
end
local full = Library.empty()
for i = 1, Library.MaxRecords do
	assert(Library.add(full, spell("S" .. i), clone, i))
end
assert(not Library.add(full, spell("overflow"), clone, 999))
assert(not Library.mutate(catalog, "Tags", { Id = "1", Tags = string.rep("x", 241) }, clone, 100))
assert(not Library.mutate(catalog, "Rename", { Id = "1", Name = "" }, clone, 100))
assert(not Library.decode("malformed", {}, clone, validate))
print(
	"Grimoire: v1 migration, roundtrip, metadata isolation, search/filter, duplicate, archive/restore/delete, bounds and unsafe-data protection passed"
)
