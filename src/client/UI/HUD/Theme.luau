--!strict
-- Single source of truth for the in-game HUD look: colors, fonts, sizes, motion.
-- Dark fantasy: near-black translucent panels, thin brass strokes, rivet corners.
local Theme = {}

Theme.Color = {
	Panel = Color3.fromRGB(10, 8, 11),
	PanelRaised = Color3.fromRGB(22, 18, 22),
	Track = Color3.fromRGB(28, 22, 26),
	Brass = Color3.fromRGB(176, 142, 82),
	Bone = Color3.fromRGB(226, 214, 186),
	Gold = Color3.fromHex("E8C77A"),
	Text = Color3.fromRGB(240, 230, 210),
	Muted = Color3.fromRGB(150, 138, 124),
	Faint = Color3.fromRGB(92, 82, 78),
	Health = Color3.fromHex("C8323C"),
	Mana = Color3.fromHex("3C8CFF"),
	Strain = Color3.fromHex("FF8A2A"),
	StrainHot = Color3.fromRGB(255, 52, 40),
	Ghost = Color3.fromRGB(255, 226, 190),
	Ok = Color3.fromRGB(122, 204, 142),
	Error = Color3.fromRGB(236, 96, 88),
	Ally = Color3.fromRGB(139, 205, 237),
}

Theme.Transparency = {
	Panel = 0.25,
	Stroke = 0.35,
	Track = 0.15,
}

Theme.Font = {
	Display = Enum.Font.Fantasy,
	Body = Enum.Font.GothamMedium,
	Strong = Enum.Font.GothamBold,
	-- Monospaced digits keep counters from jittering as values change.
	Number = Enum.Font.RobotoMono,
}

Theme.TextSize = { Tiny = 11, Small = 13, Body = 15, Label = 18, Title = 26, Hero = 40 }

-- Layout sizes are authored at Theme.ReferenceSize; a UIScale per screen does the rest.
Theme.ReferenceSize = Vector2.new(1280, 720)
Theme.Size = {
	Corner = 3,
	Stroke = 1,
	Rivet = 5,
	HealthBar = Vector2.new(420, 20),
	ManaBar = Vector2.new(340, 11),
	StrainPips = 10,
	Slot = 54,
	SlotGap = 6,
	SlotsShown = 6,
	LevelBadge = 46,
	XPBar = 5,
	Banner = Vector2.new(460, 78),
	Card = Vector2.new(300, 190),
}

-- Gamepad-only players sit across the room: scale everything up a step.
Theme.TenFootScale = 1.2
Theme.MinScale = 0.65
Theme.MaxScale = 1.6

Theme.Motion = {
	Bar = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	GhostDelay = 0.45,
	Ghost = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	Hover = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	HoverScale = 1.06,
	Flash = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	StrainPulseAt = 0.8,
}

-- Hotbar keybinds by input mode (gamepad casts the selected slot with RB).
Theme.SlotKeys = { "1", "2", "3", "4", "5", "6" }
Theme.GamepadCastGlyph = "RB"

return Theme
