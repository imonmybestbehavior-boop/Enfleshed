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
local CastingSpec = require(Shared.Modules.MagicCastingSpec)
local MaterialSpec = require(Shared.Modules.MagicMaterialSpec)
local ConstructGeometrySpec = require(Shared.Modules.MagicConstructGeometrySpec)
local SpecialResourceSpec = require(Shared.Modules.MagicSpecialResourceSpec)
local SpecialResourceDefinitions = require(Shared.Configuration.MagicLocus).SpecialResources
local EnvironmentRequirementSpec = require(Shared.Modules.MagicEnvironmentRequirementSpec)
local SpellIdentitySpec = require(Shared.Modules.MagicSpellIdentitySpec)
local VisualSpec = require(Shared.Modules.MagicVisualSpec)
local CompanionSpellPolicy = require(Shared.Modules.MagicCompanionSpellPolicy)
local Protocol = require(Shared.Networking.Protocol)
local Elements = require(Shared.Configuration.MagicElements)
local Slots = require(Shared.Modules.MagicSlots)
local Camera = require(script.Parent.CameraController)
ConditionSpec.configureSpecialResources(SpecialResourceDefinitions)
local Theme = require(script.Parent.Parent.UI.GrimoireTheme)
local SpellVisual = require(script.Parent.Parent.UI.GrimoireSpellVisual)
local HomeLayout = require(script.Parent.Parent.UI.GrimoireHomeLayout)
local Grimoire = require(script.Parent.Parent.UI.Grimoire)
local LibraryView = require(script.Parent.Parent.UI.GrimoireLibraryView)
local Summary = require(Shared.Modules.GrimoireSummary)
local AuthoringGuide = require(Shared.Modules.MagicAuthoringGuide)
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
function Lab.start(send, aim)
	if not Config.Enabled or not (RunService:IsStudio() or (not Config.StudioOnly and Config.AllowLive)) then
		return
	end
	local player = Players.LocalPlayer
	local remotes = Shared:WaitForChild(Protocol.Folder)
	local request = remotes:WaitForChild("MagicLabRequest")
	local response = remotes:WaitForChild("MagicLabResponse")
	local trainingRequest = remotes:WaitForChild("TrainingDummyRequest") :: RemoteEvent
	local trainingResponse = remotes:WaitForChild("TrainingDummyResponse") :: RemoteEvent
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
	local creationStep = "Intent"
	local creationIntent: string? = nil
	local creationForm: string? = nil
	local creationEffects = {}
	local creationForLibrary = false
	local standaloneDraft = false
	local editingLibraryRecord = false
	local editingLibraryId: string? = nil
	local authoringMode = "Guided"
	local expertSearch = ""
	local activeSection = "Setup"
	local EffectCategoryOrder = { "Damage", "Healing", "Defense", "Control", "Movement", "Summoning", "Utility" }
	local function effectCategory(kind: string): string
		if kind == "Damage" or kind == "DamageOverTime" then
			return "Damage"
		elseif kind == "Heal" or kind == "Restoration" then
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
	local bar = Instance.new("TextButton")
	bar.Name = "EquippedSpells"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.fromScale(0.5, 0.86)
	bar.Size = UDim2.new(0.86, 0, 0, 48)
	bar.BackgroundColor3 = Theme.Surface
	bar.BackgroundTransparency = 0
	bar.TextColor3 = Theme.Ink
	bar.TextSize = 14
	bar.TextWrapped = true
	bar.Parent = gui
	local barStroke = Instance.new("UIStroke")
	barStroke.Color, barStroke.Thickness = Theme.Border, 1
	barStroke.Parent = bar
	local function refreshBar()
		local names = { "OPEN GRIMOIRE · P" }
		for i = 1, Slots.Count do
			table.insert(names, i .. ": " .. (equipped[i] and equipped[i].Name or "—"))
		end
		bar.Text = table.concat(names, "  |  ")
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
	toast.BackgroundColor3 = Theme.Surface
	toast.BackgroundTransparency = 0
	toast.TextColor3 = Theme.Ink
	toast.TextSize = 16
	toast.TextWrapped = true
	toast.ZIndex = 90
	toast.Visible = false
	toast.Parent = gui
	local toastEdge = Instance.new("UIStroke")
	toastEdge.Color = Theme.TileEdge
	toastEdge.Thickness = 2
	toastEdge.Parent = toast
	local toastUntil = 0
	local feedbackVisible = true
	RunService.Heartbeat:Connect(function()
		toast.Visible = feedbackVisible and os.clock() < toastUntil
	end)
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
		status.TextColor3 = if warning then Theme.Warning elseif ok then Theme.Success else Theme.Error
		toast.TextColor3 = status.TextColor3
	end
	local updateHeader
	local editorPreview
	local mobileEditorPreview
	local function estimate()
		panel:SetAttribute("SpellSummary", draft.Name .. "\n" .. draft.Form .. "  ·  " .. draft.Element)
		if editorPreview then SpellVisual.render(editorPreview, draft, false) end
		if mobileEditorPreview then SpellVisual.render(mobileEditorPreview, draft, false) end
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
		local cost = Spec.estimate(draft)
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
				"ESTIMATE · mana demand %d · strain %d · complexity %d · while active: %g mana/s, %g strain/s%s\nSave slot equips these edits. Save + cast equips and casts them.",
				cost.ManaDemand,
				cost.Strain,
				cost.Complexity,
				cost.ManaUpkeepPerSecond,
				cost.StrainPerSecond,
				specialCostText
			),
			true
		)
	end
	local function visibility(open)
		panel.Visible = open
		bar.Visible = not open
		player:SetAttribute("MagicLabOpen", open)
		Camera:SetGameplayMouseLookEnabled(not open)
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
	local function confirm(text, accept)
		if panel:FindFirstChild("Confirmation") then
			return
		end
		local shade = Instance.new("TextButton")
		shade.Name, shade.Size, shade.Text = "Confirmation", UDim2.fromScale(1, 1), ""
		shade.BackgroundColor3, shade.BackgroundTransparency, shade.AutoButtonColor = Color3.new(0, 0, 0), 0.15, false
		shade.ZIndex, shade.Parent = 40, panel
		local prompt = Instance.new("TextLabel")
		prompt.Position, prompt.Size = UDim2.fromScale(0.08, 0.2), UDim2.fromScale(0.84, 0.36)
		prompt.BackgroundTransparency, prompt.TextColor3, prompt.TextWrapped, prompt.TextSize =
			1, Theme.OnAccent, true, 19
		prompt.Text, prompt.ZIndex, prompt.Parent = text, 41, shade
		for i, caption in { "CANCEL", "CONFIRM" } do
			local b = Instance.new("TextButton")
			b.Size, b.Position = UDim2.new(0.38, 0, 0, 48), UDim2.fromScale(0.1 + (i - 1) * 0.42, 0.65)
			b.Text, b.TextSize, b.TextColor3, b.BackgroundColor3 = caption, 16, Theme.OnAccent, Theme.Accent
			b.ZIndex, b.Parent = 41, shade
			b.Activated:Connect(function()
				shade:Destroy()
				if i == 2 then
					accept()
				end
			end)
		end
	end
	local function row(label)
		cardPairHolder, cardPairCount, cardPairCards, cardPairLayout = nil, 0, {}, nil
		order += 1
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, -8, 0, 44)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		local groupVisible = not currentGroup
			or expandedGroups[currentGroup] == true
			or (authoringMode == "Expert" and expertSearch ~= "")
		local searchVisible = authoringMode ~= "Expert"
			or expertSearch == ""
			or label == "AUTHORING MODE"
			or label == "SEARCH THIS CHAPTER"
			or string.find(string.lower(label), string.lower(expertSearch), 1, true) ~= nil
		frame.Visible = groupVisible and searchVisible
		frame.Parent = scroll
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(0.58, 0, 1, 0)
		title.BackgroundTransparency = 1
		title.TextWrapped = true
		title.Text = label
		title.TextColor3 = Theme.Ink
		title.TextSize = 14
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
		local holder = canvasBlock(scroll.AbsoluteSize.Y)
		holder.Name = "SpellChoiceGrid"
		local tiles = {}
		for index, option in ipairs(options) do
			local tile = Instance.new("TextButton")
			tile.Name = "Choice_" .. tostring(option.Id or index)
			tile.BackgroundColor3 = Color3.fromRGB(104, 72, 42)
			tile.BorderSizePixel = 0
			tile.Text = ""
			tile.AutoButtonColor = true
			tile.Parent = holder
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 5)
			corner.Parent = tile
			local lip = Instance.new("Frame")
			lip.Name = "RaisedEdge"
			lip.Position = UDim2.fromOffset(2, 2)
			lip.Size = UDim2.new(1, -4, 1, -4)
			lip.BackgroundColor3 = Color3.fromRGB(176, 133, 76)
			lip.BorderSizePixel = 0
			lip.Parent = tile
			local lipCorner = Instance.new("UICorner")
			lipCorner.CornerRadius = UDim.new(0, 4)
			lipCorner.Parent = lip
			local face = Instance.new("Frame")
			face.Name = "ParchmentFace"
			face.Position = UDim2.fromOffset(3, 2)
			face.Size = UDim2.new(1, -6, 1, -8)
			face.BackgroundColor3 = Color3.fromRGB(237, 215, 173)
			face.BorderSizePixel = 0
			face.Parent = tile
			local faceCorner = Instance.new("UICorner")
			faceCorner.CornerRadius = UDim.new(0, 3)
			faceCorner.Parent = face
			local faceGradient = Instance.new("UIGradient")
			faceGradient.Rotation = 90
			faceGradient.Color = ColorSequence.new(Color3.fromRGB(255, 239, 207), Color3.fromRGB(213, 177, 123))
			faceGradient.Parent = face
			local edge = Instance.new("UIStroke")
			edge.Color = if option.Selected then Theme.Accent else Color3.fromRGB(105, 73, 38)
			edge.Thickness = if option.Selected then 3 else 2
			edge.Parent = tile
			tile.SelectionGained:Connect(function() edge.Color, edge.Thickness = Theme.Gold, 3 end)
			tile.SelectionLost:Connect(function()
				edge.Color = if option.Selected then Theme.Accent else Color3.fromRGB(105, 73, 38)
				edge.Thickness = if option.Selected then 3 else 2
			end)
			local icon = Instance.new("Frame")
			icon.Name = "ChoiceIcon"
			icon.Position = UDim2.fromScale(0.29, 0.14)
			icon.Size = UDim2.fromScale(0.42, 0.43)
			icon.BackgroundColor3 = Color3.fromRGB(218, 191, 148)
			icon.BorderSizePixel = 0
			icon.Parent = tile
			if option.Preview then
				SpellVisual.render(icon, option.Preview, true)
			else
				local mark = Instance.new("TextLabel")
				mark.Size = UDim2.fromScale(1, 1)
				mark.BackgroundTransparency = 1
				mark.Font = Enum.Font.Garamond
				mark.TextScaled = true
				mark.TextColor3 = Theme.Accent
				mark.Text = option.Symbol or "✧"
				mark.Parent = icon
			end
			local iconEdge = Instance.new("UIStroke")
			iconEdge.Color = Color3.fromRGB(120, 86, 46)
			iconEdge.Thickness = 1
			iconEdge.Parent = icon
			local name = Instance.new("TextLabel")
			name.Name = "ChoiceName"
			name.Position = UDim2.fromScale(0.06, 0.59)
			name.Size = UDim2.fromScale(0.88, 0.17)
			name.BackgroundTransparency = 1
			name.Text = option.Label
			name.Font = Enum.Font.GothamBold
			name.TextScaled = true
			name.TextWrapped = true
			name.TextColor3 = Theme.Ink
			name.Parent = tile
			local nameLimit = Instance.new("UITextSizeConstraint")
			nameLimit.MinTextSize = 11
			nameLimit.MaxTextSize = 20
			nameLimit.Parent = name
			local detail = Instance.new("TextLabel")
			detail.Name = "ChoiceDetail"
			detail.Position = UDim2.fromScale(0.06, 0.76)
			detail.Size = UDim2.fromScale(0.88, 0.18)
			detail.BackgroundTransparency = 1
			detail.Text = option.Hint or ""
			detail.Font = Enum.Font.Gotham
			detail.TextScaled = true
			detail.TextWrapped = true
			detail.TextColor3 = Theme.MutedInk
			detail.Parent = tile
			local detailLimit = Instance.new("UITextSizeConstraint")
			detailLimit.MinTextSize = 9
			detailLimit.MaxTextSize = 13
			detailLimit.Parent = detail
			if option.Badge then
				local badge = Instance.new("TextLabel")
				badge.Name = "ChoiceBadge"
				badge.Position = UDim2.fromScale(0.07, 0.04)
				badge.Size = UDim2.fromScale(0.86, 0.1)
				badge.BackgroundTransparency = 1
				badge.Text = option.Badge
				badge.Font = Enum.Font.GothamBold
				badge.TextSize = 10
				badge.TextColor3 = option.Selected and Theme.Accent or Theme.Gold
				badge.Parent = tile
			end
			tile.Activated:Connect(option.Action)
			table.insert(tiles, tile)
		end
		local function layoutGrid()
			local width, height = holder.AbsoluteSize.X, scroll.AbsoluteSize.Y
			local gap = 10
			local twoPages = width >= 620
			local cell = if twoPages
				then math.max(72, math.floor(math.min((width / 2 - 72) / 2, (height - 34) / 2)))
				else math.max(72, math.floor(math.min((width - 30) / 2, 180)))
			local pairWidth, pairHeight = cell * 2 + gap, cell * 2 + gap
			local top = if twoPages then math.max(4, math.floor((height - pairHeight) / 2)) else 6
			for index, tile in ipairs(tiles) do
				local x, y
				if twoPages then
					local spread = math.floor((index - 1) / 8)
					local within = (index - 1) % 8
					local side = math.floor(within / 4)
					local onPage = within % 4
					local pageWidth = width / 2
					x = math.floor(side * pageWidth + (pageWidth - pairWidth) / 2)
						+ (onPage % 2) * (cell + gap)
					y = top + spread * (pairHeight + 24) + math.floor(onPage / 2) * (cell + gap)
				else
					x = math.floor((width - pairWidth) / 2) + ((index - 1) % 2) * (cell + gap)
					y = top + math.floor((index - 1) / 2) * (cell + gap)
				end
				tile.Position = UDim2.fromOffset(x, y)
				tile.Size = UDim2.fromOffset(cell, cell)
			end
			local canvasHeight = if twoPages
				then top + math.max(1, math.ceil(#tiles / 8)) * (pairHeight + 24)
				else top + math.ceil(#tiles / 2) * (cell + gap) + 8
			holder.Size = UDim2.new(1, -8, 0, math.max(height, canvasHeight))
		end
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutGrid)
		local resizeConnection = scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutGrid)
		holder.Destroying:Connect(function() resizeConnection:Disconnect() end)
		layoutGrid()
	end
	local function heading(text)
		if not (currentGroup == "TRIGGER BEHAVIORS" and string.find(text, " in blast", 1, true)) then
			currentGroup = nil
		end
		local frame = row(text)
		frame.Size = UDim2.new(1, -8, 0, 42)
		local label = frame:FindFirstChildOfClass("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.Garamond
		label.TextSize = 21
		if advancedGroups[text] then
			label.Text = "ADVANCED · " .. text
			currentGroup = text
			label.Size = UDim2.new(1, -105, 1, 0)
			local reveal = Instance.new("TextButton")
			reveal.Position, reveal.Size = UDim2.new(1, -100, 0, 0), UDim2.new(0, 100, 1, 0)
			reveal.Text = if expandedGroups[text] then "HIDE −" else "SHOW +"
			reveal.TextColor3, reveal.BackgroundColor3, reveal.TextSize = Theme.OnAccent, Theme.Accent, 14
			reveal.Parent = frame
			reveal.Activated:Connect(function()
				expandedGroups[text] = not expandedGroups[text]
				rebuildPreservingScroll()
			end)
		end
	end
	local function info(text, height)
		cardPairHolder, cardPairCount, cardPairCards, cardPairLayout = nil, 0, {}, nil
		order += 1
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -8, 0, height or 42)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.BackgroundColor3 = Theme.SurfaceMuted
		label.BackgroundTransparency = 0
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.TextWrapped = true
		label.TextColor3 = Theme.MutedInk
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Text = "  " .. text
		label.LayoutOrder = order
		local groupVisible = not currentGroup
			or expandedGroups[currentGroup] == true
			or (authoringMode == "Expert" and expertSearch ~= "")
		local searchVisible = authoringMode ~= "Expert"
			or expertSearch == ""
			or string.find(string.lower(text), string.lower(expertSearch), 1, true) ~= nil
		label.Visible = groupVisible and searchVisible
		label.Parent = scroll
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = label
		local inkRule = Instance.new("UIStroke")
		inkRule.Color = Theme.TileEdge
		inkRule.Thickness = 1
		inkRule.Transparency = 0.35
		inkRule.Parent = label
		return label
	end
	local function card(title, description, enabled, onChange, canEdit, unavailableReason)
		canEdit = if canEdit == nil then true else canEdit
		local groupVisible = not currentGroup
			or expandedGroups[currentGroup] == true
			or (authoringMode == "Expert" and expertSearch ~= "")
		local searchText = string.lower(title .. " " .. description)
		local searchVisible = authoringMode ~= "Expert"
			or expertSearch == ""
			or string.find(searchText, string.lower(expertSearch), 1, true) ~= nil
		if not (groupVisible and searchVisible) then return nil end
		if not cardPairHolder or cardPairCount >= 2 then
			order += 1
			cardPairHolder = Instance.new("Frame")
			cardPairHolder.Name = "ParchmentChoicePair"
			cardPairHolder.Size = UDim2.new(1, -8, 0, 150)
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
				local cell = if columns == 2 then math.floor((width - gap) / 2) else math.min(width, 220)
				for index, choice in ipairs(cards) do
					choice.Size = UDim2.fromOffset(cell, cell)
					choice.Position = if columns == 2
						then UDim2.fromOffset((index - 1) * (cell + gap), 0)
						else UDim2.fromOffset(math.floor((width - cell) / 2), (index - 1) * (cell + gap))
				end
				holder.Size = UDim2.new(1, -8, 0, (if columns == 2 then cell else #cards * (cell + gap) - gap))
			end
			holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutPair)
			local resizeConnection = scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutPair)
			holder.Destroying:Connect(function() resizeConnection:Disconnect() end)
			cardPairLayout = layoutPair
		end
		local frame = Instance.new("TextButton")
		frame.Name = "ParchmentChoice"
		frame.BackgroundColor3 = Theme.Surface
		frame.BorderSizePixel = 0
		frame.Text = ""
		frame.AutoButtonColor = canEdit
		frame.Parent = cardPairHolder
		cardPairCount += 1
		table.insert(cardPairCards, frame)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness = if enabled then Theme.Accent else Theme.TileEdge, 3
		stroke.Parent = frame
		local glaze = Instance.new("UIGradient")
		glaze.Rotation = 90
		glaze.Color = ColorSequence.new(Color3.fromRGB(255, 239, 207), Theme.Surface)
		glaze.Parent = frame
		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromScale(0.07, 0.06)
		name.Size = UDim2.fromScale(0.86, 0.2)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 14
		name.TextWrapped = true
		name.TextColor3 = Theme.Ink
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.Text = title
		name.Parent = frame
		local detail = Instance.new("TextLabel")
		detail.Position = UDim2.fromScale(0.08, 0.3)
		detail.Size = UDim2.fromScale(0.84, 0.38)
		detail.BackgroundTransparency = 1
		detail.Font = Enum.Font.Gotham
		detail.TextSize = 11
		detail.TextWrapped = true
		detail.TextColor3 = Theme.MutedInk
		detail.TextXAlignment = Enum.TextXAlignment.Center
		detail.TextYAlignment = Enum.TextYAlignment.Center
		detail.Text = if canEdit then description else tostring(unavailableReason or "Unavailable")
		detail.Parent = frame
		local add = Instance.new("TextButton")
		add.Size = UDim2.fromScale(0.84, 0.19)
		add.Position = UDim2.fromScale(0.08, 0.76)
		add.BackgroundColor3 = if not canEdit
			then Theme.SurfaceDisabled
			elseif enabled then Theme.Accent
			else Theme.AccentSoft
		add.TextColor3 = if not canEdit then Theme.DisabledInk elseif enabled then Theme.OnAccent else Theme.Accent
		add.Font = Enum.Font.GothamBold
		add.TextSize = 13
		add.Text = if not canEdit then "UNAVAILABLE" elseif enabled then "ADDED" else "ADD"
		add.AutoButtonColor = canEdit
		add.Parent = frame
		local addCorner = Instance.new("UICorner")
		addCorner.CornerRadius = UDim.new(0, 4)
		addCorner.Parent = add
		if canEdit then
			local function choose()
				onChange(not enabled)
				rebuild()
				estimate()
			end
			frame.Activated:Connect(choose)
			add.Activated:Connect(choose)
		end
		if cardPairLayout then cardPairLayout() end
		return frame
	end
	local function button(parent, text, callback)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.4, 0, 1, 0)
		b.Position = UDim2.new(0.59, 0, 0, 0)
		b.BackgroundColor3 = Theme.Surface
		b.TextColor3 = Theme.Ink
		b.TextSize = 14
		b.TextWrapped = true
		b.Text = text
		b.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = b
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness, stroke.Transparency = Theme.TileEdge, 2, 0
		stroke.Parent = b
		local glaze = Instance.new("UIGradient")
		glaze.Rotation = 90
		glaze.Color = ColorSequence.new(Color3.fromRGB(255, 239, 207), Theme.Surface)
		glaze.Parent = b
		b.SelectionGained:Connect(function()
			stroke.Color, stroke.Thickness = Theme.Gold, 3
		end)
		b.SelectionLost:Connect(function()
			stroke.Color, stroke.Thickness = Theme.TileEdge, 2
		end)
		b.Activated:Connect(callback)
		return b
	end
	local function select(label, value, options, change, labelFor, help, isAvailable, lockedReason, presentationOnly)
		local r = row(label)
		local function display(option)
			return if labelFor then labelFor(option) else tostring(option)
		end
		button(r, display(value) .. " ▾", function()
			expandedChoiceKey = if expandedChoiceKey == label then nil else label
			rebuildPreservingScroll()
		end)
		if expandedChoiceKey == label then
			local title = r:FindFirstChildOfClass("TextLabel")
			if title then
				title.Size = UDim2.new(0.58, 0, 0, 42)
			end
			local menuHeight = math.min(220, (#options + 1) * 34)
			r.Size = UDim2.new(1, -8, 0, 46 + menuHeight)
			local choices = Instance.new("ScrollingFrame")
			choices.Name = "Choices"
			choices.Position = UDim2.fromOffset(0, 46)
			choices.Size = UDim2.new(1, -8, 0, menuHeight)
			choices.BackgroundColor3 = Theme.Surface
			choices.BorderSizePixel = 0
			choices.ScrollBarThickness = 4
			choices.ScrollBarImageColor3 = Theme.SubtleInk
			choices.CanvasSize = UDim2.fromOffset(0, (#options + 1) * 34)
			choices.Parent = r
			local menuLayout = Instance.new("UIListLayout")
			menuLayout.Padding = UDim.new(0, 2)
			menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
			menuLayout.Parent = choices
			local cancelChoice = button(choices, "CLOSE · KEEP CURRENT", function()
				expandedChoiceKey = nil
				rebuildPreservingScroll()
			end)
			cancelChoice.Size = UDim2.new(1, -6, 0, 32)
			cancelChoice.Position = UDim2.fromOffset(0, 0)
			cancelChoice.LayoutOrder = 1
			for index, option in ipairs(options) do
				local available = not isAvailable or isAvailable(option)
				local b = button(choices, display(option) .. (if available then "" else " · UNAVAILABLE"), function()
					if not available then
						return
					end
					expandedChoiceKey = nil
					change(option)
					rebuildPreservingScroll()
					if not presentationOnly then
						estimate()
					end
				end)
				b.Size = UDim2.new(1, -6, 0, 32)
				b.LayoutOrder = index + 1
				b.Active = available
				b.AutoButtonColor = available
				if not available then
					b.TextColor3 = Theme.DisabledInk
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
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0.4, 0, 1, 0)
		box.Position = UDim2.new(0.59, 0, 0, 0)
		box.BackgroundColor3 = Theme.Surface
		box.TextColor3 = Theme.Ink
		box.BorderColor3, box.BorderSizePixel = Theme.Border, 1
		box.TextSize = 14
		box.ClearTextOnFocus = false
		box.Text = tostring(object[key] or 0)
		box.Parent = r
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
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0.4, 0, 1, 0)
		box.Position = UDim2.new(0.59, 0, 0, 0)
		box.BackgroundColor3 = Theme.Surface
		box.TextColor3 = Theme.Ink
		box.BorderColor3, box.BorderSizePixel = Theme.Border, 1
		box.TextSize = 13
		box.ClearTextOnFocus = false
		box.PlaceholderText = "comma-separated tags"
		box.Text = table.concat(object[key] or {}, ", ")
		box.Parent = r
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
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0.4, 0, 1, 0)
		box.Position = UDim2.new(0.59, 0, 0, 0)
		box.BackgroundColor3 = Theme.Surface
		box.TextColor3 = Theme.Ink
		box.BorderColor3, box.BorderSizePixel = Theme.Border, 1
		box.TextSize = 14
		box.ClearTextOnFocus = false
		box.PlaceholderText = "blank = silent"
		box.Text = object[key] or ""
		box.Parent = r
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
		local b
		b = button(r, value and "ON" or "OFF", function()
			value = not value
			change(value)
			b.Text = value and "ON" or "OFF"
			b.BackgroundColor3 = if value then Theme.AccentSoft else Theme.Surface
			b.TextColor3 = if value then Theme.Accent else Theme.Ink
			rebuild()
			estimate()
		end)
		b.BackgroundColor3 = if value then Theme.AccentSoft else Theme.Surface
		b.TextColor3 = if value then Theme.Accent else Theme.Ink
		if help then
			info(help, 34)
		end
	end
	local function slider(label, object, key, minimum, maximum, help, canEdit)
		local r = row(label)
		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(0.12, 0, 1, 0)
		valueLabel.Position = UDim2.new(0.88, 0, 0, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Font = Enum.Font.GothamSemibold
		valueLabel.TextSize = 13
		valueLabel.TextColor3 = Theme.Ink
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Parent = r
		local track = Instance.new("TextButton")
		track.Size = UDim2.new(0.25, 0, 0, 10)
		track.Position = UDim2.new(0.61, 0, 0.5, -5)
		track.BackgroundColor3 = Theme.Border
		track.BorderSizePixel = 0
		track.Text = ""
		track.AutoButtonColor = canEdit
		track.Active = canEdit
		track.Parent = r
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = if canEdit then Theme.Accent else Theme.DisabledInk
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(0, 1)
		fill.Parent = track
		local knob = Instance.new("Frame")
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.Size = UDim2.fromOffset(14, 14)
		knob.Position = UDim2.new(0, 0, 0.5, 0)
		knob.BackgroundColor3 = Theme.Surface
		knob.BorderSizePixel = 0
		knob.Parent = track
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
		for _, payloadKind in definition.PayloadKinds or {} do
			local payloadDefinition = Schema.Payloads[payloadKind]
			local payloadValue = Spec.copy(payloadDefinition.Defaults)
			payloadValue.Kind = payloadKind
			table.insert(payloads, payloadValue)
		end
		local step = { Behavior = kind, Payloads = payloads }
		for key, value in definition.Defaults do
			step[key] = value
		end
		table.insert(steps, step)
	end
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
	local navButtons = {}
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
	local layoutBook = Grimoire.mount(panel, navigation, scroll, status, headerTitle, headerSummary, Schema.Sections)
	local pageTurnButton: TextButton? = nil
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
		homeButton.Visible = pageMode ~= "Slots"
		if pageMode ~= "Editor" then
			headerTitle.Text = if pageMode == "Slots" then "Grimoire" else "Grimoire  /  "
				.. (
					if pageMode == "Library"
						then "Library"
						elseif pageMode == "Help" then "How to create magic"
						elseif pageMode == "Create" then "Create a spell"
						else "Spell slots"
				)
			if pageMode == "Library" and libraryView.ChoosingSlot then
				headerTitle.Text = "Grimoire  /  Choose for slot " .. libraryView.ChoosingSlot
			end
			headerSummary.Text = if pageMode == "Create"
				then (if creationStep == "Intent" then "STEP 1 OF 3 · CHOOSE A PURPOSE"
					elseif creationStep == "Shape" then "STEP 2 OF 3 · CHOOSE A FORM"
					else "STEP 3 OF 3 · CHOOSE EFFECTS")
				elseif pageMode == "Slots" then ""
				else persistenceState .. " · The library stores spells; numbered slots equip a test loadout."
			headerSummary.Visible = pageMode == "Create"
			status.Text = if pageMode == "Slots" then "" elseif pageMode == "Create"
				then "Guided creation · choose an intent, shape, and supported effect."
				else "Your library spells and equipped slots are separate. Select an empty slot to start authoring."
			status.TextColor3 = Theme.MutedInk
			status.Visible = pageMode ~= "Slots" and pageMode ~= "Create"
			navigation.Visible = false
			backButton.Visible = false
			if actions then
				actions.Visible = false
			end
			if pageTurnButton then
				pageTurnButton.Visible = pageMode == "Slots" or pageMode == "Library" or pageMode == "Create"
				pageTurnButton.Text = if pageMode == "Slots" then "SPELL LIBRARY  ›"
					elseif pageMode == "Library" then "‹  EQUIPPED SPELLS"
					elseif creationStep == "Intent" then (if creationForLibrary then "‹  LIBRARY" else "‹  EQUIPPED SPELLS")
					elseif creationStep == "Shape" then "‹  PURPOSE"
					else "‹  FORM"
				local catalog = pageMode == "Library" and libraryView.Selected == nil
				pageTurnButton.AnchorPoint = if catalog then Vector2.new(0.5, 1) else Vector2.new(1, 1)
				pageTurnButton.Position = if catalog then UDim2.new(0.5, 0, 1, -18) else UDim2.new(1, -24, 1, -22)
				pageTurnButton.Size = if catalog then UDim2.fromOffset(170, 32) else UDim2.fromOffset(196, 38)
			end
			layoutBook(if pageMode == "Library" and libraryView.Selected then "LibraryDetail" else pageMode, activeSection, actions)
			scroll.ScrollingEnabled = pageMode ~= "Library" or libraryView.Selected ~= nil
			return
		end
		if pageTurnButton then pageTurnButton.Visible = false end
		status.Visible = panel.AbsoluteSize.X < 680
		headerSummary.Visible = true
		if saveLibraryButton then
			saveLibraryButton.Text = if editingLibraryRecord then "SAVE SPELL CHANGES" else "SAVE SPELL"
		end
		if backButton then
			backButton.Text = if standaloneDraft or editingLibraryRecord then "‹  LIBRARY" else "‹  SLOTS"
		end
		if saveSlotButton then
			saveSlotButton.Visible = not standaloneDraft and not editingLibraryRecord
		end
		-- The chapter's BACK tile and the cover's close button provide these actions.
		if footerButtons[1] then footerButtons[1].Visible = false end
		if footerButtons[5] then footerButtons[5].Visible = false end
		layoutFooterButtons()
		navigation.Visible = true
		backButton.Visible = true
		if actions then
			actions.Visible = true
		end
		local activeDefinition
		for _, section in Schema.Sections do
			if section.Id == activeSection then
				activeDefinition = section
			end
		end
		headerTitle.Text = "Grimoire  /  " .. (activeDefinition and activeDefinition.Label or "Form")
		if editingLibraryRecord then
			headerTitle.Text = "Grimoire  /  " .. (activeDefinition and activeDefinition.Label or "Form")
		elseif standaloneDraft then
			headerTitle.Text = "Grimoire  /  " .. (activeDefinition and activeDefinition.Label or "Form")
		end
		local form = Schema.Forms[draft.Form]
		local costOk, currentCost = pcall(Spec.estimate, draft)
		currentCost = if costOk then currentCost else { ManaDemand = "—" }
		local duration = if draft.Lifetime.Duration
			then tostring(draft.Lifetime.Duration) .. "s"
			else draft.Lifetime.Mode
		headerSummary.Text = string.format(
			"%s · %s · %s mana · %s studs · %s%s",
			draft.Name,
			form and form.Label or draft.Form,
			tostring(currentCost.ManaDemand),
			tostring(draft.TargetRules.Range or "—"),
			duration,
			(dirtySlots[selectedSlot] or (dirty and (standaloneDraft or editingLibraryRecord))) and " · UNSAVED" or ""
		)
		for _, section in Schema.Sections do
			local tab = navButtons[section.Id]
			if tab then
				tab.Visible = true
			end
		end
		for i, section in Schema.Sections do
			local tab = navButtons[section.Id]
			if tab then
				tab.Size = UDim2.new(0.84 / #Schema.Sections, -6, 1, 0)
				tab.Position = UDim2.new(0.16 + (i - 1) * 0.84 / #Schema.Sections, 3, 0, 0)
				tab.BackgroundColor3 = if tab.Name == activeSection then Theme.Accent else Theme.SurfaceMuted
				tab.TextColor3 = if tab.Name == activeSection then Theme.OnAccent else Theme.Ink
			end
		end
		layoutBook(pageMode, activeSection, actions)
	end
	for _, section in Schema.Sections do
		local tab = button(navigation, section.Label, function()
			activeSection = section.Id
			scroll.CanvasPosition = Vector2.zero
			rebuild()
		end)
		tab.Name = section.Id
		tab.Font = Enum.Font.GothamSemibold
		tab.Size = UDim2.new(1 / #Schema.Sections, -6, 1, 0)
		tab.Position = UDim2.new(#navButtons / #Schema.Sections, 3, 0, 0)
		navButtons[section.Id] = tab
	end
	local function renderField(object, field)
		local options = field.Options
		if options then
			select(field.Label, object[field.Key] or options[1], options, function(value)
				object[field.Key] = value
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
	pageTurnButton = Instance.new("TextButton")
	pageTurnButton.Name = "TurnPage"
	pageTurnButton.AnchorPoint = Vector2.new(1, 1)
	pageTurnButton.Position = UDim2.new(1, -24, 1, -22)
	pageTurnButton.Size = UDim2.fromOffset(196, 38)
	pageTurnButton.BackgroundColor3 = Theme.Accent
	pageTurnButton.TextColor3 = Theme.OnAccent
	pageTurnButton.Font = Enum.Font.GothamBold
	pageTurnButton.TextSize = 12
	pageTurnButton.ZIndex = 3
	pageTurnButton.Parent = panel
	local turnCorner = Instance.new("UICorner")
	turnCorner.CornerRadius = UDim.new(0, 6)
	turnCorner.Parent = pageTurnButton
	pageTurnButton.Activated:Connect(function()
		if pageMode == "Create" then
			if creationStep == "Effects" then
				creationStep = "Shape"
			elseif creationStep == "Shape" then
				creationStep = "Intent"
			else
				pageMode = if creationForLibrary then "Library" else "Slots"
			end
			scroll.CanvasPosition = Vector2.zero
			rebuild()
		else
			libraryView.ChoosingSlot = nil
			libraryView.Selected = nil
			libraryPage(if pageMode == "Slots" then "Library" else "Slots")
		end
	end)
	local function beginCreation(forLibrary)
		if forLibrary and standaloneWorkingDraft then
			message("Resume or save your current unslotted draft before starting another one.", false)
			return
		end
		creationStep, creationIntent, creationForm = "Intent", nil, nil
		creationEffects = {}
		creationForLibrary = forLibrary
		standaloneDraft = forLibrary
		editingLibraryRecord, editingLibraryId = false, nil
		authoringMode = "Guided"
		pageMode = "Create"
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
			if editorPreview then SpellVisual.render(editorPreview, definition, false) end
			panel:SetAttribute("SpellSummary", definition.Name .. "\n" .. definition.Form .. "  ·  " .. definition.Element)
		end,
		hasSidePreview = function()
			return panel.AbsoluteSize.X >= 680
		end,
		confirm = confirm,
		schema = Schema,
		spec = Spec,
		request = request,
		message = message,
		createNew = function()
			libraryView.ChoosingSlot = nil
			beginCreation(true)
		end,
		editRecord = editLibraryRecord,
		hasWorkingDraft = function()
			return standaloneWorkingDraft ~= nil or next(libraryDrafts) ~= nil
		end,
		resumeDraft = function()
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
	homeButton.Activated:Connect(function()
		libraryView.Selected = nil
		libraryView.ChoosingSlot = nil
		pageMode = "Slots"
		scroll.CanvasPosition = Vector2.zero
		rebuild()
	end)
	remotes:WaitForChild("GrimoireResponse").OnClientEvent:Connect(function(ok, text, catalog, slots, changedSlot)
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
			rebuild()
		elseif pendingLibraryEdit then
			local slot = pendingLibraryEdit
			pendingLibraryEdit = nil
			if ok and changedSlot == slot then
				openSlot(slot)
			end
		elseif pageMode ~= "Editor" then
			rebuild()
		end
		updateHeader()
		message(text, ok)
	end)

	rebuild = function()
		mobileEditorPreview = nil
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
				child:Destroy()
			end
		end
		order = 0
		currentGroup = nil
		cardPairHolder, cardPairCount, cardPairCards, cardPairLayout = nil, 0, {}, nil
		if pageMode == "Create" then
			updateHeader()
			if creationStep == "Intent" then
				local symbols = {
					Attack = "✦", Defense = "◇", Healing = "+", Movement = "↗",
					Control = "◎", Summoning = "◆", Utility = "✧", Area = "◉",
				}
				local hints = {
					Attack = "Damage a target", Defense = "Protect an ally", Healing = "Restore health",
					Movement = "Move or fly", Control = "Slow, bind, push", Summoning = "Call a companion",
					Utility = "Reveal or alter", Area = "Affect a zone",
				}
				local options = {}
				for _, intentDefinition in ipairs(AuthoringGuide.intents()) do
					local intent = intentDefinition
					if #AuthoringGuide.shapes(intent.Id, Schema, Spec) > 0 then
						table.insert(options, {
							Id = intent.Id, Label = intent.Label, Hint = hints[intent.Id], Symbol = symbols[intent.Id],
							Action = function()
								creationIntent = intent.Id
								creationForm = nil
								creationEffects = {}
								creationStep = "Shape"
								scroll.CanvasPosition = Vector2.zero
								rebuild()
							end,
						})
					end
				end
				table.insert(options, {
					Id = "Workshop", Label = "SPELL WORKSHOP", Hint = "All advanced settings", Symbol = "✧",
					Badge = "ADVANCED",
					Action = function()
						draft = Spec.createDraft("Projectile", internalDefaultForForm("Projectile"))
						ensureVisualDefaults(draft)
						event = mainEvent(draft.Form)
						standaloneDraft = creationForLibrary
						editingLibraryRecord, editingLibraryId = false, nil
						if not standaloneDraft then
							draftsBySlot[selectedSlot], dirtySlots[selectedSlot] = draft, true
						else
							standaloneWorkingDraft = Spec.copy(draft)
							lastWorkingDraftKind = "Standalone"
						end
						authoringMode = "Expert"
						pageMode, activeSection = "Editor", "Setup"
						revision += 1
						appliedRevision = -1
						scroll.CanvasPosition = Vector2.zero
						rebuild()
					end,
				})
				creationChoiceGrid(options)
			elseif creationStep == "Shape" then
				local hints = {
					Projectile = "Launch a spell", Beam = "Channel a ray", Wave = "Send a pulse",
					Field = "Fill an area", Aura = "Around the caster", SelfEnhancement = "Empower yourself",
					Construct = "Shape a structure", Manipulation = "Alter a target",
				}
				local shapes = if creationIntent then AuthoringGuide.shapes(creationIntent, Schema, Spec) else {}
				local options = {}
				for _, formName in ipairs(shapes) do
					local form = Schema.Forms[formName]
					local preview = Spec.createDraft(formName, internalDefaultForForm(formName))
					if preview then ensureVisualDefaults(preview) end
					table.insert(options, {
						Id = formName, Label = form.Label, Hint = hints[formName] or "Shape your spell",
						Preview = preview,
						Badge = if AuthoringGuide.isRecommended(creationIntent, formName)
							then "SUGGESTED · FORM" else "ALSO COMPATIBLE · FORM",
						Action = function()
							creationForm = formName
							creationStep = "Effects"
							creationEffects = {}
							scroll.CanvasPosition = Vector2.zero
							rebuild()
						end,
					})
				end
				if #options == 0 then
					table.insert(options, {
						Id = "BackToPurpose", Label = "CHOOSE A PURPOSE", Hint = "Select a spell goal first",
						Symbol = "‹", Action = function()
							creationStep = "Intent"
							rebuild()
						end,
					})
				end
				creationChoiceGrid(options)
			else
				local intent = creationIntent and AuthoringGuide.definition(creationIntent)
				local choices = if creationIntent and creationForm
					then AuthoringGuide.forShape(creationIntent, creationForm, Schema, Spec)
					else {}
				local options = {}
				for _, category in ipairs(EffectCategoryOrder) do
					for _, choice in ipairs(choices) do
						if effectCategory(choice.Payload) == category then
							local selected = choice
							local alreadySelected = creationEffects[selected.Payload] ~= nil
							local formName = creationForm or "Projectile"
							local preview = Spec.createDraft(formName, internalDefaultForForm(formName))
							if preview then
								local payload = Spec.copy((Schema.Payloads[selected.Payload] or {}).Defaults or {})
								payload.Kind = selected.Payload
								preview.Triggers[selected.Event] = { { Payloads = { payload } } }
								ensureVisualDefaults(preview)
							end
							local hint = selected.Description or ""
							if #hint > 44 then hint = string.sub(hint, 1, 43) .. "…" end
							table.insert(options, {
								Id = selected.Payload, Label = selected.PayloadLabel, Hint = hint,
								Preview = preview, Selected = alreadySelected,
								Badge = if alreadySelected then "✓ SELECTED" else string.upper(category),
								Action = function()
									if alreadySelected then creationEffects[selected.Payload] = nil
									else creationEffects[selected.Payload] = selected end
									rebuildPreservingScroll()
								end,
							})
						end
					end
				end
				local selectedCount = 0
				for _ in pairs(creationEffects) do selectedCount += 1 end
				table.insert(options, {
					Id = "Continue", Label = "CONFIGURE EFFECTS", Hint = "Tune your choices", Symbol = "›",
					Badge = string.format("%d EFFECT%s SELECTED", selectedCount, if selectedCount == 1 then "" else "S"),
					Action = function()
						if next(creationEffects) == nil then
							message("Choose at least one effect before continuing.", false)
							return
						end
						local principle = nil
						for _, kind in ipairs(Schema.PayloadOrder) do
							local selected = creationEffects[kind]
							local definition = Schema.Payloads[kind]
							if selected and definition and definition.Principle then
								principle = definition.Principle
								break
							end
						end
						principle = principle or internalDefaultForForm(creationForm or "Projectile")
						local nextDraft = Spec.createDraft(creationForm or "Projectile", principle)
						if not nextDraft then
							message("That Form is no longer available. Choose another Form.", false)
							return
						end
						nextDraft.Name = "Untitled " .. (intent and intent.Label or "Spell")
						for kind, selected in pairs(creationEffects) do
							local payloadDefinition = Schema.Payloads[kind]
							if
								not payloadDefinition
								or not Schema.supportsPayloadCapability(kind, nextDraft.Form, selected.Event)
							then
								message(
									"One selected effect no longer fits this spell. Remove it or choose a compatible effect.",
									false
								)
								return
							end
							local payloadValue = Spec.copy(payloadDefinition.Defaults or {})
							payloadValue.Kind = kind
							local steps = nextDraft.Triggers[selected.Event] or {}
							nextDraft.Triggers[selected.Event] = steps
							local step = steps[1] or { Payloads = {} }
							if #steps == 0 then table.insert(steps, step) end
							table.insert(step.Payloads, payloadValue)
						end
						draft = nextDraft
						standaloneDraft = creationForLibrary
						editingLibraryRecord, editingLibraryId = false, nil
						if not standaloneDraft then
							draftsBySlot[selectedSlot] = draft
							dirtySlots[selectedSlot] = true
						else
							standaloneWorkingDraft = Spec.copy(draft)
							lastWorkingDraftKind = "Standalone"
						end
						dirty, appliedRevision = true, -1
						local firstSelected = next(creationEffects)
						event = firstSelected and creationEffects[firstSelected].Event or mainEvent(draft.Form)
						pageMode, activeSection = "Editor", "ConfigureEffects"
						revision += 1
						scroll.CanvasPosition = Vector2.zero
						rebuild()
						estimate()
					end,
				})
				creationChoiceGrid(options)
			end
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
				[[1. Start from an intent, then choose a shape and one or more compatible effects.
2. Form: adjust how the spell reaches the world, its element, and its shape settings.
3. Targeting: choose where to aim and who can be affected.
4. Conditions: add optional rules for casting or staying active.
5. Choose Effects, then configure only the effects you selected.
6. Casting and Costs tune activation, duration, cooldowns, and estimates.
7. Appearance sets the look and sound; Review & Test validates, saves, equips, and tests.]],
				180
			)
			info(
				"Quick Create keeps the common choices close. Spell Workshop opens every chapter and lets you search advanced settings. Both edit the same spell and use the same validation. Save Draft keeps a session copy; Save Spell stores a valid library record. Equip and Test are separate actions. P returns you to play; open P again to continue.",
				100
			)
			button(row("Start or skip this guide"), "OPEN SPELL SLOTS", function()
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
					for i = 1, Slots.Count do
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
			local home = canvasBlock(500)
			home.Name = "EquippedSpellHome"
			local slotsPage = Instance.new("Frame")
			slotsPage.Name = "NineEquippedSlots"
			slotsPage.BackgroundTransparency = 1
			slotsPage.Parent = home
			local createPage = Instance.new("Frame")
			createPage.Name = "CreateSpellPage"
			createPage.BackgroundTransparency = 1
			createPage.Parent = home
			local grid = Instance.new("UIGridLayout")
			grid.CellPadding = UDim2.fromOffset(8, 8)
			grid.SortOrder = Enum.SortOrder.LayoutOrder
			grid.Parent = slotsPage
			local function tile(parent, name, orderNumber, callback)
				local item = Instance.new("TextButton")
				item.Name = name
				item.LayoutOrder = orderNumber
				item.BackgroundColor3 = Color3.fromRGB(104, 72, 42)
				item.BorderSizePixel = 0
				item.Text = ""
				item.AutoButtonColor = true
				item.Parent = parent
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 5)
				corner.Parent = item
				local lip = Instance.new("Frame")
				lip.Name = "RaisedEdge"
				lip.Position = UDim2.fromOffset(2, 2)
				lip.Size = UDim2.new(1, -4, 1, -4)
				lip.BackgroundColor3 = Color3.fromRGB(176, 133, 76)
				lip.BorderSizePixel = 0
				lip.Parent = item
				local lipCorner = Instance.new("UICorner")
				lipCorner.CornerRadius = UDim.new(0, 4)
				lipCorner.Parent = lip
				local face = Instance.new("Frame")
				face.Name = "ParchmentFace"
				face.Position = UDim2.fromOffset(3, 2)
				face.Size = UDim2.new(1, -6, 1, -8)
				face.BackgroundColor3 = Color3.fromRGB(237, 215, 173)
				face.BorderSizePixel = 0
				face.Parent = item
				local faceCorner = Instance.new("UICorner")
				faceCorner.CornerRadius = UDim.new(0, 3)
				faceCorner.Parent = face
				local faceGradient = Instance.new("UIGradient")
				faceGradient.Rotation = 90
				faceGradient.Color = ColorSequence.new(Color3.fromRGB(255, 239, 207), Color3.fromRGB(213, 177, 123))
				faceGradient.Parent = face
				local highlight = Instance.new("UIStroke")
				highlight.Color = Color3.fromRGB(255, 243, 213)
				highlight.Thickness = 1
				highlight.Transparency = 0.2
				highlight.Parent = face
				local edge = Instance.new("UIStroke")
				edge.Color = Color3.fromRGB(105, 73, 38)
				edge.Thickness = 2
				edge.Parent = item
				item.SelectionGained:Connect(function() edge.Color, edge.Thickness = Theme.Gold, 3 end)
				item.SelectionLost:Connect(function() edge.Color, edge.Thickness = Color3.fromRGB(105, 73, 38), 2 end)
				item.Activated:Connect(callback)
				return item
			end
			local createTile = tile(createPage, "CreateNewSpellTile", 1, function()
				beginCreation(true)
			end)
			local createSeal = Instance.new("Frame")
			createSeal.Name = "CreateSeal"
			createSeal.Position = UDim2.fromScale(0.24, 0.13)
			createSeal.Size = UDim2.fromScale(0.52, 0.48)
			createSeal.BackgroundColor3 = Color3.fromRGB(220, 187, 133)
			createSeal.BorderSizePixel = 0
			createSeal.Parent = createTile
			local sealCorner = Instance.new("UICorner")
			sealCorner.CornerRadius = UDim.new(1, 0)
			sealCorner.Parent = createSeal
			local sealEdge = Instance.new("UIStroke")
			sealEdge.Color = Color3.fromRGB(105, 73, 38)
			sealEdge.Thickness = 2
			sealEdge.Parent = createSeal
			local createIcon = Instance.new("TextLabel")
			createIcon.Name = "CreateIcon"
			createIcon.Size = UDim2.fromScale(1, 1)
			createIcon.BackgroundTransparency = 1
			createIcon.Text = "+"
			createIcon.Font = Enum.Font.Garamond
			createIcon.TextScaled = true
			createIcon.TextColor3 = Theme.Accent
			createIcon.Parent = createSeal
			local createCaption = Instance.new("TextLabel")
			createCaption.Position = UDim2.fromScale(0.06, 0.67)
			createCaption.Size = UDim2.fromScale(0.88, 0.22)
			createCaption.BackgroundTransparency = 1
			createCaption.Text = "CREATE A\nNEW SPELL"
			createCaption.Font = Enum.Font.GothamBold
			createCaption.TextScaled = true
			createCaption.TextWrapped = true
			createCaption.TextColor3 = Theme.Ink
			createCaption.Parent = createTile
			local createTextLimit = Instance.new("UITextSizeConstraint")
			createTextLimit.MinTextSize = 14
			createTextLimit.MaxTextSize = 25
			createTextLimit.Parent = createCaption
			for slot = 1, Slots.Count do
				local slotId = slot
				local saved = equipped[slot]
				local spell = draftsBySlot[slot] or saved
				local slotButton = tile(slotsPage, "EquippedSlot_" .. slot, slot, function()
					selectedSlot = slotId
					local previousDraft = draftsBySlot[slotId]
					if previousDraft then
						draft = previousDraft
					elseif saved then
						draft = Spec.copy(saved)
						ensureVisualDefaults(draft)
						draftsBySlot[slotId] = draft
					else
						selectedSlot = slotId
						libraryView.chooseForSlot(slotId)
						pageMode = "Library"
						scroll.CanvasPosition = Vector2.zero
						rebuild()
						return
					end
					event = mainEvent(draft.Form)
					pageMode = "Editor"
					activeSection = "Setup"
					revision += 1
					dirty = dirtySlots[slotId] == true
					appliedRevision = if dirty then -1 else revision
					scroll.CanvasPosition = Vector2.zero
					rebuild()
				end)
				local number = Instance.new("TextLabel")
				number.Name = "SlotNumber"
				number.Position = UDim2.fromScale(0.08, 0.04)
				number.Size = UDim2.fromScale(0.22, 0.14)
				number.BackgroundTransparency = 1
				number.Text = tostring(slot)
				number.Font = Enum.Font.GothamBold
				number.TextSize = 13
				number.TextColor3 = Color3.fromRGB(94, 63, 34)
				number.Parent = slotButton
				if not saved and draftsBySlot[slot] then
					local draftBadge = Instance.new("TextLabel")
					draftBadge.Name = "UnsavedDraftBadge"
					draftBadge.Position = UDim2.fromScale(0.58, 0.04)
					draftBadge.Size = UDim2.fromScale(0.34, 0.14)
					draftBadge.BackgroundTransparency = 1
					draftBadge.Text = "DRAFT"
					draftBadge.Font = Enum.Font.GothamBold
					draftBadge.TextSize = 11
					draftBadge.TextColor3 = Theme.Gold
					draftBadge.Parent = slotButton
				end
				local icon = Instance.new("Frame")
				icon.Name = "SpellIconPreview"
				icon.Position = UDim2.fromScale(0.17, 0.17)
				icon.Size = UDim2.fromScale(0.66, 0.48)
				icon.BackgroundColor3 = Color3.fromRGB(210, 182, 132)
				icon.BorderSizePixel = 0
				icon.Parent = slotButton
				if spell then
					SpellVisual.render(icon, spell, true)
				else
					local iconGradient = Instance.new("UIGradient")
					iconGradient.Rotation = 90
					iconGradient.Color = ColorSequence.new(Color3.fromRGB(230, 206, 164), Color3.fromRGB(184, 147, 98))
					iconGradient.Parent = icon
					local empty = Instance.new("TextLabel")
					empty.Size = UDim2.fromScale(1, 1)
					empty.BackgroundTransparency = 1
					empty.Text = "◇"
					empty.Font = Enum.Font.Garamond
					empty.TextScaled = true
					empty.TextColor3 = Color3.fromRGB(92, 63, 34)
					empty.Parent = icon
				end
				local iconEdge = Instance.new("UIStroke")
				iconEdge.Color = Color3.fromRGB(120, 86, 46)
				iconEdge.Thickness = 1
				iconEdge.Parent = icon
				local caption = Instance.new("TextLabel")
				caption.Name = "SpellName"
				caption.Position = UDim2.fromScale(0.06, 0.7)
				caption.Size = UDim2.fromScale(0.88, 0.23)
				caption.BackgroundTransparency = 1
				caption.Text = if spell then spell.Name else "EMPTY SLOT"
				caption.Font = Enum.Font.GothamBold
				caption.TextScaled = true
				caption.TextWrapped = true
				caption.TextColor3 = Theme.Ink
				caption.Parent = slotButton
				local captionLimit = Instance.new("UITextSizeConstraint")
				captionLimit.MinTextSize = 10
				captionLimit.MaxTextSize = 17
				captionLimit.Parent = caption
			end
			local function layoutHome()
				local geometry = HomeLayout.compute(home.AbsoluteSize.X, scroll.AbsoluteSize.Y)
				grid.CellSize = UDim2.fromOffset(geometry.Cell, geometry.Cell)
				slotsPage.Position = UDim2.fromOffset(geometry.SlotsX, geometry.SlotsY)
				slotsPage.Size = UDim2.fromOffset(geometry.GridSize, geometry.GridSize)
				createPage.Position = UDim2.fromOffset(geometry.CreateX, geometry.CreateY)
				createPage.Size = UDim2.fromOffset(geometry.CreateSize, geometry.CreateSize)
				createTile.Size = UDim2.fromScale(1, 1)
				home.Size = UDim2.new(1, -8, 0, geometry.CanvasHeight)
			end
			home:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutHome)
			local resizeConnection = scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutHome)
			home.Destroying:Connect(function()
				resizeConnection:Disconnect()
			end)
			layoutHome()
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
		if editorPreview then SpellVisual.render(editorPreview, draft, false) end
		if panel.AbsoluteSize.X < 680 then
			local previewHolder = canvasBlock(170)
			mobileEditorPreview = Instance.new("Frame")
			mobileEditorPreview.Name = "LiveSpellVisualPreview"
			mobileEditorPreview.Size = UDim2.new(1, 0, 1, 0)
			mobileEditorPreview.Parent = previewHolder
			SpellVisual.render(mobileEditorPreview, draft, false)
		end
		if activeSection == "Setup" then
			local modeRow = row("EDITING MODE")
			button(modeRow, if authoringMode == "Expert" then "WORKSHOP" else "GUIDED", function()
				authoringMode = if authoringMode == "Expert" then "Guided" else "Expert"
				expertSearch = ""
				rebuildPreservingScroll()
			end)
		end
		if authoringMode == "Expert" then
			local searchRow = row("SEARCH THIS CHAPTER")
			local search = Instance.new("TextBox")
			search.Position, search.Size = UDim2.new(0.42, 0, 0, 4), UDim2.new(0.57, -4, 1, -8)
			search.BackgroundColor3, search.TextColor3 = Theme.Surface, Theme.Ink
			search.BorderColor3, search.BorderSizePixel = Theme.Border, 1
			search.PlaceholderText, search.PlaceholderColor3 = "Find a control by name or label", Theme.SubtleInk
			search.Text, search.TextSize = expertSearch, 14
			search.ClearTextOnFocus, search.Parent = false, searchRow
			search.FocusLost:Connect(function()
				expertSearch = search.Text
				rebuildPreservingScroll()
			end)
		end
		local draftValid, draftIssue = Spec.validate(draft)
		if not draftValid then
			info("Validation needs attention · " .. creatorFacingText(draftIssue), 48)
		end
		-- Page choices are the square buttons above the chapter controls.

		local function showFields(object, fields)
			for _, field in fields do
				renderField(object, field)
			end
		end
		if activeSection == "Setup" or activeSection == "Casting" then
			if activeSection == "Setup" then
				heading("1 · CHOOSE A SPELL FORM")
				local formOptions = {}
				for _, formName in Schema.FormOrder do
					local candidate = Spec.createDraft(formName, internalDefaultForForm(formName))
					if candidate then ensureVisualDefaults(candidate) end
					table.insert(formOptions, {
						Id = formName,
						Label = Schema.Forms[formName].Label,
						Hint = if draft.Form == formName then "CURRENT FORM" else "CHOOSE FORM",
						Selected = draft.Form == formName,
						Preview = candidate,
						Action = function()
							resetForForm(formName)
							rebuild()
							estimate()
						end,
					})
				end
				creationChoiceGrid(formOptions)
				info(form.Description, 80)
				info(
					"Form controls how a spell reaches the world. Effects define what happens. Changing Form resets shape settings while keeping existing effects and their timing for review.",
					54
				)
				heading("2 · NAME & ORGANIZATION")
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
					draft.Name = nameBox.Text
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
							draft.Casting.ManaUpkeepPerSecond = 45
							draft.Lifetime = { Mode = "FixedDuration", Duration = 5 }
						elseif value == "Toggle" then
							local endWhen = draft.Lifetime.EndWhen
							draft.Casting.MinimumCharge = nil
							draft.Casting.MaximumCharge = nil
							if CastingSpec.isHeldMode(previousMode) then
								draft.Casting.ManaUpkeepPerSecond = nil
								draft.Casting.StrainPerSecond = nil
							end
							draft.Lifetime = { Mode = "UntilToggledOff", EndWhen = endWhen }
						elseif value == "CommandCast" then
							draft.Casting.MinimumCharge = nil
							draft.Casting.MaximumCharge = nil
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
							if CastingSpec.isHeldMode(previousMode) then
								draft.Casting.ManaUpkeepPerSecond = nil
								draft.Casting.StrainPerSecond = nil
							end
							draft.Casting.ManaUpkeepPerSecond = 45
							draft.Lifetime = { Mode = "FixedDuration", Duration = 5 }
						else
							draft.Casting.MinimumCharge = nil
							draft.Casting.MaximumCharge = nil
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
				end
				if
					LifetimeSpec.supports(draft.Form, "UntilToggledOff")
					and draft.Casting.Mode ~= "Channeled"
					and draft.Casting.Mode ~= "Toggle"
					and draft.Casting.Mode ~= "Sustained"
				then
					toggle(
						"Remain active until toggled off",
						draft.Lifetime.Mode == "UntilToggledOff",
						function(value)
							local endWhen = draft.Lifetime.EndWhen
							draft.Lifetime = if value
								then { Mode = "UntilToggledOff", EndWhen = endWhen }
								else { Mode = "FixedDuration", Duration = 10, EndWhen = endWhen }
						end,
						"Fields, Auras, Self Enhancements, and Constructs stay active until you cast the same spell again."
					)
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
						"How long this enhancement remains active after casting."
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
					"Maximum distance from the active Self Enhancement's caster or Construct where a target can trigger OnProximity."
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
					local propertyChoices = {}
					for family, properties in ConditionSpec.Properties do
						for property in properties do
							table.insert(propertyChoices, family .. "." .. property)
						end
					end
					table.sort(propertyChoices)
					local function replaceNode(parent, index, replacement)
						local ok, root = ConditionTree.replace(draft.Conditions, parent, index, replacement)
						if ok and not parent then
							draft.Conditions = root
						end
					end
					local function defaultFor(descriptor)
						return if descriptor.Kind == "Boolean"
							then true
							elseif descriptor.Kind == "Number" then descriptor.Min
							else ""
					end
					local function renderNode(node, parent, index, depth)
						local path = if parent then "Nested " .. tostring(index) else "Root"
						if ConditionTree.isGroup(node) then
							if node.Operator == "NOT" then
								info(path .. " group · NOT (the child result must fail)", 34)
								local unwrapRow = row("Remove NOT wrapper")
								button(unwrapRow, "UNWRAP", function()
									replaceNode(parent, index, ConditionTree.unwrapNot(node))
									rebuild()
									estimate()
								end)
							else
								select("Group logic · " .. path, node.Operator, { "ALL", "ANY" }, function(value)
									node.Operator = value
								end, function(value)
									return if value == "ALL" then "Require all children" else "Allow any child"
								end, "ALL requires every child. ANY passes when at least one child passes.")
								card(
									"Invert group · " .. path,
									"Wrap this group in NOT.",
									false,
									function()
										local wrapped = ConditionTree.wrapNot(node)
										if wrapped then
											replaceNode(parent, index, wrapped)
										end
									end,
									depth + ConditionTree.maxDepth(node) <= ConditionSpec.MaxDepth
										and ConditionTree.countNodes(draft.Conditions) < ConditionSpec.MaxNodes
								)
							end
							for childIndex, child in ipairs(node.Conditions or {}) do
								renderNode(child, node, childIndex, depth + 1)
							end
							if node.Operator ~= "NOT" then
								local nodeCount = ConditionTree.countNodes(draft.Conditions)
								local canAddRule = #node.Conditions < ConditionSpec.MaxChildren
									and nodeCount + 1 <= ConditionSpec.MaxNodes
									and depth < ConditionSpec.MaxDepth
								local canAddGroup = #node.Conditions < ConditionSpec.MaxChildren
									and nodeCount + 2 <= ConditionSpec.MaxNodes
									and depth + 1 < ConditionSpec.MaxDepth
								card(
									"Add rule · " .. path,
									"Add one explicitly exposed server value.",
									false,
									function()
										ConditionTree.addRule(
											node,
											ConditionSpec.MaxChildren,
											ConditionSpec.MaxNodes,
											draft.Conditions
										)
									end,
									canAddRule,
									"This group, depth, or tree has reached its safe limit."
								)
								card(
									"Add nested ALL group · " .. path,
									"Create a subgroup whose every rule must pass.",
									false,
									function()
										ConditionTree.addGroup(
											node,
											"ALL",
											ConditionSpec.MaxChildren,
											ConditionSpec.MaxNodes,
											draft.Conditions
										)
									end,
									canAddGroup,
									"This group, depth, or tree has reached its safe limit."
								)
								card(
									"Add nested ANY group · " .. path,
									"Create a subgroup where any one rule may pass.",
									false,
									function()
										ConditionTree.addGroup(
											node,
											"ANY",
											ConditionSpec.MaxChildren,
											ConditionSpec.MaxNodes,
											draft.Conditions
										)
									end,
									canAddGroup,
									"This group, depth, or tree has reached its safe limit."
								)
							end
							if parent and parent.Operator ~= "NOT" then
								card(
									"Remove group · " .. path,
									"Remove this nested condition and its children.",
									false,
									function()
										ConditionTree.remove(parent, index)
									end,
									#parent.Conditions > 1,
									"Condition groups must keep at least one child."
								)
							end
							return
						end

						local descriptor = ConditionSpec.Properties[node.Family]
							and ConditionSpec.Properties[node.Family][node.Property]
						if not descriptor then
							info(path .. " has an unsupported saved rule; remove it and add a valid one.", 42)
							if parent and parent.Operator ~= "NOT" then
								local removeInvalidRow = row("Remove invalid rule · " .. path)
								button(removeInvalidRow, "REMOVE", function()
									ConditionTree.remove(parent, index)
									rebuild()
								end)
							end
							return
						end
						info("Rule · " .. path, 26)
						select(
							"Runtime property · " .. path,
							node.Family .. "." .. node.Property,
							propertyChoices,
							function(value)
								local family, property = string.match(value, "^([^%.]+)%.(.+)$")
								local nextDescriptor = ConditionSpec.Properties[family][property]
								node.Family, node.Property = family, property
								node.Operator = nextDescriptor.Operators[1]
								node.Value = defaultFor(nextDescriptor)
							end,
							nil,
							"Only whitelisted server-resolved values are available."
						)
						select("Comparison · " .. path, node.Operator, descriptor.Operators, function(value)
							node.Operator = value
						end)
						if descriptor.Kind == "Number" then
							numeric(
								"Number value · " .. path,
								node,
								"Value",
								"Compare against this bounded runtime value."
							)
						elseif descriptor.Kind == "Boolean" then
							toggle("Value is true · " .. path, node.Value, function(value)
								node.Value = value
							end)
						else
							local valueRow = row("Text value · " .. path)
							local box = Instance.new("TextBox")
							box.Size = UDim2.new(0.4, 0, 1, 0)
							box.Position = UDim2.new(0.59, 0, 0, 0)
							box.BackgroundColor3 = Theme.Surface
							box.TextColor3 = Theme.Ink
							box.BorderColor3, box.BorderSizePixel = Theme.Border, 1
							box.TextSize = 14
							box.ClearTextOnFocus = false
							box.Text = tostring(node.Value or "")
							box.Parent = valueRow
							box.FocusLost:Connect(function()
								node.Value = string.sub(box.Text, 1, descriptor.MaxLength)
								estimate()
							end)
						end
						if parent and parent.Operator ~= "NOT" then
							card("Remove rule · " .. path, "Remove this condition rule.", false, function()
								ConditionTree.remove(parent, index)
							end, #parent.Conditions > 1, "Condition groups must keep at least one child.")
						end
						if depth < ConditionSpec.MaxDepth then
							local canWrap = depth + 1 <= ConditionSpec.MaxDepth
								and ConditionTree.countNodes(draft.Conditions) < ConditionSpec.MaxNodes
							card("Invert rule · " .. path, "Wrap this rule in NOT.", false, function()
								local wrapped = ConditionTree.wrapNot(node)
								if wrapped then
									replaceNode(parent, index, wrapped)
								end
							end, canWrap)
							card(
								"Nest rule in ALL · " .. path,
								"Place this rule inside a new ALL group.",
								false,
								function()
									local nested = ConditionTree.newGroup("ALL")
									if nested then
										nested.Conditions[1] = node
										replaceNode(parent, index, nested)
									end
								end,
								canWrap
							)
						end
					end
					renderNode(draft.Conditions, nil, nil, 1)
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
			heading(if configuring then "CONFIGURE THE SELECTED EFFECTS" else "CHOOSE COMPATIBLE EFFECTS")
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
			for _, category in ipairs(EffectCategoryOrder) do
				local kinds = {}
				for kind, definition in Schema.Payloads do
					if effectCategory(kind) == category then
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
				if not configuring or hasSelectedEffect then
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
														value.RespawnPolicy = value.RespawnPolicy or "DismissOnDeath"
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
														value.SpellSlot = if selected == "None" then nil else selected
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
								end
							end
						end
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
					for _, payloadKind in definition.PayloadKinds or {} do
						local payloadDefinition = Schema.Payloads[payloadKind]
						for _, value in current.Payloads or {} do
							if value.Kind == payloadKind then
								heading(payloadDefinition.Label .. " in blast")
								showFields(value, payloadDefinition.Fields)
							end
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
			local cost = Spec.estimate(draft)
			heading("SERVER-ESTIMATED CAST DEMAND")
			info(
				string.format(
					"Estimated per cast: %d mana · %d strain · complexity %d\nWhile active: %g mana/s · %g strain/s\nThese are authored spell estimates; caster state and target defenses still affect actual results.",
					cost.ManaDemand,
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
		elseif activeSection == "Presentation" then
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
			heading("SANDBOX CONTROLS")
			toggle(
				"Show combat feedback messages",
				feedbackVisible,
				function(value)
					feedbackVisible = value
				end,
				"Shows damage and invalid-cast feedback briefly during combat. Health bars stay visible on training dummies."
			)
			info(
				"Training dummies are stationary targets. Their health bars show damage and healing; test movement on a movable object or another player. Ending active spells may trigger their On expire effects. Testing continues while this book is open.",
				96
			)
			heading("TRAINING TARGETS")
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
		end
	end
	local function preview(direction, point, target)
		drawFolder:ClearAllChildren()
		if not debugGeometry then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local function anchor(name, position)
			local part = Instance.new("Part")
			part.Name = name
			part.Size = Vector3.one * 0.05
			part.CFrame = CFrame.new(position)
			part.Anchored = true
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part.Transparency = 1
			part.Parent = drawFolder
			Debris:AddItem(part, 1.5)
			return part
		end
		local function sphere(name, center, radius, color, transparency)
			if radius <= 0 then
				return
			end
			local adornee = anchor(name .. "Anchor", center)
			local adornment = Instance.new("SphereHandleAdornment")
			adornment.Name = name
			adornment.Adornee = adornee
			adornment.Radius = radius
			adornment.Color3 = color
			adornment.Transparency = transparency
			adornment.AlwaysOnTop = false
			adornment.ZIndex = 1
			adornment.Parent = adornee
		end
		local function areaShape(name, center, shape, area, color)
			if shape == "Sphere" then
				sphere(name, center, area.Radius, color, 0.72)
				return
			end
			if shape == "Capsule" then
				local radius = area.Radius
				local stemHeight = math.max(area.Height - radius * 2, 0.05)
				local function capsulePart(partName, partShape, size, cframe)
					local part = Instance.new("Part")
					part.Name = partName
					part.Shape = partShape
					part.Size = size
					part.CFrame = cframe
					part.Anchored = true
					part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
					part.Material, part.Color, part.Transparency = Enum.Material.Neon, color, 0.78
					part.Parent = drawFolder
					Debris:AddItem(part, 1.5)
				end
				local frame = CFrame.new(center) * CFrame.Angles(0, math.rad(area.Yaw or 0), 0)
				capsulePart(
					name .. "CapsuleBody",
					Enum.PartType.Cylinder,
					Vector3.new(stemHeight, radius * 2, radius * 2),
					frame * CFrame.Angles(0, 0, math.rad(90))
				)
				for _, sign in { -1, 1 } do
					capsulePart(
						name .. "CapsuleCap",
						Enum.PartType.Ball,
						Vector3.one * radius * 2,
						frame * CFrame.new(0, sign * stemHeight / 2, 0)
					)
				end
				return
			end
			if shape == "Ring" then
				local anchor = Instance.new("Part")
				anchor.Name = name .. "RingAnchor"
				anchor.Size = Vector3.one * 0.1
				anchor.CFrame = CFrame.new(center)
				anchor.Anchored = true
				anchor.Transparency = 1
				anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
				anchor.Parent = drawFolder
				local function edge(first: Vector3, second: Vector3)
					local a, b = Instance.new("Attachment"), Instance.new("Attachment")
					a.Position, b.Position = first, second
					a.Parent, b.Parent = anchor, anchor
					local beam = Instance.new("Beam")
					beam.Name = name .. "RingBoundary"
					beam.Attachment0, beam.Attachment1 = a, b
					beam.Color = ColorSequence.new(color)
					beam.Transparency = NumberSequence.new(0.2)
					beam.Width0, beam.Width1 = 0.06, 0.06
					beam.FaceCamera = false
					beam.Parent = anchor
				end
				local function circle(radius: number, y: number)
					local segments = 24
					for index = 0, segments - 1 do
						local firstAngle = index / segments * math.pi * 2
						local secondAngle = (index + 1) / segments * math.pi * 2
						edge(
							Vector3.new(math.cos(firstAngle) * radius, y, math.sin(firstAngle) * radius),
							Vector3.new(math.cos(secondAngle) * radius, y, math.sin(secondAngle) * radius)
						)
					end
				end
				local halfHeight = area.Height / 2
				for _, y in { -halfHeight, halfHeight } do
					circle(area.InnerRadius, y)
					circle(area.OuterRadius, y)
				end
				for _, angle in { 0, math.pi / 2, math.pi, math.pi * 1.5 } do
					local x, z = math.cos(angle), math.sin(angle)
					for _, y in { -halfHeight, halfHeight } do
						edge(
							Vector3.new(x * area.InnerRadius, y, z * area.InnerRadius),
							Vector3.new(x * area.OuterRadius, y, z * area.OuterRadius)
						)
					end
					edge(
						Vector3.new(x * area.InnerRadius, -halfHeight, z * area.InnerRadius),
						Vector3.new(x * area.InnerRadius, halfHeight, z * area.InnerRadius)
					)
					edge(
						Vector3.new(x * area.OuterRadius, -halfHeight, z * area.OuterRadius),
						Vector3.new(x * area.OuterRadius, halfHeight, z * area.OuterRadius)
					)
				end
				Debris:AddItem(anchor, 1.5)
				return
			end
			if shape == "Cone" then
				local frame = CFrame.new(center) * CFrame.Angles(0, math.rad(area.Yaw or 0), 0)
				local anchor = Instance.new("Part")
				anchor.Name = name .. "ConeAnchor"
				anchor.Size = Vector3.one * 0.1
				anchor.CFrame = frame
				anchor.Anchored = true
				anchor.Transparency = 1
				anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
				anchor.Parent = drawFolder
				local halfHeight = area.Height / 2
				local halfWidth = area.Range * math.tan(math.rad(area.Angle / 2))
				local function edge(first: Vector3, second: Vector3)
					local a, b = Instance.new("Attachment"), Instance.new("Attachment")
					a.Position, b.Position = first, second
					a.Parent, b.Parent = anchor, anchor
					local beam = Instance.new("Beam")
					beam.Name = name .. "ConeEdge"
					beam.Attachment0, beam.Attachment1 = a, b
					beam.Color = ColorSequence.new(color)
					beam.Transparency = NumberSequence.new(0.2)
					beam.Width0, beam.Width1 = 0.06, 0.06
					beam.FaceCamera = false
					beam.Parent = anchor
				end
				for _, y in { -halfHeight, halfHeight } do
					local apex = Vector3.new(0, y, 0)
					local left = Vector3.new(-halfWidth, y, -area.Range)
					local right = Vector3.new(halfWidth, y, -area.Range)
					edge(apex, left)
					edge(apex, right)
					edge(left, right)
				end
				edge(Vector3.new(0, -halfHeight, 0), Vector3.new(0, halfHeight, 0))
				edge(
					Vector3.new(-halfWidth, -halfHeight, -area.Range),
					Vector3.new(-halfWidth, halfHeight, -area.Range)
				)
				edge(Vector3.new(halfWidth, -halfHeight, -area.Range), Vector3.new(halfWidth, halfHeight, -area.Range))
				Debris:AddItem(anchor, 1.5)
				return
			end
			local size = Geometry.areaSize(shape, area)
			local part = Instance.new("Part")
			part.Name = name
			part.Size = if shape == "Cylinder" then Vector3.new(size.Y, size.X, size.Z) else size
			part.CFrame = CFrame.new(center)
				* CFrame.Angles(0, math.rad(area.Yaw or 0), 0)
				* (if shape == "Line" then CFrame.new(0, 0, -area.Range / 2) else CFrame.identity)
				* (if shape == "Cylinder" then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity)
			part.Shape = if shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
			part.Anchored = true
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part.Material, part.Color, part.Transparency = Enum.Material.Neon, color, 0.82
			part.Parent = drawFolder
			Debris:AddItem(part, 1.5)
		end
		local function beamBetween(first, second, name)
			local a = Instance.new("Attachment")
			a.Parent = first
			local b = Instance.new("Attachment")
			b.Parent = second
			local beam = Instance.new("Beam")
			beam.Name = name
			beam.Attachment0, beam.Attachment1 = a, b
			beam.Width0, beam.Width1 = 0.08, 0.08
			beam.Color = ColorSequence.new(draft.Visual.Color)
			beam.Transparency = NumberSequence.new(0.2)
			beam.LightEmission = 0.55
			beam.FaceCamera = true
			beam.Parent = drawFolder
			Debris:AddItem(beam, 1.5)
		end
		local castOrigin = root.Position + Vector3.new(0, 1.5, 0)
		local targetRoot = if target and target:IsA("Model") then target:FindFirstChild("HumanoidRootPart") else nil
		local previewPoint = if targetRoot and targetRoot:IsA("BasePart") then targetRoot.Position else point
		local unitDirection = if direction.Magnitude > 0.001 then direction.Unit else root.CFrame.LookVector
		local aimFrame = CFrame.lookAt(castOrigin, castOrigin + unitDirection)
		if draft.Projectile then
			local position = castOrigin + unitDirection * 3
			-- The green sphere is the server hit radius; the colored core is appearance-only.
			sphere("ProjectileCollisionRadius", position, draft.Projectile.Radius, Color3.fromRGB(105, 230, 185), 0.45)
			local shape = draft.Visual.CoreShape or "Sphere"
			local appearanceScale = draft.Visual.ProjectileScale or 1
			local radius = draft.Projectile.Radius * appearanceScale
			local appearance = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
			appearance.Name = "ProjectileAppearance"
			if appearance:IsA("Part") then
				appearance.Shape =
					Enum.PartType[if shape == "Sphere" then "Ball" elseif shape == "Crystal" then "Block" else shape]
			end
			appearance.Size = Vector3.one * radius * 2
			appearance.CFrame = CFrame.new(position)
				* (
					if shape == "Crystal"
						then CFrame.Angles(math.rad(45), math.rad(45), math.rad(45))
						else CFrame.identity
				)
			appearance.Anchored = true
			appearance.CanCollide, appearance.CanTouch, appearance.CanQuery = false, false, false
			appearance.Material = visualMaterial(draft)
			appearance.Color = draft.Visual.Color
			appearance.Transparency = 1 - (draft.Visual.Opacity or 0.85)
			appearance.Parent = drawFolder
			Debris:AddItem(appearance, 1.5)
		elseif draft.Beam then
			local maximumScale = math.max(draft.Beam.GrowthStartScale or 1, draft.Beam.GrowthEndScale or 1)
			local range = math.min(draft.Beam.Range * maximumScale, draft.TargetRules.Range)
			local width = math.max(0.12, draft.Beam.Width * maximumScale)
			local part = Instance.new("Part")
			part.Name = "BeamHitVolumePreview"
			part.Size = Vector3.new(width, width, range)
			part.CFrame = CFrame.lookAt(castOrigin + unitDirection * range / 2, castOrigin + unitDirection * range)
			part.Anchored = true
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part.Material = visualMaterial(draft)
			part.Color = draft.Visual.Color
			part.Transparency = 1 - (draft.Visual.Opacity or 0.85)
			part.Parent = drawFolder
			Debris:AddItem(part, 1.5)
		elseif draft.Field then
			areaShape("FieldHitVolume", previewPoint, draft.Geometry, draft.Field, draft.Visual.Color)
		elseif draft.Aura then
			local center = if draft.Targeting == "EntityTarget" or draft.Targeting == "ObjectTarget"
				then previewPoint
				else root.Position
			areaShape("AuraHitVolume", center, draft.Geometry, draft.Aura, draft.Visual.Color)
		elseif draft.Wave then
			local maximumScale = math.max(draft.Wave.GrowthStartScale or 1, draft.Wave.GrowthEndScale or 1)
			local previewRange = draft.Wave.Range * maximumScale
			if draft.Geometry == "Sphere" then
				sphere("WaveSphere", root.Position, previewRange, draft.Visual.Color, 0.82)
			else
				local count = 10
				local halfAngle = math.acos(math.clamp(draft.Wave.Dot, -1, 1))
				local ring = {}
				local originAnchor = anchor("WaveConeOrigin", castOrigin)
				local originAttachment = Instance.new("Attachment")
				originAttachment.Parent = originAnchor
				for index = 1, count do
					local angle = (index - 1) / count * math.pi * 2
					local radial = aimFrame.RightVector * math.cos(angle) + aimFrame.UpVector * math.sin(angle)
					local edgeDirection = unitDirection * math.cos(halfAngle) + radial * math.sin(halfAngle)
					local edgeAnchor = anchor("WaveConeEdge", castOrigin + edgeDirection * previewRange)
					local edgeAttachment = Instance.new("Attachment")
					edgeAttachment.Parent = edgeAnchor
					local spoke = Instance.new("Beam")
					spoke.Name = "WaveConeBoundary"
					spoke.Attachment0, spoke.Attachment1 = originAttachment, edgeAttachment
					spoke.Width0, spoke.Width1 = 0.08, 0.08
					spoke.Color = ColorSequence.new(draft.Visual.Color)
					spoke.Transparency = NumberSequence.new(0.2)
					spoke.FaceCamera = true
					spoke.Parent = drawFolder
					Debris:AddItem(spoke, 1.5)
					ring[index] = edgeAnchor
				end
				for index = 1, count do
					beamBetween(ring[index], ring[index % count + 1], "WaveConeRim")
				end
			end
		elseif draft.Construct then
			local center = if draft.Targeting == "WorldPoint"
				then point
				else castOrigin + unitDirection * draft.Construct.Distance
			local flatDirection = Vector3.new(unitDirection.X, 0, unitDirection.Z)
			if flatDirection.Magnitude < 0.001 then
				flatDirection = Vector3.new(0, 0, -1)
			end
			local frame = CFrame.lookAt(center, center + flatDirection.Unit)
			local components = ConstructGeometrySpec.components(
				draft.Geometry,
				draft.Construct.Width,
				draft.Construct.Height,
				draft.Construct.Depth,
				draft.Construct.Components
			)
			local previewScale = if draft.Construct.GrowthDuration and draft.Construct.GrowthDuration > 0
				then draft.Construct.GrowthStartScale or 1
				else 1
			for index, component in ipairs(components or {}) do
				local part = Instance.new(if component.Shape == "Wedge" then "WedgePart" else "Part")
				part.Name = string.format("ConstructGeometryPreview%02d", index)
				part.Size = Vector3.new(component.Size[1], component.Size[2], component.Size[3]) * previewScale
				if part:IsA("Part") then
					part.Shape = Enum.PartType[component.Shape]
				end
				local rotation = component.RotationDegrees
				part.CFrame = frame
					* CFrame.new(
						component.Offset[1] * previewScale,
						component.Offset[2] * previewScale,
						component.Offset[3] * previewScale
					)
					* CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
				part.Anchored = true
				part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
				part.Material, part.Color, part.Transparency = Enum.Material.Neon, draft.Visual.Color, 0.84
				part.Parent = drawFolder
				Debris:AddItem(part, 1.5)
			end
		end
		for triggerEvent, steps in pairs(draft.Triggers or {}) do
			for _, step in ipairs(steps or {}) do
				if step.Behavior == "Explode" then
					local explosionCenter = if triggerEvent == "OnCast" and draft.Form == "Wave"
						then root.Position
						else previewPoint
					sphere(
						"ExplosionRadiusAt" .. triggerEvent,
						explosionCenter,
						step.Radius,
						Color3.fromRGB(255, 167, 89),
						0.78
					)
				end
			end
		end
		if draft.TargetRules then
			sphere("TargetingRange", root.Position, draft.TargetRules.Range, Color3.fromRGB(255, 221, 105), 0.94)
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
				rebuild()
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
			rebuild()
		end
	end)
	trainingResponse.OnClientEvent:Connect(function(ok, text, count, limit)
		message(string.format("%s  (%d / %d owned)", text, count or 0, limit or 0), ok)
	end)
	remotes:WaitForChild("ActionFeedback").OnClientEvent:Connect(function(data)
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
	bar.Activated:Connect(function()
		rebuild()
		visibility(true)
	end)
	ContextActionService:BindAction("ToggleGrimoireGamepad", function(_, state)
		if state == Enum.UserInputState.Begin then
			rebuild()
			visibility(not panel.Visible)
			if panel.Visible then
				game:GetService("GuiService").SelectedObject = closeButton
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonSelect)
	UIS.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.P and not UIS:GetFocusedTextBox() then
			if panel.Visible then
				visibility(false)
			else
				rebuild()
				visibility(true)
			end
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
		local direction = aim()
		if direction.Magnitude < 0.9 then
			return
		end
		send(Protocol.MagicAimUpdate, { SpellId = spell.SpellId, AimDirection = direction.Unit })
	end
	for slot, key in slotKeys do
		local held = false
		ContextActionService:BindActionAtPriority("MagicLabSlot" .. slot, function(_, state)
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
			if state == Enum.UserInputState.Begin and player:GetAttribute("OpeningComplete") then
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
		end, false, Enum.ContextActionPriority.High.Value + 1, key)
	end
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
