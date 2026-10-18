--!strict
-- Compact top-centre banner (mode, phase, timer, active wall "WALL 2 / 3" with its
-- HP bar, Gateway (final doors) HP bar, defender + guard and enemy counters) plus the thin XP bar along the very bottom edge.
local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local MissionTracker = {}
local Color = Theme.Color

-- Pure: total XP → (level, xp into level, xp needed). Matches the old mission panel curve.
function MissionTracker.level(totalXP: number): (number, number, number)
	local xp, level, threshold = math.max(0, totalXP), 1, 100
	while level < 100 and xp >= threshold do
		xp -= threshold
		level += 1
		threshold = 100 + (level - 1) * 50
	end
	return level, xp, threshold
end

function MissionTracker.new(gui: ScreenGui)
	local root = C.root(gui)
	local size = Theme.Size.Banner
	local banner = C.panel(root, {
		Name = "MissionBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
	})
	local title = C.text(banner, "DEFEND THE WALLS", Theme.TextSize.Body, Color.Gold, Theme.Font.Display, {
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(0.5, -12, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local phase = C.text(banner, "", Theme.TextSize.Small, Color.Bone, Theme.Font.Strong, {
		Position = UDim2.new(0.5, 0, 0, 5),
		Size = UDim2.new(0.5, -70, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local timer = C.text(banner, "00:00", Theme.TextSize.Label, Color.Text, Theme.Font.Number, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 3),
		Size = UDim2.fromOffset(56, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	-- Active wall row, then the final doors ("Gateway") row.
	local wallLabel = C.text(banner, "WALL 1 / 3", Theme.TextSize.Tiny, Color.Gold, Theme.Font.Strong, {
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.fromOffset(78, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local wall = C.bar(banner, Vector2.new(size.X - 230, 12), Color.Gold, true)
	wall.Frame.Position = UDim2.fromOffset(92, 27)
	local gate = C.bar(banner, Vector2.new(size.X - 230, 12), Color.Bone, true)
	gate.Frame.Position = UDim2.fromOffset(92, 44)
	C.text(banner, "GATEWAY", Theme.TextSize.Tiny, Color.Muted, Theme.Font.Strong, {
		Position = UDim2.fromOffset(12, 43),
		Size = UDim2.fromOffset(78, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local repairs = C.text(banner, "", Theme.TextSize.Tiny, Color.Muted, Theme.Font.Number, {
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.fromOffset(160, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local function counter(icon: string, tint: Color3, x: number): TextLabel
		C.text(banner, icon, Theme.TextSize.Body, tint, Theme.Font.Strong, {
			Position = UDim2.new(1, x, 0, 26),
			Size = UDim2.fromOffset(18, 18),
		})
		return C.text(banner, "0", Theme.TextSize.Body, Color.Text, Theme.Font.Number, {
			Position = UDim2.new(1, x + 18, 0, 26),
			Size = UDim2.fromOffset(44, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	local defenders = counter("⛨", Color.Ally, -128)
	local enemies = counter("☠", Color.Health, -62)
	local warning = C.text(root, "", Theme.TextSize.Label, Color.Error, Theme.Font.Display, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10 + size.Y + 6),
		Size = UDim2.fromOffset(size.X, 22),
		TextStrokeTransparency = 0.2,
	})

	-- Thin XP bar on the very bottom edge.
	local xpBar = C.bar(root, Vector2.new(0, Theme.Size.XPBar), Color.Gold, false)
	xpBar.Frame.AnchorPoint = Vector2.new(0, 1)
	xpBar.Frame.Position = UDim2.fromScale(0, 1)
	xpBar.Frame.Size = UDim2.new(1, 0, 0, Theme.Size.XPBar)
	local xpText = C.text(root, "", Theme.TextSize.Tiny, Color.Gold, Theme.Font.Number, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -Theme.Size.XPBar - 2),
		Size = UDim2.fromOffset(300, 14),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local warningToken = 0
	return {
		Warn = function(text: string, seconds: number?)
			warningToken += 1
			local token = warningToken
			warning.Text = text
			task.delay(seconds or 4, function()
				if token == warningToken then
					warning.Text = ""
				end
			end)
		end,
		-- Returns the player's level so the vitals badge can show it.
		Update = function(message: any): number?
			local state = message.State
			banner.Visible = message.Joined == true and (state == "PREPARING" or state == "ACTIVE")
			title.Text = string.upper((string.gsub(tostring(message.Mode or "DefendTheWalls"), "(%l)(%u)", "%1 %2")))
			phase.Text = string.upper(tostring(message.PhaseName or state or ""))
				.. (if message.Phase then "  ·  WAVE " .. tostring(message.Phase) else "")
			local remaining = tonumber(message.Remaining) or 0
			timer.Text = string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60)
			local count = message.WallCount or 3
			local level = message.WallLevel or 1
			if level > count then
				wallLabel.Text = "FINAL GATE"
				wall.Set(0, "BREACHED")
			else
				wallLabel.Text = string.format("WALL %d / %d", level, count)
				local hp, top = message.WallHP or 0, math.max(1, message.WallMax or 1)
				wall.Set(hp / top, string.format("%d / %d", math.ceil(hp), top))
			end
			local gateway, maximum = message.Gateway or 0, math.max(1, message.GatewayMax or 1)
			gate.Set(gateway / maximum, string.format("%d / %d", math.ceil(gateway), maximum))
			repairs.Text = string.format("REPAIRS %d", message.Repairs or 0)
			-- Players, plus living guards when the squad is out.
			defenders.Text = tostring(message.Participants or 0)
				.. (if (message.GuardsAlive or 0) > 0 then "+" .. tostring(message.GuardsAlive) else "")
			enemies.Text = tostring(message.Enemies or 0)
			local profile = message.Profile
			if type(profile) ~= "table" then
				return nil
			end
			local playerLevel, xp, needed = MissionTracker.level(profile.XP or 0)
			xpBar.Set(xp / needed)
			xpText.Text = string.format(
				"LV %d  ·  %d / %d XP  ·  %d MARKS%s",
				playerLevel,
				xp,
				needed,
				profile.Marks or 0,
				if message.SaveAvailable == false then "  ·  SAVE UNAVAILABLE" else ""
			)
			return playerLevel
		end,
	}
end

return MissionTracker
