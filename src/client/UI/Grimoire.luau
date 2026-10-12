--!strict
-- Presentation only: owns no spell data, input bindings, or persistence.
local Grimoire = {}
local Theme = require(script.Parent.GrimoireTheme)
local Art = require(script.Parent.GrimoireArt)
local ink = Theme.Ink
local mutedInk = Theme.MutedInk
local gold = Theme.Gold
local leather = Theme.Binding
local paperLight = Theme.Page

function Grimoire.mount(panel, navigation, scroll, status, title, summary, sections)
	panel.BorderSizePixel = 0
	panel.BackgroundColor3 = paperLight
	panel.ClipsDescendants = true
	local outline = Instance.new("UIStroke")
	outline.Color = Theme.BindingEdge
	outline.Thickness = 5
	outline.Parent = panel
	local page = Instance.new("Frame")
	page.Name = "OpenPages"
	page.Position = UDim2.fromOffset(9, 9)
	page.Size = UDim2.new(1, -18, 1, -18)
	page.BackgroundColor3 = paperLight
	page.BorderSizePixel = 0
	page.ZIndex = 1
	page.Parent = panel
	local notebook = Instance.new("ImageLabel")
	notebook.Name = "NotebookArtwork"
	notebook.Size = UDim2.fromScale(1, 1)
	notebook.BackgroundTransparency = 1
	notebook.ZIndex = 1
	notebook.Image = Art.NotebookImageId or ""
	notebook.Visible = type(Art.NotebookImageId) == "string" and Art.NotebookImageId ~= ""
	notebook.Parent = page
	local pageCorner = Instance.new("UICorner")
	pageCorner.CornerRadius = UDim.new(0, 5)
	pageCorner.Parent = page
	local pageEdge = Instance.new("UIStroke")
	pageEdge.Color = Theme.PageEdge
	pageEdge.Transparency = 0.08
	pageEdge.Thickness = 1
	pageEdge.Parent = page
	local paper = Instance.new("UIGradient")
	paper.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.PageShade),
		ColorSequenceKeypoint.new(0.08, paperLight),
		ColorSequenceKeypoint.new(0.48, Theme.PageHighlight),
		ColorSequenceKeypoint.new(0.52, Theme.PageShade),
		ColorSequenceKeypoint.new(0.92, paperLight),
		ColorSequenceKeypoint.new(1, Theme.PageShade),
	})
	paper.Parent = page
	local function label(name, text, size)
		local item = Instance.new("TextLabel")
		item.Name = name
		item.BackgroundTransparency = 1
		item.TextColor3 = ink
		item.Font = Enum.Font.Garamond
		item.TextSize = size
		item.TextWrapped = true
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.Text = text
		item.Parent = panel
		return item
	end
	local contents = label("Contents", "CONTENTS  /  SPELL LIBRARY", 15)
	contents.TextColor3 = gold
	local chapter = label("Chapter", "The spell library", 24)
	local purpose = label("Purpose", "Choose a slot to read or author its spell.", 14)
	purpose.Font = Enum.Font.Gotham
	purpose.TextColor3 = mutedInk
	local folio = label("Folio", "ENFLESHED  ·  MAGIC LAB", 12)
	folio.TextColor3 = gold
	local seam = Instance.new("Frame")
	seam.Name = "Binding"
	seam.BackgroundColor3 = Theme.PageEdge
	seam.BackgroundTransparency = 0.15
	seam.BorderSizePixel = 0
	seam.Parent = panel
	local topRule = Instance.new("Frame")
	topRule.Name = "GiltRule"
	topRule.BorderSizePixel = 0
	topRule.BackgroundColor3 = gold
	topRule.BackgroundTransparency = 0.3
	topRule.Parent = panel
	local overview = Instance.new("ScrollingFrame")
	overview.Name = "LiveSpellSummary"
	overview.BackgroundColor3 = Theme.PageShade
	overview.BackgroundTransparency = 0
	overview.BorderSizePixel = 0
	overview.ScrollBarThickness = 3
	overview.ScrollBarImageColor3 = gold
	overview.AutomaticCanvasSize = Enum.AutomaticSize.None
	overview.CanvasSize = UDim2.new()
	overview.ScrollingEnabled = false
	overview.Parent = panel
	local overviewCorner = Instance.new("UICorner")
	overviewCorner.CornerRadius = UDim.new(0, 4)
	overviewCorner.Parent = overview
	local overviewStroke = Instance.new("UIStroke")
	overviewStroke.Color = Theme.Border
	overviewStroke.Transparency = 0.08
	overviewStroke.Parent = overview
	local overviewLabel = label("SummaryHeading", "LIVE SPELL PREVIEW", 16)
	overviewLabel.Font = Enum.Font.Garamond
	overviewLabel.TextColor3 = gold
	overviewLabel.Parent = overview
	local overviewText = label("SummaryText", "", 12)
	overviewText.Font = Enum.Font.Gotham
	overviewText.TextColor3 = mutedInk
	overviewText.TextSize = 14
	overviewText.TextYAlignment = Enum.TextYAlignment.Top
	overviewText.Size = UDim2.new(1, -20, 0, 0)
	overviewText.AutomaticSize = Enum.AutomaticSize.Y
	overviewText.Parent = overview
	overviewLabel.Position = UDim2.fromOffset(14, 10)
	overviewLabel.Size = UDim2.new(1, -28, 0, 23)
	overviewText.Position = UDim2.new(0, 14, 1, -56)
	overviewText.Size = UDim2.new(1, -28, 0, 46)
	overviewText.AutomaticSize = Enum.AutomaticSize.None
	overviewText.TextTruncate = Enum.TextTruncate.AtEnd
	overviewText.Visible = false
	panel:GetAttributeChangedSignal("SpellSummary"):Connect(function()
		overviewText.Text = panel:GetAttribute("SpellSummary") or ""
	end)
	for _, child in { navigation, scroll, status, title, summary, contents, chapter, purpose, folio, seam, topRule, overview } do
		child.ZIndex = 10
	end
	title.TextColor3 = ink

	local mode, current = "Slots", "Setup"
	local actionFrame
	local function layout()
		local width, height = panel.AbsoluteSize.X, panel.AbsoluteSize.Y
		local wide = width >= 850
		local editorSpread = mode == "Editor" and width >= 680
		local compact = height < 560
		local left = if wide and mode == "Editor" then 0.31 else 0
		local sideInset = if wide then 24 else 16
		local contentInset = if notebook.Visible and wide and mode ~= "Editor" then 72 else (if wide then 24 else 16)
		local navCount = #sections + 1
		summary.Visible = true

		page.Position = UDim2.fromOffset(8, 8)
		page.Size = UDim2.new(1, -16, 1, -16)
		local pageMargin = if notebook.Visible and width >= 500 then 70 else 24
		local headingInset = if mode == "Slots" then 0 else 28
		title.Position = UDim2.fromOffset(pageMargin + headingInset, if notebook.Visible then 29 else 12)
		title.Size = UDim2.new(1, -(pageMargin + headingInset + 54), 0, 30)
		summary.Position = UDim2.fromOffset(pageMargin + headingInset, if notebook.Visible then 55 else 43)
		summary.Size = UDim2.new(1, -(pageMargin + headingInset + 26), 0, 27)
		summary.Font = Enum.Font.Gotham
		summary.TextSize = 12
		summary.TextColor3 = mutedInk
		contents.Visible = wide and mode == "Editor"
		contents.Position = UDim2.new(0, sideInset, 0, 91)
		contents.Size = UDim2.new(left, -sideInset * 2, 0, 22)
		seam.Visible = wide and mode == "Editor"
		seam.Position = UDim2.new(left, 0, 0, 82)
		seam.Size = UDim2.new(0, 1, 1, -102)
		topRule.Position = UDim2.new(left, 20, 0, 80)
		topRule.Size = UDim2.new(1 - left, -40, 0, 1)

		navigation.ScrollBarThickness = if wide then 3 else 2
		navigation.ScrollBarImageColor3 = gold
		navigation.BackgroundTransparency = 1
		navigation.BorderSizePixel = 0
		navigation.ScrollingDirection = if wide then Enum.ScrollingDirection.Y else Enum.ScrollingDirection.X
		navigation.ScrollingEnabled = mode == "Editor"
		local navTop = if compact and not wide then 80 else 84
		local navHeight = if wide then math.min(330, math.max(132, height - 500)) else 42
		navigation.Position = if wide then UDim2.new(0, sideInset, 0, 120) else UDim2.new(0, 16, 0, navTop)
		navigation.Size = if wide
			then UDim2.new(left, -sideInset * 2, 0, navHeight)
			else UDim2.new(1, -32, 0, navHeight)
		local back = navigation:FindFirstChild("TextButton")
		local index = 0
		local function place(tab, n)
			if wide then
				tab.Position = UDim2.fromOffset(0, n * 42)
				tab.Size = UDim2.new(1, -4, 0, 36)
			else
				tab.Position = UDim2.fromOffset(n * 126, 0)
				tab.Size = UDim2.fromOffset(120, 38)
			end
		end
		if back then
			place(back, index)
			index += 1
		end
		for _, section in sections do
			local tab = navigation:FindFirstChild(section.Id)
			if tab then
				place(tab, index)
				tab.Text = (if section.Id == current then "◆  " else "◇  ") .. section.Label
				index += 1
			end
		end
		if wide then
			navigation.CanvasSize = UDim2.fromOffset(0, navCount * 42)
		else
			navigation.CanvasSize = UDim2.fromOffset(navCount * 126, 0)
		end

		local contentTop
		if wide then
			chapter.Position = UDim2.new(left, contentInset, 0, 104)
			chapter.Size = UDim2.new(1 - left, -contentInset * 2, 0, 32)
			purpose.Position = UDim2.new(left, contentInset, 0, 140)
			purpose.Size = UDim2.new(1 - left, -contentInset * 2, 0, 34)
			contentTop = if mode == "Slots" or mode == "Create" or mode == "Library" then 93 else 184
		else
			chapter.Position = UDim2.new(0, 20, 0, if compact then 130 else 136)
			chapter.Size = UDim2.new(1, -40, 0, 30)
			purpose.Position = UDim2.new(0, 20, 0, if compact then 160 else 168)
			purpose.Size = UDim2.new(1, -40, 0, if compact then 0 else 32)
			purpose.Visible = not compact
			contentTop = if mode == "Slots" or mode == "Create" or mode == "Library" then 86 else (if compact then 166 else 208)
		end
		if wide or not compact then
			purpose.Visible = true
		end
		chapter.Visible = mode ~= "Slots" and mode ~= "Create" and mode ~= "Library"
		purpose.Visible = mode ~= "Slots" and mode ~= "Create" and mode ~= "Library" and purpose.Visible
		local mainLeft = if wide then left else 0
		scroll.Position = UDim2.new(mainLeft, contentInset, 0, contentTop)
		scroll.Size = UDim2.new(1 - mainLeft, -contentInset * 2, 1, -(contentTop + (if mode == "Slots" or mode == "Create" or mode == "Library" then 58 else 132)))
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 5
		scroll.ScrollBarImageColor3 = gold

		status.Position = if wide then UDim2.new(left, contentInset, 1, -112) else UDim2.new(0, 20, 1, -112)
		status.Size = UDim2.new(1 - (if wide then left else 0), -contentInset * 2, 0, 46)
		status.BackgroundTransparency = 1
		status.TextColor3 = ink
		status.TextSize = 12
		status.TextWrapped = true
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.TextYAlignment = Enum.TextYAlignment.Center
		if mode == "Library" then
			status.Visible = false
			summary.Visible = false
			topRule.Visible = false
		end

		if wide then
			local overviewTop = 130 + navHeight + 14
			overview.Position = UDim2.new(0, sideInset, 0, overviewTop)
			overview.Size = UDim2.new(left, -sideInset * 2, 1, -(overviewTop + 130))
			overviewLabel.LayoutOrder = 1
			overviewText.LayoutOrder = 3
			overview.Visible = mode == "Editor"
			folio.Visible = mode == "Editor" and height >= 520
			folio.Position = UDim2.new(0, sideInset, 1, -30)
			folio.Size = UDim2.new(left, -sideInset * 2, 0, 20)
		else
			overview.Visible = false
			folio.Visible = false
		end
		if actionFrame then
			actionFrame.ZIndex = 10
			actionFrame.Position = UDim2.new(mainLeft, contentInset, 1, -58)
			actionFrame.Size = UDim2.new(1 - mainLeft, -contentInset * 2, 0, 42)
		end
		if editorSpread then
			-- The notebook's left page contains the controls; the right page is a live visual plate.
			local pageWidth = width / 2
			local margin = if notebook.Visible then 45 else 24
			local leftWidth = pageWidth - margin - 18
			local gap = 6
			local cell = math.floor((leftWidth - gap * 4) / 5)
			local navHeight = cell * 2 + gap
			title.Position = UDim2.fromOffset(margin + 50, 24)
			title.Size = UDim2.new(1, -(margin + 102), 0, 29)
			summary.Position = UDim2.fromOffset(margin + 50, 52)
			summary.Size = UDim2.new(1, -(margin + 102), 0, 20)
			contents.Visible = false
			chapter.Visible = false
			purpose.Visible = false
			folio.Visible = false
			seam.Visible = false
			topRule.Visible = false
			navigation.Position = UDim2.fromOffset(margin, 86)
			navigation.Size = UDim2.fromOffset(leftWidth, navHeight + 2)
			navigation.ScrollingEnabled = false
			navigation.ScrollBarThickness = 0
			local editorTabs = { "BACK", "FORM", "TARGET", "RULES", "CHOOSE", "TUNE", "CAST", "COST", "LOOK", "TEST" }
			local index = 0
			local function placeEditorTab(tab)
				tab.Position = UDim2.fromOffset((index % 5) * (cell + gap), math.floor(index / 5) * (cell + gap))
				tab.Size = UDim2.fromOffset(cell, cell)
				tab.BackgroundColor3 = if tab.Name == current then Theme.Accent else Theme.Surface
				tab.TextColor3 = if tab.Name == current then Theme.OnAccent else Theme.Ink
				tab.Text = editorTabs[index + 1]
				tab.TextSize = math.clamp(math.floor(cell / 6), 10, 13)
				tab.TextWrapped = true
				local stroke = tab:FindFirstChild("UIStroke")
				if stroke then
					stroke.Color = if tab.Name == current then Theme.Gold else Theme.TileEdge
					stroke.Thickness = 3
				end
				if not tab:FindFirstChild("UIGradient") then
					local gradient = Instance.new("UIGradient")
					gradient.Rotation = 90
					gradient.Color = ColorSequence.new(Color3.fromRGB(255, 239, 207), Theme.Surface)
					gradient.Parent = tab
				end
				index += 1
			end
			local back = navigation:FindFirstChild("TextButton")
			if back then placeEditorTab(back) end
			for _, section in sections do
				local tab = navigation:FindFirstChild(section.Id)
				if tab then placeEditorTab(tab) end
			end
			navigation.CanvasSize = UDim2.fromOffset(0, 0)
			local controlTop = 86 + navHeight + 15
			scroll.Position = UDim2.fromOffset(margin, controlTop)
			scroll.Size = UDim2.new(0, leftWidth, 1, -(controlTop + 66))
			status.Visible = false
			overview.Visible = true
			overview.Position = UDim2.fromOffset(pageWidth + 18, 88)
			overview.Size = UDim2.new(0, pageWidth - 18 - margin, 1, -155)
			if actionFrame then
				actionFrame.Position = UDim2.fromOffset(margin, height - 52)
				actionFrame.Size = UDim2.new(1, -(margin * 2), 0, 38)
			end
		elseif mode == "Editor" then
			chapter.Visible = false
			purpose.Visible = false
			contents.Visible = false
			folio.Visible = false
			seam.Visible = false
			topRule.Visible = false
			navigation.Position = UDim2.fromOffset(18, 82)
			navigation.Size = UDim2.new(1, -36, 0, 76)
			navigation.ScrollingDirection = Enum.ScrollingDirection.X
			navigation.ScrollingEnabled = true
			local labels = { "BACK", "FORM", "TARGET", "RULES", "CHOOSE", "TUNE", "CAST", "COST", "LOOK", "TEST" }
			local index = 0
			local function placeNarrowTab(tab)
				tab.Position = UDim2.fromOffset(index * 77, 0)
				tab.Size = UDim2.fromOffset(70, 70)
				tab.Text = labels[index + 1]
				tab.TextSize = 11
				tab.TextWrapped = true
				tab.BackgroundColor3 = if tab.Name == current then Theme.Accent else Theme.Surface
				tab.TextColor3 = if tab.Name == current then Theme.OnAccent else Theme.Ink
				local stroke = tab:FindFirstChild("UIStroke")
				if stroke then stroke.Color, stroke.Thickness = Theme.TileEdge, 3 end
				index += 1
			end
			local back = navigation:FindFirstChild("TextButton")
			if back then placeNarrowTab(back) end
			for _, section in sections do
				local tab = navigation:FindFirstChild(section.Id)
				if tab then placeNarrowTab(tab) end
			end
			navigation.CanvasSize = UDim2.fromOffset(index * 77, 0)
			scroll.Position = UDim2.fromOffset(18, 166)
			scroll.Size = UDim2.new(1, -36, 1, -226)
			status.Visible = false
			if actionFrame then
				actionFrame.Position = UDim2.fromOffset(18, height - 52)
				actionFrame.Size = UDim2.new(1, -36, 0, 38)
			end
		elseif mode == "LibraryDetail" and width >= 680 then
			local pageWidth = width / 2
			local margin = if notebook.Visible then 45 else 24
			local pageContentWidth = pageWidth - margin - 18
			title.Position = UDim2.fromOffset(margin + 50, 24)
			title.Size = UDim2.new(1, -(margin + 102), 0, 29)
			summary.Visible = false
			chapter.Visible = false
			purpose.Visible = false
			contents.Visible = false
			folio.Visible = false
			seam.Visible = false
			topRule.Visible = false
			status.Visible = false
			scroll.Position = UDim2.fromOffset(margin, 88)
			scroll.Size = UDim2.new(0, pageContentWidth, 1, -146)
			overview.Visible = true
			overview.Position = UDim2.fromOffset(pageWidth + 18, 88)
			overview.Size = UDim2.new(0, pageContentWidth, 1, -155)
		else
			topRule.Visible = mode ~= "Library"
			summary.Visible = mode ~= "Library"
		end
	end

	navigation.AutomaticCanvasSize = Enum.AutomaticSize.None
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	return function(pageMode, activeSection, actions)
		mode, current, actionFrame = pageMode, activeSection, actions
		chapter.Text = if mode == "Help"
			then "How to create magic"
			elseif mode == "Library" then "Your spell library"
			elseif mode == "Create" then "Create a spell"
			else "Combat spell slots"
		purpose.Text = if mode == "Help"
			then "A short guide you can skip and reopen."
			elseif mode == "Library" then "Find, preview and organize your saved spells."
			elseif mode == "Create" then "Begin with intent, then choose a compatible form and effects."
			else "Choose a slot to create or edit a spell. Number keys cast equipped slots."
		if mode == "Editor" then
			for index, section in sections do
				if section.Id == current then
					chapter.Text = string.format("%02d  /  %s", index, section.Label)
					purpose.Text = section.Description
				end
			end
		end
		layout()
	end
end

return Grimoire
