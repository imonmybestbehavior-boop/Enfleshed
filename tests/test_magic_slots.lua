local slots = assert(loadfile("src/shared/Modules/MagicSlots.luau"))()
local seen = {}
for i = 1, 9 do
	local id = assert(slots.id(i))
	assert(not seen[id])
	seen[id] = true
	assert(slots.id(i) == id)
end
for _, bad in ipairs({ 0, 10, -1, 1.5, math.huge, 0 / 0, "1", {}, false }) do
	assert(slots.id(bad) == nil)
end
assert(slots.id(nil) == nil)
print("PASS: nine stable distinct slot identities; malformed and out-of-range indices rejected")
