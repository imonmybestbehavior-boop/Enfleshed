--!strict

-- Pure inventory container rules. The server applies these to its authoritative
-- copy; the client uses the same functions only to predict what a drag will do.
-- Locations are strings: "Bag:<1..BagSize>", "Equip:<Slot>", "Quick:<1..QuickSize>".
local Rules = require(script.Parent.ItemRules)

local Model = {}

Model.BagSize = 24
Model.QuickSize = 2
Model.EquipSlots = table.freeze({ "MainHand", "MagicFocus", "Head", "Body", "Legs" })

local equipSlotSet: { [string]: boolean } = {}
for _, slot in Model.EquipSlots do
	equipSlotSet[slot] = true
end

export type Inventory = {
	Bag: { [number]: Rules.Instance },
	Equip: { [string]: Rules.Instance },
	Quick: { [number]: Rules.Instance },
}

export type Location = { Area: string, Key: any }

function Model.blank(): Inventory
	return { Bag = {}, Equip = {}, Quick = {} }
end

function Model.parse(value: any): Location?
	if type(value) ~= "string" or #value > 32 then
		return nil
	end
	local area, key = string.match(value, "^(%a+):(%w+)$")
	if area == "Bag" or area == "Quick" then
		local index = tonumber(key)
		local size = if area == "Bag" then Model.BagSize else Model.QuickSize
		if index and index % 1 == 0 and index >= 1 and index <= size then
			return { Area = area, Key = index }
		end
	elseif area == "Equip" and key and equipSlotSet[key] then
		return { Area = "Equip", Key = key }
	end
	return nil
end

function Model.format(location: Location): string
	return location.Area .. ":" .. tostring(location.Key)
end

local function container(inventory: Inventory, location: Location): { [any]: Rules.Instance }
	return (inventory :: any)[location.Area]
end

function Model.get(inventory: Inventory, location: Location): Rules.Instance?
	return container(inventory, location)[location.Key]
end

local function put(inventory: Inventory, location: Location, instance: Rules.Instance?)
	container(inventory, location)[location.Key] = instance :: any
end

-- Whether a location may hold this instance at all.
function Model.accepts(location: Location, instance: Rules.Instance?): boolean
	if not instance then
		return true
	end
	local definition = Rules.definition(instance.ItemId)
	if not definition then
		return false
	end
	if location.Area == "Bag" then
		return true
	elseif location.Area == "Quick" then
		return definition.Category == "Consumable"
	elseif location.Area == "Equip" then
		return definition.EquipSlot == location.Key
	end
	return false
end

function Model.firstEmptyBag(inventory: Inventory): number?
	for index = 1, Model.BagSize do
		if not inventory.Bag[index] then
			return index
		end
	end
	return nil
end

-- Moves, merges, or swaps. Returns success and a short reason on failure.
function Model.move(inventory: Inventory, fromValue: any, toValue: any): (boolean, string?)
	local from, to = Model.parse(fromValue), Model.parse(toValue)
	if not from or not to then
		return false, "BadLocation"
	end
	if Model.format(from) == Model.format(to) then
		return false, "Same"
	end
	local moving = Model.get(inventory, from)
	if not moving then
		return false, "Empty"
	end
	local target = Model.get(inventory, to)
	if not Model.accepts(to, moving) then
		return false, "Rejected"
	end
	if target and Rules.canStack(moving, target) then
		local room = Rules.maxStack(Rules.definition(target.ItemId)) - target.Count
		if room <= 0 then
			-- Full stacks simply trade places.
			put(inventory, from, target)
			put(inventory, to, moving)
			return true
		end
		local amount = math.min(room, moving.Count)
		target.Count += amount
		moving.Count -= amount
		if moving.Count <= 0 then
			put(inventory, from, nil)
		end
		return true
	end
	if target and not Model.accepts(from, target) then
		return false, "SwapRejected"
	end
	put(inventory, from, target)
	put(inventory, to, moving)
	return true
