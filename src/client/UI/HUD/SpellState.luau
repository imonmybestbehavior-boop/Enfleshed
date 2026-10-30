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
	HealthCost: string?, -- blood magic, e.g. "30 HP" or "15% HP + 40 HP"
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

local costCache: { [any]: { Mana: number, Health: string? } } = setmetatable({}, { __mode = "k" }) :: any
-- Mana actually paid (health may pay part of it) and the blood-magic part of the cost line.
local function castCost(definition: any): (number, string?)
	local cached = costCache[definition]
	if cached then
		return cached.Mana, cached.Health
	end
	local ok, mana, health = pcall(function()
		local Spec = require(Shared.Modules.SpellSpec)
		local BloodCostSpec = require(Shared.Modules.MagicBloodCostSpec)
		local estimate = Spec.estimate(definition)
		return estimate.ManaPaid or estimate.ManaDemand,
			string.match(BloodCostSpec.costLabel(estimate), "^.- mana %+ (.+)$")
	end)
	local value = {
		Mana = if ok and type(mana) == "number" then mana else 0,
		Health = if ok and type(health) == "string" then health else nil,
	}
	costCache[definition] = value
	return value.Mana, value.Health
end

local function describe(definition: any): SlotInfo?
	if type(definition) ~= "table" then
		return nil
	end
	local visual = definition.Visual
	local mana, health = castCost(definition)
	return {
		Name = tostring(definition.Name or "Spell"),
		Element = definition.Element,
		Color = if visual and typeof(visual.Color) == "Color3" then visual.Color else nil,
		ManaCost = mana,
		HealthCost = health,
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
			-- A recast is free and starts no cooldown (MagicRecastSpec).
			if
				type(message) ~= "table"
				or message.Kind ~= "Magic"
				or message.Result == "IMPOSSIBLE"
				or message.Result == "RECAST"
			then
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
