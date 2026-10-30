--!strict
-- Development spell library editor. Slot persistence is server-owned; casts stay authoritative.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Configuration.MagicLab)
local Spec = require(Shared.Modules.SpellSpec)
local VisualAssets = require(Shared.Configuration.MagicVisualAssets)
local Schema = require(Shared.Configuration.MagicSchema)
local Geometry = require(Shared.Modules.MagicGeometry)
local ProjectileBehaviorSpec = require(Shared.Modules.ProjectileBehaviorSpec)
local ConditionSpec = require(Shared.Modules.MagicConditionSpec)
local ConditionTree = require(Shared.Modules.MagicConditionTree)
local LifetimeSpec = require(Shared.Modules.MagicLifetimeSpec)
local ScaleSpec = require(Shared.Modules.MagicScaleSpec)
local AttributeSpec = require(Shared.Modules.MagicAttributeSpec)
local CastingSpec = require(Shared.Modules.MagicCastingSpec)
local MaterialSpec = require(Shared.Modules.MagicMaterialSpec)
local ConstructGeometrySpec = require(Shared.Modules.MagicConstructGeometrySpec)
local SpecialResourceSpec = require(Shared.Modules.MagicSpecialResourceSpec)
local SpecialResourceDefinitions = require(Shared.Configuration.MagicLocus).SpecialResources
local EnvironmentRequirementSpec = require(Shared.Modules.MagicEnvironmentRequirementSpec)
local SpellIdentitySpec = require(Shared.Modules.MagicSpellIdentitySpec)
local SpellTargetSpec = require(Shared.Modules.MagicSpellTargetSpec)
local BloodCostSpec = require(Shared.Modules.MagicBloodCostSpec)
local GamepadNav = require(script.Parent.Parent.UI.Kit.GamepadNav)
local InputMode = require(script.Parent.Parent.UI.Kit.InputMode)
local Responsive = require(script.Parent.Parent.UI.Kit.Responsive)
local Tokens = require(script.Parent.Parent.UI.Kit.Tokens)
local GeometryPreview = require(script.Parent.GrimoireGeometryPreview)
local ConditionTreeEditor = require(script.Parent.GrimoireConditionTreeEditor)
local VisualSpec = require(Shared.Modules.MagicVisualSpec)
local CompanionSpellPolicy = require(Shared.Modules.MagicCompanionSpellPolicy)
local Protocol = require(Shared.Networking.Protocol)
local Elements = require(Shared.Configuration.MagicElements)
local Slots = require(Shared.Modules.MagicSlots)
local ProgressionRules = require(Shared.Modules.SpellProgressionRules)
local DevelopmentSandbox = require(Shared.Configuration.DevelopmentSandbox)
local Camera = require(script.Parent.CameraController)
ConditionSpec.configureSpecialResources(SpecialResourceDefinitions)
-- Every spell screen uses the Spell Forge palette and components.
local Theme = require(script.Parent.Parent.UI.SpellForgeTheme).Book
local K = require(script.Parent.Parent.UI.SpellForgeComponents)
local Hub = require(script.Parent.Parent.UI.SpellHub)
-- True while Advanced section editors draw into the forge inspector.
local forgeHosted = false
local SpellVisual = require(script.Parent.Parent.UI.GrimoireSpellVisual)
local VFXAnalyzer = require(Shared.SpellVFXSystem.Core.SpellVFXAnalyzer)
local VFXComposer = require(Shared.SpellVFXSystem.Core.SpellVFXComposer)
local LibraryView = require(script.Parent.Parent.UI.GrimoireLibraryView)
local Summary = require(Shared.Modules.GrimoireSummary)
local ActionFlow = require(Shared.Modules.MagicActionFlow)
local GuidedForge = require(script.Parent.Parent.UI.GuidedSpellForge)
local Lab = {}
local function ensureVisualDefaults(definition)
	definition.Visual = definition.Visual or {}
	for key, value in VisualSpec.Defaults do
		if definition.Visual[key] == nil then
			definition.Visual[key] = value
		end
	end
end
local function visualMaterial(definition)
	local name = definition.Visual.MaterialAppearance
	if not name or name == "Auto" then
		name = VisualSpec.autoMaterial(definition.Source.Principle, definition.Source.Expression, definition.Form)
	end
	return Enum.Material[name] or Enum.Material.Neon
