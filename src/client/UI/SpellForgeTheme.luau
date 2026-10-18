--!strict
-- Dark fantasy palette shared by the Spell Forge (Guided and Advanced).
-- `Book` maps the parchment GrimoireTheme keys onto this palette so the
-- Advanced section editors can draw inside the forge without their own colors.
local C = {
	Backdrop = Color3.fromRGB(11, 9, 13),
	Panel = Color3.fromRGB(21, 18, 24),
	PanelEdge = Color3.fromRGB(62, 48, 52),
	Card = Color3.fromRGB(33, 28, 36),
	CardHover = Color3.fromRGB(44, 37, 47),
	CardSelected = Color3.fromRGB(56, 42, 38),
	Input = Color3.fromRGB(15, 13, 18),
	Ink = Color3.fromRGB(238, 228, 212),
	Muted = Color3.fromRGB(168, 155, 146),
	Faint = Color3.fromRGB(110, 99, 97),
	Rail = Color3.fromRGB(78, 62, 60),
	Gold = Color3.fromRGB(218, 174, 96),
	GoldDeep = Color3.fromRGB(122, 88, 40),
	Ember = Color3.fromRGB(214, 96, 58),
	Blood = Color3.fromRGB(170, 48, 60),
	Arcane = Color3.fromRGB(150, 118, 230),
	Verdant = Color3.fromRGB(104, 184, 128),
	Frost = Color3.fromRGB(112, 176, 220),
	Ok = Color3.fromRGB(122, 204, 142),
	Warn = Color3.fromRGB(236, 168, 76),
	Error = Color3.fromRGB(232, 96, 96),
}

local Book = {
	Page = C.Panel,
	PageShade = C.Card,
	PageHighlight = C.CardSelected,
	Binding = C.Backdrop,
	BindingEdge = C.PanelEdge,
	PageEdge = C.PanelEdge,
	Ink = C.Ink,
	MutedInk = C.Muted,
	SubtleInk = C.Faint,
	Gold = C.Gold,
	Accent = C.Ember,
	AccentAlt = C.Arcane,
	AccentSoft = Color3.fromRGB(70, 38, 32),
	Surface = C.Card,
	SurfaceMuted = Color3.fromRGB(27, 23, 30),
	SurfaceDisabled = Color3.fromRGB(24, 21, 26),
	Border = C.PanelEdge,
	TileEdge = C.Rail,
	DisabledInk = C.Faint,
	OnAccent = Color3.fromRGB(255, 244, 230),
	Success = C.Ok,
	Warning = C.Warn,
	WarningSurface = Color3.fromRGB(52, 38, 24),
	Error = C.Error,
}

return { C = C, Book = Book }
