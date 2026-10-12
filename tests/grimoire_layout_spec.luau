-- Layout geometry checks with lightweight GUI doubles; not an engine rendering test.
local callbacks = {}
local function signal()
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
		end,
	}
end
local function instance(class)
	local self = { Name = class, children = {} }
	local methods = {
		FindFirstChild = function(_, name)
			for _, child in self.children do
				if child.Name == name then
					return child
				end
			end
		end,
		GetPropertyChangedSignal = function()
			return signal()
		end,
		GetAttributeChangedSignal = function()
			return signal()
		end,
		GetAttribute = function()
			return nil
		end,
	}
	return setmetatable(self, {
		__index = methods,
		__newindex = function(t, key, value)
			rawset(t, key, value)
			if key == "Parent" then
				table.insert(value.children, t)
			end
		end,
	})
end
local function dimension(xs, xo, ys, yo)
	return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
end
local themeModule = assert(loadstring(__GRIMOIRE_THEME_SOURCE))
local env = setmetatable({
	Instance = { new = instance },
	Color3 = {
		fromRGB = function(...)
			return { ... }
		end,
	},
	ColorSequence = {
		new = function(v)
			return v
		end,
	},
	ColorSequenceKeypoint = {
		new = function(...)
			return { ... }
		end,
	},
	Enum = {
		Font = { Garamond = "Serif", Gotham = "Sans" },
		TextXAlignment = { Left = "Left", Center = "Center" },
		TextYAlignment = { Top = "Top" },
		AutomaticSize = { None = "None", Y = "Y" },
		TextTruncate = { None = "None" },
		ScrollingDirection = { X = "X", Y = "Y" },
		SortOrder = { LayoutOrder = "LayoutOrder" },
	},
	UDim = {
		new = function(s, o)
			return { Scale = s, Offset = o }
		end,
	},
	UDim2 = {
		new = dimension,
		fromOffset = function(x, y)
			return dimension(0, x, 0, y)
		end,
		fromScale = function(x, y)
			return dimension(x, 0, y, 0)
		end,
	},
}, { __index = getfenv() })
setfenv(themeModule, env)
local theme = themeModule()
env.script = { Parent = { GrimoireTheme = {} } }
env.require = function()
	return theme
end
local module = assert(loadstring(__GRIMOIRE_SOURCE))
setfenv(module, env)
local grimoire = module()
local sections = {
	{ Id = "Setup", Label = "Form", Description = "Start" },
	{ Id = "Targeting", Label = "Targeting", Description = "Aim" },
	{ Id = "Conditions", Label = "Conditions", Description = "Rules" },
	{ Id = "ChooseEffects", Label = "Choose Effects", Description = "Effects" },
	{ Id = "ConfigureEffects", Label = "Configure Effects", Description = "Settings" },
	{ Id = "Casting", Label = "Casting", Description = "Timing" },
	{ Id = "Cost", Label = "Costs", Description = "Costs" },
	{ Id = "Presentation", Label = "Appearance", Description = "Looks" },
	{ Id = "Test", Label = "Review & Test", Description = "Test" },
}
for _, size in { { 360, 640 }, { 768, 600 }, { 864, 480 }, { 1120, 900 } } do
	local panel = instance("Panel")
	panel.AbsoluteSize = { X = size[1], Y = size[2] }
	local nav = instance("Navigation")
	nav.Parent = panel
	local back = instance("TextButton")
	back.Parent = nav
	for _, section in sections do
		local tab = instance("TextButton")
		tab.Name = section.Id
		tab.Parent = nav
	end
	local scroll, status, title, summary, actions =
		instance("Scroll"), instance("Status"), instance("Title"), instance("Summary"), instance("Actions")
	local layout = grimoire.mount(panel, nav, scroll, status, title, summary, sections)
	local function rect(item, parentWidth, parentHeight)
		return item.Position.X.Scale * parentWidth + item.Position.X.Offset,
			item.Position.Y.Scale * parentHeight + item.Position.Y.Offset,
			item.Size.X.Scale * parentWidth + item.Size.X.Offset,
			item.Size.Y.Scale * parentHeight + item.Size.Y.Offset
	end
	for _, mode in { "Editor", "Library", "LibraryDetail", "Help", "Slots", "Create" } do
		layout(mode, "ChooseEffects", actions)
		local x, y, w, h = rect(scroll, size[1], size[2])
		assert(
			x >= 0 and y >= 0 and w >= 240 and h >= 100,
			"Readable scrolling page at " .. size[1] .. "x" .. size[2] .. " " .. mode
		)
		assert(x + w <= size[1] and y + h <= size[2], "Page must fit within cover")
		if mode == "Library" and size[1] >= 850 then
			assert(w >= size[1] - 60, "The spell grid should use the open book width")
		end
		local _, ay, _, ah = rect(actions, size[1], size[2])
		assert(ay >= y + h and ay + ah <= size[2], "Actions stay below settings")
		if mode == "Editor" then
			local _, _, nw, nh = rect(nav, size[1], size[2])
			for _, tab in nav.children do
				local tx, ty, tw, th = rect(tab, nw, nh)
				assert(math.abs(tw - th) <= 1, "Editor chapter choices must be square")
				local canvasWidth, canvasHeight = nav.CanvasSize.X.Offset, nav.CanvasSize.Y.Offset
				assert(
					tx >= 0
						and ty >= 0
						and tx + tw <= math.max(nw, canvasWidth) + 1
						and ty + th <= math.max(nh, canvasHeight) + 1
						and th >= 29,
					"Every chapter tab remains reachable inside the scroll canvas"
				)
			end
			if size[1] >= 680 then
				local preview = panel:FindFirstChild("LiveSpellSummary")
				local px, py, pw, ph = rect(preview, size[1], size[2])
				assert(preview.Visible and px > size[1] / 2 and py < y, "Preview belongs on the right page")
				assert(pw >= size[1] * 0.3 and ph >= size[2] * 0.6, "Preview should fill most of the right page")
				assert(x + w <= size[1] / 2, "Editor controls belong on the left page")
			end
		end
		if mode == "LibraryDetail" and size[1] >= 680 then
			local preview = panel:FindFirstChild("LiveSpellSummary")
			local px, _, pw, ph = rect(preview, size[1], size[2])
			assert(preview.Visible and px > size[1] / 2, "Selected library spell previews on the right page")
			assert(pw >= size[1] * 0.3 and ph >= size[2] * 0.6, "Library preview fills the right page")
			assert(x + w <= size[1] / 2, "Library spell controls stay on the left page")
		end
	end
end
print("PASS: grimoire page, action and navigation geometry at portrait, tablet, short landscape and desktop sizes")
