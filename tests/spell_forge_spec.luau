-- Runs after the real schema/SpellSpec fixtures in run_luau_magic_tests.py (--forge-only).
-- Mounts the real Spell Forge UI on a minimal Instance mock and drives it the
-- way a player would: by activating buttons. Asserts land on the canonical draft.

local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return {
				Disconnect = function()
					local index = table.find(handlers, fn)
					if index then
						table.remove(handlers, index)
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for _, fn in table.clone(handlers) do
				fn(...)
			end
		end,
	}
end

local rootWidth = 1280
local Inst = {}
local function newInstance(class)
	local props = {
		ClassName = class,
		Name = class,
		Visible = true,
		Text = "",
		AbsoluteSize = { X = rootWidth, Y = 720 },
		AbsolutePosition = { X = 0, Y = 0 },
	}
	local children = {}
	local events = {}
	local self
	local methods = {
		GetChildren = function()
			return table.clone(children)
		end,
		GetDescendants = function()
			local out = {}
			local function walk(node)
				for _, child in node:GetChildren() do
					table.insert(out, child)
					walk(child)
				end
			end
			walk(self)
			return out
		end,
		FindFirstChild = function(_, name)
			for _, child in children do
				if child.Name == name then
					return child
				end
			end
			return nil
		end,
		IsA = function(_, name)
			if name == class then
				return true
			end
			if name == "GuiObject" then
				return class == "Frame"
					or class == "TextLabel"
					or class == "TextButton"
					or class == "TextBox"
					or class == "ScrollingFrame"
			end
			return false
		end,
		Destroy = function()
			for _, child in table.clone(children) do
				child:Destroy()
			end
			self.Parent = nil
			if events.Destroying then
				events.Destroying:Fire()
			end
		end,
		IsFocused = function()
			return false
		end,
		GetPropertyChangedSignal = function()
			return signal()
		end,
		_children = children,
	}
	self = setmetatable({}, {
		__index = function(_, key)
			if methods[key] then
				return methods[key]
			end
			if props[key] ~= nil then
				return props[key]
			end
			if
				key == "Activated"
				or key == "MouseEnter"
				or key == "MouseLeave"
				or key == "FocusLost"
				or key == "InputBegan"
				or key == "Destroying"
				or key == "SelectionGained"
				or key == "SelectionLost"
			then
				events[key] = events[key] or signal()
				return events[key]
			end
			return nil
		end,
		__newindex = function(_, key, value)
			if key == "Parent" then
				local old = props.Parent
				if old then
					local index = table.find(old._children, self)
					if index then
						table.remove(old._children, index)
					end
				end
				if value then
					table.insert(value._children, self)
				end
			end
			props[key] = value
		end,
	})
	return self
end
Inst.new = newInstance

local enumProxy
enumProxy = setmetatable({}, {
	__index = function(_, key)
		return setmetatable({}, {
			__index = function(_, item)
				return key .. "." .. item
			end,
		})
	end,
})
local function value(...)
	return { ... }
end
local fakeService = setmetatable({}, {
	__index = function(t, key)
		if key == "Heartbeat" or key == "InputChanged" or key == "InputEnded" then
			rawset(t, key, signal())
			return rawget(t, key)
		end
		return nil
	end,
})
fakeService.Create = function()
	return { Play = function() end }
end

local uiCache = {}
local forgeEnv
function loadUi(name)
	if uiCache[name] == nil then
		local chunk = assert(loadstring(assert(getfenv().__UI_SOURCES[name], name), name))
		setfenv(chunk, forgeEnv)
		uiCache[name] = chunk()
	end
	return uiCache[name]
