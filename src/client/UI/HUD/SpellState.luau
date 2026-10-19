--!strict
-- Client mirror of the equipped spell slots for the HUD spell bar, plus the
-- drag-and-drop hand-off from Grimoire library cards to open bar slots.
-- Server owns slots: equipping goes through MagicLabRequest("Library", Equip).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Slots = require(Shared.Modules.MagicSlots)
local AttributeSpec = require(Shared.Modules.MagicAttributeSpec)

local State = {}
local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

export type SlotInfo = {
	Name: string,
	Element: string?,
	Color: Color3?,
	ManaCost: number,
	Cooldown: number,
	SpellId: string?,
}
State.Slots = {} :: { [number]: SlotInfo }
State.SlotLimit = 4
State.Selected = 1
State.CooldownEnds = {} :: { [number]: number }
-- Length of the cooldown that is running, after CooldownRate (for the sweep fill).
State.CooldownDurations = {} :: { [number]: number }
State.Drag = nil :: { Id: string, Name: string, Color: Color3?, Start: Vector2, Active: boolean }?

local costCache: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any
local function manaCost(definition: any): number
	local cached = costCache[definition]
	if cached then
		return cached
	end
	local ok, cost = pcall(function()
		local Spec = require(Shared.Modules.SpellSpec)
		return Spec.estimate(definition).ManaDemand
	end)
	local value = if ok and type(cost) == "number" then cost else 0
	costCache[definition] = value
	return value
end

local function describe(definition: any): SlotInfo?
	if type(definition) ~= "table" then
		return nil
	end
	local visual = definition.Visual
	return {
		Name = tostring(definition.Name or "Spell"),
		Element = definition.Element,
		Color = if visual and typeof(visual.Color) == "Color3" then visual.Color else nil,
		ManaCost = manaCost(definition),
		-- Same base the server uses: the longer of Cooldown and RecoveryTime.
		Cooldown = math.max(
			if definition.Casting and type(definition.Casting.Cooldown) == "number"
				then definition.Casting.Cooldown
				else 0,
			if definition.Casting and type(definition.Casting.RecoveryTime) == "number"
				then definition.Casting.RecoveryTime
				else 0
		),
		SpellId = definition.SpellId,
	}
end

local request: RemoteEvent? = nil

-- Cooldown length after CooldownRate: +50 (multiplier 1.5) is 1.5x faster.
function State.cooldownDuration(base: number, rateMultiplier: number): number
	return base / math.max(0.01, rateMultiplier)
end

function State.equip(libraryId: string, slot: number)
	if request and slot >= 1 and slot <= State.SlotLimit then
		request:FireServer("Library", { Action = "Equip", Id = libraryId, Slot = slot })
	end
end

-- Called by a Grimoire library card on press; becomes a drag once the pointer moves.
function State.pressCard(libraryId: string, definition: any)
	local location = UserInputService:GetMouseLocation()
	local info = describe(definition)
	State.Drag = {
		Id = libraryId,
		Name = if info then info.Name else "Spell",
		Color = if info then info.Color else nil,
		Start = location,
		Active = false,
	}
end

function State.endDrag()
	State.Drag = nil
	changed:Fire("Drag")
end

function State.start()
	local player = Players.LocalPlayer
	local remotes = Shared:WaitForChild("SandboxRemotes")
	request = remotes:WaitForChild("MagicLabRequest", 15) :: RemoteEvent?
	local response = remotes:WaitForChild("GrimoireResponse", 15) :: RemoteEvent?
	local feedback = remotes:WaitForChild("ActionFeedback", 15) :: RemoteEvent?
	if response then
		response.OnClientEvent:Connect(function(_, _, catalog, slots)
			if type(catalog) == "table" then
				if catalog.Unrestricted then
					State.SlotLimit = Slots.Count
				elseif type(catalog.Progression) == "table" then
					local ok, limit = pcall(function()
						return require(Shared.Modules.SpellProgressionRules).slots(catalog.Progression)
					end)
					if ok and type(limit) == "number" then
						State.SlotLimit = limit
					end
				end
			end
			if type(slots) == "table" then
				for slot = 1, Slots.Count do
					State.Slots[slot] = describe(slots[tostring(slot)])
				end
			end
			changed:Fire("Slots")
		end)
	end
	if feedback then
		feedback.OnClientEvent:Connect(function(message)
			if type(message) ~= "table" or message.Kind ~= "Magic" or message.Result == "IMPOSSIBLE" then
				return
			end
			-- The server divides the cooldown by the caster's CooldownRate multiplier.
			local rate = math.max(0.01, AttributeSpec.multiplier(player.Character, "CooldownRate"))
			for slot, info in State.Slots do
				if info.SpellId and info.SpellId == message.SpellId and info.Cooldown > 0 then
					local duration = State.cooldownDuration(info.Cooldown, rate)
					State.CooldownEnds[slot] = os.clock() + duration
					State.CooldownDurations[slot] = duration
				end
			end
		end)
	end
	local function selected()
		local value = player:GetAttribute("GamepadSpellSlot")
		State.Selected = if type(value) == "number" then value else 1
		changed:Fire("Selected")
	end
	player:GetAttributeChangedSignal("GamepadSpellSlot"):Connect(selected)
	selected()
	-- Load the library so the bar shows equipped spells before the Grimoire is ever opened.
	if request then
		request:FireServer("Load")
	end
end

return State
