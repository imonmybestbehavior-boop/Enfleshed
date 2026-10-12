--!strict
-- Organization only. Spell definitions remain owned and validated by SpellSpec.
local Library = { Version = 2, MaxRecords = 200, MaxCollections = 32 }
local function text(value, limit)
	return type(value) == "string" and #value > 0 and #value <= limit and not value:find("[%c]")
end
local function count(values)
	local n = 0
	for _ in pairs(values) do
		n = n + 1
	end
	return n
end
function Library.labels(record)
	return string.gsub(record.Tags, "starter%-template,?%s*", "")
end
function Library.empty()
	return { Records = {}, Collections = { "Unfiled" }, Assignments = {}, NextId = 1, HelpDismissed = false }
end
function Library.add(catalog, definition, clone, now)
	if count(catalog.Records) >= Library.MaxRecords then
		return nil, "Library is full (200 spells). Archive and permanently delete unused spells first."
	end
	local id = tostring(catalog.NextId)
	catalog.NextId = catalog.NextId + 1
	catalog.Records[id] = {
		Definition = clone(definition),
		Collection = "Unfiled",
		Tags = "",
		Favorite = false,
		Archived = false,
		UpdatedAt = now,
	}
	return id
end
function Library.capture(catalog, slot, definition, clone, now)
	local key = tostring(slot)
	local id = catalog.Assignments[key]
	local record = id and catalog.Records[id]
	if record and not record.Archived then
		record.Definition, record.UpdatedAt = clone(definition), now
		return id
	end
	local reason
	id, reason = Library.add(catalog, definition, clone, now)
	if id then
		catalog.Assignments[key] = id
	end
	return id, reason
end
function Library.update(catalog, id, definition, clone, now)
	local record = type(id) == "string" and catalog.Records[id]
	if not record or record.Archived then
		return false, "Choose an active saved spell to update"
	end
	record.Definition = clone(definition)
	record.UpdatedAt = now
	return true, "Saved spell updated; equipped copies were refreshed"
end
function Library.decode(raw, slots, clone, validate, hydrate)
	local catalog = Library.empty()
	if raw ~= nil and type(raw) ~= "table" then
		return nil, "Invalid library format"
	end
	if raw == nil or raw.Version == 1 then
		for slot = 1, 9 do
			if slots[slot] then
				Library.capture(catalog, slot, slots[slot], clone, 0)
			end
		end
		return catalog
	end
	if raw.Version ~= Library.Version or type(raw.Catalog) ~= "table" then
		return nil, "Unknown library format; saved data was left untouched"
	end
	catalog = clone(raw.Catalog)
	for key in pairs(raw) do
		if key ~= "Version" and key ~= "Slots" and key ~= "Catalog" then
			return nil, "Unknown saved library fields"
		end
	end
	for key in pairs(catalog) do
		if
			key ~= "Records"
			and key ~= "Collections"
			and key ~= "Assignments"
			and key ~= "NextId"
			and key ~= "HelpDismissed"
		then
			return nil, "Unknown catalog fields"
		end
	end
	if
		type(catalog.Records) ~= "table"
		or type(catalog.Collections) ~= "table"
		or type(catalog.Assignments) ~= "table"
		or type(catalog.NextId) ~= "number"
		or catalog.NextId % 1 ~= 0
		or catalog.NextId < 1
		or catalog.NextId > 1e9
		or type(catalog.HelpDismissed) ~= "boolean"
		or count(catalog.Records) > Library.MaxRecords
		or #catalog.Collections < 1
		or #catalog.Collections > Library.MaxCollections
	then
		return nil, "Invalid library metadata"
	end
	local collections = {}
	for index, name in pairs(catalog.Collections) do
		if
			type(index) ~= "number"
			or index % 1 ~= 0
			or index < 1
			or index > #catalog.Collections
			or not text(name, 48)
			or collections[name]
		then
			return nil, "Invalid collection names"
		end
		collections[name] = true
	end
	if not collections.Unfiled then
		return nil, "Default collection is missing"
	end
	for id, record in pairs(catalog.Records) do
		local number = tonumber(id)
		if
			type(id) ~= "string"
			or not number
			or tostring(number) ~= id
			or number % 1 ~= 0
			or number < 1
			or number >= catalog.NextId
			or type(record) ~= "table"
		then
			return nil, "Invalid library entry"
		end
		for key in pairs(record) do
			if
				key ~= "Definition"
				and key ~= "Collection"
				and key ~= "Tags"
				and key ~= "Favorite"
				and key ~= "Archived"
				and key ~= "UpdatedAt"
			then
				return nil, "Unknown entry metadata"
			end
		end
		if
			not collections[record.Collection]
			or type(record.Tags) ~= "string"
			or #record.Tags > 240
			or record.Tags:find("[%c]")
			or type(record.Favorite) ~= "boolean"
			or type(record.Archived) ~= "boolean"
			or type(record.UpdatedAt) ~= "number"
			or record.UpdatedAt ~= record.UpdatedAt
			or record.UpdatedAt < 0
			or record.UpdatedAt > 1e12
		then
			return nil, "Invalid entry metadata"
		end
		if not validate(record.Definition) then
			return nil, "A library spell failed validation; saved data was left untouched"
		end
		if hydrate then
			record.Definition = hydrate(record.Definition, 1, record.Definition.SpellId)
		end
	end
	for slot, id in pairs(catalog.Assignments) do
		local number = tonumber(slot)
		if
			type(slot) ~= "string"
			or not number
			or tostring(number) ~= slot
			or number % 1 ~= 0
			or number < 1
			or number > 9
			or not slots[number]
			or not catalog.Records[id]
			or catalog.Records[id].Archived
		then
			return nil, "Invalid equipped library reference"
		end
	end
	return catalog