end

-- Splits `amount` off a stack into the first empty bag slot.
function Model.split(inventory: Inventory, fromValue: any, amount: any, newUid: string): (boolean, string?)
	local from = Model.parse(fromValue)
	local source = if from then Model.get(inventory, from) else nil
	if not source or type(amount) ~= "number" or amount ~= amount then
		return false, "BadSplit"
	end
	amount = math.floor(amount)
	if amount < 1 or amount >= source.Count then
		return false, "BadAmount"
	end
	local index = Model.firstEmptyBag(inventory)
	if not index then
		return false, "Full"
	end
	source.Count -= amount
	inventory.Bag[index] = Rules.new(source.ItemId, newUid, amount, source.Rarity, {})
	return true
end

-- Removes up to `count` (default: all) from a location and returns what was taken.
function Model.take(inventory: Inventory, location: Location, count: number?, newUid: string?): Rules.Instance?
	local source = Model.get(inventory, location)
	if not source then
		return nil
	end
	local amount = math.clamp(math.floor(count or source.Count), 1, source.Count)
	if amount >= source.Count then
		put(inventory, location, nil)
		return source
	end
	source.Count -= amount
	local taken = Rules.copy(source)
	taken.Uid = newUid or source.Uid
	taken.Count = amount
	return taken
end

-- Adds an instance, merging into compatible stacks (quick slots first) then
-- filling empty bag slots. Returns the count that did not fit.
function Model.add(inventory: Inventory, instance: Rules.Instance): number
	local definition = Rules.definition(instance.ItemId)
	if not definition then
		return instance.Count
	end
	local maxStack = Rules.maxStack(definition)
	if maxStack > 1 and #instance.Affixes == 0 then
		local stacks = {}
		for index = 1, Model.QuickSize do
			table.insert(stacks, inventory.Quick[index])
		end
		for index = 1, Model.BagSize do
			table.insert(stacks, inventory.Bag[index])
		end
		for _, stack in stacks do
			if instance.Count <= 0 then
				break
			end
			if stack and Rules.canStack(stack, instance) and stack.Count < maxStack then
				local amount = math.min(maxStack - stack.Count, instance.Count)
				stack.Count += amount
				instance.Count -= amount
			end
		end
	end
	if instance.Count <= 0 then
		return 0
	end
	local index = Model.firstEmptyBag(inventory)
	if not index then
		return instance.Count
	end
	inventory.Bag[index] = instance
	return 0
end

function Model.isEmpty(inventory: Inventory): boolean
	return next(inventory.Bag) == nil and next(inventory.Equip) == nil and next(inventory.Quick) == nil
end

-- Flat list form that survives DataStore and remote serialisation (no sparse arrays).
function Model.serialize(inventory: Inventory): { any }
	local list = {}
	for _, area in { "Bag", "Equip", "Quick" } do
		for key, instance in (inventory :: any)[area] do
			local entry = Rules.copy(instance) :: any
			entry.Location = area .. ":" .. tostring(key)
			table.insert(list, entry)
		end
	end
	return list
end

-- Rebuilds from untrusted serialised data, dropping invalid or duplicate entries.
function Model.deserialize(raw: any): Inventory
	local inventory = Model.blank()
	if type(raw) ~= "table" then
		return inventory
	end
	local seen: { [string]: boolean } = {}
	local overflow = {}
	for index, entry in raw do
		if type(index) ~= "number" or index > 200 then
			continue
		end
		local instance = Rules.clean(entry)
		if not instance or seen[instance.Uid] then
			continue
		end
		seen[instance.Uid] = true
		local location = Model.parse(if type(entry) == "table" then entry.Location else nil)
		if location and not Model.get(inventory, location) and Model.accepts(location, instance) then
			put(inventory, location, instance)
		else
			table.insert(overflow, instance)
		end
	end
	for _, instance in overflow do
		Model.add(inventory, instance)
	end
	return inventory
end

return Model
