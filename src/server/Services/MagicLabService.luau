--!strict
-- A separate development transport; never accepts a live-player spell registry edit.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Configuration.MagicLab)
local Slots = require(Shared.Modules.MagicSlots)
local Spec = require(Shared.Modules.SpellSpec)
local Profile = require(Shared.Modules.MagicLibraryProfile)
local Library = require(Shared.Modules.GrimoireLibrary)
local Starters = require(Shared.Modules.GrimoireStarters)
local LabCost = require(Shared.Modules.MagicLabCost)
local Magic = require(script.Parent.MagicService)
local Lab = {}

function Lab.start(folder: Folder, getState: (Player) -> any, feedback: RemoteEvent)
	local request = Instance.new("RemoteEvent")
	request.Name = "MagicLabRequest"
	request.Parent = folder
	local response = Instance.new("RemoteEvent")
	response.Name = "MagicLabResponse"
	response.Parent = folder
	local catalogResponse = Instance.new("RemoteEvent")
	catalogResponse.Name, catalogResponse.Parent = "GrimoireResponse", folder
	local catalogs = {}
	local saving = {}
	local loading = {}
	local last: { [Player]: number } = {}
	local definitions: { [Player]: any } = {}
	local loaded: { [Player]: boolean } = {}
	local writable: { [Player]: boolean } = {}
	local dirty: { [Player]: boolean } = {}
	local saveRevision: { [Player]: number } = {}
	local store
	local storeReady = pcall(function()
		store = DataStoreService:GetDataStore(Config.LibraryDataStoreName)
	end)
	if not storeReady then
		store = nil
	end

	local function allowed(): boolean
		return Config.Enabled and (RunService:IsStudio() or (not Config.StudioOnly and Config.AllowLive))
	end
	local function ready(player: Player): boolean
		local state = getState(player)
		return state ~= nil
			and state.Character == player.Character
			and state.Humanoid.Health > 0
			and state.Root:IsDescendantOf(workspace)
			and player:GetAttribute("OpeningComplete") == true
	end
	local function slotId(slot: number): string?
		return Slots.id(slot)
	end
	local function validateStored(definition): boolean
		if type(definition) ~= "table" then
			return false
		end
		local clean = Spec.copy(definition)
		clean.Development = nil
		LabCost.normalize(clean)
		for _, colorKey in { "Color", "SecondaryColor", "AccentColor" } do
			local color = if type(clean.Visual) == "table" then clean.Visual[colorKey] else nil
			if type(color) == "table" then
				if
					type(color[1]) ~= "number"
					or type(color[2]) ~= "number"
					or type(color[3]) ~= "number"
					or color[1] < 0
					or color[1] > 1
					or color[2] < 0
					or color[2] > 1
					or color[3] < 0
					or color[3] > 1
				then
					return false
				end
				clean.Visual[colorKey] = Color3.new(color[1], color[2], color[3])
			end
		end
		local ok = Spec.validate(clean)
		return ok == true
	end
	local function hydrate(definition, slot: number, id: string)
		LabCost.normalize(definition)
		for _, colorKey in { "Color", "SecondaryColor", "AccentColor" } do
			local color = if type(definition.Visual) == "table" then definition.Visual[colorKey] else nil
			if
				type(color) == "table"
				and type(color[1]) == "number"
				and type(color[2]) == "number"
				and type(color[3]) == "number"
				and color[1] >= 0
				and color[1] <= 1
				and color[2] >= 0
				and color[2] <= 1
				and color[3] >= 0
				and color[3] <= 1
			then
				definition.Visual[colorKey] = Color3.new(color[1], color[2], color[3])
			end
		end
		if validateStored(definition) then
			if type(definition.Visual) == "table" and definition.Visual.Palette == nil then
				-- Preserve pre-discovery RGB authoring without changing its appearance.
				definition.Visual.Palette = "LegacyCustom"
			end
			definition.SpellId = id
			LabCost.refresh(definition, Spec.estimate, Spec.copy)
			definition.Development = true
		end
		return definition
	end
	local function dehydrate(definition, slot: number, id: string)
		definition.SpellId = id
		LabCost.refresh(definition, Spec.estimate, Spec.copy)
		definition.Development = nil
		for _, colorKey in { "Color", "SecondaryColor", "AccentColor" } do
			local color = if type(definition.Visual) == "table" then definition.Visual[colorKey] else nil
			if typeof(color) == "Color3" then
				definition.Visual[colorKey] = { color.R, color.G, color.B }
			end
		end
		return definition
	end
	local function makePublic(defs)
		local public = {}
		for slot, value in pairs(defs) do
			local definition = Spec.copy(value)
			definition.Development = nil
			public[tostring(slot)] = definition
		end
		return public
	end
	local function reply(player: Player, action, ok: boolean, text: string, data, slot)
		response:FireClient(player, ok, text, data, action, slot)
	end
	local function profileKey(player: Player): string
		return "u:" .. tostring(player.UserId)
	end
	local function decode(raw)
		local slotData = raw
		if type(raw) == "table" and raw.Version == Library.Version then
			slotData = { Version = Profile.Version, Slots = raw.Slots }
		end
		local defs, safe, reason = Profile.decode(slotData, Slots.Count, slotId, validateStored, Spec.copy, hydrate)
		if not safe then
			return defs, false, reason
		end
		local catalog, catalogReason = Library.decode(raw, defs, Spec.copy, validateStored, hydrate)
		return defs, catalog ~= nil, catalogReason, catalog
	end
	local function publish(player, ok, text, slot, saveState)
		if loaded[player] and not writable[player] then
			text ..= " · session only; persistent storage is unavailable or protected"
		end
		local catalog = Spec.copy(catalogs[player] or Library.empty())
		catalog.SaveState = saveState
			or (if not writable[player] then "SESSION ONLY" elseif dirty[player] then "SAVING" else "SAVED")
		for _, record in pairs(catalog.Records) do
			record.Definition.Development = nil
		end
		catalogResponse:FireClient(player, ok, text, catalog, makePublic(definitions[player] or {}), slot)
	end
	local function save(player: Player): (boolean, string)
		-- Serialize writes so a slower older save cannot overwrite a newer snapshot.
		while saving[player] do
			task.wait(0.1)
		end
		if not dirty[player] then
			return true, "Spell library is unchanged"
		end
		if not loaded[player] then
			return false, "Spell library has not loaded"
		end
		if not writable[player] or not store then
			return false, "Persistent storage is unavailable; this session remains usable"
		end
		local snapshot, encodeFailure =
			Profile.encode(definitions[player] or {}, Slots.Count, slotId, validateStored, Spec.copy, dehydrate)
		if not snapshot then
			return false, encodeFailure or "Spell library could not be saved"
		end
		snapshot.Version = Library.Version
		snapshot.Catalog = Spec.copy(catalogs[player] or Library.empty())
		for _, record in pairs(snapshot.Catalog.Records) do
			record.Definition = dehydrate(record.Definition, 1, record.Definition.SpellId)
		end
		local _, validSnapshot, invalidReason = decode(snapshot)
		if not validSnapshot then
			return false, invalidReason or "Library validation failed"
		end
		local rejectedExistingProfile = false
		local savedRevision = saveRevision[player]
		saving[player] = true
		local ok, result = pcall(function()
			return store:UpdateAsync(profileKey(player), function(existing)
				rejectedExistingProfile = false
				if existing ~= nil then
					local _, safe = decode(existing)
					if not safe then
						rejectedExistingProfile = true
						return nil
					end
				end
				return snapshot
			end)
		end)
		saving[player] = nil
		if not ok then
			return false, "Spell library save failed; session copy is still equipped"
		end
		if rejectedExistingProfile or result == nil then
			writable[player] = false
			return false, "Existing spell data was not overwritten because it could not be validated"
		end
		if saveRevision[player] == savedRevision then
			dirty[player] = nil
		end
		return true, "Spell library saved"
	end
	local function scheduleSave(player: Player)
		if not writable[player] then
			return
		end
		saveRevision[player] = (saveRevision[player] or 0) + 1
		dirty[player] = true
		local revision = saveRevision[player]
		task.delay(Config.LibrarySaveDebounce, function()
			if player.Parent ~= Players or saveRevision[player] ~= revision then
				return
			end
			local ok, text = save(player)
			reply(player, "Save", ok, text, nil, nil)
		end)
	end
	local function seedStarters(player: Player)
		local catalog = catalogs[player]
		for _, collection in ipairs(catalog.Collections) do
			if collection == Starters.Collection then
				return
			end
		end
		local templates = Starters.build()
		local recordCount = 0
		for _ in pairs(catalog.Records) do
			recordCount += 1
		end
		if recordCount + #templates > Library.MaxRecords or #catalog.Collections >= Library.MaxCollections then
			return
		end
		table.insert(catalog.Collections, Starters.Collection)
		for _, template in ipairs(templates) do
			local definition = Spec.copy(template.Definition)
			LabCost.refresh(definition, Spec.estimate, Spec.copy)
			local valid, reason = Spec.validate(definition)
			assert(valid, "Starter failed server validation: " .. tostring(reason))
			local id = assert(Library.add(catalog, definition, Spec.copy, os.time()))
			catalog.Records[id].Collection = Starters.Collection
			catalog.Records[id].Tags = Starters.Tag
		end
		if writable[player] then
			scheduleSave(player)
		end
	end
	local function load(player: Player)
		if loading[player] then
			reply(player, "Load", false, "The library is still loading; try again shortly", nil, nil)
			return
		end
		if loaded[player] then
			publish(player, true, "Library ready")
			reply(player, "Load", true, "Spell library ready", makePublic(definitions[player] or {}), nil)
			return
		end
		if not store then
			catalogs[player] = Library.empty()
			definitions[player] = {}
			loaded[player], writable[player] = true, false
			seedStarters(player)
			reply(player, "Load", true, "Session library ready · persistent storage unavailable", {}, nil)
			return
		end
		loading[player] = true
		local ok, raw = pcall(function()
			return store:GetAsync(profileKey(player))
		end)
		loading[player] = nil
		if player.Parent ~= Players then
			return
		end
		if not ok then
			catalogs[player] = Library.empty()
			definitions[player] = {}
			loaded[player], writable[player] = true, false
			seedStarters(player)
			reply(
				player,
				"Load",
				true,
				"Session library ready · DataStore unavailable; saved data was not changed",
				{},
				nil
			)
			return
		end
		local result, safe, reason, catalog = decode(raw)
		if not safe then
			catalogs[player] = Library.empty()
			definitions[player] = {}
			loaded[player], writable[player] = true, false
			seedStarters(player)
			reply(player, "Load", true, reason or "Saved library was left untouched; session library ready", {}, nil)
			return
		end
		catalogs[player] = catalog
		definitions[player] = result
		loaded[player], writable[player] = true, true
		seedStarters(player)
		for slot, definition in pairs(result) do
			Magic.setCompanionSpell(player, slot, definition)
		end
		reply(player, "Load", true, "Spell library loaded", makePublic(result), nil)
	end

	request.OnServerEvent:Connect(function(player, action, data, slot)
		if not allowed() then
			return
		end
		local now = os.clock()
		if now - (last[player] or -math.huge) < 0.1 then
			response:FireClient(player, false, "Please wait briefly between Lab requests", nil, action, slot)
			return
		end
		last[player] = now
		if not ready(player) then
			response:FireClient(player, false, "Character is not ready", nil, action, slot)
			return
		end
		if action == "Load" then
			load(player)
			publish(player, true, "Library ready")
			return
		end
		if action == "Library" then
			if not loaded[player] or type(data) ~= "table" or type(data.Action) ~= "string" then
				publish(player, false, "Load the library first")
				return
			end
			if data.Action == "RetrySave" then
				local ok, text = save(player)
				publish(player, ok, text, nil, (not ok and writable[player]) and "SAVE FAILED · SESSION COPY" or nil)
				return
			end
			local catalog = catalogs[player]
			local ok, text = false, "Unknown library action"
			local changedSlot
			if data.Action == "Equip" or data.Action == "Unequip" then
				local id = Slots.id(data.Slot)
				local record = type(data.Id) == "string" and catalog.Records[data.Id]
				if not id or (data.Action == "Equip" and (not record or record.Archived)) then
					publish(player, false, "Choose an active spell and a valid slot")
					return
				end
				local definition = record and Spec.copy(record.Definition)
				if definition then
					definition.SpellId, definition.Development = id, nil
					local valid, reason = Spec.validate(definition)
					if not valid then
						publish(player, false, reason)
						return
					end
					LabCost.refresh(definition, Spec.estimate, Spec.copy)
					definition.Development = true
				end
				Magic.clearTemporary(player, getState(player), id)
				definitions[player][data.Slot] = if data.Action == "Equip" then definition else nil
				catalog.Assignments[tostring(data.Slot)] = if data.Action == "Equip" then data.Id else nil
				Magic.setCompanionSpell(player, data.Slot, definitions[player][data.Slot])
				changedSlot = data.Slot
				ok, text =
					true,
					if data.Action == "Equip" then "Spell equipped" else "Slot cleared; spell remains in the library"
			elseif data.Action == "SaveNew" then
				if type(data.Definition) ~= "table" then
					publish(player, false, "Spell definition is required")
					return
				end
				local valid, reason = Spec.validate(data.Definition)
				if not valid then
					publish(player, false, reason)
					return
				end
				local definition = Spec.copy(data.Definition)
				LabCost.refresh(definition, Spec.estimate, Spec.copy)
				local recordId, addReason = Library.add(catalog, definition, Spec.copy, os.time())
				if recordId then
					catalog.Records[recordId].Definition = Spec.copy(definition)
					ok, text = true, "Saved as a separate library spell; no loadout slot changed"
				else
					text = addReason or "Spell could not be saved to the library"
				end
			elseif data.Action == "Update" then
				local record = type(data.Id) == "string" and catalog.Records[data.Id]
				if not record or record.Archived or type(data.Definition) ~= "table" then
					publish(player, false, "Choose an active saved spell and provide its revised definition")
					return
				end
				local valid, reason = Spec.validate(data.Definition)
				if not valid then
					publish(player, false, reason)
					return
				end
				local definition = Spec.copy(data.Definition)
				definition.SpellId = record.Definition.SpellId or Slots.id(1)
				definition.Development = true
				LabCost.refresh(definition, Spec.estimate, Spec.copy)
				ok, text = Library.update(catalog, data.Id, definition, Spec.copy, os.time())
				if ok then
					for key, assignedId in pairs(catalog.Assignments) do
						if assignedId == data.Id then
							local assignedSlot = tonumber(key)
							local assigned = Spec.copy(definition)
							assigned.SpellId = Slots.id(assignedSlot)
							Magic.clearTemporary(player, getState(player), assigned.SpellId)
							definitions[player][assignedSlot] = assigned
							Magic.setCompanionSpell(player, assignedSlot, assigned)
						end
					end
				end
			else
				ok, text = Library.mutate(catalog, data.Action, data, Spec.copy, os.time())
				if ok and data.Action == "Rename" then
					for key, id in pairs(catalog.Assignments) do
						if id == data.Id then
							definitions[player][tonumber(key)].Name = catalog.Records[id].Definition.Name
							Magic.setCompanionSpell(player, tonumber(key), definitions[player][tonumber(key)])
						end
					end
				end
			end
			if ok then
				dirty[player] = true
				scheduleSave(player)
			end
			publish(
				player,
				ok,
				text
					.. (
						if ok
							then " · " .. (if writable[player] then "saving" else "session only; storage unavailable")
							else ""
					),
				changedSlot
			)
			return
		end
		local slotIdValue = slotId(slot)
		if not slotIdValue then
			return
		end
		local state = getState(player)
		if action == "Apply" then
			if not loaded[player] then
				reply(player, action, false, "Load the spell library before editing slots", nil, slot)
				return
			end
			local ok, reason = Spec.validate(data)
			if not ok then
				reply(player, action, false, reason, nil, slot)
				return
			end
			-- The Lab is a development editor: progression never gates valid test spells.
			-- Spec.validate above still enforces expressions, visual enums, and compatibility.
			local catalog = catalogs[player] or Library.empty()
			catalogs[player] = catalog
			local recordId, recordReason = Library.capture(catalog, slot, data, Spec.copy, os.time())
			if not recordId then
				reply(player, action, false, recordReason, nil, slot)
				return
			end
			local definition = Spec.copy(data)
			definition.SpellId = slotIdValue
			LabCost.refresh(definition, Spec.estimate, Spec.copy)
			definition.Development = true -- server-only capability, rejected if supplied in client schema
			catalog.Records[recordId].Definition = Spec.copy(definition)
			-- Keep references to the same library spell consistent across equipped slots.
			for key, id in pairs(catalog.Assignments) do
				local otherSlot = tonumber(key)
				if id == recordId and otherSlot ~= slot then
					local other = Spec.copy(definition)
					other.SpellId = Slots.id(otherSlot)
					Magic.clearTemporary(player, getState(player), other.SpellId)
					definitions[player][otherSlot] = other
					Magic.setCompanionSpell(player, otherSlot, other)
				end
			end
			Magic.clearTemporary(player, state, slotIdValue)
			definitions[player] = definitions[player] or {}
			definitions[player][slot] = definition
			dirty[player] = true
			Magic.setCompanionSpell(player, slot, definition)
			scheduleSave(player)
			publish(player, true, "Library updated")
			reply(
				player,
				action,
				true,
				"Equipped slot "
					.. slot
					.. (writable[player] and " · saving library" or " · session only; storage unavailable"),
				definition.Cost,
				slot
			)
		elseif action == "Cast" then
			if
				typeof(data) ~= "table"
				or data.Character ~= player.Character
				or typeof(data.AimDirection) ~= "Vector3"
				or typeof(data.WorldPoint) ~= "Vector3"
				or (data.CastOrigin ~= nil and typeof(data.CastOrigin) ~= "Vector3")
				or (data.TargetModel ~= nil and typeof(data.TargetModel) ~= "Instance")
				or (data.TargetInstance ~= nil and typeof(data.TargetInstance) ~= "Instance")
			then
				return
			end
			local definition = definitions[player] and definitions[player][slot]
			if not definition then
				reply(player, action, false, "Apply a valid spell first", nil, slot)
				return
			end
			Magic.start(player, state, data, feedback, nil, definition)
		else
			reply(player, action, false, "Unknown Lab action", nil, slot)
		end
	end)

	local function releasePlayer(player: Player)
		if definitions[player] and writable[player] then
			local _, text = save(player)
			if text then
				-- Saving on leave is best-effort; the server shutdown path cannot rely on client feedback.
			end
		end
		catalogs[player], loading[player] = nil, nil
		last[player], definitions[player], loaded[player], writable[player], dirty[player], saveRevision[player] =
			nil, nil, nil, nil, nil, nil
	end
	Players.PlayerRemoving:Connect(releasePlayer)
	game:BindToClose(function()
		for player in pairs(definitions) do
			if writable[player] then
				save(player)
			end
		end
	end)
end

return Lab
