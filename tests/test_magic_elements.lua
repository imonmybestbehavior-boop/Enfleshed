local damage = assert(loadfile("src/shared/Modules/MagicDamageRules.luau"))()
local colors = assert(loadfile("src/shared/Configuration/MagicElements.luau", "t", {
	Color3 = {
		fromRGB = function(r, g, b)
			return { R = r, G = g, B = b }
		end,
	},
}))()

for _, element in ipairs(damage.Elements) do
	local color = colors[element]
	assert(color and color.R and color.G and color.B, element .. " needs a visual palette")
end
for element in pairs(colors) do
	assert(damage.KnownElements[element], element .. " palette has no damage-channel registration")
end

print("Magic element registry: damage channels and presentation palettes match")
