local reveal = assert(loadfile("src/shared/Modules/MagicRevealSpec.luau"))()

local untilAttribute, colorAttribute = reveal.attributeNames(12345)
assert(untilAttribute == "MagicRevealUntil_12345")
assert(colorAttribute == "MagicRevealColor_12345")

local red, blue = { Name = "red" }, { Name = "blue" }
local aggregated = reveal.aggregate({
	{ Kind = "Reveal", ViewerUserId = 10, ExpiresAt = 20, Color = red },
	{ Kind = "Reveal", ViewerUserId = 10, ExpiresAt = 25, Color = blue },
	{ Kind = "Reveal", ViewerUserId = 11, ExpiresAt = 22, Color = red },
	{ Kind = "Reveal", ViewerUserId = 12, ExpiresAt = 9, Color = red },
	{ Kind = "Slow", ViewerUserId = 13, ExpiresAt = 40, Color = red },
}, 10)
assert(
	aggregated[10].ExpiresAt == 25 and aggregated[10].Color == blue,
	"same-owner reveals should keep the latest expiry"
)
assert(aggregated[11].ExpiresAt == 22 and aggregated[11].Color == red, "different owners need independent reveals")
assert(aggregated[12] == nil and aggregated[13] == nil, "expired or non-Reveal effects should be ignored")

print("Magic reveal spec: owner-specific attribute naming and expiry aggregation passed")