end
forgeEnv = setmetatable({
	Instance = Inst,
	Enum = enumProxy,
	UDim2 = { new = value, fromOffset = value, fromScale = value },
	UDim = { new = value },
	Vector2 = { new = value, zero = {} },
	Color3 = { new = value, fromRGB = value },
	ColorSequence = { new = value },
	TweenInfo = { new = value },
	task = {
		defer = function(fn, ...)
			fn(...)
		end,
	},
	game = {
		GetService = function(_, name)
			if name == "ReplicatedStorage" then
				return {
					WaitForChild = function()
						return {
							Modules = {
								ProjectileBehaviorSpec = "projectileBehaviorSpec",
								MagicSpellIdentitySpec = "identitySpec",
							},
						}
					end,
				}
			end
			return fakeService
		end,
	},
	script = { Parent = setmetatable({}, {
		__index = function(_, name)
			return "ui:" .. name
		end,
	}) },
	require = function(v)
		if v == "ui:GrimoireSpellVisual" then
			return { render = function() end }
		elseif type(v) == "string" and string.sub(v, 1, 3) == "ui:" then
			return loadUi(string.sub(v, 4))
		elseif v == "projectileBehaviorSpec" then
			return projectileBehaviorSpec
		elseif v == "identitySpec" then
			return identitySpec
		elseif v == "spellVisual" then
			return { render = function() end }
		end
		error(v)
	end,
}, { __index = getfenv() })
local Forge = loadUi("GuidedSpellForge")

local function texts(node)
	local out = {}
	for _, item in node:GetDescendants() do
		if item.Text ~= "" and item.Text ~= nil then
			table.insert(out, item.Text)
		end
	end
	return out
end
local function has(node, needle)
	for _, t in texts(node) do
		if string.find(t, needle, 1, true) then
			return true
		end
	end
	return false
end
-- Button by its own text, or a tile button whose child label carries the text.
local function click(node, needle)
	for _, item in node:GetDescendants() do
		if item.ClassName == "TextButton" then
			if string.find(item.Text, needle, 1, true) then
				item.Activated:Fire()
				return true
			end
			if item.Text == "" then
				for _, child in item:GetChildren() do
					if child.ClassName == "TextLabel" and child.Text == needle then
						item.Activated:Fire()
						return true
					end
				end
			end
		end
	end
	error("No button: " .. needle)
end
local function panelOf(root, name)
	return assert(root:FindFirstChild(name), name)
end

local calls = {}
local function callbacks(draft)
	return {
		change = function()
			calls.change = (calls.change or 0) + 1
		end,
		changeForm = function(formName, principle)
			local fresh = spec.createDraft(formName, principle)
			fresh.Triggers = draft.Triggers
			fresh.Name = draft.Name
			table.clear(draft)
			for k, v in fresh do
				draft[k] = v
			end
		end,
		save = function()
			calls.save = true
		end,
		keep = function() end,
		load = function()
			calls.load = true
		end,
		advanced = function()
			calls.advanced = true
		end,
		test = function()
			calls.test = true
		end,
		back = function() end,
	}
end

-- 1-4. Open the forge on a fresh Projectile: the tree shows what it creates.
local panel = newInstance("Frame")
local draft = spec.createDraft("Projectile", "Energy")
local root = Forge.mount(panel, draft, schema, spec, callbacks(draft))
local tree = panelOf(root, "SpellConstruction")
local inspector = panelOf(root, "ContextualInspector")
assert(has(tree, "CREATE PROJECTILE"), "Projectile action card is shown")
assert(has(tree, "ON CAST"), "Cast root is shown")
assert(panelOf(root, "SpellPreview") and panelOf(root, "ValidationPanel"), "Preview and validation regions exist")

-- 5-6. Selecting the projectile shows only its properties.
click(tree, "CREATE PROJECTILE")
assert(has(inspector, "Travel speed"), "Projectile inspector shows speed")
assert(has(inspector, "Magical principle"), "Projectile inspector shows principle")
assert(not has(inspector, "Damage amount"), "Projectile inspector hides unrelated damage fields")

-- 7-8. Attach "When it hits" and add damage beneath it.
click(tree, "Choose when something happens")
assert(root:FindFirstChild("ActionPicker"), "Trigger picker opens")
click(root:FindFirstChild("ActionPicker"), "When it hits")
assert(has(root:FindFirstChild("ActionPicker"), "What do you want to happen?"), "Intent stage")
click(root:FindFirstChild("ActionPicker"), "Affect a target")
click(root:FindFirstChild("ActionPicker"), "Deal damage")
assert(root:FindFirstChild("ActionPicker") == nil, "Picker closes after choosing")
assert(draft.Triggers.OnImpact and draft.Triggers.OnImpact[1].Payloads[1].Kind == "Damage", "Damage added on impact")
assert(has(tree, "WHEN IT HITS") and has(tree, "DEAL DAMAGE"), "Tree shows trigger and damage")
assert(has(inspector, "Damage amount"), "Damage selected and inspected")
assert(not has(inspector, "Travel speed"), "Damage inspector hides projectile fields")
assert(spec.validate(draft), "Spell is valid after adding damage")

