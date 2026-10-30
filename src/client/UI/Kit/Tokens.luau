--!strict
-- Shared design tokens for every screen. Colors come from the Spell Forge palette
-- (the game's dark-fantasy look); new UI should use these instead of literals.
local Forge = require(script.Parent.Parent.SpellForgeTheme)

local Tokens = {}
Tokens.Color = Forge.C
Tokens.Font = {
	Display = Enum.Font.Garamond,
	Body = Enum.Font.Gotham,
	Strong = Enum.Font.GothamBold,
	Mono = Enum.Font.Code,
}
Tokens.TextSize = { Caption = 12, Body = 14, Label = 16, Title = 22, Display = 30 }
Tokens.Space = { XS = 4, S = 8, M = 12, L = 18, XL = 28 }
Tokens.Radius = { S = 4, M = 8, L = 14 }
Tokens.Stroke = 1
-- Minimum touch/gamepad target (Roblox guideline ≈ 44 px at 1x scale).
Tokens.MinTarget = 44
-- Design resolution the layouts are authored at; Responsive scales from it.
Tokens.ReferenceSize = Vector2.new(1280, 720)

return Tokens