end
function Library.mutate(catalog, action, args, clone, now)
	if type(args) ~= "table" then
		return false, "Invalid library request"
	end
	if action == "Collection" then
		local name = args.Name
		if not text(name, 48) then
			return false, "Use a collection name of 1–48 characters"
		end
		if name:lower() == "all" then
			return false, "All is reserved for the collection filter; choose another name"
		end
		for _, existing in ipairs(catalog.Collections) do
			if existing:lower() == name:lower() then
				return false, "A collection with that name already exists"
			end
		end
		if #catalog.Collections >= Library.MaxCollections then
			return false, "Collection limit reached"
		end
		table.insert(catalog.Collections, name)
		return true, "Collection created"
	elseif action == "DismissHelp" then
		catalog.HelpDismissed = true
		return true, "Help is always available from the library"
	end
	local record = type(args.Id) == "string" and catalog.Records[args.Id]
	if not record then
		return false, "Select a library spell first"
	end
	if action == "Duplicate" then
		local id, reason = Library.add(catalog, record.Definition, clone, now)
		if not id then
			return false, reason
		end
		local copy = catalog.Records[id]
		copy.Collection = if record.Collection == "Starter templates" then "Unfiled" else record.Collection
		copy.Tags = Library.labels(record)
		copy.Definition.Name = string.sub(record.Definition.Name, 1, 41) .. " (copy)"
		return true, "Copy created; the original is unchanged"
	elseif action == "Rename" then
		if not text(args.Name, 48) then
			return false, "Use a spell name of 1–48 characters"
		end
		record.Definition.Name = args.Name
	elseif action == "Move" then
		local found = false
		for _, name in ipairs(catalog.Collections) do
			if name == args.Collection then
				found = true
			end
		end
		if not found then
			return false, "Choose an existing collection"
		end
		record.Collection = args.Collection
	elseif action == "Tags" then
		if type(args.Tags) ~= "string" or #args.Tags > 240 or args.Tags:find("[%c]") then
			return false, "Labels must be at most 240 characters"
		end
		if string.find(record.Tags, "starter-template", 1, true) then
			if #args.Tags > 222 then
				return false, "Starter labels must be at most 222 characters"
			end
			record.Tags = "starter-template" .. (if args.Tags == "" then "" else ", " .. args.Tags)
		else
			record.Tags = args.Tags
		end
	elseif action == "Favorite" then
		record.Favorite = not record.Favorite
	elseif action == "Archive" or action == "Delete" then
		for _, id in pairs(catalog.Assignments) do
			if id == args.Id then
				return false, "Unequip this spell before archiving or deleting it"
			end
		end
		if action == "Delete" then
			if not record.Archived then
				return false, "Archive the spell before permanently deleting it"
			end
			catalog.Records[args.Id] = nil
			return true, "Archived spell permanently deleted"
		end
		record.Archived = true
	elseif action == "Restore" then
		record.Archived = false
	else
		return false, "Unknown library action"
	end
	record.UpdatedAt = now
	return true, "Library updated"
end
function Library.query(catalog, query)
	local results = {}
	local search = string.lower(query.Search or "")
	for id, record in pairs(catalog.Records) do
		local d = record.Definition
		local equipped = false
		for _, assigned in pairs(catalog.Assignments) do
			if assigned == id then
				equipped = true
			end
		end
		local matches = (query.Status == "Archived" and record.Archived)
			or (query.Status ~= "Archived" and not record.Archived)
		matches = matches
			and (query.Status ~= "Favorites" or record.Favorite)
			and (query.Status ~= "Equipped" or equipped)
			and (query.Status ~= "Unequipped" or not equipped)
			and (query.Status ~= "Starter templates" or string.find(record.Tags, "starter-template", 1, true) ~= nil)
		matches = matches
			and (not query.Collection or query.Collection == "All" or query.Collection == record.Collection)
		matches = matches
			and (not query.Form or query.Form == "All" or query.Form == d.Form)
			and (not query.Element or query.Element == "All" or query.Element == d.Element)
		local words = { d.Name, d.Form, d.Element, record.Collection, record.Tags }
		for event, steps in pairs(d.Triggers or {}) do
			table.insert(words, event)
			for _, step in ipairs(steps) do
				for _, payload in ipairs(step.Payloads or {}) do
					table.insert(words, payload.Kind)
				end
			end
		end
		if matches and string.find(string.lower(table.concat(words, " ")), search, 1, true) then
			table.insert(results, { Id = id, Record = record, Equipped = equipped })
		end
	end
	table.sort(results, function(a, b)
		if query.Sort == "Name" and a.Record.Definition.Name ~= b.Record.Definition.Name then
			return a.Record.Definition.Name:lower() < b.Record.Definition.Name:lower()
		end
		if query.Sort == "Cost" then
			local ca, cb =
				(a.Record.Definition.Cost or {}).ManaDemand or 0, (b.Record.Definition.Cost or {}).ManaDemand or 0
			if ca ~= cb then
				return ca < cb
			end
		elseif query.Sort ~= "Name" and a.Record.UpdatedAt ~= b.Record.UpdatedAt then
			return a.Record.UpdatedAt > b.Record.UpdatedAt
		end
		return tonumber(a.Id) < tonumber(b.Id)
	end)
	return results
end
return Library
