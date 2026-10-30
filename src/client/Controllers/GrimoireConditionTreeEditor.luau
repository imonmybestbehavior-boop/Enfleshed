--!strict
-- Grimoire editor section for condition trees (spell and step conditions).
-- Extracted from MagicLabController (Phase 1.7). The Grimoire passes its form
-- widgets in `ctx`; this module only lays them out and edits `holder[key]`.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ConditionSpec = require(Shared.Modules.MagicConditionSpec)
local ConditionTree = require(Shared.Modules.MagicConditionTree)
local Theme = require(script.Parent.Parent.UI.SpellForgeTheme).Book
local ConditionTreeEditor = {}

export type Widgets = {
	button: any,
	card: any,
	estimate: any,
	info: any,
	numeric: any,
	rebuild: any,
	row: any,
	select: any,
	toggle: any,
}

function ConditionTreeEditor.render(ctx: Widgets, holder: any, key: string, label: string?)
	local button, card, estimate, info, numeric, rebuild, row, select, toggle =
		ctx.button, ctx.card, ctx.estimate, ctx.info, ctx.numeric, ctx.rebuild, ctx.row, ctx.select, ctx.toggle
	local propertyChoices = {}
	for family, properties in ConditionSpec.Properties do
		for property in properties do
			table.insert(propertyChoices, family .. "." .. property)
		end
	end
	table.sort(propertyChoices)
	local function replaceNode(parent, index, replacement)
		local ok, root = ConditionTree.replace(holder[key], parent, index, replacement)
		if ok and not parent then
			holder[key] = root
		end
	end
	local function defaultFor(descriptor)
		return if descriptor.Kind == "Boolean" then true elseif descriptor.Kind == "Number" then descriptor.Min else ""
	end
	local function renderNode(node, parent, index, depth)
		local path = (if label then label .. " · " else "")
			.. (if parent then "Nested " .. tostring(index) else "Root")
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
						and ConditionTree.countNodes(holder[key]) < ConditionSpec.MaxNodes
				)
			end
			for childIndex, child in ipairs(node.Conditions or {}) do
				renderNode(child, node, childIndex, depth + 1)
			end
			if node.Operator ~= "NOT" then
				local nodeCount = ConditionTree.countNodes(holder[key])
				local canAddRule = #node.Conditions < ConditionSpec.MaxChildren
					and nodeCount + 1 <= ConditionSpec.MaxNodes
					and depth < ConditionSpec.MaxDepth
				local canAddGroup = #node.Conditions < ConditionSpec.MaxChildren
					and nodeCount + 2 <= ConditionSpec.MaxNodes
					and depth + 1 < ConditionSpec.MaxDepth
				card("Add rule · " .. path, "Add one explicitly exposed server value.", false, function()
					ConditionTree.addRule(node, ConditionSpec.MaxChildren, ConditionSpec.MaxNodes, holder[key])
				end, canAddRule, "This group, depth, or tree has reached its safe limit.")
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
							holder[key]
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
							holder[key]
						)
					end,
					canAddGroup,
					"This group, depth, or tree has reached its safe limit."
				)
			end
			if parent and parent.Operator ~= "NOT" then
				card("Remove group · " .. path, "Remove this nested condition and its children.", false, function()
					ConditionTree.remove(parent, index)
				end, #parent.Conditions > 1, "Condition groups must keep at least one child.")
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
		select("Runtime property · " .. path, node.Family .. "." .. node.Property, propertyChoices, function(value)
			local family, property = string.match(value, "^([^%.]+)%.(.+)$")
			local nextDescriptor = ConditionSpec.Properties[family][property]
			node.Family, node.Property = family, property
			node.Operator = nextDescriptor.Operators[1]
			node.Value = defaultFor(nextDescriptor)
		end, nil, "Only whitelisted server-resolved values are available.")
		select("Comparison · " .. path, node.Operator, descriptor.Operators, function(value)
			node.Operator = value
		end)
		if descriptor.Kind == "Number" then
			numeric("Number value · " .. path, node, "Value", "Compare against this bounded runtime value.")
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
				and ConditionTree.countNodes(holder[key]) < ConditionSpec.MaxNodes
			card("Invert rule · " .. path, "Wrap this rule in NOT.", false, function()
				local wrapped = ConditionTree.wrapNot(node)
				if wrapped then
					replaceNode(parent, index, wrapped)
				end
			end, canWrap)
			card("Nest rule in ALL · " .. path, "Place this rule inside a new ALL group.", false, function()
				local nested = ConditionTree.newGroup("ALL")
				if nested then
					nested.Conditions[1] = node
					replaceNode(parent, index, nested)
				end
			end, canWrap)
		end
	end
	renderNode(holder[key], nil, nil, 1)
end

return ConditionTreeEditor