end
function Lab.start(send, aim, launcher)
	if not Config.Enabled or not (RunService:IsStudio() or (not Config.StudioOnly and Config.AllowLive)) then
		return
	end
	launcher = launcher or require(script.Parent.GrimoireLauncher).start()
	local player = Players.LocalPlayer
	local remotes = Shared:WaitForChild(Protocol.Folder, 15)
	assert(remotes, "Action remotes did not start within 15 seconds")
	local request = remotes:WaitForChild("MagicLabRequest", 15)
	assert(request, "Grimoire editor remote did not start within 15 seconds")
	local response = remotes:WaitForChild("MagicLabResponse", 15)
	assert(response, "Grimoire response remote did not start within 15 seconds")
	local trainingRequest = remotes:WaitForChild("TrainingDummyRequest", 15) :: RemoteEvent?
	assert(trainingRequest, "Training dummy remote did not start within 15 seconds")
	local trainingResponse = remotes:WaitForChild("TrainingDummyResponse", 15) :: RemoteEvent?
	assert(trainingResponse, "Training response remote did not start within 15 seconds")
	-- Validate every response event before building the editor. Waiting for these
	-- events later in the 5,000-line UI setup could leave the launcher stuck in
	-- its connecting state forever if a server bootstrap regresses.
	local grimoireResponse = remotes:WaitForChild("GrimoireResponse", 15)
	assert(
		grimoireResponse and grimoireResponse:IsA("RemoteEvent"),
		"Grimoire library response remote did not start within 15 seconds"
	)
	local actionFeedback = remotes:WaitForChild(Protocol.Feedback, 15)
	assert(
		actionFeedback and actionFeedback:IsA("RemoteEvent"),
		"Action feedback remote did not start within 15 seconds"
	)
	local consentAttribute = "MagicAcceptsTargetedSpells"
	local consentEnabled = player:GetAttribute(consentAttribute) == true
	player:GetAttributeChangedSignal(consentAttribute):Connect(function()
		consentEnabled = player:GetAttribute(consentAttribute) == true
	end)
	local gui = Instance.new("ScreenGui")
	local heldAimSlot: number? = nil
	local aimUpdateElapsed = 0
	gui.Name = "MagicLab"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 80
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")
	-- Roblox switches to its pointing-hand cursor over GuiButtons. Keep the
	-- grimoire's pointer visually steady by drawing one cursor above the UI.
	local cursorGui = Instance.new("ScreenGui")
	cursorGui.Name = "GrimoireStableCursor"
	cursorGui.ResetOnSpawn = false
	cursorGui.IgnoreGuiInset = true
	cursorGui.DisplayOrder = 200
	cursorGui.Parent = player.PlayerGui
	local cursor = Instance.new("TextLabel")
	cursor.Name = "Pointer"
	cursor.AnchorPoint = Vector2.new(0.15, 0.12)
	cursor.Size = UDim2.fromOffset(24, 24)
	cursor.BackgroundTransparency = 1
	cursor.Font = Enum.Font.GothamBold
	cursor.Text = "↖"
	cursor.TextSize = 21
	cursor.TextColor3 = Theme.Gold
	cursor.TextStrokeColor3 = Theme.Ink
	cursor.TextStrokeTransparency = 0.1
	cursor.ZIndex = 100
	cursor.Visible = false
	cursor.Parent = cursorGui
	RunService.RenderStepped:Connect(function()
		if cursor.Visible then
			local mouse = UIS:GetMouseLocation()
			cursor.Position = UDim2.fromOffset(mouse.X, mouse.Y)
		end
	end)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Size = UDim2.new(0.96, 0, 0.96, 0)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.ClipsDescendants = true
	panel.Visible = false
	panel.Parent = gui
	local panelConstraint = Instance.new("UISizeConstraint")
	panelConstraint.MinSize = Vector2.new(0, 0)
	panelConstraint.MaxSize = Vector2.new(1120, 940)
	panelConstraint.Parent = panel
	local headerTitle = Instance.new("TextLabel")
	headerTitle.Size = UDim2.new(1, -72, 0, 28)
	headerTitle.Position = UDim2.fromOffset(18, 9)
	headerTitle.BackgroundTransparency = 1
	headerTitle.Font = Enum.Font.Garamond
	headerTitle.TextSize = 24
	headerTitle.TextColor3 = Theme.Ink
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Parent = panel
	local headerSummary = Instance.new("TextLabel")
	headerSummary.Size = UDim2.new(1, -72, 0, 24)
	headerSummary.Position = UDim2.fromOffset(19, 38)
	headerSummary.BackgroundTransparency = 1
	headerSummary.TextSize = 14
	headerSummary.TextColor3 = Theme.MutedInk
	headerSummary.TextXAlignment = Enum.TextXAlignment.Left
	headerSummary.TextTruncate = Enum.TextTruncate.AtEnd
	headerSummary.Parent = panel
	local navigation = Instance.new("ScrollingFrame")
	navigation.Size = UDim2.new(1, -24, 0, 40)
	navigation.Position = UDim2.fromOffset(12, 68)
	navigation.BackgroundTransparency = 1
	navigation.BorderSizePixel = 0
	navigation.ScrollBarThickness = 3
	navigation.CanvasSize = UDim2.new()
	navigation.ScrollingDirection = Enum.ScrollingDirection.X
	navigation.Parent = panel
	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.fromOffset(34, 30)
	closeButton.Position = UDim2.new(1, -46, 0, 8)
	closeButton.BackgroundColor3 = Theme.Accent
	closeButton.Text = "×"
	closeButton.TextColor3 = Theme.OnAccent
	closeButton.TextSize = 21
	closeButton.Font = Enum.Font.GothamBold
	closeButton.ZIndex = 3
	closeButton.Parent = panel
	local homeButton = Instance.new("TextButton")
	homeButton.Name = "ReturnToGrimoireHome"
	homeButton.Size = UDim2.fromOffset(36, 36)
	homeButton.BackgroundColor3 = Theme.Surface
	homeButton.BorderSizePixel = 0
	homeButton.Text = ""
	homeButton.ZIndex = 20
	homeButton.Visible = false
	homeButton.Parent = panel
	local homeCorner = Instance.new("UICorner")
	homeCorner.CornerRadius = UDim.new(0, 5)
	homeCorner.Parent = homeButton
	local homeEdge = Instance.new("UIStroke")
	homeEdge.Color = Theme.TileEdge
	homeEdge.Thickness = 2
	homeEdge.Parent = homeButton
	local roof = Instance.new("Frame")
	roof.Name = "HouseRoof"
	roof.Position = UDim2.fromOffset(11, 7)
	roof.Size = UDim2.fromOffset(14, 14)
	roof.Rotation = 45
	roof.BackgroundColor3 = Theme.Accent
	roof.BorderSizePixel = 0
	roof.ZIndex = 21
	roof.Parent = homeButton
	local house = Instance.new("Frame")
	house.Name = "HouseBody"
	house.Position = UDim2.fromOffset(8, 15)
	house.Size = UDim2.fromOffset(20, 15)
	house.BackgroundColor3 = Theme.Accent
	house.BorderSizePixel = 0
	house.ZIndex = 22
	house.Parent = homeButton
	local door = Instance.new("Frame")
	door.Name = "HouseDoor"
	door.Position = UDim2.fromOffset(15, 22)
	door.Size = UDim2.fromOffset(6, 8)
	door.BackgroundColor3 = Theme.PageHighlight
	door.BorderSizePixel = 0
	door.ZIndex = 23
	door.Parent = homeButton
	local function positionHomeButton()
		homeButton.Position = if panel.AbsoluteSize.X >= 500 then UDim2.fromOffset(40, 22) else UDim2.fromOffset(12, 14)
	end
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(positionHomeButton)
	positionHomeButton()
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -24, 1, -260)
	scroll.Position = UDim2.fromOffset(12, 116)
	scroll.BackgroundTransparency = 1
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 5)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -24, 0, 58)
	status.Position = UDim2.new(0, 12, 1, -142)
	status.BackgroundTransparency = 1
	status.TextWrapped = true
	status.TextSize = 13
	status.TextColor3 = Theme.Ink
	status.Parent = panel
	local draft = Spec.createDraft("Projectile", "Energy")
	local event = Schema.Forms[draft.Form].DefaultEvent
	local selectedSlot = 1
	local equipped = {}
	local draftsBySlot = {}
	local libraryDrafts = {}
	local standaloneWorkingDraft: any = nil
	local lastLibraryDraftId: string? = nil
	local lastWorkingDraftKind: string? = nil
	local dirtySlots = {}
	local persistenceState = "NOT LOADED"
	local libraryLoaded = false
	local libraryLoading = false
	local pageMode = "Slots"
	local standaloneDraft = false
	local editingLibraryRecord = false
	local editingLibraryId: string? = nil
	local authoringMode = "Guided"
	local selectedStepByEvent = {}
	local expertSearch = ""
	local activeSection = "Setup"
	local visualSubpage = "Composer"
	local visualPage = 1
	local visualStudioFrame: Frame? = nil
	local visualLayoutConnection: RBXScriptConnection? = nil
	local EffectCategoryOrder = { "Damage", "Healing", "Defense", "Control", "Movement", "Summoning", "Utility" }
	local function effectCategory(kind: string): string
		if kind == "Damage" or kind == "DamageOverTime" then
			return "Damage"
		elseif kind == "Heal" or kind == "Restoration" or kind == "Cleanse" then
			return "Healing"
		elseif kind == "Shield" or kind == "ModifyAttribute" or kind == "Enhancement" then
			return "Defense"
		elseif kind == "AerialMovement" then
			return "Movement"
		elseif kind == "Summon" then
			return "Summoning"
		elseif kind == "Reveal" or kind == "Manipulation" or kind == "Transformation" then
			return "Utility"
		end
		return "Control"
	end
	local applyingDraft, applyingSlot
	local function refreshBar()
		-- The persistent launcher owns its own label and lives outside this panel.
	end
	refreshBar()
	local pendingCast = false
	local applying = false
	local dirty = true
	local revision = 0
	local appliedRevision = -1
	local debugGeometry = false
	local drawFolder = Instance.new("Folder")
	drawFolder.Name = "MagicLabLocalPreview"
	drawFolder.Parent = workspace
	local toast = Instance.new("TextLabel")
	toast.Name = "CastFeedback"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.fromScale(0.5, 0.15)
	toast.Size = UDim2.new(0.7, 0, 0, 44)
	toast.BackgroundColor3 = K.C.Panel
	toast.BackgroundTransparency = 0.05
	toast.TextColor3 = Theme.Ink
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 14
	toast.TextWrapped = true
	K.corner(toast, 10)
	K.pad(toast, 14, 6)
	toast.ZIndex = 90
	toast.Visible = false
	toast.Parent = gui
	local toastEdge = Instance.new("UIStroke")
	toastEdge.Color = K.C.Gold
	toastEdge.Thickness = 1
	toastEdge.Transparency = 0.4
	toastEdge.Parent = toast
	local toastUntil = 0
	local toastToken = 0
	local feedbackVisible = true
	local function refreshToast()
		toast.Visible = feedbackVisible and os.clock() < toastUntil
	end
	local function creatorFacingText(text)
		local value = tostring(text)
		local lowered = string.lower(value)
		if
			string.find(lowered, "principle", 1, true)
			or string.find(lowered, "expression", 1, true)
			or string.find(lowered, "source", 1, true)
		then
			return "One or more selected effects or settings conflict with this combination. Remove or adjust an effect, then review again."
		end
		return value
	end
	local function message(text, ok, warning)
		text = creatorFacingText(text)
		status.Text = text
		toast.Text = text
		toastUntil = os.clock() + 3
		toastToken += 1
		local token = toastToken
		refreshToast()
		task.delay(3, function()
			if token == toastToken then
				toast.Visible = false
			end
		end)
		status.TextColor3 = if warning then Theme.Warning elseif ok then Theme.Success else Theme.Error
		toast.TextColor3 = status.TextColor3
	end
	local updateHeader
	local forgeApi = nil
	local editorPreview
	local mobileEditorPreview
	local liveIconPreview
	local function estimate()
		if forgeApi and not forgeHosted then
			task.defer(forgeApi.refresh)
		end
		panel:SetAttribute("SpellSummary", draft.Name .. "\n" .. draft.Form .. "  ·  " .. draft.Element)
		if editorPreview then
			SpellVisual.render(editorPreview, draft, false)
		end
		if mobileEditorPreview then
			SpellVisual.render(mobileEditorPreview, draft, false)
		end
		if liveIconPreview and liveIconPreview.Parent then
			SpellVisual.render(liveIconPreview, draft, true)
		end
		revision += 1
		dirty = true
		if pageMode == "Editor" and standaloneDraft then
			standaloneWorkingDraft = Spec.copy(draft)
			lastWorkingDraftKind = "Standalone"
		elseif pageMode == "Editor" and not editingLibraryRecord then
			draftsBySlot[selectedSlot] = draft
			dirtySlots[selectedSlot] = true
		elseif pageMode == "Editor" and editingLibraryRecord and editingLibraryId then
			libraryDrafts[editingLibraryId] = Spec.copy(draft)
			lastLibraryDraftId = editingLibraryId
			lastWorkingDraftKind = "Library"
		end
		if updateHeader then
			updateHeader()
		end
		local ok, reason = Spec.validate(draft)
		if not ok then
			if reason == "Specify 1–8 payloads across triggers" then
				message("Blank draft ready · choose a compatible effect on the Effects page before equipping.", true)
				return
			end
			message(reason, false)
			return
		end
		local priced = Spec.copy(draft)
		local publicCombat = not (RunService:IsStudio() and DevelopmentSandbox.Enabled)
		local cost = if publicCombat
			then ProgressionRules.reprice(priced, Spec.estimate, Spec.copy)
			else Spec.estimate(draft)
		if publicCombat then
			cost.ManaUpkeepPerSecond = priced.Casting.ManaUpkeepPerSecond or 0
			cost.StrainPerSecond = priced.Casting.StrainPerSecond or 0
		end
		local specialCostLabels = {}
		for _, resourceId in ipairs(SpecialResourceSpec.order(SpecialResourceDefinitions)) do
			local amount = draft.Cost.SpecialResources and draft.Cost.SpecialResources[resourceId]
			if amount and amount > 0 then
				table.insert(specialCostLabels, SpecialResourceDefinitions[resourceId].Label .. " " .. tostring(amount))
			end
		end
		local specialCostText = if #specialCostLabels > 0 then " · " .. table.concat(specialCostLabels, ", ") else ""
		message(
			string.format(
				"ESTIMATE · %s · strain %d · complexity %d · cooldown %.2fs · while active: %g mana/s, %g strain/s%s%s\nServer checks unlocks and spell rank before equipping.",
				BloodCostSpec.costLabel(cost),
				cost.Strain,
				cost.Complexity,
				priced.Casting.Cooldown,
				cost.ManaUpkeepPerSecond,
				cost.StrainPerSecond,
				if (cost.HealthPerSecond or 0) > 0 then ", " .. cost.HealthPerSecond .. " HP/s" else "",
				specialCostText
			),
			true
		)
	end
	local function visibility(open)
		panel.Visible = open
		if open then
			GamepadNav.open(panel, function()
				visibility(false)
			end)
		else
			GamepadNav.close(panel)
		end
		launcher:SetOpen(open)
		player:SetAttribute("MagicLabOpen", open)
		Camera:SetGameplayMouseLookEnabled(not open)
		cursor.Visible = open and UIS.MouseEnabled
		if open then
			UIS.MouseIconEnabled = false
		end
		if open then
			send("Sprint", { Sprinting = false })
			if not libraryLoaded and not libraryLoading then
				libraryLoading = true
				request:FireServer("Load")
			end
		end
	end
	closeButton.Activated:Connect(function()
		visibility(false)
	end)
	local rebuild
	-- Server responses can arrive in bursts or while the lab is closed. Opening
	-- the lab always rebuilds, so hidden updates are skipped and visible ones
	-- are coalesced into a single rebuild on the next resumption point.
	local rebuildQueued = false
	local function requestRebuild()
		if rebuildQueued then
			return
		end
		rebuildQueued = true
		task.defer(function()
			rebuildQueued = false
			if panel.Visible then
				rebuild()
			end
		end)
	end
	local apply
	local cast
	local actions
	local saveLibraryButton
	local saveSlotButton
	local footerButtons = {}
	local pendingLibrarySaveMode: string? = nil
	local pendingStandaloneSave = false
	local order = 0
	local currentGroup
	local cardPairHolder
	local cardPairCount = 0
	local cardPairCards = {}
	local cardPairLayout
	local expandedGroups = {}
	local expandedChoiceKey: string? = nil
	local advancedGroups = {
		["OPTIONAL CASTER REQUIREMENTS"] = true,
		["SPECIAL RESOURCE COSTS"] = true,
		["ENVIRONMENT REQUIREMENTS"] = true,
		["OPTIONAL CAST RULES"] = true,
		["TRIGGER BEHAVIORS"] = true,
		["PROJECTILE TRAVEL BEHAVIORS"] = true,
		["TIMED MOTION PHASES"] = true,
		["ACTIVE PROXIMITY"] = true,
		["SPATIAL AUDIO"] = true,
	}
	local choiceScrollRestoreRevision = 0
	local function rebuildPreservingScroll()
		local previousCanvasPosition = scroll.CanvasPosition
		local restorePageMode, restoreSection, restoreSlot = pageMode, activeSection, selectedSlot
		rebuild()
		choiceScrollRestoreRevision += 1
		local restoreRevision = choiceScrollRestoreRevision
		task.defer(function()
			-- Rebuilding briefly removes the scroll content, so wait for its
			-- automatic canvas size to settle before restoring the position.
			RunService.Heartbeat:Wait()
			if
				restoreRevision == choiceScrollRestoreRevision
				and pageMode == restorePageMode
				and activeSection == restoreSection
				and selectedSlot == restoreSlot
				and scroll.Parent
			then
				scroll.CanvasPosition = previousCanvasPosition
			end
		end)
	end
	local function layoutFooterButtons()
		local visible = {}
		for _, item in ipairs(footerButtons) do
			if item and item.Visible then
				table.insert(visible, item)
			end
		end
		local width = 1 / math.max(1, #visible)
		for index, item in ipairs(visible) do
			item.Size = UDim2.new(width, -4, 1, 0)
			item.Position = UDim2.new((index - 1) * width, 2, 0, 0)
		end
	end
	local libraryView
	local pendingLibraryEdit
	local helpSeen = false
	-- Section helpers. Every screen (Library, Training, Help, and the Advanced
	-- editors hosted in the forge inspector) is drawn with these, so they build
	-- Spell Forge components rather than their own styling.
	local function confirm(text, accept)
		if panel:FindFirstChild("Confirmation") then
			return
		end
		local shade = K.new("TextButton", {
			Name = "Confirmation",
			Size = UDim2.fromScale(1, 1),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			ZIndex = 60,
		}, panel)
		local sheet = K.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.9, 0, 0, 200),
			BackgroundColor3 = K.C.Panel,
			Active = true,
			ZIndex = 61,
		}, shade)
		K.new("UISizeConstraint", { MaxSize = Vector2.new(480, 260) }, sheet)
		K.corner(sheet, 14)
		K.stroke(sheet, K.C.Gold, 1, 0.4)
		K.text(sheet, "CONFIRM", 12, K.C.Gold, Enum.Font.GothamBlack, {
			Position = UDim2.fromOffset(20, 14),
			Size = UDim2.new(1, -40, 0, 18),
			ZIndex = 62,
		})
		K.text(sheet, text, 15, K.C.Ink, Enum.Font.GothamMedium, {
			Position = UDim2.fromOffset(20, 38),
			Size = UDim2.new(1, -40, 1, -110),
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 62,
		})
		for i, caption in { "CANCEL", "CONFIRM" } do
			local b = K.pill(sheet, caption, function()
				shade:Destroy()
				if i == 2 then
					accept()
				end
			end, if i == 2 then "accent" else nil)
			b.Size, b.Position = UDim2.new(0.5, -26, 0, 42), UDim2.new((i - 1) * 0.5, if i == 1 then 20 else 6, 1, -58)
			b.ZIndex = 62
		end
	end
	local function visibleNow(label)
		local groupVisible = not currentGroup
			or expandedGroups[currentGroup] == true
			or (authoringMode == "Expert" and expertSearch ~= "")
		local searchVisible = authoringMode ~= "Expert"
			or expertSearch == ""
			or string.find(string.lower(label), string.lower(expertSearch), 1, true) ~= nil
		return groupVisible and searchVisible
	end
	local function row(label)
		cardPairHolder, cardPairCount, cardPairCards, cardPairLayout = nil, 0, {}, nil
		order += 1
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, -8, 0, 44)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		frame.Visible = visibleNow(label)
		frame.Parent = scroll
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(0.56, 0, 1, 0)
		title.BackgroundTransparency = 1
		title.TextWrapped = true
		title.Text = label
		title.TextColor3 = K.C.Ink
		title.Font = Enum.Font.GothamMedium
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = frame
		return frame
	end
	local function canvasBlock(height)
		cardPairHolder, cardPairCount, cardPairCards, cardPairLayout = nil, 0, {}, nil
		order += 1
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, -8, 0, height)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		frame.Parent = scroll
		return frame
	end
	local function creationChoiceGrid(options)
		local gridHost = scroll
		local holder = canvasBlock(gridHost.AbsoluteSize.Y)
		holder.Name = "SpellChoiceGrid"
		local tiles = {}
		for index, option in ipairs(options) do
			local tile = K.new("TextButton", {
				Name = "Choice_" .. tostring(option.Id or index),
				BackgroundColor3 = K.C.Card,
				Text = "",
				AutoButtonColor = false,
			}, holder)
			K.corner(tile, 12)
			local edge =
				K.stroke(tile, if option.Selected then K.C.Gold else K.C.PanelEdge, if option.Selected then 2 else 1)
			K.hover(tile, K.C.Card, K.C.CardHover)
			tile.SelectionGained:Connect(function()
				edge.Color = K.C.Gold
			end)
			tile.SelectionLost:Connect(function()
				edge.Color = if option.Selected then K.C.Gold else K.C.PanelEdge
			end)
			local icon = K.new("Frame", {
				Name = "ChoiceIcon",
				Position = UDim2.fromScale(0.29, 0.14),
				Size = UDim2.fromScale(0.42, 0.43),
				BackgroundColor3 = K.C.Input,
			}, tile)
			K.corner(icon, 10)
			if option.Preview then
				SpellVisual.render(icon, option.Preview, true)
			else
				K.text(icon, option.Symbol or "◆", 26, K.C.Gold, Enum.Font.GothamBold, {
					Size = UDim2.fromScale(1, 1),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			end
			K.text(tile, option.Label, 14, K.C.Ink, Enum.Font.GothamBold, {
				Name = "ChoiceName",
				Position = UDim2.fromScale(0.06, 0.6),
				Size = UDim2.fromScale(0.88, 0.16),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			K.text(tile, option.Hint or "", 11, K.C.Muted, Enum.Font.Gotham, {
				Name = "ChoiceDetail",
				Position = UDim2.fromScale(0.06, 0.77),
				Size = UDim2.fromScale(0.88, 0.18),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			if option.Badge then
				K.text(tile, option.Badge, 10, if option.Selected then K.C.Gold else K.C.Faint, Enum.Font.GothamBlack, {
					Name = "ChoiceBadge",
					Position = UDim2.fromScale(0.07, 0.03),
					Size = UDim2.fromScale(0.86, 0.1),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			end
			tile.Activated:Connect(option.Action)
			table.insert(tiles, tile)
		end
		local function layoutGrid()
			local width = holder.AbsoluteSize.X
			local gap = 10
			local columns = math.max(2, math.min(4, math.floor((width + gap) / 150)))
			local cell = math.max(72, math.floor((width - gap * (columns - 1)) / columns))
			cell = math.min(cell, 190)
			local left = math.floor((width - (cell * columns + gap * (columns - 1))) / 2)
			for index, tile in ipairs(tiles) do
				local column = (index - 1) % columns
				local rowIndex = math.floor((index - 1) / columns)
				tile.Position = UDim2.fromOffset(left + column * (cell + gap), rowIndex * (cell + gap))
				tile.Size = UDim2.fromOffset(cell, cell)
			end
			holder.Size = UDim2.new(1, -8, 0, math.ceil(#tiles / columns) * (cell + gap))
		end
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutGrid)
		local resizeConnection = gridHost:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutGrid)
		holder.Destroying:Connect(function()
			resizeConnection:Disconnect()
		end)
		layoutGrid()
	end
	local function heading(text)
		if not (currentGroup == "TRIGGER BEHAVIORS" and string.find(text, " in blast", 1, true)) then
			currentGroup = nil
		end
		local frame = row(text)
		frame.Size = UDim2.new(1, -8, 0, 34)
		local label = frame:FindFirstChildOfClass("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 12
		label.TextColor3 = K.C.Gold
		label.TextYAlignment = Enum.TextYAlignment.Bottom
		if advancedGroups[text] then
			label.Text = (if expandedGroups[text] then "▼   " else "▶   ") .. text
			currentGroup = text
			frame.Size = UDim2.new(1, -8, 0, 40)
			label.Position = UDim2.fromOffset(14, 0)
			label.Size = UDim2.new(1, -28, 1, 0)
			label.Font = Enum.Font.GothamBold
			label.TextColor3 = K.C.Ink
			label.TextYAlignment = Enum.TextYAlignment.Center
			frame.BackgroundColor3 = K.C.Card
			frame.BackgroundTransparency = 0
			K.stroke(frame, K.C.PanelEdge)
			K.corner(frame, 8)
			local reveal = K.new("TextButton", {
				Name = "AdvancedTriggerBar",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
			}, frame)
			reveal.Activated:Connect(function()
				expandedGroups[text] = not expandedGroups[text]
				rebuildPreservingScroll()
			end)
		end
		return label
	end
	local function info(text, _height)
		cardPairHolder, cardPairCount, cardPairCards, cardPairLayout = nil, 0, {}, nil
		order += 1
		local label = K.text(scroll, text, 12, K.C.Muted, Enum.Font.Gotham, {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(27, 23, 30),
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = order,
		})
		K.pad(label, 12, 9)
		K.corner(label, 8)
		label.Visible = visibleNow(text)
		return label
	end
	local function card(title, description, enabled, onChange, canEdit, unavailableReason)
		canEdit = if canEdit == nil then true else canEdit
		if not visibleNow(title .. " " .. description) then
			return nil
		end
		if not cardPairHolder or cardPairCount >= 2 then
			order += 1
			cardPairHolder = Instance.new("Frame")
			cardPairHolder.Name = "EffectChoicePair"
			cardPairHolder.Size = UDim2.new(1, -8, 0, 128)
			cardPairHolder.BackgroundTransparency = 1
			cardPairHolder.LayoutOrder = order
			cardPairHolder.Parent = scroll
			cardPairCount, cardPairCards = 0, {}
			local holder = cardPairHolder
			local cards = cardPairCards
			local function layoutPair()
				local width = holder.AbsoluteSize.X
				local columns = if width >= 295 then 2 else 1
				local gap = 10
				local cellWidth = if columns == 2 then math.floor((width - gap) / 2) else width
				for index, choice in ipairs(cards) do
					choice.Size = UDim2.fromOffset(cellWidth, 120)
					choice.Position = if columns == 2
						then UDim2.fromOffset((index - 1) * (cellWidth + gap), 0)
						else UDim2.fromOffset(0, (index - 1) * (120 + gap))
				end
				holder.Size = UDim2.new(1, -8, 0, if columns == 2 then 120 else #cards * (120 + gap) - gap)
			end
			holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutPair)
			local resizeConnection = scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutPair)
			holder.Destroying:Connect(function()
				resizeConnection:Disconnect()
			end)
			cardPairLayout = layoutPair
		end
		local base = if canEdit then K.C.Card else Color3.fromRGB(24, 21, 26)
		local frame = K.new("TextButton", {
			Name = "EffectChoice",
			BackgroundColor3 = base,
			Text = "",
			AutoButtonColor = false,
		}, cardPairHolder)
		cardPairCount += 1
		table.insert(cardPairCards, frame)
		K.corner(frame, 12)
		K.stroke(frame, if enabled then K.C.Gold else K.C.PanelEdge, if enabled then 2 else 1)
		if canEdit then
			K.hover(frame, base, K.C.CardHover)
		end
		K.text(frame, title, 13, if canEdit then K.C.Ink else K.C.Faint, Enum.Font.GothamBold, {
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.new(1, -24, 0, 18),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		K.text(
			frame,
			if canEdit then description else tostring(unavailableReason or "Unavailable"),
			11,
			K.C.Muted,
			Enum.Font.Gotham,
			{
				Position = UDim2.fromOffset(12, 30),
				Size = UDim2.new(1, -24, 1, -76),
				TextYAlignment = Enum.TextYAlignment.Top,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}
		)
		local add = K.pill(
			frame,
			if not canEdit then "UNAVAILABLE" elseif enabled then "ADDED" else "+ ADD",
			function() end,
			if enabled and canEdit then "accent" else nil
		)
		add.Size, add.Position = UDim2.new(1, -24, 0, 32), UDim2.new(0, 12, 1, -42)
		if not canEdit then
			add.TextColor3 = K.C.Faint
		end
		if canEdit then
			local function choose()
				onChange(not enabled)
				rebuild()
				estimate()
			end
			frame.Activated:Connect(choose)
			add.Activated:Connect(choose)
		end
		if cardPairLayout then
			cardPairLayout()
		end
		return frame
	end
	local function button(parent, text, callback)
		local b = K.pill(parent, text, callback)
		b.Size = UDim2.new(0.42, 0, 0, 36)
		b.Position = UDim2.new(0.58, 0, 0.5, -18)
		b.TextSize = 12
		b.TextWrapped = true
		return b
	end
	local function inputBox(r, value, placeholder)
		local box = K.new("TextBox", {
			Size = UDim2.new(0.42, 0, 0, 36),
			Position = UDim2.new(0.58, 0, 0.5, -18),
			BackgroundColor3 = K.C.Input,
			TextColor3 = K.C.Ink,
			PlaceholderColor3 = K.C.Faint,
			PlaceholderText = placeholder or "",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			ClearTextOnFocus = false,
			Text = value,
		}, r)
		K.corner(box, 8)
		K.stroke(box, K.C.PanelEdge)
		return box
	end
	local function select(label, value, options, change, labelFor, help, isAvailable, lockedReason, presentationOnly)
		local r = row(label)
		local function display(option)
			return if labelFor then labelFor(option) else tostring(option)
		end
		local function pick(option)
			expandedChoiceKey = nil
			change(option)
			rebuildPreservingScroll()
			if not presentationOnly then
				estimate()
			end
		end
		local title = r:FindFirstChildOfClass("TextLabel")
		if #options <= 8 then
			-- Few choices: show them all as chips under the label.
			r.AutomaticSize = Enum.AutomaticSize.Y
			r.Size = UDim2.new(1, -8, 0, 0)
			title.Size = UDim2.new(1, 0, 0, 22)
			local holder = K.new("Frame", {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			}, r)
			K.new("UIPadding", { PaddingBottom = UDim.new(0, 6) }, holder)
			K.chips(holder, options, value, pick, display, isAvailable)
		else
			button(r, display(value) .. "  ▼", function()
				expandedChoiceKey = if expandedChoiceKey == label then nil else label
				rebuildPreservingScroll()
			end)
			if expandedChoiceKey == label then
				title.Size = UDim2.new(0.56, 0, 0, 44)
				local menuHeight = math.min(240, #options * 38 + 4)
				r.Size = UDim2.new(1, -8, 0, 48 + menuHeight)
				local choices = K.new("ScrollingFrame", {
					Name = "Choices",
					Position = UDim2.fromOffset(0, 48),
					Size = UDim2.new(1, 0, 0, menuHeight),
					BackgroundColor3 = K.C.Input,
					BorderSizePixel = 0,
					ScrollBarThickness = 4,
					ScrollBarImageColor3 = K.C.Rail,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.new(),
				}, r)
				K.corner(choices, 8)
				K.pad(choices, 4, 4)
				K.list(choices, 4)
				for index, option in ipairs(options) do
					local available = not isAvailable or isAvailable(option)
					local b = K.pill(
						choices,
						display(option) .. (if available then "" else "  ·  UNAVAILABLE"),
						function()
							if available then
								pick(option)
							end
						end
					)
					b.Size = UDim2.new(1, -4, 0, 34)
					b.LayoutOrder = index
					b.TextXAlignment = Enum.TextXAlignment.Left
					K.pad(b, 12, 0)
					if option == value then
						b.BackgroundColor3, b.TextColor3 = K.C.Gold, K.C.Backdrop
					elseif not available then
						b.TextColor3 = K.C.Faint
					end
				end
			end
		end
		if help then
			info(help, 34)
		end
		if lockedReason then
			info(lockedReason, 34)
		end
	end
	local function numeric(label, object, key, help)
		local r = row(label)
		local box = inputBox(r, tostring(object[key] or 0))
		box.FocusLost:Connect(function()
			local value = tonumber(box.Text)
			if not value then
				object[key] = nil
				revision += 1
				dirty = true
				message(label .. ": enter a finite number", false)
				return
			end
			object[key] = value
			estimate()
		end)
		if help then
			info(help, 34)
		end
	end
	local function tagList(label, object, key, help)
		local r = row(label)
		local box = inputBox(r, table.concat(object[key] or {}, ", "), "comma-separated tags")
		box.TextSize = 12
		box.FocusLost:Connect(function()
			if object == draft and key == "Tags" then
				local tags, reason = SpellIdentitySpec.parse(box.Text)
				if not tags then
					message(label .. ": " .. tostring(reason), false)
					box.Text = table.concat(object[key] or {}, ", ")
					return
				end
				object[key] = tags
				estimate()
				return
			end
			local tags = {}
			local seen = {}
			for token in string.gmatch(box.Text, "[^,;]+") do
				local tag = string.lower(string.gsub(token, "^%s*(.-)%s*$", "%1"))
				if tag ~= "" and not seen[tag] then
					table.insert(tags, tag)
					seen[tag] = true
				end
			end
			if #tags > EnvironmentRequirementSpec.MaxTags then
				message(label .. ": use at most " .. EnvironmentRequirementSpec.MaxTags .. " tags", false)
				box.Text = table.concat(object[key] or {}, ", ")
				return
			end
			object[key] = tags
			estimate()
		end)
		if help then
			info(help, 34)
		end
	end
	local function assetId(label, object, key, help)
		local r = row(label)
		local box = inputBox(r, object[key] or "", "blank = silent")
		box.FocusLost:Connect(function()
			local value = string.gsub(box.Text, "^%s*(.-)%s*$", "%1")
			if value ~= "" and (#value > 20 or not string.match(value, "^%d+$")) then
				message(label .. ": enter a numeric Roblox audio asset ID", false)
				box.Text = object[key] or ""
				return
			end
			object[key] = value
			revision += 1
			dirty = true
			estimate()
		end)
		if help then
			info(help, 34)
		end
	end
	local function toggle(label, value, change, help)
		local r = row(label)
		local b = K.switch(r, value, function(nextValue)
			change(nextValue)
			rebuild()
			estimate()
		end)
		b.Size = UDim2.new(0, 72, 0, 32)
		b.Position = UDim2.new(1, -72, 0.5, -16)
		if help then
			info(help, 34)
		end
	end
	-- Spell steps (Dispel, Force): whether they act on live spells, and whose.
	local function spellTargetControls(step)
		local mode = SpellTargetSpec.stepMode(step, Schema.SpellTargetPayloads)
		if mode == "Optional" then
			toggle("Target spells", step.TargetKind == "Spell", function(value)
				step.TargetKind = if value then "Spell" else nil
				if not value then
					step.SpellRelationship = nil
				end
				dirty = true
				revision += 1
			end, "Off: acts on creatures. On: acts on live Fields, Auras, Constructs and Tethers here instead.")
		end
		if mode and step.TargetKind == "Spell" then
			select(
				"Which spells",
				step.SpellRelationship or "Hostile",
				Schema.SpellRelationships,
				function(value)
					step.SpellRelationship = if value == "Hostile" then nil else value
				end,
				nil,
				"Hostile: spells of those you can fight. Allied: yours and your allies'. Any: every spell it touches. Each spell is affected once per cast."
			)
		end
	end
	local function slider(label, object, key, minimum, maximum, help, canEdit)
		local r = row(label)
		local valueLabel = K.text(r, "", 13, K.C.Ink, Enum.Font.GothamBold, {
			Size = UDim2.new(0.12, 0, 1, 0),
			Position = UDim2.new(0.88, 0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		local track = K.new("TextButton", {
			Size = UDim2.new(0.27, 0, 0, 8),
			Position = UDim2.new(0.58, 0, 0.5, -4),
			BackgroundColor3 = K.C.Input,
			Text = "",
			AutoButtonColor = false,
			Active = canEdit,
		}, r)
		K.corner(track, 4)
		local fill = K.new("Frame", {
			BackgroundColor3 = if canEdit then K.C.Ember else K.C.Faint,
			Size = UDim2.fromScale(0, 1),
		}, track)
		K.corner(fill, 4)
		local knob = K.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(0, 0, 0.5, 0),
			BackgroundColor3 = K.C.Gold,
		}, track)
		K.corner(knob, 8)
		local function refresh()
			local alpha = math.clamp((object[key] - minimum) / (maximum - minimum), 0, 1)
			fill.Size = UDim2.new(alpha, 0, 1, 0)
			knob.Position = UDim2.new(alpha, 0, 0.5, 0)
			valueLabel.Text = if minimum >= 1
				then string.format("%.1fx", object[key])
				else string.format("%d%%", math.floor(object[key] * 100 + 0.5))
		end
		refresh()
		if canEdit then
			local dragging = false
			local touchInput
			local function update(positionX)
				local alpha = math.clamp((positionX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				object[key] =
					math.clamp(math.round((minimum + alpha * (maximum - minimum)) * 10) / 10, minimum, maximum)
				refresh()
				estimate()
			end
			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = true
					update(input.Position.X)
				elseif input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					touchInput = input
					update(input.Position.X)
				end
			end)
			local changed = UIS.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == touchInput) then
					update(input.Position.X)
				end
			end)
			local ended = UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input == touchInput then
					dragging = false
					touchInput = nil
				end
			end)
			track.Destroying:Connect(function()
				changed:Disconnect()
				ended:Disconnect()
			end)
		end
		if help then
			info(help, 38)
		end
	end
	local function hasPayloadAnywhere(kind, excludedEvent)
		for triggerEvent, steps in draft.Triggers or {} do
			if triggerEvent ~= "OnBreak" and triggerEvent ~= excludedEvent then
				for _, step in steps or {} do
					for _, value in step.Payloads or {} do
						if value.Kind == kind then
							return true
						end
					end
				end
			end
		end
		return false
	end
	local function hasConflictingInternalRequirement(principle: string): boolean
		local targetRequiresMatter = draft.Form == "Manipulation"
			or draft.Targeting == "MaterialTarget"
			or (draft.Targeting == "ObjectTarget" and hasPayloadAnywhere("Manipulation"))
		if targetRequiresMatter and principle ~= "Matter" then
			return true
		end
		for _, steps in pairs(draft.Triggers or {}) do
			for _, step in ipairs(steps or {}) do
				for _, value in ipairs(step.Payloads or {}) do
					local definition = Schema.Payloads[value.Kind]
					if definition and definition.Principle and definition.Principle ~= principle then
						return true
					end
					if
						value.DamageChannel == "Physical" and principle ~= "Body"
						or value.DamageChannel == "Soul" and principle ~= "Soul"
					then
						return true
					end
				end
			end
		end
		return false
	end
	local function setInternalDefault(principle: string, expression: string?): boolean
		if not Schema.supportsPrincipleForm(principle, draft.Form) or hasConflictingInternalRequirement(principle) then
			return false
		end
		local selectedExpression = expression or draft.Source.Expression
		if not Schema.expressionMatches(principle, selectedExpression) then
			selectedExpression = Schema.defaultExpression(principle)
		end
		if not selectedExpression then
			return false
		end
		draft.Source.Principle = principle
		draft.Source.Expression = selectedExpression
		return true
	end
	local function supportedEffectEventsForDraft()
		local result = Schema.eventsForEffects(draft.Form, draft.Casting.Mode, draft.Targeting)
		for index = #result, 1, -1 do
			if result[index] == "OnBreak" and not hasPayloadAnywhere("Shield") then
				table.remove(result, index)
			elseif result[index] == "OnCommand" and not hasPayloadAnywhere("Summon", "OnCommand") then
				table.remove(result, index)
			end
		end
		return result
	end
	local function effectEventsForDraft()
		local result = supportedEffectEventsForDraft()
		local available = {}
		for _, eventName in result do
			available[eventName] = true
		end
		for _, eventName in Schema.EventOrder do
			local steps = draft.Triggers[eventName]
			if type(steps) == "table" and #steps > 0 and not available[eventName] then
				table.insert(result, eventName)
				available[eventName] = true
			end
		end
		local unknownEvents = {}
		for eventName, steps in draft.Triggers do
			if type(eventName) == "string" and type(steps) == "table" and #steps > 0 and not available[eventName] then
				table.insert(unknownEvents, eventName)
			end
		end
		table.sort(unknownEvents)
		for _, eventName in unknownEvents do
			table.insert(result, eventName)
		end
		return result
	end
	local function primary()
		draft.Triggers[event] = draft.Triggers[event] or {}
		local selectedIndex = selectedStepByEvent[event]
		local selected = selectedIndex and draft.Triggers[event][selectedIndex]
		if selected and not selected.Behavior then
			return selected
		end
		for _, step in draft.Triggers[event] do
			if not step.Behavior then
				return step
			end
		end
		return nil
	end
	local function payload(kind)
		local step = primary()
		if step then
			for _, p in step.Payloads do
				if p.Kind == kind then
					return p
				end
			end
		end
	end
	local function setPayload(kind, on)
		if
			kind == "Summon"
			and on
			and draft.Form == "Projectile"
			and event == "OnImpact"
			and not hasPayloadAnywhere("Summon")
		then
			-- Projectile drafts default to impact effects. For a first Summon,
			-- prefer the cast event so the configured Caster placement appears
			-- immediately instead of silently waiting for a collision.
			event = "OnCast"
		end
		local step = primary()
		if not step and on then
			step = { Payloads = {} }
			if event == "OnThreshold" then
				step.HealthPercent = 50
			end
			table.insert(draft.Triggers[event], 1, step)
		end
		if not step then
			return
		end
		for i = #step.Payloads, 1, -1 do
			if step.Payloads[i].Kind == kind then
				table.remove(step.Payloads, i)
			end
		end
		if on then
			local definition = Schema.Payloads[kind]
			if definition then
				local requiredPrinciple = definition.Principle or (kind == "Manipulation" and "Matter")
				if requiredPrinciple and requiredPrinciple ~= draft.Source.Principle then
					setInternalDefault(requiredPrinciple, if requiredPrinciple == "Matter" then "Earth" else nil)
				end
				local value = Spec.copy(definition.Defaults)
				value.Kind = kind
				table.insert(step.Payloads, value)
			end
		end
		SpellTargetSpec.syncStep(step, Schema.SpellTargetPayloads)
		if #step.Payloads == 0 then
			for i, s in draft.Triggers[event] do
				if s == step then
					table.remove(draft.Triggers[event], i)
					break
				end
			end
		end
		if kind == "Summon" and not on and not hasPayloadAnywhere("Summon", "OnCommand") then
			draft.Triggers.OnCommand = nil
			if event == "OnCommand" then
				event = (Schema.Forms[draft.Form] and Schema.Forms[draft.Form].DefaultEvent) or "OnCast"
			end
		end
		if
			draft.Targeting == "ObjectTarget"
			and (
				draft.Form == "Manipulation"
				or draft.Form == "Projectile"
				or draft.Form == "Beam"
				or draft.Form == "Wave"
			)
		then
			if hasPayloadAnywhere("Manipulation") then
				local options = MaterialSpec.options("Matter", "Earth", draft.Form, draft.Targeting)
				if options[1] then
					draft.Material = draft.Material or { SearchRadius = 12 }
					draft.Material.Material = draft.Material.Material or options[1]
					draft.Material.SearchRadius = draft.Material.SearchRadius or 12
				end
			elseif draft.Material then
				draft.Material.Material = nil
			end
		end
	end
	local function behavior(kind)
		for _, step in draft.Triggers[event] or {} do
			if step.Behavior == kind then
				return step
			end
		end
		return nil
	end
	local function setBehavior(kind, on)
		local steps = draft.Triggers[event] or {}
		draft.Triggers[event] = steps
		for i = #steps, 1, -1 do
			if steps[i].Behavior == kind then
				table.remove(steps, i)
			end
		end
		if not on then
			return
		end
		local definition = Schema.Behaviors[kind]
		if not definition then
			return
		end
		local payloads = {}
		for _, payloadKind in definition.DefaultPayloadKinds or definition.PayloadKinds or {} do
			local payloadDefinition = Schema.Payloads[payloadKind]
			local payloadValue = Spec.copy(payloadDefinition.Defaults)
			payloadValue.Kind = payloadKind
			table.insert(payloads, payloadValue)
		end
		local step = { Behavior = kind, Payloads = payloads }
		for key, value in definition.Defaults do
			step[key] = value
		end
		if kind == "SpawnEffect" then
			step.Effect = Spec.defaultSpawnEffect("Field", draft.Source.Principle)
		end
		table.insert(steps, step)
	end
	-- Which timing of a spawned effect the editor is showing, per SpawnEffect step.
	local spawnedEventFor = setmetatable({}, { __mode = "k" })
	local function projectileBehavior(kind)
		if not draft.Projectile then
			return nil
		end
		for _, behavior in ipairs(draft.Projectile.Behaviors or {}) do
			if behavior.Kind == kind then
				return behavior
			end
		end
		return nil
	end
	local function setProjectileBehavior(kind, on)
		draft.Projectile.Behaviors = draft.Projectile.Behaviors or {}
		for i = #draft.Projectile.Behaviors, 1, -1 do
			if draft.Projectile.Behaviors[i].Kind == kind then
				table.remove(draft.Projectile.Behaviors, i)
			end
		end
		if not on then
			return
		end
		local behavior = ProjectileBehaviorSpec.copyDefaults(kind)
		if behavior then
			table.insert(draft.Projectile.Behaviors, behavior)
		end
	end
	local function mainEvent(form)
		return (Schema.Forms[form] and Schema.Forms[form].DefaultEvent) or "OnCast"
	end
	local function migrateEffects(previous, target)
		-- Keep the user's chosen effects and timing intact. The editor marks any
		-- newly incompatible entry so it can be repaired without losing its work.
		target.Triggers = Spec.copy(previous.Triggers)
	end
	local backButton = button(navigation, "‹  SLOTS", function()
		if standaloneDraft or editingLibraryRecord then
			pageMode = "Library"
		else
			draftsBySlot[selectedSlot] = draft
			pageMode = "Slots"
		end
		scroll.CanvasPosition = Vector2.zero
		rebuild()
	end)
	backButton.Size = UDim2.new(0.16, -4, 1, 0)
	backButton.Position = UDim2.new(0, 0, 0, 0)
	backButton.Font = Enum.Font.GothamBold
	local navigateTab
	local layoutBook = Hub.mountShell(panel, {
		scroll = scroll,
		title = headerTitle,
		summary = headerSummary,
		status = status,
		navigation = navigation,
		closeButton = closeButton,
		homeButton = homeButton,
	}, function(tab)
		navigateTab(tab)
	end)
	local overview = panel:FindFirstChild("LiveSpellSummary")
	if overview then
		editorPreview = Instance.new("Frame")
		editorPreview.Name = "LiveSpellVisualPreview"
		editorPreview.Position = UDim2.fromOffset(12, 38)
		editorPreview.Size = UDim2.new(1, -24, 1, -52)
		editorPreview.Parent = overview
		SpellVisual.render(editorPreview, draft, false)
	end
	updateHeader = function()
		homeButton.Visible = false
		navigation.Visible = false
		backButton.Visible = false
		if actions then
			actions.Visible = false
		end
		if pageMode == "Editor" then
			layoutBook("Editor")
			return
		end
		closeButton.Visible = true
		headerTitle.Visible = true
		headerTitle.Text = if pageMode == "Slots"
			then "Home"
			elseif pageMode == "Library" then (if libraryView.ChoosingSlot
				then "Choose a spell for slot " .. libraryView.ChoosingSlot
				else "Spell library")
			elseif pageMode == "Help" then "How spell creation works"
			elseif pageMode == "Training" then "Training & targets"
			else "Spellcraft"
		headerSummary.Text = if pageMode == "Slots"
			then "Your nine equipped spells and quick actions."
			elseif pageMode == "Training" then "Spawn targets and manage your practice session."
			elseif pageMode == "Help" then "Build spells from actions, triggers, and effects."
			else persistenceState .. "  ·  Library spells are separate from your equipped slots."
		headerSummary.Visible = true
		status.Visible = false
		layoutBook(if pageMode == "Library" and libraryView.Selected then "LibraryDetail" else pageMode)
		scroll.ScrollingEnabled = pageMode ~= "Library" or libraryView.Selected ~= nil
	end
	local function renderField(object, field)
		if not Schema.fieldVisible(object, field) then
			return
		end
		field = Schema.resolveField(object, field)
		local options = field.Options
		if type(object[field.Key]) == "boolean" then
			select(field.Label, if object[field.Key] then "On" else "Off", { "On", "Off" }, function(value)
				object[field.Key] = value == "On"
			end, nil, field.Help)
		elseif options then
			select(field.Label, object[field.Key] or options[1], options, function(value)
				object[field.Key] = value
				Schema.normalizePayload(object)
				if field.Key == "DamageChannel" then
					if value == "Physical" then
						setInternalDefault("Body")
					elseif value == "Soul" then
						setInternalDefault("Soul")
					end
				end
			end, nil, field.Help)
		else
			numeric(
				field.Label,
				object,
				field.Key,
				(field.Help and field.Help .. "  " or "")
					.. string.format("Allowed: %s to %s", tostring(field.Min), tostring(field.Max))
			)
		end
	end
	-- Editor for a whitelisted ALL/ANY/NOT condition tree stored at holder[key].
	-- Used for spell-level conditions and per-step trigger conditions.
	local function renderConditionTree(holder, key, label)
		-- Widgets are read at call time: `rebuild` is assigned after this point.
		return ConditionTreeEditor.render({
			button = button,
			card = card,
			estimate = estimate,
			info = info,
			numeric = numeric,
			rebuild = rebuild,
			row = row,
			select = select,
			toggle = toggle,
		}, holder, key, label)
	end
	local function internalDefaultForForm(formName: string): string
		if Schema.supportsPrincipleForm("Energy", formName) then
			return "Energy"
		end
		for _, value in ipairs(Schema.Principles) do
			if Schema.supportsPrincipleForm(value, formName) then
				return value
			end
		end
		return "Matter"
	end
	local function resetForForm(formName: string, principle: string?, confirmed: boolean?)
		if not confirmed and formName ~= draft.Form and dirtySlots[selectedSlot] then
			confirm(
				"Change the spell Form? Shape settings reset. Existing effects and their timing stay in place; incompatible entries will be flagged for repair.",
				function()
					resetForForm(formName, principle, true)
					rebuild()
					estimate()
				end
			)
			return
		end
		local previous = draft
		local selectedPrinciple = principle or draft.Source.Principle
		if not Schema.supportsPrincipleForm(selectedPrinciple, formName) then
			selectedPrinciple = internalDefaultForForm(formName)
		end
		local nextDraft = Spec.createDraft(formName, selectedPrinciple)
		if not nextDraft then
			return
		end
		nextDraft.Name = previous.Name
		nextDraft.Element = previous.Element
		nextDraft.Visual.Color = previous.Visual.Color
		nextDraft.Visual.ProjectileScale = previous.Visual.ProjectileScale or 1
		nextDraft.Audio = previous.Audio or nextDraft.Audio
		nextDraft.Casting = Spec.copy(previous.Casting)
		if
			formName ~= "Beam"
			and formName ~= "Projectile"
			and formName ~= "Wave"
			and formName ~= "Field"
			and formName ~= "Aura"
			and formName ~= "SelfEnhancement"
			and nextDraft.Casting.Mode == "Channeled"
		then
			nextDraft.Casting.Mode = "Instant"
			nextDraft.Casting.MinimumCharge = nil
			nextDraft.Casting.MaximumCharge = nil
			nextDraft.Casting.ChargeScaling = nil
			nextDraft.Casting.ManaUpkeepPerSecond = nil
			nextDraft.Casting.StrainPerSecond = nil
		end
		if nextDraft.Casting.Mode == "Toggle" then
			if CastingSpec.supportsToggle(formName) then
				nextDraft.Lifetime = { Mode = "UntilToggledOff" }
			else
				nextDraft.Casting.Mode = "Instant"
			end
		end
		if nextDraft.Casting.Mode == "CommandCast" and not CastingSpec.supportsCommandCast(formName) then
			nextDraft.Casting.Mode = "Instant"
		end
		if nextDraft.Casting.Mode == "Sustained" and not CastingSpec.supportsSustained(formName) then
			nextDraft.Casting.Mode = "Instant"
			nextDraft.Casting.ManaUpkeepPerSecond = nil
			nextDraft.Casting.StrainPerSecond = nil
		end
		nextDraft.TargetRules = Spec.copy(previous.TargetRules)
		nextDraft.Conditions = Spec.copy(previous.Conditions)
		if nextDraft.Targeting == previous.Targeting then
			if previous.Material then
				nextDraft.Material = Spec.copy(previous.Material)
			end
			if previous.TargetPolicy then
				nextDraft.TargetPolicy = previous.TargetPolicy
			end
		end
		if nextDraft.Lifetime.Mode == "Instantaneous" then
			nextDraft.Casting.ManaUpkeepPerSecond = nil
			nextDraft.Casting.StrainPerSecond = nil
		end
		if formName == previous.Form and previous.Projectile then
			nextDraft.Projectile.Behaviors = Spec.copy(previous.Projectile.Behaviors)
			nextDraft.Projectile.MotionPhases = Spec.copy(previous.Projectile.MotionPhases or {})
		end
		migrateEffects(previous, nextDraft)
		draft = nextDraft
		event = mainEvent(formName)
	end

	local function openSlot(slot)
		standaloneDraft, editingLibraryRecord, editingLibraryId = false, false, nil
		selectedSlot = slot
		draft = draftsBySlot[slot]
			or (equipped[slot] and Spec.copy(equipped[slot]))
			or Spec.createDraft("Projectile", "Energy")
		ensureVisualDefaults(draft)
		draftsBySlot[slot] = draft
		if not equipped[slot] then
			dirtySlots[slot] = true
		end
		dirty = dirtySlots[slot] == true
		event = mainEvent(draft.Form)
		pageMode, activeSection = "Editor", "Setup"
		revision += 1
		appliedRevision = if dirty then -1 else revision
		scroll.CanvasPosition = Vector2.zero
		rebuild()
	end
	local function libraryPage(mode)
		pageMode = mode
		scroll.CanvasPosition = Vector2.zero
		rebuild()
	end
	local function beginCreation(forLibrary, fresh)
		if forLibrary and standaloneWorkingDraft and not fresh then
			draft = Spec.copy(standaloneWorkingDraft)
			ensureVisualDefaults(draft)
			standaloneDraft = true
			editingLibraryRecord, editingLibraryId = false, nil
			event = mainEvent(draft.Form)
			authoringMode = "Guided"
			pageMode, activeSection = "Editor", "Setup"
			dirty = true
			revision += 1
			appliedRevision = -1
			rebuild()
			message("Resumed your unsaved spell draft.", true)
			return
		end
		standaloneDraft = forLibrary
		editingLibraryRecord, editingLibraryId = false, nil
		authoringMode = "Guided"
		local principle = internalDefaultForForm("Projectile")
		draft = Spec.createDraft("Projectile", principle)
		ensureVisualDefaults(draft)
		-- Starter: a projectile that deals damage on impact, ready to test.
		local starterDamage = Spec.copy(Schema.Payloads.Damage.Defaults or {})
		starterDamage.Kind = "Damage"
		draft.Triggers.OnImpact = { { Payloads = { starterDamage } } }
		draft.Name = "New Spell"
		event = mainEvent(draft.Form)
		if standaloneDraft then
			standaloneWorkingDraft = Spec.copy(draft)
			lastWorkingDraftKind = "Standalone"
		else
			draftsBySlot[selectedSlot], dirtySlots[selectedSlot] = draft, true
		end
		pageMode, activeSection = "Editor", "Setup"
		revision += 1
		appliedRevision = -1
		scroll.CanvasPosition = Vector2.zero
		rebuild()
	end

	local function editLibraryRecord(id, definition)
		if standaloneDraft and dirty then
			standaloneWorkingDraft = Spec.copy(draft)
		end
		editingLibraryRecord, editingLibraryId = true, id
		standaloneDraft = false
		draft = Spec.copy(libraryDrafts[id] or definition)
		ensureVisualDefaults(draft)
		event = mainEvent(draft.Form)
		pageMode, activeSection = "Editor", "Setup"
		revision += 1
		dirty = libraryDrafts[id] ~= nil
		appliedRevision = if dirty then -1 else revision
		if dirty then
			lastLibraryDraftId = id
			lastWorkingDraftKind = "Library"
		end
		expertSearch = ""
		scroll.CanvasPosition = Vector2.zero
		rebuild()
	end
	-- "New spell" always starts fresh; a kept draft is resumed separately.
	local function startNewSpell()
		if standaloneWorkingDraft then
			confirm(
				"Start a new spell? Your unsaved draft “"
					.. tostring(standaloneWorkingDraft.Name)
					.. "” will be discarded. Use Resume draft to keep working on it.",
				function()
					standaloneWorkingDraft = nil
					if lastWorkingDraftKind == "Standalone" then
						lastWorkingDraftKind = nil
					end
					beginCreation(true, true)
				end
			)
		else
			beginCreation(true, true)
		end
	end
	local function hasWorkingDraft()
		return standaloneWorkingDraft ~= nil or (lastLibraryDraftId ~= nil and libraryDrafts[lastLibraryDraftId] ~= nil)
	end
	local function resumeWorkingDraft()
		local record = lastLibraryDraftId and libraryView.Catalog.Records[lastLibraryDraftId]
		if lastWorkingDraftKind == "Standalone" and standaloneWorkingDraft then
			draft = Spec.copy(standaloneWorkingDraft)
			standaloneDraft = true
			editingLibraryRecord, editingLibraryId = false, nil
			dirty = true
			event = mainEvent(draft.Form)
			revision += 1
			appliedRevision = -1
			pageMode, activeSection = "Editor", "Setup"
			rebuild()
		elseif record and lastLibraryDraftId and libraryDrafts[lastLibraryDraftId] then
			editLibraryRecord(lastLibraryDraftId, record.Definition)
		else
			pageMode, activeSection = "Library", "Setup"
			rebuild()
		end
	end
	libraryView = LibraryView.new({
		row = row,
		block = canvasBlock,
		width = function()
			return scroll.AbsoluteSize.X
		end,
		height = function()
			return scroll.AbsoluteSize.Y
		end,
		button = button,
		heading = heading,
		select = select,
		info = info,
		showPreview = function(definition)
			if editorPreview then
				SpellVisual.render(editorPreview, definition, false)
			end
			panel:SetAttribute(
				"SpellSummary",
				definition.Name .. "\n" .. definition.Form .. "  ·  " .. definition.Element
			)
		end,
		-- The library draws its own preview; the old book side panel is gone.
		hasSidePreview = function()
			return false
		end,
		confirm = confirm,
		schema = Schema,
		spec = Spec,
		request = request,
		message = message,
		createNew = function()
			libraryView.ChoosingSlot = nil
			startNewSpell()
		end,
		editRecord = editLibraryRecord,
		hasWorkingDraft = function()
			return standaloneWorkingDraft ~= nil or next(libraryDrafts) ~= nil
		end,
		resumeDraft = function()
			resumeWorkingDraft()
		end,
		isDirtyRecord = function(id)
			return libraryDrafts[id] ~= nil
		end,
		rebuild = function()
			rebuild()
		end,
		top = function()
			scroll.CanvasPosition = Vector2.zero
		end,
		slots = function()
			libraryPage("Slots")
		end,
		help = function()
			libraryPage("Help")
		end,
		pendingEdit = function(slot)
			pendingLibraryEdit = slot
		end,
	})
	navigateTab = function(tab)
		if tab == "Forge" then
			if pageMode == "Editor" then
				return
			end
			if hasWorkingDraft() then
				resumeWorkingDraft()
			else
				beginCreation(true, true)
			end
			return
		end
		libraryView.Selected = nil
		libraryView.ChoosingSlot = nil
		pageMode = if tab == "Home"
			then "Slots"
			elseif tab == "Library" then "Library"
			elseif tab == "Training" then "Training"
			else "Help"
		scroll.CanvasPosition = Vector2.zero
		rebuild()
	end
	homeButton.Activated:Connect(function()
		libraryView.Selected = nil
		libraryView.ChoosingSlot = nil
		pageMode = "Slots"
		scroll.CanvasPosition = Vector2.zero
		rebuild()
	end)
	grimoireResponse.OnClientEvent:Connect(function(ok, text, catalog, slots, changedSlot)
		libraryView.receive(ok, text, catalog)
		local completedSlotChoice = ok and changedSlot ~= nil and changedSlot == libraryView.ChoosingSlot
		if completedSlotChoice then
			libraryView.ChoosingSlot = nil
			libraryView.Selected = nil
		end
		local saveMode = pendingLibrarySaveMode
		pendingLibrarySaveMode = nil
		if ok and saveMode == "SaveNew" then
			editingLibraryId = tostring(libraryView.Catalog.NextId - 1)
			editingLibraryRecord = true
			standaloneDraft = false
			if pendingStandaloneSave then
				standaloneWorkingDraft = nil
				if lastWorkingDraftKind == "Standalone" then
					lastWorkingDraftKind = nil
				end
			end
			libraryDrafts[editingLibraryId] = nil
			dirty, appliedRevision = false, revision
		elseif ok and saveMode == "Update" then
			if editingLibraryId then
				libraryDrafts[editingLibraryId] = nil
			end
			dirty, appliedRevision = false, revision
		end
		-- A saved spell is finished: close the forge and drop its working draft
		-- so the next "New spell" starts fresh. Slot work returns Home (the slot
		-- keeps its own draft until equipped); library work returns to My spells.
		local closeAfterSave = ok and saveMode ~= nil and pageMode == "Editor"
		local savedFromSlot = saveMode == "SaveNew" and not pendingStandaloneSave
		if closeAfterSave then
			if lastWorkingDraftKind == "Library" and lastLibraryDraftId == editingLibraryId then
				lastWorkingDraftKind = nil
			end
			editingLibraryRecord, editingLibraryId, standaloneDraft = false, nil, false
			libraryView.Selected = nil
			libraryView.ChoosingSlot = nil
			libraryView.Shelf = "Mine"
			pageMode = if savedFromSlot then "Slots" else "Library"
			scroll.CanvasPosition = Vector2.zero
		end
		pendingStandaloneSave = false
		persistenceState = catalog.SaveState or persistenceState
		for slot = 1, Slots.Count do
			equipped[slot] = slots[tostring(slot)]
			if draftsBySlot[slot] and not dirtySlots[slot] and not applying then
				draftsBySlot[slot] = equipped[slot] and Spec.copy(equipped[slot]) or nil
				if slot == selectedSlot and draftsBySlot[slot] then
					draft = draftsBySlot[slot]
				end
			end
		end
		if ok and changedSlot then
			draftsBySlot[changedSlot], dirtySlots[changedSlot] = nil, nil
		end
		refreshBar()
		if not helpSeen and libraryLoaded then
			helpSeen = true
		end
		if completedSlotChoice then
			pageMode = "Slots"
			scroll.CanvasPosition = Vector2.zero
			requestRebuild()
		elseif pendingLibraryEdit then
			local slot = pendingLibraryEdit
			pendingLibraryEdit = nil
			if ok and changedSlot == slot then
				openSlot(slot)
			end
		elseif pageMode ~= "Editor" then
			requestRebuild()
		end
		updateHeader()
		message(text, ok)
	end)

	rebuild = function()
		mobileEditorPreview = nil
		if not forgeHosted then
			forgeApi = nil
			-- The forge hides the book page; every other page needs it back.
			scroll.Visible = true
			local existingForge = panel:FindFirstChild("GuidedSpellForge")
			if existingForge then
				existingForge:Destroy()
			end
			for _, child in scroll:GetChildren() do
				if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
					child:Destroy()
				end
			end
		end
		visualStudioFrame = nil
		if visualLayoutConnection then
			visualLayoutConnection:Disconnect()
			visualLayoutConnection = nil
		end
		if not forgeHosted then
			order = 0
		end
		currentGroup = nil
		cardPairHolder, cardPairCount, cardPairCards, cardPairLayout = nil, 0, {}, nil
		local function renderTraining()
			heading("TRAINING TARGETS")
			if not RunService:IsStudio() then
				info("Training targets and resource reset controls are available in Studio practice sessions.", 60)
				return
			end
			info(
				"Spawn stationary Humanoid targets on nearby clear ground. Target relationship and other target rules determine which targets your spell can affect.",
				48
			)
			for _, option in
				{
					{ Label = "Spawn ally dummy", Action = "SpawnAlly" },
					{ Label = "Spawn enemy dummy", Action = "SpawnEnemy" },
					{ Label = "Restore my dummies", Action = "ResetMine" },
					{ Label = "Remove my dummies", Action = "ClearMine" },
					{ Label = "Restore health and magic resources", Action = "RestorePlayer" },
					{ Label = "Clear my spells and reset cooldowns", Action = "ClearEffects" },
					{ Label = "Respawn my character", Action = "ResetPlayer" },
					{ Label = "Return to practice start", Action = "ReturnToStart" },
				}
			do
				if option.Action ~= "ReturnToStart" or require(Shared.Configuration.DevelopmentSandbox).Enabled then
					local control = row(option.Label)
					local controlButton = button(control, "RUN", function()
						if option.Action == "ResetPlayer" or option.Action == "ClearEffects" then
							confirm(
								"Run “"
									.. option.Label
									.. "”? Active spells may end through their normal expiry behavior.",
								function()
									trainingRequest:FireServer(option.Action)
								end
							)
						else
							trainingRequest:FireServer(option.Action)
						end
					end)
					controlButton.Font = Enum.Font.GothamBold
				end
			end
			heading("SANDBOX CONTROLS")
			toggle(
				"Show combat feedback messages",
				feedbackVisible,
				function(value)
					feedbackVisible = value
					refreshToast()
				end,
				"Shows damage and invalid-cast feedback briefly during combat. Health bars stay visible on training dummies."
			)
			info(
				"Training dummies are stationary targets. Their health bars show damage and healing; test movement on a movable object or another player. Ending active spells may trigger their On expire effects. Testing continues while this screen is open.",
				96
			)
		end
		if pageMode == "Training" then
			updateHeader()
			renderTraining()
			return
		end
		if pageMode == "Library" then
			updateHeader()
			libraryView.render()
			return
		elseif pageMode == "Help" then
			updateHeader()
			heading("HOW SPELL CREATION WORKS")
			info(
				[[1. NEW SPELL opens the Spell Forge with a starter projectile.
2. The left panel is your spell: what it creates, its triggers (WHEN IT HITS...), and the effects each trigger runs.
3. Select any card to edit only its properties on the right. Use + to attach triggers and effects.
4. ADVANCED adds casting, targeting, condition and appearance cards and shows every setting, with search.
5. TEST SPELL casts it for real; SAVE SPELL stores it in your library; EQUIP puts it in a slot.]],
				180
			)
			info(
				"Guided and Advanced edit the same spell and use the same validation. Keep Draft keeps a session copy; Save Spell stores a valid library record. P returns you to play; open P again to continue.",
				100
			)
			button(row("Start or skip this guide"), "OPEN HOME", function()
				libraryView.dismissHelp()
				libraryPage("Slots")
			end)
			button(row("Browse saved magic"), "OPEN LIBRARY", function()
				libraryPage("Library")
			end)
			heading("TRY A REAL EXAMPLE")
			info(
				"These examples use the same Forms, default effects and validation as your own spells. They create an unsaved draft in the first empty slot and never replace existing work.",
				64
			)
			for _, example in
				{
					{ "Projectile", "Energy", "Damage", "OnImpact", "Practice bolt" },
					{ "Beam", "Body", "Heal", "OnCast", "Healing beam" },
				}
			do
				button(row(example[5]), "CREATE EXAMPLE", function()
					local slot
					for i = 1, libraryView.slotLimit() do
						if not equipped[i] and not draftsBySlot[i] then
							slot = i
							break
						end
					end
					if not slot then
						message("All slots contain work. Save and unequip a slot from the Library first.", false)
						return
					end
					local sample = Spec.createDraft(example[1], example[2])
					sample.Name = example[5]
					local effect = Spec.copy(Schema.Payloads[example[3]].Defaults)
					effect.Kind = example[3]
					sample.Triggers[example[4]] = { { Payloads = { effect } } }
					draftsBySlot[slot], dirtySlots[slot] = sample, true
					openSlot(slot)
					estimate()
				end)
			end
			return
		end
		if pageMode == "Slots" then
			updateHeader()
			local slotData = {}
			for slot = 1, Slots.Count do
				table.insert(slotData, {
					Number = slot,
					Spell = draftsBySlot[slot] or equipped[slot],
					Locked = slot > libraryView.slotLimit(),
					Draft = equipped[slot] == nil and draftsBySlot[slot] ~= nil,
					Selected = slot == selectedSlot and (draftsBySlot[slot] or equipped[slot]) ~= nil,
				})
			end
			order += 1
			Hub.home(scroll, {
				Slots = slotData,
				ResumeDraft = hasWorkingDraft(),
			}, {
				create = startNewSpell,
				resume = resumeWorkingDraft,
				library = function()
					navigateTab("Library")
				end,
				training = function()
					navigateTab("Training")
				end,
				openSlot = function(slotId)
					if slotId > libraryView.slotLimit() then
						message("This loadout slot unlocks with more mission XP.", false)
						return
					end
					if draftsBySlot[slotId] or equipped[slotId] then
						openSlot(slotId)
					else
						selectedSlot = slotId
						libraryView.chooseForSlot(slotId)
						pageMode = "Library"
						scroll.CanvasPosition = Vector2.zero
						rebuild()
					end
				end,
			}, Schema, Spec)
			return
		end
		if pageMode == "Editor" and not forgeHosted then
			updateHeader()
			navigation.Visible = false
			backButton.Visible = false
			if actions then
				actions.Visible = false
			end
			status.Visible = false
			headerTitle.Visible = false
			headerSummary.Visible = false
			homeButton.Visible = false
			closeButton.Visible = false
			scroll.Visible = false
			local _, api = GuidedForge.mount(panel, draft, Schema, Spec, {
				mode = authoringMode,
				-- Draws the real Advanced section editors into a forge inspector
				-- host. Section helpers append to `scroll`, so it points at the
				-- host for one pass and the page state is restored afterwards.
				renderSections = function(host, sections, sectionEvent, search, startOrder)
					local savedScroll, savedSection, savedEvent, savedSearch =
						scroll, activeSection, event, expertSearch
					local savedOrder, savedGroup = order, currentGroup
					local savedMode = authoringMode
					forgeHosted = true
					authoringMode = "Expert"
					scroll = host
					expertSearch = search or ""
					order = startOrder or 0
					local finalOrder = order
					local ok, failure = pcall(function()
						for _, sectionId in sections do
							activeSection = sectionId
							if sectionEvent then
								event = sectionEvent
							end
							currentGroup = nil
							cardPairHolder, cardPairCount, cardPairCards, cardPairLayout = nil, 0, {}, nil
							rebuild()
						end
						finalOrder = order
					end)
					scroll, activeSection, expertSearch = savedScroll, savedSection, savedSearch
					if not sectionEvent then
						event = savedEvent
					end
					order, currentGroup = savedOrder, savedGroup
					authoringMode = savedMode
					forgeHosted = false
					if not ok then
						warn("Spell Forge advanced section failed: " .. tostring(failure))
					end
					return finalOrder
				end,
				change = function()
					estimate()
					updateHeader()
				end,
				changeForm = function(formName, principle)
					local previousDraft = draft
					resetForForm(formName, principle, true)
					if draft ~= previousDraft then
						local replacement = draft
						table.clear(previousDraft)
						for key, value in pairs(replacement) do
							previousDraft[key] = value
						end
						draft = previousDraft
					end
					estimate()
				end,
				save = function()
					if saveLibraryButton then
						saveLibraryButton:Activate()
					end
				end,
				keep = function()
					if standaloneDraft then
						standaloneWorkingDraft = Spec.copy(draft)
						lastWorkingDraftKind = "Standalone"
					elseif editingLibraryRecord and editingLibraryId then
						libraryDrafts[editingLibraryId] = Spec.copy(draft)
						lastLibraryDraftId = editingLibraryId
						lastWorkingDraftKind = "Library"
					else
						draftsBySlot[selectedSlot] = Spec.copy(draft)
						dirtySlots[selectedSlot] = true
					end
					dirty = true
					message("Draft kept for this session. Resume it from Home or the Forge tab.", true)
				end,
				load = function()
					libraryView.Selected = nil
					libraryPage("Library")
				end,
				advanced = function()
					authoringMode = if authoringMode == "Expert" then "Guided" else "Expert"
					expertSearch = ""
					rebuild()
				end,
				test = function()
					apply(true)
				end,
				equip = if not standaloneDraft and not editingLibraryRecord
					then function()
						apply(false)
					end
					else nil,
				equipLabel = "EQUIP · SLOT " .. tostring(selectedSlot),
				close = function()
					visibility(false)
				end,
				spawnTarget = if trainingRequest and RunService:IsStudio()
					then function()
						trainingRequest:FireServer("SpawnEnemy")
					end
					else nil,
				back = function()
					if standaloneDraft then
						standaloneWorkingDraft = Spec.copy(draft)
						lastWorkingDraftKind = "Standalone"
					elseif editingLibraryRecord and editingLibraryId then
						libraryDrafts[editingLibraryId] = Spec.copy(draft)
					end
					libraryView.Selected = nil
					libraryView.ChoosingSlot = nil
					pageMode = "Slots"
					rebuild()
				end,
			})
			forgeApi = api
			return
		end
		local form = Schema.Forms[draft.Form]
		if not form then
			activeSection = "Setup"
			info("This spell Form has no editor definition yet.")
			updateHeader()
			return
		end
		local effectEvents = effectEventsForDraft()
		if #effectEvents > 0 and not table.find(effectEvents, event) then
			event = form.DefaultEvent or effectEvents[1]
		end
		updateHeader()
		panel:SetAttribute("SpellSummary", draft.Name .. "\n" .. draft.Form .. "  ·  " .. draft.Element)
		if editorPreview then
			SpellVisual.render(editorPreview, draft, false)
		end
		-- Editor sections run only hosted inside the Spell Forge inspector
		-- (see renderSections); the forge owns Form choice, search and validation.

		local function showFields(object, fields)
			for _, field in fields do
				renderField(object, field)
			end
		end
		if activeSection == "Setup" or activeSection == "Casting" then
			if activeSection == "Setup" then
				heading("NAME & ORGANIZATION")
				local nameRow = row("Spell name")
				local nameBox = Instance.new("TextBox")
				nameBox.Size = UDim2.new(0.4, 0, 1, 0)
				nameBox.Position = UDim2.new(0.59, 0, 0, 0)
				nameBox.Text = draft.Name
				nameBox.ClearTextOnFocus = false
				nameBox.TextSize = 14
				nameBox.TextColor3 = Theme.Ink
				nameBox.BackgroundColor3 = Theme.Surface
				nameBox.BorderColor3, nameBox.BorderSizePixel = Theme.Border, 1
				nameBox.Parent = nameRow
				nameBox.FocusLost:Connect(function()
					draft.Name = SpellIdentitySpec.normalizeName(nameBox.Text) or draft.Name
					nameBox.Text = draft.Name
					estimate()
					updateHeader()
				end)
				tagList(
					"Spell tags",
					draft,
					"Tags",
					"Optional labels to organize spells, such as fire or support. These do not add effects. Up to 16 tags, 48 characters each."
				)
				select(
					"Element",
					draft.Element,
					Schema.Elements,
					function(value)
						draft.Element = value
						draft.Visual.Color = Elements[value]
					end,
					nil,
					"If the spell deals Elemental damage, this decides which resistance protects the target: Fire resistance reduces Fire damage, for example. It also sets the main color. Choosing an Element does not add damage or burning; add effects separately."
				)
			end
			if activeSection == "Casting" then
				heading("CASTING STYLE")
				local castStyles = { "Instant", "Charged", "HoldAndRelease" }
				if CastingSpec.supportsChannel(draft.Form) then
					table.insert(castStyles, "Channeled")
				end
				if CastingSpec.supportsToggle(draft.Form) then
					table.insert(castStyles, "Toggle")
				end
				if CastingSpec.supportsCommandCast(draft.Form) then
					table.insert(castStyles, "CommandCast")
				end
				if CastingSpec.supportsSustained(draft.Form) then
					table.insert(castStyles, "Sustained")
				end
				select(
					"Cast style",
					draft.Casting.Mode,
					castStyles,
					function(value)
						local previousMode = draft.Casting.Mode
						draft.Casting.Mode = value
						if value ~= "Instant" and draft.Beam and draft.Beam.Pattern == "Cascade" then
							draft.Beam.Pattern = "Single"
						end
						if CastingSpec.isChargeMode(value) then
							draft.Casting.MinimumCharge = 0.2
							draft.Casting.MaximumCharge = 1.2
							if CastingSpec.isHeldMode(previousMode) then
								draft.Casting.ManaUpkeepPerSecond = nil
								draft.Casting.StrainPerSecond = nil
							end
							if draft.Form == "Beam" or draft.Form == "Wave" then
								draft.Lifetime = { Mode = "Instantaneous" }
								draft.Casting.ManaUpkeepPerSecond = nil
								draft.Casting.StrainPerSecond = nil
							end
						elseif value == "Channeled" then
							draft.Casting.MinimumCharge = nil
							draft.Casting.MaximumCharge = nil
							draft.Casting.ChargeScaling = nil
							draft.Casting.ManaUpkeepPerSecond = 45
							draft.Lifetime = { Mode = "FixedDuration", Duration = 5 }
						elseif value == "Toggle" then
							local endWhen = draft.Lifetime.EndWhen
							draft.Casting.MinimumCharge = nil
							draft.Casting.MaximumCharge = nil
							draft.Casting.ChargeScaling = nil
							if CastingSpec.isHeldMode(previousMode) then
								draft.Casting.ManaUpkeepPerSecond = nil
								draft.Casting.StrainPerSecond = nil
							end
							draft.Lifetime = { Mode = "UntilToggledOff", EndWhen = endWhen }
						elseif value == "CommandCast" then
							draft.Casting.MinimumCharge = nil
							draft.Casting.MaximumCharge = nil
							draft.Casting.ChargeScaling = nil
							if CastingSpec.isHeldMode(previousMode) then
								draft.Casting.ManaUpkeepPerSecond = nil
								draft.Casting.StrainPerSecond = nil
							end
							if draft.Form == "Beam" or draft.Form == "Wave" then
								draft.Lifetime = { Mode = "Instantaneous" }
							end
						elseif value == "Sustained" then
							draft.Casting.MinimumCharge = nil
							draft.Casting.MaximumCharge = nil
							draft.Casting.ChargeScaling = nil
							if CastingSpec.isHeldMode(previousMode) then
								draft.Casting.ManaUpkeepPerSecond = nil
								draft.Casting.StrainPerSecond = nil
							end
							draft.Casting.ManaUpkeepPerSecond = 45
							draft.Lifetime = { Mode = "FixedDuration", Duration = 5 }
						else
							draft.Casting.MinimumCharge = nil
							draft.Casting.MaximumCharge = nil
							draft.Casting.ChargeScaling = nil
							if CastingSpec.isHeldMode(previousMode) then
								draft.Casting.ManaUpkeepPerSecond = nil
								draft.Casting.StrainPerSecond = nil
							end
							if draft.Form == "Beam" or draft.Form == "Wave" then
								draft.Lifetime = { Mode = "Instantaneous" }
								draft.Casting.ManaUpkeepPerSecond = nil
								draft.Casting.StrainPerSecond = nil
							end
						end
					end,
					nil,
					"Instant resolves on press. Charged auto-releases at full charge; HoldAndRelease waits for key-up at full charge (up to 8 seconds). Channeled repeats while held. Sustained holds a Construct in the world until release or expiry. Toggle starts a supported persistent effect; cast the same slot again to stop it. CommandCast is summon-only and runs on owner Attack/Support orders."
				)
				if draft.Casting.Mode == "CommandCast" then
					info(
						"Assign this spell through a Summon payload's companion slot. Summons wait without acquiring targets until you issue Attack or Support. Direct player casting is rejected by the server.",
						48
					)
				end
				toggle("Interrupt windup if damaged", draft.Casting.InterruptOnDamage == true, function(value)
					draft.Casting.InterruptOnDamage = value
				end, "Cancels a charged or gathering cast if the caster takes health damage before release.")
				numeric(
					"Movement interrupt distance (0 disables)",
					draft.Casting,
					"InterruptMoveDistance",
					"Cancels a gathering cast if the caster moves farther than this many studs before it resolves."
				)
				toggle(
					"Allow movement while casting",
					draft.Casting.CanMoveWhileCasting ~= false,
					function(value)
						draft.Casting.CanMoveWhileCasting = value
					end,
					"When off, the server temporarily prevents walking, jumping, and dashing during charge, gather, and held channels."
				)
				numeric(
					"Movement penalty (0–0.9)",
					draft.Casting,
					"MovementPenalty",
					"Reduces normal and sprint speed by this fraction while casting when movement is allowed. It composes with sprint and Body Enhancement."
				)
				toggle(
					"Allow rotation while casting",
					draft.Casting.CanRotateWhileCasting ~= false,
					function(value)
						draft.Casting.CanRotateWhileCasting = value
					end,
					"Turn off to lock your aim while preparing or holding this spell. Turn on to keep aiming as you cast."
				)
				toggle("Requires a free hand", draft.Casting.RequiresFreeHand == true, function(value)
					draft.Casting.RequiresFreeHand = value
				end, "When on, you need at least one free hand to start and keep using this spell.")
				heading("SPECIAL RESOURCE COSTS")
				info(
					"Optional named resource costs are separate from Mana and Strain. The server checks and spends each configured pool when this spell is cast.",
					44
				)
				draft.Cost.SpecialResources = draft.Cost.SpecialResources or {}
				for _, resourceId in ipairs(SpecialResourceSpec.order(SpecialResourceDefinitions)) do
					local resource = SpecialResourceDefinitions[resourceId]
					numeric(
						resource.Label .. " cost (0 disables)",
						draft.Cost.SpecialResources,
						resourceId,
						"Spends this amount from the caster's "
							.. resource.Label
							.. " pool. Current pool value is available as the "
							.. resource.Attribute
							.. " player attribute."
					)
				end
				heading("ENVIRONMENT REQUIREMENTS")
				info(
					"Optional server-checked cast limits. Zone tags come from tagged MagicEnvironmentZone parts; time windows may cross midnight.",
					48
				)
				draft.EnvironmentRequirements = draft.EnvironmentRequirements or {}
				local environmentRequirements = draft.EnvironmentRequirements
				toggle("Require solid ground", environmentRequirements.RequireGrounded == true, function(value)
					environmentRequirements.RequireGrounded = if value then true else nil
				end, "Rejects casts while the caster is airborne.")
				toggle(
					"Limit by time of day",
					environmentRequirements.ClockTime ~= nil,
					function(value)
						environmentRequirements.ClockTime = if value then { Start = 6, End = 18 } else nil
					end,
					"Uses Lighting.ClockTime from the server. If the start is later than the end, the window crosses midnight."
				)
				if environmentRequirements.ClockTime then
					numeric(
						"Time window start (0–24)",
						environmentRequirements.ClockTime,
						"Start",
						"Inclusive Roblox clock hour."
					)
					numeric(
						"Time window end (0–24)",
						environmentRequirements.ClockTime,
						"End",
						"Inclusive Roblox clock hour."
					)
				end
				environmentRequirements.ZoneTags = environmentRequirements.ZoneTags or { Required = {}, Forbidden = {} }
				tagList(
					"Required zone tags",
					environmentRequirements.ZoneTags,
					"Required",
					"Comma-separated tags that must exist on the caster's current MagicEnvironmentZone."
				)
				tagList(
					"Forbidden zone tags",
					environmentRequirements.ZoneTags,
					"Forbidden",
					"Comma-separated tags that block casting in matching zones."
				)
				if CastingSpec.isChargeMode(draft.Casting.Mode) then
					info(
						if draft.Casting.Mode == "Charged"
							then "The spell releases automatically at maximum charge."
							else "The spell holds at maximum charge until key-up; it cancels if not released within 8 seconds.",
						38
					)
					numeric(
						"Minimum charge time",
						draft.Casting,
						"MinimumCharge",
						"Minimum hold time before the spell can be released."
					)
					numeric(
						"Maximum charge time",
						draft.Casting,
						"MaximumCharge",
						"Charged releases at this time; HoldAndRelease waits here until you release the key."
					)
					select(
						"Charge scales power",
						if draft.Casting.ChargeScaling then "On" else "Off",
						{ "Off", "On" },
						function(choice)
							draft.Casting.ChargeScaling = if choice == "On"
								then (draft.Casting.ChargeScaling or { MinPotency = 1, MaxPotency = 2 })
								else nil
						end,
						nil,
						"Holding longer multiplies the spell's power, from the minimum at minimum charge to the maximum at full charge (0.25x to 5x)."
					)
					if draft.Casting.ChargeScaling then
						numeric(
							"Power at minimum charge",
							draft.Casting.ChargeScaling,
							"MinPotency",
							"Multiplier when released at the minimum charge time. Allowed: 0.25 to 5."
						)
						numeric(
							"Power at full charge",
							draft.Casting.ChargeScaling,
							"MaxPotency",
							"Multiplier at the maximum charge time. Allowed: 0.25 to 5; the cost is priced at this value."
						)
						if draft.Form == "Projectile" then
							numeric(
								"Extra projectiles at full charge",
								draft.Casting.ChargeScaling,
								"MaxExtraProjectiles",
								"Fires floor(charge x this) more projectiles, fanned out like Spread. Whole number, 0 to "
									.. Config.MaxSpawnCount
									.. "; the cost is priced at the full count."
							)
						end
					end
				end
				if
					LifetimeSpec.supports(draft.Form, "UntilToggledOff")
					and draft.Casting.Mode ~= "Channeled"
					and draft.Casting.Mode ~= "Toggle"
					and draft.Casting.Mode ~= "Sustained"
				then
					toggle("Remain active until toggled off", draft.Lifetime.Mode == "UntilToggledOff", function(value)
						local endWhen = draft.Lifetime.EndWhen
						draft.Lifetime = if value
							then { Mode = "UntilToggledOff", EndWhen = endWhen }
							else { Mode = "FixedDuration", Duration = 10, EndWhen = endWhen }
					end, "Fields, Auras, Enchantments, and Constructs stay active until you cast the same spell again.")
				end
				if
					LifetimeSpec.supports(draft.Form, "UntilDestroyed")
					and not CastingSpec.isHeldMode(draft.Casting.Mode)
				then
					local destroyedLabel = if draft.Form == "Construct"
						then "Remain active until the Construct is destroyed"
						else "Remain active until the area marker is destroyed"
					local destroyedHelp = if draft.Form == "Construct"
						then "The server keeps this Construct until its model is removed, the caster is cleaned up, or another active lifetime condition ends it."
						else "The server keeps this Field/Aura active until its world marker is removed, the caster is cleaned up, or another active lifetime condition ends it."
					toggle(destroyedLabel, draft.Lifetime.Mode == "UntilDestroyed", function(value)
						local endWhen = draft.Lifetime.EndWhen
						draft.Lifetime = if value
							then { Mode = "UntilDestroyed", EndWhen = endWhen }
							else { Mode = "FixedDuration", Duration = 10, EndWhen = endWhen }
					end, destroyedHelp)
				end
				if draft.Form == "Construct" and not CastingSpec.isHeldMode(draft.Casting.Mode) then
					toggle(
						"Persist in this place between servers",
						draft.Lifetime.Mode == "Persistent",
						function(value)
							draft.Lifetime = if value
								then { Mode = "Persistent" }
								else { Mode = "FixedDuration", Duration = 10 }
						end,
						"Saves this static Construct to this place's server DataStore and restores it when a server starts. It has no gameplay triggers; destroy its model in Workspace to remove the saved record."
					)
				end
				if
					LifetimeSpec.supports(draft.Form, "UntilResourceDepleted")
					and not CastingSpec.isHeldMode(draft.Casting.Mode)
				then
					toggle(
						"Remain active until mana is depleted",
						draft.Lifetime.Mode == "UntilResourceDepleted",
						function(value)
							local endWhen = draft.Lifetime.EndWhen
							draft.Lifetime = if value
								then { Mode = "UntilResourceDepleted", EndWhen = endWhen }
								else { Mode = "FixedDuration", Duration = 10, EndWhen = endWhen }
						end,
						"The server pays mana upkeep while active and runs this Form's normal expiry cleanup when mana runs out. Set Mana upkeep per second above zero."
					)
				end
				local conditionBoundChannel = draft.Casting.Mode == "Channeled"
				if
					LifetimeSpec.supports(draft.Form, "UntilConditionFails")
					and (not CastingSpec.isHeldMode(draft.Casting.Mode) or conditionBoundChannel)
				then
					toggle(
						"Remain active while a condition stays true",
						draft.Lifetime.Mode == "UntilConditionFails",
						function(value)
							local endWhen = draft.Lifetime.EndWhen
							local duration = if draft.Lifetime.Mode == "UntilConditionFails"
								then draft.Lifetime.Duration
								else nil
							if value and endWhen == nil then
								endWhen = { Family = "Resource", Property = "Mana", Operator = ">", Value = 0 }
							end
							draft.Lifetime = if value
								then {
									Mode = "UntilConditionFails",
									EndWhen = endWhen,
									Duration = if draft.Form == "Projectile"
										then duration or 3
										elseif conditionBoundChannel then duration or 10
										else duration,
								}
								else { Mode = "FixedDuration", Duration = 10, EndWhen = endWhen }
						end,
						"This active effect is kept alive only while its server-checked condition remains true. The condition must already be true when you cast."
					)
				end
				local canEndOnTargetLoss = LifetimeSpec.supportsTargeting(
					draft.Form,
					"UntilTargetLost",
					draft.Targeting,
					draft.Form == "Field" and draft.Field.FollowTarget == true,
					draft.TargetPolicy == "MaintainTarget"
				)
				if canEndOnTargetLoss and not CastingSpec.isHeldMode(draft.Casting.Mode) then
					toggle(
						"Remain active until its target is lost",
						draft.Lifetime.Mode == "UntilTargetLost",
						function(value)
							local endWhen = draft.Lifetime.EndWhen
							draft.Lifetime = if value
								then { Mode = "UntilTargetLost", EndWhen = endWhen }
								else { Mode = "FixedDuration", Duration = 10, EndWhen = endWhen }
						end,
						"Follow the selected character/object and run ordinary expiry cleanup when it is removed or no longer valid. Fields require Follow selected target to be enabled."
					)
				end
				if draft.Lifetime.Mode == "FixedDuration" then
					numeric(
						"Active duration (seconds)",
						draft.Lifetime,
						"Duration",
						"How long this enchantment remains active after casting."
					)
				elseif draft.Lifetime.Mode == "UntilConditionFails" then
					if draft.Form == "Projectile" or conditionBoundChannel then
						numeric(
							if draft.Form == "Projectile"
								then "Maximum flight time (seconds)"
								else "Maximum channel duration (seconds)",
							draft.Lifetime,
							"Duration",
							if draft.Form == "Projectile"
								then "Hard safety cap for this projectile, even while its keep-alive condition remains true."
								else "Hard safety cap for this channel, even while its keep-alive condition remains true."
						)
					else
						toggle(
							"Also expire after a maximum duration",
							draft.Lifetime.Duration ~= nil,
							function(value)
								draft.Lifetime.Duration = if value then 10 else nil
							end,
							"Combine the keep-alive condition with a hard time limit. Either ending rule expires the effect."
						)
						if draft.Lifetime.Duration ~= nil then
							numeric(
								"Maximum active duration (seconds)",
								draft.Lifetime,
								"Duration",
								"The first of this timer or the keep-alive condition ending expires the effect."
							)
						end
					end
				end
				if draft.Lifetime.Mode ~= "Instantaneous" and draft.Lifetime.Mode ~= "Persistent" then
					local endRule = draft.Lifetime.EndWhen
					local simpleRule = endRule and endRule.Operator == nil and endRule.Family ~= nil
					local mustRemainTrue = draft.Lifetime.Mode == "UntilConditionFails"
					if mustRemainTrue then
						info(
							"Required keep-alive condition: this spell can only start while the condition is true, then expires when it becomes false.",
							42
						)
					else
						toggle("End when a condition is met", endRule ~= nil, function(value)
							if value then
								draft.Lifetime.EndWhen = endRule
									or {
										Family = "Caster",
										Property = "HealthPercent",
										Operator = "<=",
										Value = 0.25,
									}
							else
								draft.Lifetime.EndWhen = nil
							end
						end, "The effect checks this server-side while active, then runs its normal expiry cleanup.")
					end
					if endRule and simpleRule then
						local propertyOptions = {}
						for familyName, family in ConditionSpec.Properties do
							if ConditionSpec.EndConditionFamilies[familyName] then
								for propertyName, descriptor in family do
									if
										descriptor.Kind == "Number"
										or descriptor.Kind == "Boolean"
										or descriptor.Kind == "String"
									then
										table.insert(propertyOptions, { Family = familyName, Property = propertyName })
									end
								end
							end
						end
						table.sort(propertyOptions, function(a, b)
							return a.Family == b.Family and a.Property < b.Property or a.Family < b.Family
						end)
						select(
							"Condition",
							{ Family = endRule.Family, Property = endRule.Property },
							propertyOptions,
							function(option)
								local descriptor = ConditionSpec.Properties[option.Family][option.Property]
								draft.Lifetime.EndWhen = {
									Family = option.Family,
									Property = option.Property,
									Operator = if descriptor.Kind == "Number" then "<=" else "==",
									Value = if descriptor.Kind == "Number"
										then (descriptor.Min or 0)
										elseif descriptor.Kind == "Boolean" then true
										else "",
								}
							end,
							function(option)
								return option.Family .. " · " .. option.Property
							end
						)
						local descriptor = ConditionSpec.Properties[endRule.Family]
							and ConditionSpec.Properties[endRule.Family][endRule.Property]
						if descriptor then
							select("Comparison", endRule.Operator, descriptor.Operators, function(option)
								endRule.Operator = option
							end)
							if descriptor.Kind == "Number" then
								numeric("Value", endRule, "Value", "Compare against this number.")
							elseif descriptor.Kind == "Boolean" then
								toggle("Value is true", endRule.Value == true, function(value)
									endRule.Value = value
								end)
							else
								local valueRow = row("Text value")
								local box = Instance.new("TextBox")
								box.Size = UDim2.new(0.4, 0, 1, 0)
								box.Position = UDim2.new(0.59, 0, 0, 0)
								box.BackgroundColor3 = Theme.Surface
								box.TextColor3 = Theme.Ink
								box.BorderColor3, box.BorderSizePixel = Theme.Border, 1
								box.TextSize = 14
								box.ClearTextOnFocus = false
								box.Text = tostring(endRule.Value or "")
								box.Parent = valueRow
								box.FocusLost:Connect(function()
									endRule.Value = string.sub(box.Text, 1, descriptor.MaxLength)
									revision += 1
									dirty = true
								end)
							end
						end
					elseif endRule then
						info(
							if mustRemainTrue
								then "This saved keep-alive condition uses a grouped rule. Edit its condition tree in the Conditions section."
								else "This saved condition uses a grouped rule. Disable it to replace it with a single editable condition.",
							42
						)
					end
				end
			end
		end
		if activeSection == "Setup" then
			heading("FORM SETTINGS · SIZE, REACH & MOVEMENT")
			if draft.Form == "Field" or draft.Form == "Aura" then
				local area = draft[draft.Form]
				select("Area geometry", draft.Geometry, form.GeometryOptions, function(shape)
					local interval = area.Interval
					local yaw = area.Yaw or 0
					local followTarget = area.FollowTarget == true
					local debugHeight = if draft.Form == "Field" then area.DebugHeight else nil
					draft.Geometry = shape
					if shape == "Sphere" then
						area = { Radius = 8, Interval = interval, Yaw = yaw, FollowTarget = followTarget }
					elseif shape == "Capsule" then
						area = { Radius = 3, Height = 14, Interval = interval, Yaw = yaw, FollowTarget = followTarget }
					elseif shape == "Cylinder" then
						area = { Radius = 8, Height = 6, Interval = interval, Yaw = yaw, FollowTarget = followTarget }
					elseif shape == "Cone" then
						area = {
							Range = 12,
							Angle = 70,
							Height = 6,
							Interval = interval,
							Yaw = yaw,
							FollowTarget = followTarget,
						}
					elseif shape == "Ring" then
						area = {
							InnerRadius = 3,
							OuterRadius = 8,
							Height = 6,
							Interval = interval,
							Yaw = yaw,
							FollowTarget = followTarget,
						}
					elseif shape == "Plane" then
						area = {
							Width = 12,
							Height = 8,
							Thickness = 1,
							Interval = interval,
							Yaw = yaw,
							FollowTarget = followTarget,
						}
					elseif shape == "Line" then
						area = {
							Width = 4,
							Height = 6,
							Range = 16,
							Interval = interval,
							Yaw = yaw,
							FollowTarget = followTarget,
						}
					else
						area = {
							Width = 12,
							Height = 6,
							Depth = 12,
							Interval = interval,
							Yaw = yaw,
							FollowTarget = followTarget,
						}
					end
					if draft.Form == "Field" then
						area.DebugHeight = debugHeight or 0.2
						local previous = draft.Field
						area.ArmDelay, area.Hidden, area.ConsumeOnTrigger, area.AffectsSpells =
							previous.ArmDelay, previous.Hidden, previous.ConsumeOnTrigger, previous.AffectsSpells
					end
					draft[draft.Form] = area
				end, nil, "Choose the server hit shape. Visual scale does not change these dimensions.")
				if draft.Geometry == "Sphere" then
					numeric("Radius", area, "Radius")
				elseif draft.Geometry == "Capsule" then
					numeric("Radius", area, "Radius", "Radius of the rounded ends and cylindrical center.")
					numeric(
						"Overall height",
						area,
						"Height",
						"Total height including both rounded ends. Must be at least twice the radius."
					)
				elseif draft.Geometry == "Cylinder" then
					numeric("Radius", area, "Radius")
					numeric("Height", area, "Height")
				elseif draft.Geometry == "Cone" then
					numeric("Reach", area, "Range", "Forward distance from the area origin.")
					numeric("Angle", area, "Angle", "Full horizontal cone angle in degrees (5–120).")
					numeric("Height", area, "Height", "Vertical thickness of the cone volume.")
				elseif draft.Geometry == "Ring" then
					numeric("Safe center radius", area, "InnerRadius", "Targets inside this radius are excluded.")
					numeric("Outer radius", area, "OuterRadius", "Maximum distance from the center affected.")
					numeric("Height", area, "Height", "Vertical thickness of the ring volume.")
				elseif draft.Geometry == "Plane" then
					numeric("Width", area, "Width", "Horizontal width of the vertical hit volume.")
					numeric("Height", area, "Height", "Vertical height of the hit volume.")
					numeric("Thickness", area, "Thickness", "Depth of the hit volume; this does not block movement.")
				elseif draft.Geometry == "Line" then
					numeric("Corridor width", area, "Width", "Side-to-side width of the forward corridor.")
					numeric("Corridor height", area, "Height", "Vertical thickness of the forward corridor.")
					numeric("Reach", area, "Range", "Forward distance from the area origin.")
				else
					numeric("Width", area, "Width")
					numeric("Height", area, "Height")
					numeric("Depth", area, "Depth")
				end
				numeric("Pulse interval", area, "Interval")
				if
					draft.Geometry == "Box"
					or draft.Geometry == "Cone"
					or draft.Geometry == "Plane"
					or draft.Geometry == "Line"
				then
					numeric(
						"Yaw (degrees)",
						area,
						"Yaw",
						"Rotate the hit volume around world vertical (-180° to 180°)."
					)
				end
				if draft.Form == "Field" then
					if draft.Targeting == "EntityTarget" or draft.Targeting == "ObjectTarget" then
						toggle(
							"Follow selected target",
							area.FollowTarget == true,
							function(value)
								area.FollowTarget = value
								if not value and draft.Lifetime.Mode == "UntilTargetLost" then
									draft.Lifetime = {
										Mode = "FixedDuration",
										Duration = 10,
										EndWhen = draft.Lifetime.EndWhen,
									}
								end
								dirty = true
								revision += 1
								estimate()
							end,
							"Attach this Field to the selected character or surface. It ends safely if that target is removed or invalidated."
						)
					end
					numeric(
						"Debug marker height",
						area,
						"DebugHeight",
						"Presentation only; it does not change hit detection."
					)
					heading("TRAP")
					numeric(
						"Arm delay (seconds)",
						area,
						"ArmDelay",
						"Entering, leaving and pulse effects wait this long after placement. Allowed: 0 to "
							.. Config.MaxTrapArmDelay
					)
					toggle(
						"Hidden from opponents",
						area.Hidden == true,
						function(value)
							area.Hidden = value
							dirty = true
							revision += 1
						end,
						"Players who can fight you are never sent its marker; you and your allies still see it. A hidden Field cannot follow a target or grow."
					)
					toggle(
						"Ends when triggered",
						area.ConsumeOnTrigger == true,
						function(value)
							area.ConsumeOnTrigger = value
							dirty = true
							revision += 1
						end,
						"The first time a target enters (after arming), its entering effects run and then the Field ends."
					)
					heading("LENS")
					local lens = area.AffectsSpells
					select(
						"Changes projectiles crossing it",
						if lens then lens.Who else "Off",
						{ "Off", "Hostile", "Allied", "Any" },
						function(value)
							if value == "Off" then
								area.AffectsSpells = nil
							elseif lens then
								lens.Who = value
							else
								area.AffectsSpells = { Who = value, Slow = 0.7 }
							end
						end,
						nil,
						"Whose projectiles it changes as they fly through, once per projectile per Field."
					)
					if lens then
						local marks = { "None" }
						for _, element in Schema.MarkElements do
							table.insert(marks, element)
						end
						select("Adds a mark", lens.AddMark or "None", marks, function(value)
							lens.AddMark = if value == "None" then nil else value
						end, nil, "The projectile marks what it hits with this element.")
						numeric(
							"Potency (x)",
							lens,
							"ScalePotency",
							"Allowed: 0.5 to 1.5; clear for no change. Against players: at least 0.7 (0.8 ranked)."
						)
						numeric(
							"Speed (x)",
							lens,
							"Slow",
							"Allowed: 0.3 to 1; clear for no change. Against players: at least 0.6 (0.7 ranked)."
						)
					end
				end
			elseif draft.Form == "Construct" then
				select(
					"Construct geometry",
					draft.Geometry,
					form.GeometryOptions,
					function(shape)
						draft.Geometry = shape
						if shape == "Custom" and #(draft.Construct.Components or {}) == 0 then
							draft.Construct.Components = { Spec.copy(ConstructGeometrySpec.DefaultCustomComponent) }
						end
					end,
					nil,
					"Choose a primitive or bounded multi-part template. Width, Height, and Depth set its overall size."
				)
				showFields(draft.Construct, form.Mechanics)
				if draft.Construct.GrowthDuration and draft.Construct.GrowthDuration > 0 then
					info(
						"The solid construct grows over time. The server pauses growth when its expanded collision bounds would enter another solid or character.",
						42
					)
				end
				if draft.Geometry == "Custom" then
					draft.Construct.Components = draft.Construct.Components or {}
					info(
						"Compose up to five primitive parts inside the Construct envelope. Size and offset values are fractions of its Width, Height, and Depth; rotated bounds must stay inside the envelope.",
						48
					)
					for index, component in ipairs(draft.Construct.Components) do
						heading("CUSTOM PART " .. index)
						local componentRow = row("Primitive")
						button(componentRow, "REMOVE", function()
							table.remove(draft.Construct.Components, index)
							dirty = true
							revision += 1
							rebuild()
							estimate()
						end)
						select("Part shape", component.Shape, ConstructGeometrySpec.PrimitiveOrder, function(value)
							component.Shape = value
						end)
						for axis, label in ipairs({ "X", "Y", "Z" }) do
							numeric(
								label .. " size fraction",
								component,
								"Size" .. label,
								"Part dimension as a fraction of the matching envelope dimension (0.05–1)."
							)
							numeric(
								label .. " center offset",
								component,
								"Offset" .. label,
								"Part center as a fraction of the envelope dimension (-0.5–0.5)."
							)
							numeric(
								label .. " rotation",
								component,
								"Rotation" .. label,
								"Part rotation in degrees (-180–180)."
							)
						end
						local componentDuration = component.Duration ~= nil
						card(
							"Independent part expiry",
							"Expire this primitive before the rest of the Construct.",
							componentDuration,
							function(enabled)
								component.Duration = if enabled then 3 else nil
							end
						)
						if componentDuration then
							numeric(
								"Part lifetime (seconds)",
								component,
								"Duration",
								"This primitive disappears independently after 0.1–"
									.. ConstructGeometrySpec.MaxComponentLifetime
									.. " seconds. Blank it to inherit the Construct lifetime."
							)
						end
					end
					local customComponents = draft.Construct.Components
					local addComponentRow = row("Add custom primitive")
					button(
						addComponentRow,
						#customComponents < ConstructGeometrySpec.MaxCustomComponents and "ADD PART" or "LIMIT",
						function()
							if #customComponents >= ConstructGeometrySpec.MaxCustomComponents then
								return
							end
							table.insert(customComponents, Spec.copy(ConstructGeometrySpec.DefaultCustomComponent))
							dirty = true
							rebuild()
							estimate()
						end
					)
				end
			elseif draft.Form == "Beam" then
				select(
					"Beam pattern",
					draft.Beam.Pattern or "Single",
					if draft.Casting.Mode == "Instant" then { "Single", "Cascade" } else { "Single" },
					function(pattern)
						draft.Beam.Pattern = pattern
						dirty = true
					end,
					nil,
					"Single is one aimed Beam. Cascade sends a short, server-timed sequence of vertical Beams around the aim point. Every strike uses world obstruction and the same OnImpact effects."
				)
				local fields = {}
				for _, field in form.Mechanics do
					if field.Key == "Range" or field.Key == "Width" or field.Key == "DebugDuration" then
						table.insert(fields, field)
					elseif field.Key == "Interval" and draft.Casting.Mode == "Channeled" then
						table.insert(fields, field)
					elseif
						field.Key == "GrowthStartScale"
						or field.Key == "GrowthEndScale"
						or field.Key == "GrowthDuration"
					then
						if draft.Casting.Mode == "Channeled" then
							table.insert(fields, field)
						end
					elseif field.Key == "Pattern" then
						-- Pattern is selected above so its help stays visible without duplicating the selector.
					elseif draft.Beam.Pattern == "Cascade" and draft.Casting.Mode == "Instant" then
						table.insert(fields, field)
					end
				end
				showFields(draft.Beam, fields)
			elseif draft.Form == "Wave" then
				select(
					"Wave shape",
					draft.Geometry,
					form.GeometryOptions,
					function(shape)
						draft.Geometry = shape
						revision += 1
						dirty = true
					end,
					nil,
					"Cone follows your aim. Sphere reaches equally in every direction for Humanoid targets. ObjectTarget continues to use its validated aim ray."
				)
				local fields = {}
				for _, field in form.Mechanics do
					if field.Key ~= "Dot" or draft.Geometry == "Cone" then
						if field.Key ~= "Interval" or draft.Casting.Mode == "Channeled" then
							table.insert(fields, field)
						end
					end
				end
				showFields(draft.Wave, fields)
			elseif #form.Mechanics > 0 then
				for _, field in form.Mechanics do
					if
						(field.Key ~= "Interval" and field.Key ~= "ChannelInterval")
						or draft.Casting.Mode == "Channeled"
						or draft.Form == "Field"
						or draft.Form == "Aura"
						or draft.Form == "Tether"
					then
						showFields(draft[field.Object], { field })
					end
				end
			else
				info("This Form has no extra shape or movement settings.", 38)
			end
		elseif activeSection == "Targeting" then
			heading("TARGETING")
			info(form.Description, 48)
			heading("TARGETING MODES")
			for _, mode in Schema.TargetingModeOrder do
				local definition = Schema.TargetingModes[mode]
				local available = form.Targeting[mode] == true
				local unavailableReason = "This Form does not support this targeting mode."
				local materialObjectTarget = mode == "ObjectTarget"
					and draft.Form ~= "Construct"
					and draft.Form ~= "Field"
					and draft.Form ~= "Aura"
				local objectPhysicsTarget = mode == "ObjectTarget"
					and (draft.Form == "Projectile" or draft.Form == "Beam" or draft.Form == "Wave")
				if mode == "MaterialTarget" or (materialObjectTarget and not objectPhysicsTarget) then
					available = available and #MaterialSpec.options("Matter", "Earth", draft.Form, mode) > 0
					if form.Targeting[mode] and not available then
						unavailableReason = "This Form cannot act on this kind of tagged material object."
					end
				end
				card(definition.Label, definition.Description, draft.Targeting == mode, function()
					draft.Targeting = mode
					if mode == "MaterialTarget" or (mode == "ObjectTarget" and draft.Form == "Manipulation") then
						setInternalDefault("Matter", "Earth")
					end
					draft.TargetPolicy = if mode == "EntityTarget" then "Aim" else nil
					if
						not LifetimeSpec.supportsTargeting(
							draft.Form,
							draft.Lifetime.Mode,
							mode,
							draft.Form == "Field" and draft.Field.FollowTarget == true
						)
					then
						local endWhen = draft.Lifetime.EndWhen
						draft.Lifetime = { Mode = "FixedDuration", Duration = 10, EndWhen = endWhen }
					end
					if mode == "ObjectTarget" and draft.Form == "Manipulation" then
						draft.Material = if hasPayloadAnywhere("Manipulation")
							then {
								Material = MaterialSpec.options("Matter", "Earth", draft.Form, mode)[1],
								SearchRadius = 12,
							}
							else { SearchRadius = 12 }
					elseif objectPhysicsTarget then
						local options = MaterialSpec.options("Matter", "Earth", draft.Form, mode)
						draft.Material = if hasPayloadAnywhere("Manipulation") and options[1]
							then { Material = options[1], SearchRadius = 12 }
							else nil
					elseif
						mode == "ObjectTarget"
						and (draft.Form == "Construct" or draft.Form == "Field" or draft.Form == "Aura")
					then
						draft.Material = nil
					elseif mode == "MaterialTarget" or mode == "ObjectTarget" then
						draft.Material = {
							Material = MaterialSpec.options("Matter", "Earth", draft.Form, mode)[1],
							Amount = if draft.Form ~= "Manipulation" then 1 else nil,
							SearchRadius = 12,
						}
					else
						draft.Material = nil
					end
				end, available, unavailableReason)
			end
			if draft.Targeting == "EntityTarget" then
				local targetPolicies = if draft.Form == "Projectile"
					then Schema.TargetPolicyOrder
					else { "Aim", "LockOn", "AimOrLockOn" }
				select("Entity target policy", draft.TargetPolicy or "Aim", targetPolicies, function(value)
					draft.TargetPolicy = value
					if value ~= "MaintainTarget" and draft.Lifetime.Mode == "UntilTargetLost" then
						draft.Lifetime = {
							Mode = "FixedDuration",
							Duration = draft.Lifetime.Duration or 3,
							EndWhen = draft.Lifetime.EndWhen,
						}
					end
				end, function(value)
					return value
				end, Schema.TargetPolicies[draft.TargetPolicy or "Aim"])
				if draft.TargetPolicy == "MaintainTarget" then
					info(
						"Requires Homing. The projectile keeps the selected target without reacquiring; choose UntilTargetLost if it should expire when the target disappears.",
						42
					)
				end
			end
			if
				draft.Targeting == "ObjectTarget"
				and (draft.Form == "Projectile" or draft.Form == "Beam" or draft.Form == "Wave")
			then
				info(
					"The server affects only the exact authorized object under your aim, within TargetRules and Form reach. Force and Physical control need a movable tagged part. Material manipulation uses only Raise and also needs matching MagicMaterial and MagicRaise authorization.",
					48
				)
			end
			if draft.Material then
				local genericObjectPhysicsTarget = (
					draft.Form == "Manipulation"
					or draft.Form == "Projectile"
					or draft.Form == "Beam"
					or draft.Form == "Wave"
				)
					and draft.Targeting == "ObjectTarget"
					and draft.Material.Material == nil
				if genericObjectPhysicsTarget then
					info(
						"Force and Physical control can target a movable, non-character part tagged MagicManipulable. The server checks reach, aim, and obstruction.",
						48
					)
					numeric(
						"Movable object reach",
						draft.Material,
						"SearchRadius",
						"Maximum distance to the exact selected object; the server checks aim and obstruction."
					)
				else
					local materialOptions = MaterialSpec.options("Matter", "Earth", draft.Form, draft.Targeting)
					if #materialOptions > 0 then
						select(
							"Required material",
							draft.Material.Material,
							materialOptions,
							function(value)
								draft.Material.Material = value
							end,
							MaterialSpec.label,
							if draft.Targeting == "ObjectTarget"
								then "The selected part must carry this exact MagicMaterial tag and MagicRaise authorization."
								else "A nearby tagged object must have this material type and enough remaining amount."
						)
					else
						info("This Form and target mode have no compatible tagged material objects.", 38)
					end
					numeric(
						"Material search radius",
						draft.Material,
						"SearchRadius",
						"How far from the aim point the spell searches for usable material."
					)
					if draft.Targeting == "MaterialTarget" and draft.Form ~= "Manipulation" then
						numeric(
							"Material consumed",
							draft.Material,
							"Amount",
							"Amount of eligible material consumed when this cast succeeds."
						)
					end
				end
			end
			if form.TargetRules then
				heading("TARGET LIMITS")
				numeric(
					"Maximum reach (studs)",
					draft.TargetRules,
					"Range",
					"Farthest distance this spell may affect a target."
				)
				numeric(
					"Maximum targets",
					draft.TargetRules,
					"MaxTargets",
					"How many characters can be affected at once. Repeating spells check again on later pulses."
				)
				toggle("Require clear line of sight", draft.TargetRules.RequiresLineOfSight, function(value)
					draft.TargetRules.RequiresLineOfSight = value
				end, "When enabled, blocking world geometry prevents the spell from reaching a target.")
				select(
					"Target relationship",
					draft.TargetRules.Relationship or "Any",
					Schema.TargetRelationshipOrder,
					function(value)
						draft.TargetRules.Relationship = value
					end,
					function(value)
						return value
					end,
					Schema.TargetRelationships[draft.TargetRules.Relationship or "Any"]
				)
				if form.CanIncludeCaster then
					toggle("Include yourself in this area", draft.TargetRules.IncludeCaster, function(value)
						draft.TargetRules.IncludeCaster = value
					end, "Allows area payloads, including damage or control, to affect your own character.")
				end
				toggle(
					"Require target consent",
					draft.TargetRules.RequiresConsent,
					function(value)
						draft.TargetRules.RequiresConsent = value
					end,
					"When enabled, player characters are affected only if they have opted in. NPCs and training dummies are not gated."
				)
			end
			if draft.Proximity then
				heading("ACTIVE PROXIMITY")
				numeric(
					"Approach radius (studs)",
					draft.Proximity,
					"Radius",
					"Maximum distance from the active Enchantment's caster or Construct where a target can trigger OnProximity."
				)
				numeric(
					"Proximity sample interval (seconds)",
					draft.Proximity,
					"Interval",
					"Minimum time between server target queries for this active effect."
				)
				numeric(
					"Maximum proximity targets",
					draft.Proximity,
					"MaxTargets",
					"Maximum distinct Humanoids that can trigger OnProximity for this active effect."
				)
			end
		elseif activeSection == "Conditions" then
			local applicable = {}
			for _, condition in Schema.Conditions do
				if condition.Forms[draft.Form] then
					table.insert(applicable, condition)
				end
			end
			if #applicable > 0 then
				heading("OPTIONAL CAST RULES")
				if draft.Conditions.Operator == nil then
					for _, condition in applicable do
						local enabled = table.find(draft.Conditions, condition.Id) ~= nil
						card(condition.Label, condition.Description, enabled, function(value)
							local index = table.find(draft.Conditions, condition.Id)
							if index then
								table.remove(draft.Conditions, index)
							end
							if value then
								table.insert(draft.Conditions, condition.Id)
							end
						end)
					end
					card(
						"Use advanced condition rules",
						"Build server-checked ALL/ANY/NOT rules from safe runtime properties such as health, relationship, resources, status, material, and distance.",
						false,
						function()
							draft.Conditions = ConditionTree.newGroup("ALL")
						end
					)
				else
					info(
						"Environment.ZoneTags reads the selected MagicEnvironmentZone part's MagicZoneTags attribute (comma/semicolon separated). Status rules include shield, slow, bind, reveal, and MagicArmor.",
						44
					)
					renderConditionTree(draft, "Conditions")
					card(
						"Return to simple cast rules",
						"Discard this advanced condition tree and return to the simple cast rules.",
						false,
						function()
							draft.Conditions = {}
						end
					)
				end
			end
		elseif activeSection == "ChooseEffects" or activeSection == "ConfigureEffects" then
			local configuring = activeSection == "ConfigureEffects"
			heading(if configuring then "SPELL EFFECT COMPOSER" else "CHOOSE COMPATIBLE EFFECTS")
			if configuring then
				info(
					"Read the spell from top to bottom. WHEN starts a timing; ALSO means another independent step runs at that same timing. IF marks a conditional branch. The server validates and executes these exact saved steps.",
					56
				)
				heading("ACTION MAP")
				local actionBlocks = ActionFlow.build(draft, Schema, effectEventsForDraft())
				for _, block in ipairs(actionBlocks) do
					local selected = event == block.Event and selectedStepByEvent[block.Event] == block.StepIndex
					local label = string.format(
						"%s · %s  ›  %s%s",
						block.Relation,
						string.upper(block.EventLabel),
						block.Title,
						if block.HasCondition then "  ·  " .. block.ConditionLabel else ""
					)
					local actionNode = row(label)
					actionNode.Name = "ActionBlock_" .. block.Event .. "_" .. tostring(block.StepIndex)
					local editAction = button(actionNode, if selected then "SELECTED" else "EDIT", function()
						event = block.Event
						selectedStepByEvent[block.Event] = block.StepIndex
						rebuildPreservingScroll()
					end)
					editAction.Size = UDim2.fromOffset(92, 30)
				end
				if #actionBlocks == 0 then
					info("No actions yet. Choose a timing and add an effect to create the first action block.", 36)
				end
				local compositionCount = 0
				local orderedEvents = effectEventsForDraft()
				for _, eventName in ipairs(orderedEvents) do
					local steps = draft.Triggers[eventName] or {}
					local eventPayloadCount = 0
					for _, step in ipairs(steps) do
						for _, selectedPayload in ipairs(step.Payloads or {}) do
							eventPayloadCount += 1
						end
					end
					if eventPayloadCount > 0 then
						compositionCount += eventPayloadCount
						local eventLabel = Schema.EventLabels[eventName] or eventName
						local node = row(
							"WHEN · "
								.. string.upper(eventLabel)
								.. "   ›   "
								.. tostring(eventPayloadCount)
								.. " effect(s)"
						)
						node.Size = UDim2.new(1, -8, 0, 42)
						local jump = button(node, if event == eventName then "SELECTED" else "EDIT NODE", function()
							event = eventName
							rebuildPreservingScroll()
						end)
						jump.Size = UDim2.fromOffset(106, 30)
						for _, step in ipairs(steps) do
							for _, selectedPayload in ipairs(step.Payloads or {}) do
								local definition = Schema.Payloads[selectedPayload.Kind]
								local title = definition and definition.Label or selectedPayload.Kind or "Effect"
								local effectNode = row("      └  " .. tostring(title))
								effectNode.Size = UDim2.new(1, -8, 0, 34)
								local edit = button(effectNode, "EDIT", function()
									event = eventName
									activeSection = "ConfigureEffects"
									rebuildPreservingScroll()
								end)
								edit.Size = UDim2.fromOffset(70, 28)
							end
						end
					end
				end
				if compositionCount == 0 then
					info(
						"No gameplay effects yet. Choose an event below, then switch to Choose Effects to add compatible outcomes.",
						40
					)
				end
			end
			if configuring then
				heading("SELECTED EVENT NODE")
			end
			local supportedEvents = supportedEffectEventsForDraft()
			local availableEvents = effectEventsForDraft()
			select(
				"Effect timing",
				event,
				availableEvents,
				function(value)
					event = value
				end,
				function(value)
					local label = Schema.EventLabels[value] or value
					return if table.find(supportedEvents, value) then label else "Unavailable: " .. label
				end,
				if configuring
					then "The selected effects below run at this timing. Choose another timing to configure its effects, or return to Choose Effects to add outcomes."
					else "Choose when something should happen, then add one or more outcomes below. For example, On impact can make a Projectile damage a target when it hits."
			)
			if not table.find(supportedEvents, event) then
				info(
					"This saved timing is unsupported by the current Form/targeting mode. Remove its effects here or restore a compatible targeting mode before saving.",
					44
				)
			end
			if configuring then
				info(Schema.EventDescriptions[event] or "Effects run when this Form resolves its target.", 40)
				local steps = draft.Triggers[event] or {}
				local selectedIndex = selectedStepByEvent[event]
				if not selectedIndex or not steps[selectedIndex] then
					for index, step in ipairs(steps) do
						if not step.Behavior then
							selectedStepByEvent[event] = index
							selectedIndex = index
							break
						end
					end
				end
				local selectedStep = selectedIndex and steps[selectedIndex]
				if selectedStep and not selectedStep.Behavior then
					local stepTools = row("EDITING ACTION " .. tostring(selectedIndex) .. " OF " .. tostring(#steps))
					if selectedIndex > 1 then
						local moveUp = button(stepTools, "MOVE UP", function()
							steps[selectedIndex], steps[selectedIndex - 1] =
								steps[selectedIndex - 1], steps[selectedIndex]
							selectedStepByEvent[event] = selectedIndex - 1
							estimate()
							rebuildPreservingScroll()
						end)
						moveUp.Size = UDim2.fromOffset(86, 30)
					end
					local removeStep = button(stepTools, "REMOVE", function()
						table.remove(steps, selectedIndex)
						selectedStepByEvent[event] = math.max(1, selectedIndex - 1)
						estimate()
						rebuildPreservingScroll()
					end)
					removeStep.Size = UDim2.fromOffset(78, 30)
				end
				local canAdd, addReason = ActionFlow.canAddStep(draft, event, Config.MaxSteps)
				local addRow = row("Add another independent action at this same timing")
				local addStep = button(addRow, if canAdd then "+ ADD ALSO" else "STEP LIMIT", function()
					if not canAdd then
						message(addReason or "No more actions can be added here.", false)
						return
					end
					local sourceStep = primary()
					local added = if sourceStep then Spec.copy(sourceStep) else { Payloads = {} }
					added.Condition = nil
					table.insert(steps, added)
					selectedStepByEvent[event] = #steps
					estimate()
					rebuildPreservingScroll()
				end)
				addStep.Size = UDim2.fromOffset(124, 32)
				-- Branches are ordinary steps with a Condition: the IF branch
				-- starts as a copy of the selected step; OTHERWISE copies it with
				-- the exact inverse condition, so exactly one of the pair runs.
				local branchSource = (selectedIndex and steps[selectedIndex]) or primary()
				local branchRow = row("Add a conditional branch at this timing")
				local addBranch = button(branchRow, if canAdd then "+ ADD IF" else "STEP LIMIT", function()
					if not canAdd then
						message(addReason or "No more actions can be added here.", false)
						return
					end
					local added = if branchSource then Spec.copy(branchSource) else { Payloads = {} }
					added.Condition = ActionFlow.branchCondition()
					table.insert(steps, added)
					selectedStepByEvent[event] = #steps
					estimate()
					rebuildPreservingScroll()
				end)
				addBranch.Size = UDim2.fromOffset(110, 32)
				-- "Stronger when you're hurt": the same step, only while the caster is below 50%.
				local hurtRow = row("Add a branch that runs while you're hurt (caster health below 50%)")
				local addHurt = button(hurtRow, if canAdd then "+ IF HURT" else "STEP LIMIT", function()
					if not canAdd then
						message(addReason or "No more actions can be added here.", false)
						return
					end
					local added = if branchSource then Spec.copy(branchSource) else { Payloads = {} }
					added.Condition = ActionFlow.casterHealthBelow(50)
					table.insert(steps, added)
					selectedStepByEvent[event] = #steps
					estimate()
					rebuildPreservingScroll()
				end)
				addHurt.Size = UDim2.fromOffset(110, 32)
				if branchSource and branchSource.Condition then
					local otherwiseCondition, otherwiseReason =
						ActionFlow.otherwise(branchSource.Condition, ConditionSpec.MaxDepth)
					local otherwiseRow = row("Add the opposite branch: runs when this step's condition fails")
					local addOtherwise = button(
						otherwiseRow,
						if canAdd and otherwiseCondition then "+ OTHERWISE" else "UNAVAILABLE",
						function()
							if not canAdd or not otherwiseCondition then
								message(otherwiseReason or addReason or "No more actions can be added here.", false)
								return
							end
							local added = Spec.copy(branchSource)
							added.Condition = otherwiseCondition
							table.insert(steps, added)
							selectedStepByEvent[event] = #steps
							estimate()
							rebuildPreservingScroll()
						end
					)
					addOtherwise.Size = UDim2.fromOffset(124, 32)
				end
				if not canAdd then
					info(addReason or "This timing cannot accept another action.", 34)
				end
			end
			if configuring and event == "OnThreshold" then
				local thresholdStep = primary()
				if thresholdStep then
					numeric(
						"Health threshold percent",
						thresholdStep,
						"HealthPercent",
						"This step runs once when its spell damage crosses from above this target-health percentage to at or below it. Use a unique whole percentage for each step."
					)
				else
					info("Add a payload below to create a threshold step, then set its health percentage.", 34)
				end
			end
			if configuring and event == "OnCommand" then
				local commandStep = primary()
				if commandStep then
					local options = { "Any" }
					for _, command in Schema.CommandOrder do
						table.insert(options, command)
					end
					select("Command filter", commandStep.Command or "Any", options, function(value)
						commandStep.Command = if value == "Any" then nil else value
					end, function(value)
						return value
					end, "Any runs for each accepted order; choose one order to run this step only for that command.")
				else
					info("Add a payload to create a command-trigger step, then optionally filter by command.", 34)
				end
			end
			if configuring and Schema.TargetFromByEvent[event] then
				local damageStep = primary()
				if damageStep then
					select(
						"Applies to",
						damageStep.TargetFrom or "Holder",
						Schema.TargetFromByEvent[event],
						function(value)
							damageStep.TargetFrom = if value == "Holder" then nil else value
						end,
						nil,
						if event == "OnDamageDealt"
							then "Holder applies the effect to the creature that was hit. Caster applies it to you (for example lifesteal)."
							else "Holder applies the effect to you. Attacker applies it to whoever damaged you (thorns), if this spell's relationship allows them."
					)
				end
			end
			if configuring and draft.Form == "Tether" then
				local tetherStep = primary()
				if tetherStep then
					select(
						"Acts on",
						tetherStep.Anchor or "Both",
						Schema.TetherAnchors,
						function(value)
							tetherStep.Anchor = if value == "Both" then nil else value
						end,
						nil,
						"Both ends, or only end A (you, or the first target) or end B (the target, or the second one)."
					)
				end
			end
			if configuring and primary() then
				spellTargetControls(primary())
			end
			if configuring and event == "OnBeforeDamageTaken" then
				-- Interception: what this spell does to the incoming hit.
				local interceptStep = nil
				for _, step in draft.Triggers[event] or {} do
					if step.Intercept then
						interceptStep = step
						break
					end
				end
				select(
					"Interception",
					if interceptStep then interceptStep.Intercept.Action else "None",
					{ "None", "Negate", "Reduce", "Redirect" },
					function(value)
						draft.Triggers[event] = draft.Triggers[event] or {}
						if value == "None" then
							if interceptStep then
								interceptStep.Intercept = nil
							end
							return
						end
						if not interceptStep then
							interceptStep = { Payloads = {} }
							table.insert(draft.Triggers[event], 1, interceptStep)
						end
						interceptStep.Intercept = if value == "Negate"
							then { Action = "Negate" }
							elseif value == "Reduce" then { Action = "Reduce", Percent = 50 }
							else { Action = "Redirect", Percent = 50, To = "Owner" }
						draft.Interception = draft.Interception or { Charges = 1 }
					end,
					nil,
					"Negate cancels the hit; Reduce cuts it by 1-90%; Redirect sends 10-100% to your caster (Owner) or back to the attacker. One spell intercepts each hit; damage over time is never intercepted."
				)
				local intercept = interceptStep and interceptStep.Intercept
				if intercept and intercept.Action ~= "Negate" then
					numeric(
						"Percent",
						intercept,
						"Percent",
						if intercept.Action == "Reduce" then "Allowed: 1 to 90" else "Allowed: 10 to 100"
					)
				end
				if intercept and intercept.Action == "Redirect" then
					select("Send it to", intercept.To or "Owner", Schema.InterceptTargets, function(value)
						intercept.To = value
					end, nil, "Owner: the caster of this spell (a guardian on an ally). Attacker: back to whoever hit.")
				end
				if draft.Triggers[event] and #draft.Triggers[event] > 0 then
					draft.Interception = draft.Interception or { Charges = 1 }
					numeric(
						"Interception charges",
						draft.Interception,
						"Charges",
						"One is used per intercepted hit, at most every 0.25 s. Allowed: 1 to "
							.. Config.MaxInterceptionCharges
					)
					toggle("Ends when charges run out", draft.Interception.EndWhenSpent == true, function(value)
						draft.Interception.EndWhenSpent = value
						dirty = true
					end, "Off: the spell stays but no longer intercepts.")
				end
			end
			if configuring and event == "OnTargetDeath" then
				local deathStep = primary()
				if deathStep then
					select(
						"Death cause",
						deathStep.DeathMode or "Either",
						Schema.TargetDeathModes,
						function(value)
							deathStep.DeathMode = if value == "Either" then nil else value
						end,
						nil,
						"Choose whether this step runs when this spell gets the defeating blow, when another cause kills someone this active spell affected, or either way."
					)
				else
					info("Add a payload below to create an OnTargetDeath step and choose its cause.", 34)
				end
			end
			if not configuring then
				info(Schema.EventDescriptions[event] or "Effects run when this Form resolves its target.", 40)
			end
			-- Group effects by Polarity (Boons, Banes, Other); Category stays as the sub-heading.
			for _, polarity in Schema.PolarityOrder do
				local groupShown = false
				for _, category in ipairs(EffectCategoryOrder) do
					local kinds = {}
					for kind, definition in Schema.Payloads do
						if effectCategory(kind) == category and (definition.Polarity or "Neutral") == polarity then
							table.insert(kinds, kind)
						end
					end
					table.sort(kinds)
					local hasSelectedEffect = false
					for _, kind in ipairs(kinds) do
						if payload(kind) then
							hasSelectedEffect = true
							break
						end
					end
					if #kinds > 0 and (not configuring or hasSelectedEffect) then
						if not groupShown then
							groupShown = true
							local groupLabel = heading(string.upper(Schema.PolarityLabels[polarity]))
							groupLabel.TextSize = 15
							groupLabel.TextColor3 = K.C.Ink
						end
						heading(string.upper(category))
						if not configuring then
							local categoryDescriptions = {
								Damage = "Hurt targets immediately or over time.",
								Healing = "Restore health or help a target recover.",
								Defense = "Shield targets or improve defensive attributes.",
								Control = "Push, pull, slow, bind, or otherwise limit movement.",
								Movement = "Change how a target moves through the world.",
								Summoning = "Create a companion with a bounded lifetime and behavior.",
								Utility = "Reveal, transform, or interact with prepared objects.",
							}
							info(
								categoryDescriptions[category] or "Effects describe the gameplay outcomes of the spell.",
								34
							)
						end
						for _, kind in kinds do
							local definition = Schema.Payloads[kind]
							local value = payload(kind)
							if not configuring or value ~= nil then
								local objectInteractionOnly = draft.Targeting == "ObjectTarget"
									and (draft.Form == "Projectile" or draft.Form == "Beam" or draft.Form == "Wave")
								local formAndTargetCompatible = (
									not objectInteractionOnly
									or kind == "Force"
									or kind == "Control"
									or kind == "Manipulation"
								)
									and (
										kind ~= "Manipulation"
										or draft.Form == "Manipulation"
										or draft.Targeting == "ObjectTarget"
									)
								local capabilityCompatible = Schema.supportsPayloadCapability(kind, draft.Form, event)
								local available = (capabilityCompatible and formAndTargetCompatible) or value ~= nil
								local reason = if kind == "Manipulation"
										and (draft.Form == "Projectile" or draft.Form == "Beam" or draft.Form == "Wave")
										and draft.Targeting ~= "ObjectTarget"
									then "Requires ObjectTarget so the server can validate the exact manipulated part."
									elseif
										objectInteractionOnly
										and kind ~= "Force"
										and kind ~= "Control"
										and kind ~= "Manipulation"
									then "Aimed object Forms allow Force, Control, or authorized material Manipulation."
									elseif
										not definition.TargetIndependent
										and (not form.TargetTypes or not form.TargetTypes.Humanoid)
									then "This Form does not resolve Humanoid targets."
									elseif
										definition.Events[draft.Form]
									then "Available on a different event for this Form."
									else "This effect cannot run with the current Form, target mode, or timing. Choose a compatible combination."
								if not configuring then
									card(definition.Label, definition.Description, value ~= nil, function(enabled)
										setPayload(kind, enabled)
									end, available, reason)
								elseif value then
									heading(definition.Label)
									info(definition.Description, 38)
									if not capabilityCompatible or not formAndTargetCompatible then
										info(
											"This selected effect is incompatible with the current Form, target mode, or timing. "
												.. reason,
											52
										)
									end
								end
								if configuring and value then
									if kind == "Summon" then
										heading("HOW SUMMONS WORK")
										info(
											"CURRENT TRIGGER: "
												.. event
												.. (if draft.Form == "Projectile" and event == "OnImpact"
													then " — waits for the projectile to collide. Choose OnCast to summon as soon as you cast."
													else " — the summon appears when this event occurs.")
												.. " Spawn position (Caster or Event) controls where it appears, not when. Repeated Event triggers add members up to the cap; Caster placement refreshes one group. Assign a spell slot and choose Hunter to let companions seek visible hostiles near their spawn points.",
											76
										)
										for _, field in definition.Fields do
											if
												(field.Key ~= "Duration" and field.Key ~= "RespawnPolicy")
												or (field.Key == "Duration" and (value.LifetimeMode or "FixedDuration") == "FixedDuration")
												or (
													field.Key == "RespawnPolicy"
													and (value.LifetimeMode or "FixedDuration") == "UntilCommanded"
												)
											then
												if field.Key == "LifetimeMode" then
													local previous = value.LifetimeMode or "FixedDuration"
													select(field.Label, previous, field.Options, function(selected)
														value.LifetimeMode = selected
														if selected == "UntilCommanded" then
															value.Duration = nil
															value.RespawnPolicy = value.RespawnPolicy
																or "DismissOnDeath"
														elseif value.Duration == nil then
															value.Duration = 30
															value.RespawnPolicy = "DismissOnDeath"
														end
													end, nil, field.Help)
												elseif field.Key == "SpellSlot" then
													select(
														field.Label,
														value.SpellSlot or "None",
														field.Options,
														function(selected)
															value.SpellSlot = if selected == "None"
																then nil
																else selected
														end,
														nil,
														field.Help
													)
												else
													renderField(value, field)
												end
											end
										end
										local companionSlot = tonumber(value.SpellSlot)
										local companion = if companionSlot then equipped[companionSlot] else nil
										local assignedProfile, assignedReason = nil, nil
										if companion then
											assignedProfile, assignedReason =
												CompanionSpellPolicy.classify(Spec.normalize(companion))
										end
										if not companionSlot then
											local noSpellHelp = if value.Role == "Medic"
												then "No companion spell assigned. Medic stays idle until you choose an equipped Ally spell with Heal, Restoration, or Shield."
												elseif
													value.Role == "Controller"
												then "No companion spell assigned. Controller stays idle until you choose an equipped hostile-control spell."
												else "No companion spell assigned. This is valid: Guardian/Hunter uses its basic attack. Choose an equipped spell slot only if you want it to cast magic."
											info(noSpellHelp, 54)
										elseif not companion then
											info(
												string.format(
													"Slot %d is empty. Equip a spell there in the spell slots, or choose None.",
													companionSlot
												),
												48
											)
										elseif not assignedProfile then
											info(
												string.format(
													"Slot %d · %s cannot be cast by a companion: %s",
													companionSlot,
													companion.Name,
													assignedReason or "incompatible spell"
												),
												54
											)
										elseif
											value.Role == "Medic"
											and (
												assignedProfile.Mode ~= "Ally"
												or (
													not assignedProfile.CanHeal
													and not assignedProfile.CanShield
													and not assignedProfile.CanModifyAttribute
												)
											)
										then
											info(
												string.format(
													"Slot %d · %s is not a healing/protection spell. Medic requires an Ally spell with Heal, Restoration, Shield, or a positive armor modifier.",
													companionSlot,
													companion.Name
												),
												54
											)
										elseif value.Role == "Controller" and not assignedProfile.CanControl then
											info(
												string.format(
													"Slot %d · %s does not have a control effect. Controller requires hostile Slow, Bind, Control, or Displacement.",
													companionSlot,
													companion.Name
												),
												54
											)
										else
											info(
												string.format(
													"Ready · slot %d: %s (%s, %s target). Use Protect/Attack for hostile spells or Support for Ally spells. Companions use your normal magic resource limits.",
													companionSlot,
													companion.Name,
													companion.Form,
													assignedProfile.Mode
												),
												54
											)
										end
									else
										showFields(value, definition.Fields)
										if ScaleSpec.ScalableKinds[kind] then
											-- ScaleBy: Amount + Per unit x measure (up to Max), per target.
											local options = { "None" }
											for _, source in ScaleSpec.SourceOrder do
												table.insert(options, source)
											end
											local scaleBy = value.ScaleBy
											select(
												"Scale by",
												if scaleBy then scaleBy.Source else "None",
												options,
												function(choice)
													if choice == "None" then
														value.ScaleBy = nil
														return
													end
													if choice == "HealthPaid" then
														-- Preset: x (1 + HP paid / 100), edited below.
														value.ScaleBy = BloodCostSpec.paidScalePreset(
															value.Amount or 0,
															Config.MaxScaleBonus
														)
														return
													end
													local updated = value.ScaleBy or { PerUnit = 1, Max = 20 }
													updated.Source = choice
													updated.Element = if ScaleSpec.Sources[choice].NeedsElement
														then (updated.Element or (if draft.Element ~= "Neutral"
															then draft.Element
															else AttributeSpec.Elements[1]))
														else nil
													value.ScaleBy = updated
												end,
												function(choice)
													return if choice == "None"
														then "None"
														else ScaleSpec.Sources[choice].Label
												end,
												"Adds Per unit times the chosen measure to this amount, up to Max. Measured on each target when the effect lands."
											)
											if scaleBy then
												numeric(
													"Scale per unit",
													scaleBy,
													"PerUnit",
													"Added per unit of the measure."
												)
												numeric(
													"Scale maximum bonus",
													scaleBy,
													"Max",
													"The most the scaling can add."
												)
												if ScaleSpec.Sources[scaleBy.Source].NeedsElement then
													select(
														"Scale element",
														scaleBy.Element or AttributeSpec.Elements[1],
														AttributeSpec.Elements,
														function(choice)
															scaleBy.Element = choice
														end,
														nil,
														"Which element's mark stacks to count."
													)
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
			if configuring then
				local conditionSteps = draft.Triggers[event] or {}
				local conditionIndex = selectedStepByEvent[event]
				if not conditionIndex or not conditionSteps[conditionIndex] then
					conditionIndex = if #conditionSteps > 0 then 1 else nil
				end
				local selectedConditionStep = conditionIndex and conditionSteps[conditionIndex]
				if selectedConditionStep then
					local step = selectedConditionStep
					local stepIndex = conditionIndex :: number
					local behaviorDefinition = step.Behavior and Schema.Behaviors[step.Behavior]
					local stepLabel = (if behaviorDefinition then behaviorDefinition.Label else "Effects")
						.. " step "
						.. tostring(stepIndex)
					heading("STEP CONDITION · " .. string.upper(stepLabel))
					if step.Condition then
						info(
							"This step only runs for event targets that pass. Target rules check each target; caster and spell rules apply to the whole step.",
							40
						)
						renderConditionTree(step, "Condition", stepLabel)
						card(
							"Remove step condition · " .. stepLabel,
							"Run this step unconditionally again.",
							false,
							function()
								step.Condition = nil
							end
						)
					else
						card(
							"Only when a condition passes · " .. stepLabel,
							"Branch this step on target health, relationship, status, resources, or spell state.",
							false,
							function()
								step.Condition = ConditionTree.newGroup("ALL")
							end
						)
					end
				end
			end
			local behaviorKinds = {}
			for kind in Schema.Behaviors do
				table.insert(behaviorKinds, kind)
			end
			table.sort(behaviorKinds)
			if not configuring then
				heading("TRIGGER BEHAVIORS")
				info("Optional behavior choices change how compatible effects resolve.", 42)
			end
			for _, kind in behaviorKinds do
				local definition = Schema.Behaviors[kind]
				local objectPhysicsOnly = draft.Targeting == "ObjectTarget"
					and (draft.Form == "Projectile" or draft.Form == "Beam" or draft.Form == "Wave")
				local current = behavior(kind)
				local available = (not objectPhysicsOnly and Schema.supportsBehavior(kind, draft.Form, event))
					or current ~= nil
				local reason = if not table.find(form.Events, event)
					then "This Form does not run effects at this timing."
					else "This behavior is incompatible with the current Form or timing."
				if not configuring then
					card(definition.Label, definition.Description, current ~= nil, function(enabled)
						setBehavior(kind, enabled)
					end, available, reason)
				elseif current then
					heading(definition.Label)
					info(definition.Description, 38)
					showFields(current, definition.Fields)
					current.Payloads = current.Payloads or {}
					if kind == "Explode" then
						spellTargetControls(current)
					end
					if kind == "SpawnEffect" then
						current.Effect = current.Effect or Spec.defaultSpawnEffect("Field", draft.Source.Principle)
						local spawnForms = {}
						for _, formName in Spec.SpawnForms do
							if Schema.supportsPrincipleForm(draft.Source.Principle, formName) then
								table.insert(spawnForms, formName)
							end
						end
						select("Spawned Form", current.Effect.Form, spawnForms, function(value)
							if value ~= current.Effect.Form then
								current.Effect = Spec.defaultSpawnEffect(value, draft.Source.Principle)
								spawnedEventFor[current] = nil
							end
						end, function(value)
							return Schema.Forms[value].Label
						end, "A Projectile travels on its own, a Field stays and pulses, and a Wave sweeps once.")
						local effect = current.Effect
						local childForm = Schema.Forms[effect.Form]
						heading("SPAWNED " .. string.upper(childForm.Label) .. " SETTINGS")
						for _, field in childForm.Mechanics or {} do
							if
								field.Object == effect.Form
								and effect[effect.Form]
								and effect[effect.Form][field.Key] ~= nil
							then
								renderField(effect[effect.Form], field)
							end
						end
						if effect.Lifetime.Mode == "FixedDuration" then
							numeric(
								"Spawned duration",
								effect.Lifetime,
								"Duration",
								string.format(
									"Seconds the spawned effect lasts. Allowed: 0.1 to %s",
									tostring(Config.MaxDuration)
								)
							)
						end
						local childEvents = Schema.eventsForEffects(effect.Form, "Instant")
						local childEvent = spawnedEventFor[current]
						if not table.find(childEvents, childEvent) then
							childEvent = if table.find(childEvents, childForm.DefaultEvent)
								then childForm.DefaultEvent
								else childEvents[1]
						end
						spawnedEventFor[current] = childEvent
						select("Spawned effect timing", childEvent, childEvents, function(value)
							spawnedEventFor[current] = value
						end, function(value)
							return Schema.EventLabels[value] or value
						end, "The spawned effect has its own timings and effects, separate from this spell.")
						if childEvent then
							effect.Triggers = effect.Triggers or {}
							local function childPayload(payloadKind)
								for _, step in ipairs(effect.Triggers[childEvent] or {}) do
									if not step.Behavior then
										for index, value in ipairs(step.Payloads or {}) do
											if value.Kind == payloadKind then
												return value, step, index
											end
										end
									end
								end
								return nil, nil, nil
							end
							for _, payloadKind in Schema.payloadsFor(effect.Form, childEvent) do
								local payloadDefinition = Schema.Payloads[payloadKind]
								local fits = payloadKind ~= "Summon"
									and (
										payloadDefinition.Principle == nil
										or payloadDefinition.Principle == draft.Source.Principle
									)
								local value = childPayload(payloadKind)
								if fits or value then
									toggle(payloadDefinition.Label .. " · spawned", value ~= nil, function(on)
										local existing, owner, at = childPayload(payloadKind)
										if on and not existing then
											local steps = effect.Triggers[childEvent] or {}
											effect.Triggers[childEvent] = steps
											local target = nil
											for _, candidate in ipairs(steps) do
												if not candidate.Behavior then
													target = candidate
													break
												end
											end
											if not target then
												target = { Payloads = {} }
												table.insert(steps, 1, target)
											end
											if #target.Payloads < Config.MaxPayloads then
												local added = Spec.copy(payloadDefinition.Defaults or {})
												added.Kind = payloadKind
												table.insert(target.Payloads, added)
											end
										elseif not on and existing and owner and at then
											table.remove(owner.Payloads, at)
											if #owner.Payloads == 0 then
												local steps = effect.Triggers[childEvent]
												table.remove(steps, table.find(steps, owner))
												if #steps == 0 then
													effect.Triggers[childEvent] = nil
												end
											end
										end
										dirty = true
										revision += 1
									end)
									if value then
										showFields(value, payloadDefinition.Fields)
									end
								end
							end
						end
					end
					local function blastPayload(payloadKind)
						for index, value in current.Payloads do
							if value.Kind == payloadKind then
								return value, index
							end
						end
						return nil, nil
					end
					for _, payloadKind in definition.PayloadKinds or {} do
						local payloadDefinition = Schema.Payloads[payloadKind]
						local value, index = blastPayload(payloadKind)
						local fitsSpell = payloadDefinition
							and payloadDefinition.Forms[draft.Form] == true
							and (
								payloadDefinition.Principle == nil
								or payloadDefinition.Principle == draft.Source.Principle
							)
						local full = #current.Payloads >= Config.MaxPayloads
						local last = #current.Payloads <= (definition.MinimumPayloads or 0)
						if value or (fitsSpell and not full) then
							toggle(payloadDefinition.Label .. " in blast", value ~= nil, function(on)
								local existing, at = blastPayload(payloadKind)
								if on and not existing and #current.Payloads < Config.MaxPayloads then
									local added = Spec.copy(payloadDefinition.Defaults or {})
									added.Kind = payloadKind
									table.insert(current.Payloads, added)
								elseif not on and at and not last then
									table.remove(current.Payloads, at)
								end
								SpellTargetSpec.syncStep(current, Schema.SpellTargetPayloads)
								dirty = true
								revision += 1
							end)
						end
						if value and index then
							showFields(value, payloadDefinition.Fields)
						end
					end
				end
			end
			if not configuring then
				heading("PROJECTILE TRAVEL BEHAVIORS")
				info("These change how a Projectile travels, selects targets, or persists after impact.", 42)
			end
			for _, kind in ProjectileBehaviorSpec.Order do
				local current = if draft.Form == "Projectile" then projectileBehavior(kind) else nil
				local definition = ProjectileBehaviorSpec.get(kind)
				local objectPhysicsOnly = draft.Targeting == "ObjectTarget" and draft.Form == "Projectile"
				local available = (draft.Form == "Projectile" and not objectPhysicsOnly) or current ~= nil
				if not configuring then
					card(
						definition.Label or kind,
						definition.Description or "Composes this behavior with the Projectile.",
						current ~= nil,
						function(enabled)
							setProjectileBehavior(kind, enabled)
						end,
						available,
						"Travel behaviors require the Projectile Form."
					)
				elseif current then
					heading(definition.Label or kind)
					info(definition.Description or "Changes how the Projectile behaves while travelling.", 38)
					for _, field in definition.Fields do
						renderField(current, field)
					end
				end
			end
			if configuring and draft.Form == "Projectile" then
				heading("TIMED MOTION PHASES")
				info(
					"Phases run in order over time. Their final settings remain active after the last phase; collision and damage still use the ordinary server projectile path.",
					48
				)
				draft.Projectile.MotionPhases = draft.Projectile.MotionPhases or {}
				for index, phase in ipairs(draft.Projectile.MotionPhases) do
					local phaseRow = row("Phase " .. index)
					button(phaseRow, "REMOVE", function()
						table.remove(draft.Projectile.MotionPhases, index)
						dirty = true
						revision += 1
						message("Motion phase removed", false)
						rebuild()
						estimate()
					end)
					select(
						"Motion mode",
						phase.Mode or "Linear",
						Config.ProjectileMotionModes,
						function(value)
							phase.Mode = value
							if value == "Arcing" then
								phase.ArcHeight = phase.ArcHeight or 8
							elseif value == "Bezier" then
								phase.BezierSide = phase.BezierSide or 8
								phase.BezierHeight = phase.BezierHeight or 0
								phase.Acceleration = 0
								phase.Gravity = 0
							elseif value == "Orbiting" then
								phase.OrbitRadius = phase.OrbitRadius or 3
								phase.OrbitAngularSpeed = phase.OrbitAngularSpeed or 3
							elseif value == "Expanding" then
								phase.ExpandMultiplier = phase.ExpandMultiplier or 3
							elseif value == "Falling" then
								phase.Gravity = phase.Gravity or 40
							end
						end,
						nil,
						"Linear preserves velocity; Arcing adds a bounded vertical arc; Bezier follows a bounded curved path; Falling applies gravity; Orbiting curves around the flight path; Stationary samples in place; Expanding grows hit and visual radius; Attached needs Linger."
					)
					numeric(
						"Duration (seconds)",
						phase,
						"Duration",
						"How long this motion phase lasts before the next one begins."
					)
					numeric(
						"Speed multiplier",
						phase,
						"SpeedMultiplier",
						"Sets speed to base projectile speed times this value at the phase boundary."
					)
					if (phase.Mode or "Linear") == "Linear" or phase.Mode == "Arcing" then
						numeric(
							"Acceleration override",
							phase,
							"Acceleration",
							"Acceleration along flight direction. Set 0 to stop accelerating in this phase."
						)
						numeric(
							"Gravity override",
							phase,
							"Gravity",
							"Additional downward acceleration during this phase."
						)
					elseif phase.Mode == "Falling" then
						numeric("Downward gravity", phase, "Gravity", "Gravity applied during this falling phase.")
					end
					if phase.Mode == "Arcing" then
						numeric(
							"Arc height",
							phase,
							"ArcHeight",
							"Peak vertical offset for the projectile's parabolic arc."
						)
					elseif phase.Mode == "Bezier" then
						numeric(
							"Side curve (studs)",
							phase,
							"BezierSide",
							"Offsets both inner cubic control points sideways. Negative values bend the other way; the server sweeps the full curved segment."
						)
						numeric(
							"Vertical curve (studs)",
							phase,
							"BezierHeight",
							"Offsets both inner cubic control points vertically. Use this with Side curve for a compound path."
						)
					elseif phase.Mode == "Orbiting" then
						numeric("Orbit radius", phase, "OrbitRadius", "Radius around the forward flight path.")
						numeric(
							"Orbit speed",
							phase,
							"OrbitAngularSpeed",
							"Signed radians per second around the flight path."
						)
					elseif phase.Mode == "Expanding" then
						numeric(
							"Final hit-radius multiplier",
							phase,
							"ExpandMultiplier",
							"Collision and projectile appearance grow from 1× to this value."
						)
					end
				end
				local addPhaseRow = row("Add motion phase")
				button(
					addPhaseRow,
					#draft.Projectile.MotionPhases < Config.MaxProjectileMotionPhases and "ADD" or "LIMIT",
					function()
						if #draft.Projectile.MotionPhases >= Config.MaxProjectileMotionPhases then
							return
						end
						table.insert(draft.Projectile.MotionPhases, {
							Mode = "Linear",
							Duration = 0.5,
							SpeedMultiplier = 1,
							Acceleration = draft.Projectile.Acceleration or 0,
							Gravity = draft.Projectile.Gravity or 0,
						})
						dirty = true
						rebuild()
						estimate()
					end
				)
			end
			local selectedEffectCount = 0
			for _, steps in pairs(draft.Triggers or {}) do
				for _, step in ipairs(steps or {}) do
					for _, value in ipairs(step.Payloads or {}) do
						selectedEffectCount += 1
					end
				end
			end
			currentGroup = nil
			if configuring then
				if selectedEffectCount == 0 then
					info("No effects are selected yet. Choose compatible outcomes before configuring this spell.", 44)
				end
				button(row("Review the live summary, validation, and save actions"), "REVIEW SPELL ›", function()
					activeSection = "Test"
					scroll.CanvasPosition = Vector2.zero
					rebuild()
				end)
			else
				button(
					row(
						string.format(
							"%d effect%s selected · next, configure only these",
							selectedEffectCount,
							if selectedEffectCount == 1 then "" else "s"
						)
					),
					"CONFIGURE EFFECTS ›",
					function()
						activeSection = "ConfigureEffects"
						scroll.CanvasPosition = Vector2.zero
						rebuild()
					end
				)
			end
		elseif activeSection == "Cost" then
			heading("CAST TIMING")
			info(
				"These controls tune when the spell resolves and how often it can be used. Values are checked again by the server when saved and cast.",
				48
			)
			numeric(
				"Cooldown (seconds)",
				draft.Casting,
				"Cooldown",
				"Time before this equipped spell can be cast again."
			)
			numeric(
				"Cast time (seconds)",
				draft.Casting,
				"CastTime",
				"Delay before the spell resolves after activation."
			)
			numeric("Recovery (seconds)", draft.Casting, "RecoveryTime", "Brief lockout after resolving.")
			if draft.Triggers.OnRecast and #draft.Triggers.OnRecast > 0 then
				draft.Casting.MaxRecasts = draft.Casting.MaxRecasts or 1
				numeric(
					"Recasts",
					draft.Casting,
					"MaxRecasts",
					"How many times pressing this spell's slot again (while its effect is active) runs On recast instead of casting. Free. Allowed: 1 to "
						.. Config.MaxRecasts
				)
			end
			if draft.Lifetime.Mode ~= "Instantaneous" then
				heading("ONGOING RESOURCE USE")
				info(
					"Mana and strain are spent over time while a lasting effect remains active. A zero upkeep value means no recurring mana cost.",
					44
				)
				numeric(
					"Mana upkeep per second",
					draft.Casting,
					"ManaUpkeepPerSecond",
					"For a channel, this must be positive; the server stops the effect if payment cannot continue."
				)
				numeric(
					"Strain per second",
					draft.Casting,
					"StrainPerSecond",
					"Ongoing Locus strain accumulated during the active lifetime."
				)
			end
			heading("PAY WITH HEALTH")
			info(
				"Blood magic (players only). Paying health is not damage, and a cast is refused if it would leave you below "
					.. math.floor(Config.BloodHealthFloor * 100 + 0.5)
					.. "% health. Health scales with charge like mana.",
				48
			)
			local sacrifice = draft.Cost.Health
			select("Health sacrifice", if sacrifice then sacrifice.Mode else "None", {
				"None",
				"Flat",
				"PercentMax",
			}, function(value)
				if value == "None" then
					draft.Cost.Health = nil
				elseif sacrifice then
					sacrifice.Mode = value
					sacrifice.Amount = math.min(
						sacrifice.Amount,
						if value == "Flat" then Config.MaxFlatHealthCost else Config.MaxPercentHealthCost
					)
				else
					draft.Cost.Health = { Mode = value, Amount = if value == "Flat" then 20 else 10 }
				end
			end, function(value)
				return if value == "PercentMax" then "% of max health" elseif value == "Flat" then "Flat HP" else "None"
			end, "Health paid on top of the mana cost each cast; HealthPaid scaling grows with it.")
			if draft.Cost.Health then
				numeric(
					if draft.Cost.Health.Mode == "Flat" then "Health cost (HP)" else "Health cost (% of max)",
					draft.Cost.Health,
					"Amount",
					if draft.Cost.Health.Mode == "Flat"
						then "Allowed: 1 to " .. Config.MaxFlatHealthCost
						else "Allowed: 1 to "
							.. Config.MaxPercentHealthCost
							.. ". Against players: at most 40% (30% ranked)."
				)
			end
			numeric(
				"Mana paid with health (%)",
				draft.Cost,
				"HealthForMana",
				"0 to 100. Each mana replaced costs "
					.. Config.HealthPerMana
					.. " HP, so health is always the worse rate."
			)
			if draft.Lifetime.Mode ~= "Instantaneous" then
				numeric(
					"Health per second",
					draft.Cost,
					"HealthPerSecond",
					"Channelled, sustained or toggled spells only. Allowed: "
						.. Config.MinHealthPerSecond
						.. " to "
						.. Config.MaxHealthPerSecond
						.. "; the spell ends itself before a tick would cross the health floor. Clear for none."
				)
			end
			local cost = Spec.estimate(draft)
			heading("SERVER-ESTIMATED CAST DEMAND")
			info(
				string.format(
					"Estimated per cast: %s · %d strain · complexity %d\nWhile active: %g mana/s · %g strain/s\nThese are authored spell estimates; caster state and target defenses still affect actual results.",
					BloodCostSpec.costLabel(cost),
					cost.Strain,
					cost.Complexity,
					cost.ManaUpkeepPerSecond or 0,
					cost.StrainPerSecond or 0
				),
				78
			)
			heading("ADVANCED LIMITS")
			info(
				"Optional caster, environment, and lifetime rules are available in Casting and specialist controls. They remain server-validated.",
				52
			)
		elseif activeSection == "Presentation" and visualSubpage == "Composer" then
			heading("SPELL VISUAL STUDIO")
			info(
				"Automatic composes element, form, shape and behavior. Presets override the motif; Advanced tunes colors, core, opacity and trails. Preview, then save.",
				48
			)
			local options = {}
			local visualCards = {
				{ Id = "None", Label = "Automatic", Hint = "Infer from element, form and behavior", Symbol = "◇" },
				{ Id = "FireProjectile", Label = "Fire", Hint = "Rotating ember core", Symbol = "✦" },
				{ Id = "FrostProjectile", Label = "Frost", Hint = "Spinning ice crystal", Symbol = "❄" },
				{ Id = "ArcaneProjectile", Label = "Arcane", Hint = "Violet arcane core", Symbol = "✧" },
				{ Id = "FireBurst", Label = "Fire Burst", Hint = "Impact flash and ring", Symbol = "☼" },
				{ Id = "FrostCharge", Label = "Frost Charge", Hint = "Shrinking crystal charge", Symbol = "❅" },
				{ Id = "ArcaneTrail", Label = "Arcane Trail", Hint = "Purple trail and motes", Symbol = "〰" },
			}
			local pageSize = 6
			local pageCount = math.ceil(#visualCards / pageSize)
			visualPage = math.clamp(visualPage, 1, pageCount)
			local firstCard = (visualPage - 1) * pageSize + 1
			local lastCard = math.min(#visualCards, firstCard + pageSize - 1)
			for index = firstCard, lastCard do
				local visualCard = visualCards[index]
				local card = table.clone(visualCard)
				card.Selected = (draft.Visual.VFXDefinition or "None") == card.Id
				card.Action = function()
					draft.Visual.VFXDefinition = card.Id
					estimate()
					rebuildPreservingScroll()
				end
				table.insert(options, card)
			end
			table.insert(options, {
				Id = "AdvancedAppearance",
				Label = "Advanced",
				Hint = "Legacy color, audio and component controls",
				Symbol = "⚙",
				Action = function()
					visualSubpage = "Advanced"
					rebuild()
				end,
			})
			creationChoiceGrid(options)
			visualStudioFrame = scroll:FindFirstChild("SpellChoiceGrid") :: Frame?
			local previewBlock = canvasBlock(112)
			local previewFrame = Instance.new("Frame")
			previewFrame.Name = "VisualPreviewTile"
			previewFrame.Position = UDim2.fromOffset(0, 0)
			previewFrame.Size = UDim2.new(1, -8, 1, -8)
			previewFrame.BackgroundColor3 = Theme.Surface
			previewFrame.BorderSizePixel = 0
			previewFrame.Parent = previewBlock
			local iconPreview = Instance.new("Frame")
			iconPreview.Name = "LiveSpellIconPreview"
			iconPreview.Position = UDim2.fromOffset(12, 12)
			iconPreview.Size = UDim2.fromOffset(72, 72)
			iconPreview.Parent = previewFrame
			liveIconPreview = iconPreview
			SpellVisual.render(iconPreview, draft, true)
			local previewEdge = Instance.new("UIStroke")
			previewEdge.Color = Theme.TileEdge
			previewEdge.Thickness = 2
			previewEdge.Parent = previewFrame
			local previewTitle = Instance.new("TextLabel")
			previewTitle.BackgroundTransparency = 1
			previewTitle.Position = UDim2.fromOffset(96, 9)
			previewTitle.Size = UDim2.new(1, -258, 0, 26)
			previewTitle.Font = Enum.Font.Garamond
			previewTitle.TextSize = 14
			previewTitle.TextTruncate = Enum.TextTruncate.AtEnd
			previewTitle.TextColor3 = Theme.Ink
			previewTitle.TextXAlignment = Enum.TextXAlignment.Left
			previewTitle.Text = VFXAnalyzer.resolve(draft).Label
			previewTitle.Parent = previewFrame
			local previewHint = Instance.new("TextLabel")
			previewHint.BackgroundTransparency = 1
			previewHint.Position = UDim2.fromOffset(96, 38)
			previewHint.Size = UDim2.new(1, -258, 0, 44)
			previewHint.Font = Enum.Font.Gotham
			previewHint.TextSize = 14
			previewHint.TextWrapped = true
			previewHint.TextColor3 = Theme.MutedInk
			previewHint.TextXAlignment = Enum.TextXAlignment.Left
			previewHint.Text = VFXAnalyzer.resolve(draft).Source
				.. " · "
				.. VFXAnalyzer.resolve(draft).Accents
				.. ". Advanced overrides palette, core, opacity, emission and trails."
			previewHint.Parent = previewFrame
			local previewButton = Instance.new("TextButton")
			previewButton.AnchorPoint = Vector2.new(1, 0.5)
			previewButton.Position = UDim2.new(1, -12, 0.5, 0)
			previewButton.Size = UDim2.fromOffset(128, 44)
			previewButton.BackgroundColor3 = Theme.Accent
			previewButton.TextColor3 = Theme.OnAccent
			previewButton.Text = "PLAY PREVIEW"
			previewButton.TextSize = 14
			previewButton.Font = Enum.Font.GothamBold
			previewButton.Parent = previewFrame
			previewButton.Activated:Connect(function()
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root then
					message("Character is not ready for preview.", false)
					return
				end
				VFXComposer.preview(draft, root.CFrame * CFrame.new(0, 0, -12))
				message("Previewing " .. VFXAnalyzer.resolve(draft).Label .. ".", true)
			end)
			if pageCount > 1 then
				local pager = row("VISUAL PAGE")
				pager.Name = "VISUAL PAGE"
				local pageLabel = pager:FindFirstChildOfClass("TextLabel")
				if pageLabel then
					pageLabel.Text = "VISUAL PAGE " .. tostring(visualPage) .. " / " .. tostring(pageCount)
				end
				pager.Size = UDim2.new(1, -8, 0, 42)
				local previous = button(pager, "‹ PREVIOUS", function()
					visualPage = math.max(1, visualPage - 1)
					rebuild()
				end)
				previous.Position = UDim2.new(0.08, 0, 0, 0)
				previous.Size = UDim2.new(0.36, 0, 1, 0)
				local nextPage = button(pager, "NEXT ›", function()
					visualPage = math.min(pageCount, visualPage + 1)
					rebuild()
				end)
				nextPage.Position = UDim2.new(0.56, 0, 0, 0)
				nextPage.Size = UDim2.new(0.36, 0, 1, 0)
			end
			-- Captured: inside the Spell Forge this lays out the inspector host.
			local studioHost, studioHosted = scroll, forgeHosted
			local function layoutVisualStudio()
				if not visualStudioFrame or not visualStudioFrame.Parent then
					return
				end
				local width, height = studioHost.AbsoluteSize.X, studioHost.AbsoluteSize.Y
				local gap = 10
				local cell = math.floor(math.clamp(math.min((width - 24) / 3, (height - 160) / 2), 78, 148))
				local gridWidth = cell * 3 + gap * 2
				visualStudioFrame.Position = UDim2.fromOffset(math.max(0, (width - gridWidth) / 2), 0)
				visualStudioFrame.Size = UDim2.fromOffset(gridWidth, cell * 2 + gap)
				local tileIndex = 0
				for _, tile in visualStudioFrame:GetChildren() do
					if tile:IsA("TextButton") then
						tile.Position =
							UDim2.fromOffset((tileIndex % 3) * (cell + gap), math.floor(tileIndex / 3) * (cell + gap))
						tile.Size = UDim2.fromOffset(cell, cell)
						tileIndex += 1
					end
				end
				local preview = studioHost:FindFirstChild("VisualPreviewTile", true)
				if preview and preview:IsA("Frame") then
					preview.Position = UDim2.fromOffset(0, cell * 2 + gap + 6)
					preview.Size = UDim2.new(1, -8, 0, 100)
				end
				local pagerFrame = studioHost:FindFirstChild("VISUAL PAGE", true)
				if pagerFrame and pagerFrame:IsA("Frame") then
					pagerFrame.Position = UDim2.fromOffset(0, cell * 2 + gap + 112)
					pagerFrame.Size = UDim2.new(1, -8, 0, 38)
				end
				if not studioHosted then
					visualStudioFrame.Parent.Size = UDim2.new(1, -8, 0, cell * 2 + gap + 118)
				end
			end
			layoutVisualStudio()
			visualLayoutConnection = studioHost:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutVisualStudio)
			task.defer(layoutVisualStudio)
		elseif activeSection == "Presentation" then
			heading("ADVANCED APPEARANCE")
			local back = row("Return to the visual composition editor")
			button(back, "‹ VISUAL STUDIO", function()
				visualSubpage = "Composer"
				rebuild()
			end)
			heading("CAST PRESENTATION")
			info(
				"Change how the spell looks and sounds. Colors and particles do not add damage, and a larger visual does not make the spell hit a larger area.",
				42
			)
			select("Casting profile", draft.Visual.Profile or "Auto", Schema.PresentationProfiles, function(value)
				draft.Visual.Profile = value
			end)
			heading("APPEARANCE")
			info(
				"Combine a starting look with independent shape, surface, particle, trail, impact, casting, and ambient components. These are cosmetic layers; they do not alter spell behavior or hit geometry.",
				56
			)
			heading("MIX AND MATCH STARTERS")
			for _, preset in ipairs(VisualAssets.Presets) do
				local presetRow = row(preset.Label .. " · " .. preset.Description)
				presetRow.Size = UDim2.new(1, -8, 0, 56)
				button(presetRow, "APPLY", function()
					local composed, reason = VisualAssets.apply(draft.Visual, preset.Id)
					if composed then
						draft.Visual = composed
						rebuild()
						message("Visual starter applied. Adjust any component below.", true)
					else
						message(reason or "Could not apply visual starter.", false)
					end
				end)
			end
			heading("COMPONENT LIBRARY")
			for _, group in ipairs(VisualAssets.Groups) do
				local slot = group.Slot
				local current = draft.Visual[slot]
				if slot ~= "MaterialAppearance" or draft.Form == "Projectile" or draft.Form == "Construct" then
					select(group.Label, current or "None", group.Options, function(value)
						local composed, reason = VisualAssets.set(draft.Visual, slot, value)
						if composed then
							draft.Visual = composed
						else
							message(reason or "Could not set visual component.", false)
						end
					end)
				end
			end
			if draft.Form == "Projectile" then
				select(
					"Projectile core shape",
					draft.Visual.CoreShape,
					Schema.VisualOptions.CoreShapes,
					function(value)
						draft.Visual.CoreShape = value
					end,
					function(value)
						return value
					end,
					"Changes the visible projectile core. Collision radius is set by Projectile size in Setup. All core shapes are available for testing."
				)
			end
			if draft.Form == "Projectile" or draft.Form == "Construct" then
				select(
					"Material appearance",
					draft.Visual.MaterialAppearance,
					Schema.VisualOptions.Materials,
					function(value)
						draft.Visual.MaterialAppearance = value
					end,
					nil,
					"Auto uses this Form's established appearance. Construct Auto keeps the established Slate look."
				)
			end
			select(
				"Visual palette",
				draft.Visual.Palette or "LegacyCustom",
				Schema.VisualOptions.Palettes,
				function(value)
					draft.Visual.Palette = value
					local palette = VisualSpec.PaletteDefinitions[value]
					if palette then
						draft.Visual.Color = palette.Colors[1]
						draft.Visual.SecondaryColor = palette.Colors[2]
						draft.Visual.AccentColor = palette.Colors[3]
					end
				end,
				function(value)
					local palette = VisualSpec.PaletteDefinitions[value]
					if not palette then
						return "Custom (current colors)"
					end
					return palette.Label
				end,
				"Sets the primary, secondary, and accent colors. Custom keeps the current RGB colors. All palettes are available for testing."
			)
			slider(
				"Opacity",
				draft.Visual,
				"Opacity",
				0.2,
				1,
				"A minimum opacity keeps the spell's core visible.",
				true
			)
			slider("Emission", draft.Visual, "Emission", 0, 1, "Controls particle and beam glow only.", true)
			select("Particles", draft.Visual.ParticleStyle, Schema.VisualOptions.ParticleStyles, function(value)
				draft.Visual.ParticleStyle = value
			end)
			if draft.Form == "Field" or draft.Form == "Aura" then
				slider(
					"Camera distortion",
					draft.Visual,
					"Distortion",
					0,
					1,
					"Optional local camera blur/color shift near this active area. It is subtle and does not affect other clients or gameplay.",
					true
				)
				select(
					"Environmental layer",
					draft.Visual.EnvironmentalVisual or "None",
					Schema.VisualOptions.EnvironmentalVisuals,
					function(value)
						draft.Visual.EnvironmentalVisual = value
					end,
					function(value)
						return if value == "Motes"
							then "Low-rate drifting motes around the active area."
							elseif value == "GroundMist" then "Subtle smoke-textured haze around the active area."
							else "No additional environmental particles."
					end,
					"Cosmetic only. Uses the shared particle budget and never changes hit geometry, damage, or visibility rules."
				)
			end
			if draft.Form == "Projectile" then
				select("Projectile trail", draft.Visual.TrailStyle, Schema.VisualOptions.TrailStyles, function(value)
					draft.Visual.TrailStyle = value
				end, nil, "Trail presentation does not change projectile collision or range.")
				select(
					"Surface impact behavior",
					draft.Visual.SurfaceBehavior,
					Schema.VisualOptions.SurfaceBehaviors,
					function(value)
						draft.Visual.SurfaceBehavior = value
					end,
					nil,
					"Adds a brief cosmetic pulse aligned to world surfaces. It does not persist or change gameplay."
				)
			end
			select("Impact effect", draft.Visual.ImpactStyle, Schema.VisualOptions.ImpactStyles, function(value)
				draft.Visual.ImpactStyle = value
			end)
			select("Casting effect", draft.Visual.CastingStyle, Schema.VisualOptions.CastingStyles, function(value)
				draft.Visual.CastingStyle = value
			end)
			heading("SPATIAL AUDIO")
			info(
				"Optional Roblox audio asset IDs. Travel and active-effect cues loop and stop with their server-owned effect; blank cues remain silent.",
				44
			)
			for _, cue in Schema.AudioCues do
				assetId(cue.Label .. (if cue.Mode == "Loop" then " · loop" else ""), draft.Audio, cue.Key)
			end
			numeric("Audio volume (0–1)", draft.Audio, "Volume", "Spatial sound loudness for this spell.")
			numeric(
				"Audio distance (10–250 studs)",
				draft.Audio,
				"RollOffMaxDistance",
				"Maximum spatial distance for this spell's sounds."
			)
			slider(
				"Projectile appearance scale",
				draft.Visual,
				"ProjectileScale",
				1,
				4,
				"Scales the projectile core, particles, and trail only. Its Projectile size controls collision and hit detection.",
				draft.Form == "Projectile"
			)
			heading("ELEMENT COLOR")
			local swatch = row("Current element: " .. tostring(draft.Element))
			local color = Instance.new("Frame")
			color.Size = UDim2.fromOffset(40, 20)
			color.Position = UDim2.new(0.59, 0, 0.5, -10)
			color.BackgroundColor3 = draft.Visual.Color
			color.Parent = swatch
			info("Choose the element on Setup; it supplies this spell's magic damage type and presentation color.", 38)
			card(
				"Local geometry preview",
				"Approximates the next test cast's Form geometry; projectile appearance scale stays separate from collision size.",
				debugGeometry,
				function(value)
					debugGeometry = value
				end
			)
		else
			heading("REVIEW YOUR SPELL")
			info(Summary.describe(draft, Schema, Spec), 200)
			info(
				"Lab resource rules: Channeled and Sustained casts spend mana and strain. Other Lab cast styles bypass that spending. Special-resource costs still apply, and running spells can charge upkeep. These existing testing rules are separate from the estimates above.",
				100
			)
			info(
				"Numbers above are authored values and estimates, not guaranteed damage. Target defenses, charge and your caster stats can change the result. Test against the health bars on dummies and check cast feedback.",
				72
			)
			heading(string.format("TEST SLOT %d · %s", selectedSlot, equipped[selectedSlot] and "EQUIPPED" or "EMPTY"))
			info(
				"Test casts the spell currently equipped in this slot. Equip your valid edits first, then return here to test them.",
				44
			)
			heading("MULTIPLAYER CONSENT")
			toggle("Allow consent-gated spells to affect me", consentEnabled, function(value)
				consentEnabled = value
				send(Protocol.MagicConsent, { AllowsTargetedSpells = value })
			end, "This session setting is off by default and applies only when a spell explicitly requires consent.")
			local castRow = row("Test equipped spell")
			local castButton = button(castRow, "TEST EQUIPPED", function()
				if cast then
					cast(selectedSlot)
				end
			end)
			castButton.Font = Enum.Font.GothamBold
			local cost = Spec.estimate(draft)
			local specialCostLabels = {}
			for _, resourceId in ipairs(SpecialResourceSpec.order(SpecialResourceDefinitions)) do
				local amount = draft.Cost.SpecialResources and draft.Cost.SpecialResources[resourceId]
				if amount and amount > 0 then
					table.insert(
						specialCostLabels,
						SpecialResourceDefinitions[resourceId].Label .. " " .. tostring(amount)
					)
				end
			end
			local specialCostText = if #specialCostLabels > 0
				then " · " .. table.concat(specialCostLabels, ", ")
				else ""
			info(
				string.format(
					"Editing: %s · %s · %s element. Estimate: demand %d · strain %d · complexity %d · upkeep %g mana/s, %g strain/s%s.",
					draft.Name,
					form.Label,
					draft.Element,
					cost.ManaDemand,
					cost.Strain,
					cost.Complexity,
					cost.ManaUpkeepPerSecond,
					cost.StrainPerSecond,
					specialCostText
				),
				48
			)
			renderTraining()
		end
	end
	local function preview(direction, point, target)
		drawFolder:ClearAllChildren()
		if debugGeometry then
			GeometryPreview.draw(drawFolder, player, draft, direction, point, target)
		end
	end
	local function releaseSlot(slot)
		local id = Slots.id(slot)
		if not id then
			return
		end
		local direction, point, target, targetInstance = aim()
		send(Protocol.MagicRelease, {
			SpellId = id,
			AimDirection = direction,
			WorldPoint = point,
			TargetModel = target,
			TargetInstance = targetInstance,
		})
	end
	cast = function(slot, heldInput)
		slot = slot or selectedSlot
		if not libraryLoaded then
			message("Load the spell library before casting.", false)
			return
		end
		if not equipped[slot] then
			message("This slot is empty. Select a slot and press EQUIP.", false)
			return
		end
		if equipped[slot].Casting.Mode == "CommandCast" then
			message("This is summon-only. Assign it to a Summon payload, then issue Attack or Support.", false)
			return
		end
		if
			(
				CastingSpec.isHeldMode(equipped[slot].Casting.Mode)
				or CastingSpec.isChargeMode(equipped[slot].Casting.Mode)
			) and not heldInput
		then
			message("Hold the spell's number key, then release it to finish this cast.", false)
			return
		end
		visibility(false)
		local direction, point, target, targetInstance = aim()
		local editing = draft
		draft = equipped[slot]
		preview(direction, point, target)
		draft = editing
		request:FireServer("Cast", {
			AimDirection = direction,
			WorldPoint = point,
			TargetModel = target,
			TargetInstance = targetInstance,
			Character = player.Character,
		}, slot)
	end
	apply = function(andCast)
		if applying then
			return
		end
		if not libraryLoaded then
			message("Load the spell library before saving a slot.", false)
			return
		end
		local focused = UIS:GetFocusedTextBox()
		if focused then
			focused:ReleaseFocus()
		end
		local ok, reason = Spec.validate(draft)
		if not ok then
			message(reason, false)
			return
		end
		applying = true
		appliedRevision = revision
		pendingCast = andCast
		applyingSlot, applyingDraft = selectedSlot, Spec.copy(draft)
		request:FireServer("Apply", applyingDraft, applyingSlot)
	end
	actions = Instance.new("Frame")
	actions.Size = UDim2.new(1, -24, 0, 42)
	actions.Position = UDim2.new(0, 12, 1, -54)
	actions.BackgroundTransparency = 1
	actions.Parent = panel
	local function action(label, index, callback)
		local b = button(actions, label, callback)
		b.Size = UDim2.new(0.19, -4, 1, 0)
		b.Position = UDim2.new(index * 0.2, 0, 0, 0)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.BackgroundColor3 = if index == 2 then Theme.Accent elseif index == 3 then Theme.AccentAlt else Theme.Surface
		b.TextColor3 = if index == 2 or index == 3 then Theme.OnAccent else Theme.Ink
		footerButtons[index + 1] = b
		return b
	end
	action("BACK", 0, function()
		if standaloneDraft or editingLibraryRecord then
			pageMode = "Library"
		else
			draftsBySlot[selectedSlot] = draft
			pageMode = "Slots"
		end
		scroll.CanvasPosition = Vector2.zero
		rebuild()
	end)
	action("SAVE DRAFT", 1, function()
		if standaloneDraft then
			standaloneWorkingDraft = Spec.copy(draft)
			lastWorkingDraftKind = "Standalone"
		elseif editingLibraryRecord and editingLibraryId then
			libraryDrafts[editingLibraryId] = Spec.copy(draft)
			lastLibraryDraftId = editingLibraryId
			lastWorkingDraftKind = "Library"
		else
			draftsBySlot[selectedSlot] = Spec.copy(draft)
			dirtySlots[selectedSlot] = true
		end
		dirty = true
		message("Draft kept for this session. Save Spell adds a valid copy to your library.", true)
		updateHeader()
	end)
	saveLibraryButton = action("SAVE SPELL", 2, function()
		if not libraryLoaded then
			message("Load the spell library before saving.", false)
			return
		end
		local valid, reason = Spec.validate(draft)
		if not valid then
			message(reason, false)
			return
		end
		local saveMode = if editingLibraryRecord then "Update" else "SaveNew"
		pendingLibrarySaveMode = saveMode
		pendingStandaloneSave = standaloneDraft
		request:FireServer("Library", {
			Action = saveMode,
			Id = editingLibraryId,
			Definition = Spec.copy(draft),
		})
	end)
	saveSlotButton = action("EQUIP", 3, function()
		apply(false)
	end)
	action("CLOSE · P", 4, function()
		visibility(false)
	end)
	response.OnClientEvent:Connect(function(ok, text, cost, actionName, slot)
		if actionName == "Library" then
			libraryView.Busy = false
			pendingLibraryEdit = nil
			message(text, ok)
			return
		end
		if actionName == "Load" then
			libraryLoading = false
			if ok and type(cost) == "table" then
				equipped = {}
				for key, definition in pairs(cost) do
					local index = tonumber(key)
					if
						index
						and index % 1 == 0
						and index >= 1
						and index <= Slots.Count
						and type(definition) == "table"
					then
						equipped[index] = definition
					end
				end
				draftsBySlot, dirtySlots = {}, {}
				libraryLoaded = true
				refreshBar()
				requestRebuild()
			end
			message(text, ok)
			return
		end
		if actionName == "Save" then
			persistenceState = if ok then "SAVED" else "SAVE FAILED · SESSION COPY"
			libraryView.Catalog.SaveState = persistenceState
			updateHeader()
			message(text, ok)
			return
		end
		if actionName ~= "Apply" then
			message(text, ok)
			return
		end
		if slot ~= applyingSlot then
			return
		end
		if ok then
			equipped[slot] = applyingDraft
			if slot == selectedSlot and appliedRevision == revision then
				draftsBySlot[slot] = Spec.copy(applyingDraft)
				dirtySlots[slot] = nil
			elseif not dirtySlots[slot] then
				draftsBySlot[slot] = Spec.copy(applyingDraft)
			end
			refreshBar()
		end
		applying = false
		message(text, ok)
		if ok and appliedRevision == revision then
			dirty = false
			dirtySlots[slot] = nil
		end
		if ok and pendingCast then
			pendingCast = false
			task.delay(0.12, function()
				cast(slot)
			end)
		else
			pendingCast = false
		end
		if ok then
			requestRebuild()
		end
	end)
	trainingResponse.OnClientEvent:Connect(function(ok, text, count, limit)
		message(string.format("%s  (%d / %d owned)", text, count or 0, limit or 0), ok)
	end)
	actionFeedback.OnClientEvent:Connect(function(data)
		if data.Kind == "Magic" then
			message(
				(data.Result or "")
					.. " · "
					.. (data.Reason or data.Name or "")
					.. (data.Damage and (" damage " .. data.Damage) or "")
					.. (data.Mana and (" · mana " .. math.floor(data.Mana) .. "/" .. tostring(data.Capacity or "?")) or "")
					.. (data.Strain and (" · strain " .. math.floor(data.Strain)) or ""),
				data.Result ~= "IMPOSSIBLE",
				data.Result == "UNSAFE"
			)
		end
	end)
	launcher:Bind(function()
		if panel.Visible then
			visibility(false)
		else
			rebuild()
			visibility(true)
		end
	end)
	local slotKeys = {
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.Five,
		Enum.KeyCode.Six,
		Enum.KeyCode.Seven,
		Enum.KeyCode.Eight,
		Enum.KeyCode.Nine,
	}
	local function sendAimUpdate(spell)
		if not spell or not CastingSpec.supportsAimUpdate(spell.Form, spell.Casting.Mode) then
			return
		end
		local direction, point = aim()
		if direction.Magnitude < 0.9 then
			return
		end
		send(Protocol.MagicAimUpdate, { SpellId = spell.SpellId, AimDirection = direction.Unit, WorldPoint = point })
	end
	-- One handler per slot; keyboard keys 1–9 and the gamepad RB route through it.
	local function slotAction(slot: number)
		local held = false
		return function(_, state)
			if (state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel) and held then
				held = false
				releaseSlot(slot)
				if heldAimSlot == slot then
					heldAimSlot = nil
				end
				return Enum.ContextActionResult.Sink
			end
			if UIS:GetFocusedTextBox() then
				return Enum.ContextActionResult.Pass
			end
			if panel.Visible then
				return Enum.ContextActionResult.Sink
			end
			if
				state == Enum.UserInputState.Begin
				and (
					player:GetAttribute("CharacterReady")
					or (RunService:IsStudio() and require(Shared.Configuration.DevelopmentSandbox).Enabled)
				)
			then
				cast(slot, true)
				held = equipped[slot] ~= nil
				if
					held
					and equipped[slot]
					and CastingSpec.supportsAimUpdate(equipped[slot].Form, equipped[slot].Casting.Mode)
				then
					heldAimSlot = slot
					aimUpdateElapsed = Config.AimUpdateInterval
					-- Do not wait for the periodic refresh before correcting the initial
					-- cast direction. Continue refreshing below for the full held channel.
					sendAimUpdate(equipped[slot])
				end
			end
			return Enum.ContextActionResult.Sink
		end
	end
	local slotHandlers = {}
	for slot, key in slotKeys do
		slotHandlers[slot] = slotAction(slot)
		ContextActionService:BindActionAtPriority(
			"MagicLabSlot" .. slot,
			slotHandlers[slot],
			false,
			Enum.ContextActionPriority.High.Value + 1,
			key
		)
	end
	-- Gamepad: D-pad left/right chooses an equipped slot, RB casts (hold for held spells).
	local gamepadSlot = 1
	local gamepadCastSlot: number? = nil
	player:SetAttribute("GamepadSpellSlot", gamepadSlot)
	-- The HUD spell bar (UI/HUD/SpellBar) highlights the slot RB will cast.
	local function updateSlotLabel() end
	local function cycleGamepadSlot(step: number)
		for offset = 1, #slotKeys do
			local candidate = (gamepadSlot - 1 + step * offset) % #slotKeys + 1
			if equipped[candidate] then
				gamepadSlot = candidate
				break
			end
		end
		player:SetAttribute("GamepadSpellSlot", gamepadSlot)
		updateSlotLabel()
	end
	ContextActionService:BindActionAtPriority("MagicLabGamepadCast", function(action, state, input)
		if state == Enum.UserInputState.Begin then
			gamepadCastSlot = gamepadSlot
		end
		local slot = gamepadCastSlot or gamepadSlot
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			gamepadCastSlot = nil
		end
		return slotHandlers[slot](action, state, input)
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.ButtonR1)
	ContextActionService:BindAction("MagicLabGamepadSlot", function(_, state, input)
		if state ~= Enum.UserInputState.Begin or panel.Visible or player:GetAttribute("InventoryOpen") then
			return Enum.ContextActionResult.Pass
		end
		cycleGamepadSlot(if input.KeyCode == Enum.KeyCode.DPadLeft then -1 else 1)
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight)
	RunService.RenderStepped:Connect(function(delta)
		local slot = heldAimSlot
		local spell = slot and equipped[slot]
		if panel.Visible or not spell or not CastingSpec.supportsAimUpdate(spell.Form, spell.Casting.Mode) then
			aimUpdateElapsed = 0
			return
		end
		aimUpdateElapsed += delta
		if aimUpdateElapsed < Config.AimUpdateInterval then
			return
		end
		aimUpdateElapsed %= Config.AimUpdateInterval
		sendAimUpdate(spell)
	end)
	player.CharacterRemoving:Connect(function()
		visibility(false)
		drawFolder:ClearAllChildren()
		pendingCast = false
		heldAimSlot = nil
	end)
	rebuild()
	if pageMode == "Editor" then
		estimate()
	end
end
return Lab
