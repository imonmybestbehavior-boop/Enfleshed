--!strict
-- Gamepad focus for menus. `open(root)` makes every button/text box inside the
-- panel selectable, keeps selection inside the panel (SelectionGroup), selects a
-- sensible first item, and binds B to close it. Panels stack: closing one returns
-- selection to the panel underneath. With keyboard/mouse this is invisible.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Nav = {}
Nav.ClosePriority = Enum.ContextActionPriority.High.Value + 100

type Entry = { Root: GuiObject, OnClose: () -> (), Previous: GuiObject?, Connection: RBXScriptConnection }
local stack: { Entry } = {}

local function interactive(item: Instance): boolean
	return item:IsA("GuiButton") or item:IsA("TextBox")
end

-- Pure-ish helper (no services): the first visible interactive descendant, preferring `preferred`.
function Nav.firstSelectable(root: GuiObject, preferred: GuiObject?): GuiObject?
	if preferred and preferred:IsDescendantOf(root) and preferred.Visible then
		return preferred
	end
	local best: GuiObject? = nil
	for _, item in root:GetDescendants() do
		if interactive(item) and (item :: GuiObject).Visible then
			local gui = item :: GuiObject
			if
				not best
				or gui.AbsolutePosition.Y < (best :: GuiObject).AbsolutePosition.Y
				or (
					gui.AbsolutePosition.Y == (best :: GuiObject).AbsolutePosition.Y
					and gui.AbsolutePosition.X < (best :: GuiObject).AbsolutePosition.X
				)
			then
				best = gui
			end
		end
	end
	return best
end

local function makeSelectable(item: Instance)
	if interactive(item) then
		(item :: GuiObject).Selectable = true
	end
end

local function bindClose()
	ContextActionService:BindActionAtPriority("UIKitClose", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local top = stack[#stack]
		if not top then
			return Enum.ContextActionResult.Pass
		end
		top.OnClose()
		return Enum.ContextActionResult.Sink
	end, false, Nav.ClosePriority, Enum.KeyCode.ButtonB)
end

function Nav.isOpen(root: GuiObject?): boolean
	for _, entry in stack do
		if root == nil or entry.Root == root then
			return true
		end
	end
	return false
end

function Nav.open(root: GuiObject, onClose: () -> (), preferred: GuiObject?)
	if Nav.isOpen(root) then
		return
	end
	root.SelectionGroup = true
	for _, item in root:GetDescendants() do
		makeSelectable(item)
	end
	table.insert(stack, {
		Root = root,
		OnClose = onClose,
		Previous = GuiService.SelectedObject,
		Connection = root.DescendantAdded:Connect(makeSelectable),
	})
	if #stack == 1 then
		bindClose()
	end
	if UserInputService.GamepadEnabled then
		task.defer(function()
			if Nav.isOpen(root) then
				GuiService.SelectedObject = Nav.firstSelectable(root, preferred)
			end
		end)
	end
end

function Nav.close(root: GuiObject)
	for index = #stack, 1, -1 do
		local entry = stack[index]
		if entry.Root == root then
			entry.Connection:Disconnect()
			table.remove(stack, index)
			local selected = GuiService.SelectedObject
			if selected and selected:IsDescendantOf(root) then
				local below = stack[#stack]
				GuiService.SelectedObject = if below then Nav.firstSelectable(below.Root, entry.Previous) else nil
			end
			break
		end
	end
	if #stack == 0 then
		ContextActionService:UnbindAction("UIKitClose")
	end
end

-- Re-select inside the top panel after a rebuild destroyed the selected button.
function Nav.refresh()
	local top = stack[#stack]
	if top and UserInputService.GamepadEnabled then
		local selected = GuiService.SelectedObject
		if not selected or not selected:IsDescendantOf(top.Root) then
			GuiService.SelectedObject = Nav.firstSelectable(top.Root)
		end
	end
end

-- A rebuild that destroys the focused button clears the selection; restore it.
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
	if GuiService.SelectedObject == nil and #stack > 0 then
		task.defer(Nav.refresh)
	end
end)

return Nav
