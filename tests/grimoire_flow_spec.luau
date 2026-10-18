-- Runs after the real schema/SpellSpec fixtures in run_luau_magic_tests.py.
local library = load("src/shared/Modules/GrimoireLibrary.luau")
local summary = load("src/shared/Modules/GrimoireSummary.luau")
local catalog = library.empty()
local labCost = load("src/shared/Modules/MagicLabCost.luau")
local authoringGuide = load("src/shared/Modules/MagicAuthoringGuide.luau")
-- Guided choices no longer carry a Principle; the Lab resolves it the same
-- way: the payload's required Principle (Matter for Manipulation), else Energy, else the first Principle
-- that supports the Form (MagicLabController internalDefaultForForm).
local function choicePrinciple(choice)
	local required = schema.Payloads[choice.Payload] and schema.Payloads[choice.Payload].Principle
	if required then
		return required
	end
	if choice.Payload == "Manipulation" then
		return "Matter"
	end
	if schema.supportsPrincipleForm("Energy", choice.Form) then
		return "Energy"
	end
	for _, principle in ipairs(schema.Principles) do
		if schema.supportsPrincipleForm(principle, choice.Form) then
			return principle
		end
	end
	return nil
end
for _, intent in ipairs(authoringGuide.intents()) do
	local shapes = authoringGuide.shapes(intent.Id, schema, spec)
	for _, form in ipairs(shapes) do
		local choices = authoringGuide.forShape(intent.Id, form, schema, spec)
		assert(#choices > 0, "Every offered shape must have a valid starter effect")
		for _, choice in ipairs(choices) do
			local draft = spec.createDraft(choice.Form, choicePrinciple(choice))
			local payload = spec.copy(schema.Payloads[choice.Payload].Defaults or {})
			payload.Kind = choice.Payload
			draft.Triggers[choice.Event] = { { Payloads = { payload } } }
			assert(spec.validate(draft), "Guided choices must validate: " .. intent.Id .. "/" .. choice.Payload)
		end
	end
end
assert(#authoringGuide.shapes("not-an-intent", schema, spec) == 0, "Unknown intents should offer no shapes")
local areaForms = authoringGuide.shapes("Area", schema, spec)
assert(areaForms[1] == "Field", "Area intent should place its most characteristic Form first")
assert(authoringGuide.isRecommended("Area", "Aura"), "Aura should be suggested for area effects")
assert(
	not authoringGuide.isRecommended("Area", "Projectile"),
	"A projectile may be compatible without being the lead suggestion"
)
assert(
	table.find(areaForms, "Projectile") ~= nil,
	"Area intent must retain compatible alternate Forms instead of inheriting one fixed Form family"
)
local healingForms = authoringGuide.shapes("Healing", schema, spec)
assert(authoringGuide.isRecommended("Healing", "Aura"), "Aura should be suggested for healing")
assert(table.find(healingForms, "Projectile") ~= nil, "A healing payload may be delivered by a compatible Projectile")
-- Manipulation moves objects; it has no way to heal a creature.
assert(#authoringGuide.forShape("Healing", "Manipulation", schema, spec) == 0, "Unsupported combinations stay hidden")
local slots = {}
for slot, example in ipairs({
	{ "Projectile", "Energy", "Damage", "OnImpact", "Practice bolt" },
	{ "Beam", "Body", "Heal", "OnCast", "Healing beam" },
}) do
	local draft = spec.createDraft(example[1], example[2])
	draft.Name = example[5]
	local effect = spec.copy(schema.Payloads[example[3]].Defaults)
	effect.Kind = example[3]
	draft.Triggers[example[4]] = { { Payloads = { effect } } }
	local valid, reason = spec.validate(draft)
	assert(valid, "Walkthrough example must be castable: " .. tostring(reason))
	local text, reviewed = summary.describe(draft, schema, spec)
	assert(reviewed and string.find(text, "Ready to save and test", 1, true))
	assert(string.find(text, schema.Payloads[example[3]].Label, 1, true))
	labCost.refresh(draft, spec.estimate, spec.copy)
	draft.SpellId = "MagicLabSlot" .. slot
	slots[slot] = spec.copy(draft)
	assert(library.capture(catalog, slot, draft, spec.copy, 100))
end
local original = spec.copy(catalog.Records["1"].Definition)
assert(library.mutate(catalog, "Collection", { Name = "Practice" }, spec.copy, 101))
assert(library.mutate(catalog, "Move", { Id = "1", Collection = "Practice" }, spec.copy, 102))
assert(library.mutate(catalog, "Tags", { Id = "1", Tags = "starter bolt" }, spec.copy, 103))
assert(library.mutate(catalog, "Favorite", { Id = "1" }, spec.copy, 104))
assert(spec.validate(catalog.Records["1"].Definition))
assert(spec.estimate(catalog.Records["1"].Definition).ManaDemand == spec.estimate(original).ManaDemand)
assert(#library.query(catalog, { Search = "damage", Status = "Favorites", Collection = "Practice" }) == 1)
local raw = { Version = 2, Slots = {}, Catalog = spec.copy(catalog) }
for slot, draft in pairs(slots) do
	raw.Slots[tostring(slot)] = spec.copy(draft)
end
local reopened = assert(library.decode(raw, slots, spec.copy, spec.validate))
assert(reopened.Records["1"].Tags == "starter bolt" and reopened.Records["1"].Favorite)
assert(spec.validate(reopened.Records["2"].Definition))
assert(library.mutate(reopened, "Duplicate", { Id = "1" }, spec.copy, 105))
assert(spec.validate(reopened.Records["3"].Definition))
assert(library.mutate(reopened, "Archive", { Id = "3" }, spec.copy, 106))
assert(library.mutate(reopened, "Restore", { Id = "3" }, spec.copy, 107))
local invalid = spec.createDraft("Projectile", "Energy")
local _, valid, reason = summary.describe(invalid, schema, spec)
assert(not valid and reason, "Blank projectile must explain its missing effects")
print(
	"PASS: real-schema walkthrough examples → validate → review → save/catalog → organize → reopen → duplicate/archive/restore; combat estimates unchanged"
)

local legacyCost = spec.copy(original)
legacyCost.Cost.ManaUpkeepPerSecond = 3
legacyCost.Cost.StrainPerSecond = 2
assert(not spec.validate(legacyCost), "Display fields must not enter the saved Cost schema")
labCost.normalize(legacyCost)
labCost.refresh(legacyCost, spec.estimate, spec.copy)
assert(spec.validate(legacyCost), "Legacy estimate fields should migrate to valid saved Cost")
print("PASS: legacy estimate-cost serialization repaired without changing calculations")

-- Exercise the actual Lab serializer, not a parallel model of its storage behavior.
local codecFactory = assert(loadstring(
	"return function(Spec, LabCost, Color3, typeof, type, SpellIdentitySpec) "
		-- MagicLabService defines these just above the extracted codec; in
		-- the Studio sandbox reprice is LabCost.refresh.
		.. "local function unrestricted() return true end "
		.. "local function reprice(definition) LabCost.refresh(definition, Spec.estimate, Spec.copy) end "
		.. __CODEC_SOURCE
		.. " return validateStored, hydrate, dehydrate end"
))()
local validateStored, hydrate, dehydrate = codecFactory(spec, labCost, env.Color3, env.typeof, function(value)
	return env.typeof(value) == "Color3" and "userdata" or type(value)
end, identitySpec)
local profile = load("src/shared/Modules/MagicLibraryProfile.luau")
local ids = load("src/shared/Modules/MagicSlots.luau")
local runtimeSpell = spec.copy(original)
runtimeSpell.Development = true
local resourceId = next(locusConfig.SpecialResources)
if resourceId then
	runtimeSpell.Cost.SpecialResources[resourceId] = 1
end
labCost.refresh(runtimeSpell, spec.estimate, spec.copy)
if resourceId then
	assert(runtimeSpell.Cost.SpecialResources[resourceId] == 1, "Special resource costs must survive recalculation")
end
local snapshot = assert(profile.encode({ [1] = runtimeSpell }, 9, ids.id, validateStored, spec.copy, dehydrate))
assert(snapshot.Slots["1"].Development == nil and snapshot.Slots["1"].Cost.ManaUpkeepPerSecond == nil)
assert(type(snapshot.Slots["1"].Visual.Color[1]) == "number", "Colors must serialize as RGB arrays")
local reopenedSlots, safe = profile.decode(snapshot, 9, ids.id, validateStored, spec.copy, hydrate)
assert(safe and reopenedSlots[1].Development and validateStored(reopenedSlots[1]))
assert(reopenedSlots[1].SpellId == "MagicLabSlot1")
if resourceId then
	assert(reopenedSlots[1].Cost.SpecialResources[resourceId] == 1)
end
snapshot.Slots["1"].Cost.ManaUpkeepPerSecond = 0
snapshot.Slots["1"].Cost.StrainPerSecond = 0
local migratedSlots, safeLegacy = profile.decode(snapshot, 9, ids.id, validateStored, spec.copy, hydrate)
assert(safeLegacy and migratedSlots[1].Cost.ManaUpkeepPerSecond == nil)
snapshot.Slots["1"].Cost.Unrecognized = 99
local _, safeUnknown = profile.decode(snapshot, 9, ids.id, validateStored, spec.copy, hydrate)
assert(not safeUnknown, "Do not strip unknown saved data to force acceptance")
print(
	"PASS: actual Lab serializer → RGB storage → hydrate/reopen → legacy cost repair; special costs and stable slot IDs preserved"
)

-- Run the actual server action branches with real definitions; mock only engine transport.
local player = {}
local transport = {
	player = player,
	loaded = { [player] = true },
	writable = { [player] = true },
	dirty = {},
	definitions = { [player] = spec.copy(slots) },
	catalogs = { [player] = spec.copy(catalog) },
	Slots = ids,
	Spec = spec,
	Library = library,
	LabCost = labCost,
	Magic = { clearTemporary = function() end, setCompanionSpell = function() end },
	getState = function()
		return {}
	end,
	scheduleSave = function() end,
	save = function()
		return false, "Test storage failure"
	end,
}
local response
-- Studio-sandbox versions of MagicLabService's progression gates: when
-- unrestricted, pricing is LabCost.refresh and every slot/spell is usable.
transport.unrestricted = function()
	return true
end
transport.reprice = function(definition)
	labCost.refresh(definition, spec.estimate, spec.copy)
end
transport.usable = function()
	return true, ""
end
transport.syncCompanion = function(player, slot, definition)
	local catalog = transport.catalogs[player]
	local recordId = catalog and catalog.Assignments[tostring(slot)]
	transport.Magic.setCompanionSpell(player, slot, if definition and recordId then definition else nil)
end
transport.publish = function(_, ok, text, changedSlot, state)
	response = { Ok = ok, Text = text, Slot = changedSlot, State = state }
end
transport.reply = function(_, _, ok, text)
	response = { Ok = ok, Text = text }
end
setmetatable(transport, { __index = getfenv() })
-- Analytics is fire-and-forget; record calls so the flow can be asserted on.
transport.telemetryEvents = {}
transport.Telemetry = {
	onboarding = function(_, step)
		table.insert(transport.telemetryEvents, step)
	end,
	economy = function() end,
}
local action = assert(loadstring(__LIBRARY_ACTION_SOURCE))
setfenv(action, transport)
local function command(kind, args)
	transport.action = "Library"
	transport.data = args or {}
	transport.data.Action = kind
	action()
	return response
end
local libraryOnly = spec.copy(original)
libraryOnly.Name = "Catalog only spell"
assert(not command("SaveNew", { Definition = { Name = "invalid" } }).Ok, "Invalid independent spells are rejected")
assert(command("SaveNew", { Definition = libraryOnly }).Ok, "A valid spell can be saved without a slot")
local serverCatalog = transport.catalogs[player]
local catalogOnlyId = tostring(serverCatalog.NextId - 1)
assert(serverCatalog.Records[catalogOnlyId].Definition.Name == "Catalog only spell")
assert(not serverCatalog.Assignments[catalogOnlyId], "Independent saved spell must not equip a loadout slot")
local invalidRevision = command("Update", { Id = catalogOnlyId, Definition = { Name = "invalid" } })
assert(not invalidRevision.Ok, "Invalid saved-spell revisions are rejected")
assert(serverCatalog.Records[catalogOnlyId].Definition.Name == "Catalog only spell")
assert(command("Equip", { Id = catalogOnlyId, Slot = 4 }).Ok)
local revisedLibraryOnly = spec.copy(libraryOnly)
revisedLibraryOnly.Name = "Revised catalog spell"
assert(command("Update", { Id = catalogOnlyId, Definition = revisedLibraryOnly }).Ok)
assert(serverCatalog.Records[catalogOnlyId].Definition.Name == "Revised catalog spell")
assert(transport.definitions[player][4].Name == "Revised catalog spell")
assert(transport.definitions[player][4].SpellId == ids.id(4), "Updating a record preserves the assigned slot identity")
assert(command("Equip", { Id = "1", Slot = 3 }).Ok)
assert(transport.definitions[player][3].SpellId == "MagicLabSlot3")
assert(transport.catalogs[player].Assignments["3"] == "1")
assert(command("Rename", { Id = "1", Name = "Shared practice bolt" }).Ok)
assert(transport.definitions[player][1].Name == "Shared practice bolt")
assert(transport.definitions[player][3].Name == "Shared practice bolt")
local apply = assert(loadstring(__APPLY_ACTION_SOURCE))
setfenv(apply, transport)
transport.slot, transport.slotIdValue = 1, ids.id(1)
transport.data = spec.copy(original)
transport.data.Name = "Revised shared bolt"
apply()
assert(response.Ok and transport.definitions[player][3].Name == "Revised shared bolt")
assert(transport.definitions[player][3].SpellId == ids.id(3))
assert(not command("Archive", { Id = "1" }).Ok, "Equipped spell must stay recoverable")
assert(command("Unequip", { Slot = 1 }).Ok)
assert(command("Unequip", { Slot = 3 }).Ok)
assert(not transport.definitions[player][1] and not transport.definitions[player][3])
assert(command("Archive", { Id = "1" }).Ok)
assert(not command("Equip", { Id = "1", Slot = 3 }).Ok, "Archived spells require restoration")
assert(command("Restore", { Id = "1" }).Ok)
assert(command("Equip", { Id = "1", Slot = 3 }).Ok)
assert(command("RetrySave").State == "SAVE FAILED · SESSION COPY")
assert(transport.definitions[player][3].Name == "Revised shared bolt", "Save failure must retain session spell")
print(
	"PASS: actual server equip → rename → revise shared slots → unequip → archive/restore → re-equip; failed persistence retains session copy"
)
