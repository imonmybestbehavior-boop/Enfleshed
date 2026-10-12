local tree = assert(loadfile("src/shared/Modules/MagicConditionTree.luau"))()

local root = assert(tree.newGroup("ALL"))
assert(root.Operator == "ALL" and #root.Conditions == 1)
local added = tree.addRule(root, 8, 32, root)
assert(added and #root.Conditions == 2)
local nestedAdded = tree.addGroup(root, "ANY", 8, 32, root)
assert(nestedAdded and root.Conditions[3].Operator == "ANY")
local nested = root.Conditions[3]
assert(tree.addRule(nested, 8, 32, root))
assert(tree.maxDepth(root) == 3 and tree.countNodes(root) == 6)

local notGroup = assert(tree.wrapNot(nested))
assert(notGroup.Operator == "NOT" and tree.unwrapNot(notGroup) == nested)
assert(tree.replace(root, root, 3, notGroup))
assert(tree.maxDepth(root) == 4)
assert(not tree.addGroup(nested, "ALL", 8, 8, root), "nested growth should respect the full tree budget")

local replacement = assert(tree.newRule())
assert(tree.replace(root, notGroup, 1, replacement), "the single child of NOT remains editable")
assert(not tree.remove(notGroup, 1), "NOT cannot be left without exactly one child")
assert(tree.replace(root, root, 3, tree.unwrapNot(notGroup)))
assert(tree.remove(root, 3))
assert(#root.Conditions == 2)

local full = assert(tree.newGroup("ALL"))
for _ = 1, 7 do
	assert(tree.addRule(full, 8, 32, full))
end
assert(not tree.addRule(full, 8, 32, full), "a full group must reject a ninth child")

print("Magic condition tree: recursive editing primitives and safety limits passed")