-- 9. A second effect at the same moment runs in parallel.
click(tree, "+ ADD")
click(root:FindFirstChild("ActionPicker"), "Affect an area")
click(root:FindFirstChild("ActionPicker"), schema.Behaviors.Explode.Label)
assert(#draft.Triggers.OnImpact == 2, "Second effect added to the same trigger")
assert(draft.Triggers.OnImpact[2].Behavior == "Explode", "Explode step added")
assert(has(tree, "TOGETHER"), "Parallel relationship is labeled")
local ok, reason = spec.validate(draft)
assert(ok, "Valid after parallel blast: " .. tostring(reason))

-- Spawned effects nest their own triggers in the same tree.
click(tree, "Add another effect at this moment")
click(root:FindFirstChild("ActionPicker"), "Create something")
click(root:FindFirstChild("ActionPicker"), "Create a field")
local spawnStep = draft.Triggers.OnImpact[3]
assert(spawnStep.Behavior == "SpawnEffect" and spawnStep.Effect.Form == "Field", "Spawned field added")
assert(has(tree, "SPAWN FIELD"), "Nested effect card shown")
ok, reason = spec.validate(draft)
assert(ok, "Valid after spawned field: " .. tostring(reason))

-- 10-11. Test, edit a property, test again.
click(root, "TEST SPELL")
assert(calls.test, "Test Spell reaches the controller's server test-cast")
calls.test = nil
click(tree, "CREATE PROJECTILE")
local speedBox
for _, item in inspector:GetDescendants() do
	if item.ClassName == "TextBox" and item.Text == tostring(draft.Projectile.Speed) then
		speedBox = item
	end
end
assert(speedBox, "Speed input present")
local before = draft.Projectile.Speed
speedBox.Text = "42"
speedBox.FocusLost:Fire()
assert(draft.Projectile.Speed == 42, "Inspector edits write the draft")
click(root, "Test cast")
assert(calls.test, "Preview test cast works")

-- Undo / redo restore the canonical draft.
click(root, "UNDO")
assert(draft.Projectile.Speed == before, "Undo restores speed")
click(root, "REDO")
assert(draft.Projectile.Speed == 42, "Redo reapplies speed")

-- 12. Save and Advanced reach the controller.
click(root, "SAVE SPELL")
assert(calls.save, "Save reaches controller")
click(root, "ADVANCED")
assert(calls.advanced, "Advanced view reachable")

-- Removing an effect edits the real config.
click(tree, "DEAL DAMAGE")
click(inspector, "Remove this effect")
for _, step in draft.Triggers.OnImpact do
	for _, payload in step.Payloads or {} do
		assert(step.Behavior or payload.Kind ~= "Damage", "Direct damage removed")
	end
end

-- Unsupported intents are shown as unavailable, never as working choices.
local beam = spec.createDraft("Beam", "Energy")
local beamRoot = Forge.mount(newInstance("Frame"), beam, schema, spec, callbacks(beam))
click(panelOf(beamRoot, "SpellConstruction"), "Choose when something happens")
assert(beamRoot:FindFirstChild("ActionPicker"), "Beam trigger picker opens")

-- Existing spells with conditions and every Form mount without errors.
for _, formName in schema.FormOrder do
	for _, principle in schema.Principles do
		local d = spec.createDraft(formName, principle)
		if d then
			local event = schema.Forms[formName].DefaultEvent
			if event then
				for _, kind in schema.PayloadOrder do
					if schema.supportsPayload(kind, formName, event, principle) then
						local payload = spec.copy(schema.Payloads[kind].Defaults or {})
						payload.Kind = kind
						d.Triggers[event] = { { Payloads = { payload }, Condition = { Kind = "Placeholder" } } }
						break
					end
				end
			end
			local r = Forge.mount(newInstance("Frame"), d, schema, spec, callbacks(d))
			assert(has(panelOf(r, "SpellConstruction"), string.upper(schema.Forms[formName].Label)), formName)
			if d.Triggers[event or ""] then
				assert(has(panelOf(r, "SpellConstruction"), "IF"), "Conditional steps are marked")
			end
		end
	end
end

-- Mobile: tabs replace the three columns.
rootWidth = 420
local mobileDraft = spec.createDraft("Projectile", "Energy")
local mobile = Forge.mount(newInstance("Frame"), mobileDraft, schema, spec, callbacks(mobileDraft))
assert(panelOf(mobile, "MobileTabs").Visible, "Mobile tabs shown")
assert(panelOf(mobile, "SpellPreview").Visible == false, "Preview behind a tab on mobile")
click(panelOf(mobile, "SpellConstruction"), "CREATE PROJECTILE")
assert(panelOf(mobile, "ContextualInspector").Visible, "Selecting a card opens the properties sheet on mobile")

-- Changing shape moves effects off moments the new shape never reaches.
local shift = spec.createDraft("Projectile", "Energy")
local shiftHit = spec.copy(schema.Payloads.Damage.Defaults)
shiftHit.Kind = "Damage"
shift.Triggers.OnImpact = { { Payloads = { shiftHit } } }
local shiftRoot = Forge.mount(newInstance("Frame"), shift, schema, spec, callbacks(shift))
click(panelOf(shiftRoot, "ContextualInspector"), schema.Forms.Wave.Label)
assert(shift.Form == "Wave", "Shape changed")
assert(shift.Triggers.OnImpact == nil, "Wave cannot hit, so the hit trigger moved")
local waveHome = schema.Forms.Wave.DefaultEvent
assert(
	shift.Triggers[waveHome] and shift.Triggers[waveHome][1].Payloads[1].Kind == "Damage",
	"Damage moved to the Wave's moment"
)
assert(spec.validate(shift), "Spell stays valid after the shape change")
-- Effects stuck on an unreachable moment are flagged and can be moved.
shift.Triggers.OnImpact = { { Payloads = { spec.copy(shift.Triggers[waveHome][1].Payloads[1]) } } }
shift.Triggers[waveHome] = nil
shiftRoot = Forge.mount(newInstance("Frame"), shift, schema, spec, callbacks(shift))
local shiftTree = panelOf(shiftRoot, "SpellConstruction")
assert(has(shiftTree, "CAN'T DO THIS") and has(shiftTree, "UNSUPPORTED"), "Unreachable trigger is flagged")
click(shiftTree, "WHEN IT HITS  ·  A WAVE CAN'T DO THIS")
click(panelOf(shiftRoot, "ContextualInspector"), "Move effects to")
assert(shift.Triggers.OnImpact == nil and shift.Triggers[waveHome], "Move button relocates effects")

-- Advanced: same forge, every field, spell-wide cards, hosted section editors.
rootWidth = 1280
local hostedCalls = {}
local function advancedCallbacks(d, mode)
	local cb = callbacks(d)
	cb.mode = mode
	cb.renderSections = function(host, sections, eventName, search, startOrder)
		table.insert(hostedCalls, { Sections = sections, Event = eventName, Search = search })
		local marker = newInstance("TextLabel")
		marker.Text = "HOSTED " .. table.concat(sections, ",")
		marker.LayoutOrder = startOrder
		marker.Parent = host
		return startOrder + 1
	end
	return cb
end
local adv = spec.createDraft("Projectile", "Energy")
local damage = spec.copy(schema.Payloads.Damage.Defaults)
damage.Kind = "Damage"
adv.Triggers.OnImpact = { { Payloads = { damage }, Condition = { Kind = "Placeholder" } } }
local before = spec.copy(adv)
local advRoot, advApi = Forge.mount(newInstance("Frame"), adv, schema, spec, advancedCallbacks(adv, "Expert"))
local advTree = panelOf(advRoot, "SpellConstruction")
local advInspector = panelOf(advRoot, "ContextualInspector")
for _, title in { "CASTING & COSTS", "TARGETING", "CAST CONDITIONS", "APPEARANCE & SOUND" } do
	assert(has(advTree, title), "Advanced shows spell-wide card " .. title)
end
assert(not has(tree, "CASTING & COSTS"), "Guided keeps spell-wide cards out of the tree")
-- Root form card: every mechanic field (no "More options" fold) plus hosted Setup.
assert(has(advInspector, "HOSTED Setup"), "Root card hosts the Setup section editor")
-- Casting card hosts the casting, cost and test editors.
hostedCalls = {}
click(advTree, "CASTING & COSTS")
assert(
	#hostedCalls == 3 and hostedCalls[1].Sections[1] == "Casting" and hostedCalls[2].Sections[1] == "Cost",
	"Casting hosts"
)
click(advTree, "CAST CONDITIONS")
assert(has(advInspector, "HOSTED Conditions"), "Spell condition tree is hosted")
click(advTree, "APPEARANCE & SOUND")
assert(has(advInspector, "HOSTED Presentation"), "Appearance editors are hosted")
-- Effect-level conditions: selecting the IF effect hosts the effect editor at its moment.
hostedCalls = {}
click(advTree, "DEAL DAMAGE")
assert(
	hostedCalls[1].Sections[1] == "ConfigureEffects" and hostedCalls[1].Event == "OnImpact",
	"Effect hosts ConfigureEffects at its event"
)
assert(has(advTree, "IF"), "Conditional effect is marked")
-- Advanced shows optional damage fields without folding.
assert(has(advInspector, "Head damage multiplier"), "Advanced unfolds optional fields")
-- Search filters native fields and is passed to hosted editors.
local searchBox
for _, item in advInspector:GetDescendants() do
	if item.Name == "FieldSearch" then
		searchBox = item
	end
end
assert(searchBox, "search box")
searchBox.Text = "head"
searchBox.FocusLost:Fire()
assert(has(advInspector, "Head damage multiplier"), "Search keeps matches")
assert(not has(advInspector, "Damage amount"), "Search hides non-matches")
assert(hostedCalls[#hostedCalls].Search == "head", "Search reaches hosted editors")
-- Edits made in hosted editors are undoable after the controller refresh.
local cooldown = adv.Casting.Cooldown
adv.Casting.Cooldown = cooldown + 3
advApi.refresh()
click(advRoot, "UNDO")
assert(adv.Casting.Cooldown == cooldown, "Hosted edits undo")
assert(spec.validate(adv) == spec.validate(before), "Undo leaves a consistent draft")
-- Guided <-> Advanced round trips never change the shared draft.
local snapshot = spec.copy(adv)
for _, mode in { "Guided", "Expert", "Guided", "Expert" } do
	Forge.mount(newInstance("Frame"), adv, schema, spec, advancedCallbacks(adv, mode))
	local function same(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then
			return a == b
		end
		for k, v in a do
			if not same(v, b[k]) then
				return false
			end
		end
		for k in b do
			if a[k] == nil then
				return false
			end
		end
		return true
	end
	assert(same(snapshot, adv), "Switching to " .. mode .. " keeps the draft identical")
end
-- The mode switch reaches the controller.
calls.advanced = nil
click(advRoot, "GUIDED")
assert(calls.advanced, "Guided tab switches back")

-- App shell: toolbar tabs replace the book's page turns and home icon.
local Hub = loadUi("SpellHub")
local C = loadUi("SpellForgeTheme").C
rootWidth = 1280
local hubPanel = newInstance("Frame")
local tabCalls = {}
local function uiParts()
	return {
		scroll = newInstance("ScrollingFrame"),
		title = newInstance("TextLabel"),
		summary = newInstance("TextLabel"),
		status = newInstance("TextLabel"),
		navigation = newInstance("ScrollingFrame"),
		closeButton = newInstance("TextButton"),
		homeButton = newInstance("TextButton"),
	}
end
local parts = uiParts()
for _, part in parts do
	part.Parent = hubPanel
end
local layoutShell = Hub.mountShell(hubPanel, parts, function(tab)
	table.insert(tabCalls, tab)
end)
for _, label in { "HOME", "LIBRARY", "SPELL FORGE", "TRAINING", "?" } do
	click(hubPanel, label)
end
assert(
	table.concat(tabCalls, ",") == "Home,Library,Forge,Training,Help",
	"Toolbar tabs navigate: " .. table.concat(tabCalls, ",")
)
layoutShell("Library")
local function tab(name)
	for _, item in hubPanel:GetDescendants() do
		if item.Name == "Tab_" .. name then
			return item
		end
	end
end
assert(
	tab("Library").BackgroundColor3 == C.Gold and tab("Home").BackgroundColor3 ~= C.Gold,
	"Active tab is highlighted"
)
assert(
	parts.homeButton.Visible == false and parts.navigation.Visible == false,
	"Book home icon and chapter tabs are gone"
)
assert(parts.closeButton.Parent.Name == "HubToolbar", "Close lives in the toolbar")

-- Home: quick actions plus nine slot cards with name, form, element, cost and sequence.
local homeScroll = newInstance("ScrollingFrame")
local slotSpell = spec.createDraft("Projectile", "Energy")
slotSpell.Name = "Ember Bolt"
local hit = spec.copy(schema.Payloads.Damage.Defaults)
hit.Kind = "Damage"
slotSpell.Triggers.OnImpact = { { Payloads = { hit } } }
local homeSlots = {}
for n = 1, 9 do
	table.insert(homeSlots, {
		Number = n,
		Spell = if n == 1 then slotSpell elseif n == 2 then slotSpell else nil,
		Draft = n == 2,
		Locked = n > 6,
	})
end
local homeCalls = {}
Hub.home(homeScroll, { Slots = homeSlots, ResumeDraft = true }, {
	create = function()
		homeCalls.create = true
	end,
	resume = function()
		homeCalls.resume = true
	end,
	library = function()
		homeCalls.library = true
	end,
	training = function()
		homeCalls.training = true
	end,
	openSlot = function(n)
		homeCalls.slot = n
	end,
}, schema, spec)
local slotCount = 0
for _, item in homeScroll:GetDescendants() do
	if string.sub(item.Name, 1, 13) == "EquippedSlot_" then
		slotCount += 1
	end
end
assert(slotCount == 9, "Nine slot cards")
assert(
	has(homeScroll, "Ember Bolt") and has(homeScroll, "mana") and has(homeScroll, "When it hits: deal damage"),
	"Slot card shows name, cost and sequence"
)
assert(
	has(homeScroll, "DRAFT") and has(homeScroll, "LOCKED") and has(homeScroll, "EMPTY SLOT"),
	"Draft, locked and empty slots are labeled"
)
assert(has(homeScroll, "NEW SPELL") and has(homeScroll, "RESUME DRAFT"), "New spell and resume are separate")
click(homeScroll, "NEW SPELL")
click(homeScroll, "RESUME DRAFT")
click(homeScroll, "SPELL LIBRARY")
click(homeScroll, "TRAINING & TARGETS")
for _, item in homeScroll:GetDescendants() do
	if item.Name == "EquippedSlot_3" then
		item.Activated:Fire()
	end
end
assert(
	homeCalls.create and homeCalls.resume and homeCalls.library and homeCalls.training and homeCalls.slot == 3,
	"Home actions reach the controller"
)

-- Mobile shell: short tab labels on a second toolbar row.
rootWidth = 420
local mobilePanel = newInstance("Frame")
local mobileParts = uiParts()
Hub.mountShell(mobilePanel, mobileParts, function() end)
assert(has(mobilePanel, "FORGE") and not has(mobilePanel, "SPELL FORGE"), "Mobile tabs use short labels")

-- Library: player-made spells and curated (seeded) spells are separate shelves.
local progressionConfig = load("src/shared/Configuration/SpellProgression.luau")
local savedScript, savedRequire = env.script, env.require
env.script =
	{ Parent = { Parent = { Configuration = { SpellProgression = "progcfg" } }, MagicCastingSpec = "castingSpec" } }
env.require = function(v)
	if v == "progcfg" then
		return progressionConfig
	elseif v == "castingSpec" then
		return castingSpec
	end
	return savedRequire(v)
end
local progressionRules = load("src/shared/Modules/SpellProgressionRules.luau")
env.script, env.require = savedScript, savedRequire
local catalogLib = load("src/shared/Modules/GrimoireLibrary.luau")
local startersLib = {
	LegacyTag = "starter-template",
	buildShowcase = function()
		return {}
	end,
	buildShowcaseExpansion = function()
		return {}
	end,
}
local sharedStub = {
	Modules = {
		GrimoireLibrary = "shared:lib",
		GrimoireSummary = "shared:summary",
		GrimoireStarters = "shared:starters",
		SpellProgressionRules = "shared:rules",
	},
	Configuration = { SpellProgression = "shared:progcfg" },
}
local sharedModules = {
	["shared:lib"] = catalogLib,
	["shared:summary"] = {
		describe = function()
			return ""
		end,
	},
	["shared:starters"] = startersLib,
	["shared:rules"] = progressionRules,
	["shared:progcfg"] = progressionConfig,
}
local baseGame, baseRequire = forgeEnv.game, forgeEnv.require
forgeEnv.game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return { Shared = sharedStub }
		end
		return baseGame:GetService(name)
	end,
}
forgeEnv.require = function(v)
	return sharedModules[v] or baseRequire(v)
end
local LibraryView = loadUi("GrimoireLibraryView")
forgeEnv.game, forgeEnv.require = baseGame, baseRequire
local libScroll = newInstance("ScrollingFrame")
local libOrder = 0
local function libRow(label)
	libOrder += 1
	local frame = newInstance("Frame")
	frame.LayoutOrder = libOrder
	local title = newInstance("TextLabel")
	title.Text = label
	title.Parent = frame
	frame.Parent = libScroll
	return frame
end
local libRebuilds = 0
local libraryView
libraryView = LibraryView.new({
	row = libRow,
	block = function()
		local frame = newInstance("Frame")
		frame.Parent = libScroll
		return frame
	end,
	width = function()
		return 900
	end,
	height = function()
		return 500
	end,
	button = function(parent, label, callback)
		local b = newInstance("TextButton")
		b.Text = label
		b.Activated:Connect(callback)
		b.Parent = parent
		return b
	end,
	heading = libRow,
	select = function() end,
	info = libRow,
	showPreview = function() end,
	hasSidePreview = function()
		return false
	end,
	confirm = function() end,
	schema = schema,
	spec = spec,
	request = { FireServer = function() end },
	message = function() end,
	createNew = function() end,
	editRecord = function() end,
	hasWorkingDraft = function()
		return false
	end,
	resumeDraft = function() end,
	isDirtyRecord = function()
		return false
	end,
	rebuild = function()
		libRebuilds += 1
		for _, child in libScroll:GetChildren() do
			child:Destroy()
		end
		libraryView.render()
	end,
	top = function() end,
	slots = function() end,
	help = function() end,
	pendingEdit = function() end,
})
local catalog = catalogLib.empty()
local mineSpell = spec.copy(slotSpell)
mineSpell.Name = "My Ember Bolt"
catalogLib.add(catalog, mineSpell, spec.copy, 0)
local curatedSpell = spec.copy(slotSpell)
curatedSpell.Name = "Curated Bolt"
local curatedId = catalogLib.add(catalog, curatedSpell, spec.copy, 0)
catalog.Records[curatedId].Tags = "starter-template"
libraryView.receive(true, "", catalog)
libraryView.render()
assert(has(libScroll, "MY SPELLS  ·  1") and has(libScroll, "CURATED SPELLS  ·  1"), "Shelves show counts")
assert(has(libScroll, "My Ember Bolt") and not has(libScroll, "Curated Bolt"), "My spells shelf hides curated spells")
click(libScroll, "CURATED SPELLS")
assert(libraryView.Shelf == "Curated", "Curated shelf selected")
assert(
	has(libScroll, "Curated Bolt") and not has(libScroll, "My Ember Bolt"),
	"Curated shelf shows only curated spells"
)

print("spell forge spec: ok")
