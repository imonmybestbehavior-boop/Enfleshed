--!strict
-- Centred lobby: large mode cards shown while the player is idle, hidden once
-- they join a match. Also hosts the end-of-mission results card.
-- While visible it holds a UI modal so the cursor stays free (see UIController).
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)
local GamepadNav = require(script.Parent.Parent.Kit.GamepadNav)

local Lobby = {}
local Color = Theme.Color
local verbose = RunService:IsStudio()

local function log(...: any)
	if verbose then
		print("[Mission/client]", ...)
	end
end

export type Hooks = {
	Request: (action: string) -> (),
	SetModal: (name: string, open: boolean) -> (),
}

function Lobby.new(gui: ScreenGui, hooks: Hooks)
	local root = C.root(gui)
	local shade = C.new("Frame", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
	}, root)
	local panel = C.new("Frame", {
		Name = "Lobby",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(Theme.Size.Card.X * 2 + 40, Theme.Size.Card.Y + 150),
		BackgroundTransparency = 1,
	}, shade)
	C.text(panel, "ENFLESHED", Theme.TextSize.Hero, Color.Gold, Theme.Font.Display, {
		Size = UDim2.new(1, 0, 0, 46),
	})
	C.text(panel, "Choose your battle", Theme.TextSize.Body, Color.Muted, Theme.Font.Body, {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 20),
	})
	local cards = C.new("Frame", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, Theme.Size.Card.Y),
		BackgroundTransparency = 1,
	}, panel)
	C.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 40),
	}, cards)

	local function card(
		order: number,
		titleText: string,
		body: string,
		actionText: string
	): (Frame, TextButton, TextLabel)
		local frame = C.panel(cards, {
			LayoutOrder = order,
			Size = UDim2.fromOffset(Theme.Size.Card.X, Theme.Size.Card.Y),
		})
		C.new("UIAspectRatioConstraint", { AspectRatio = Theme.Size.Card.X / Theme.Size.Card.Y }, frame)
		C.text(frame, titleText, Theme.TextSize.Title, Color.Gold, Theme.Font.Display, {
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(1, -28, 0, 32),
		})
		local detail = C.text(frame, body, Theme.TextSize.Small, Color.Bone, Theme.Font.Body, {
			Position = UDim2.fromOffset(16, 48),
			Size = UDim2.new(1, -32, 0, 64),
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local button = C.button(frame, actionText, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.new(1, -40, 0, 48),
			TextSize = Theme.TextSize.Label + 2,
		})
		return frame, button, detail
	end

	local _, begin = card(
		1,
		"Defend the Walls",
		"Hold the Gateway against the Nascent tide. Waves grow, approaches multiply. Repair the gate at the console.",
		"BEGIN MISSION"
	)
	local _, explore = card(
		2,
		"Explore the Keep",
		"Wander the hub, enter the practice gate for the combat sandbox, or forge spells in your Grimoire.",
		"EXPLORE"
	)
	local status = C.text(panel, "", Theme.TextSize.Body, Color.Bone, Theme.Font.Strong, {
		Position = UDim2.fromOffset(0, 80 + Theme.Size.Card.Y + 14),
		Size = UDim2.new(1, 0, 0, 22),
	})
	local hint = C.text(root, "M · MISSIONS", Theme.TextSize.Small, Color.Gold, Theme.Font.Strong, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(200, 18),
		Visible = false,
	})

	-- Results card (end of mission).
	local results = C.panel(root, {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 250),
		Visible = false,
	})
	local outcome = C.text(results, "", Theme.TextSize.Title + 4, Color.Gold, Theme.Font.Display, {
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 36),
	})
	local earned = C.text(results, "", Theme.TextSize.Body, Color.Text, Theme.Font.Number, {
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 0, 50),
		TextWrapped = true,
	})
	local saved = C.text(results, "", Theme.TextSize.Small, Color.Muted, Theme.Font.Strong, {
		Position = UDim2.fromOffset(20, 116),
		Size = UDim2.new(1, -40, 0, 36),
		TextWrapped = true,
	})
	local replay = C.button(results, "PLAY AGAIN", {
		Position = UDim2.new(0, 20, 1, -70),
		Size = UDim2.new(0.5, -30, 0, 50),
	})
	local hub = C.button(results, "RETURN TO HUB", {
		Position = UDim2.new(0.5, 10, 1, -70),
		Size = UDim2.new(0.5, -30, 0, 50),
	})

	local dismissed = false
	local lastState: any = nil
	local pending: number? = nil
	local actionName = "Start"

	local function setStatus(text: string, color: Color3?)
		status.Text = text
		status.TextColor3 = color or Color.Bone
	end

	local function refreshVisible()
		local message = lastState
		local joined = message ~= nil and message.Joined == true
		local open = not dismissed and not joined and not results.Visible and message ~= nil
		if shade.Visible ~= open then
			shade.Visible = open
			if open then
				GamepadNav.open(panel, function()
					dismissed = true
					refreshVisible()
				end, begin)
			else
				GamepadNav.close(panel)
			end
		end
		hooks.SetModal("Lobby", open)
		hint.Visible = dismissed and not joined and not results.Visible
	end

	local function send(action: string)
		actionName = action
		local token = os.clock()
		pending = token
		begin.Text = "STARTING…"
		setStatus("Starting…", Color.Gold)
		log("click → FireServer", action)
		hooks.Request(action)
		task.delay(5, function()
			if pending == token then
				pending = nil
				begin.Text = "BEGIN MISSION"
				setStatus("No response from the mission server. Check the Output window.", Color.Error)
				warn("[Mission/client] no server reply to", action)
			end
		end)
	end

	begin.Activated:Connect(function()
		log("Begin button activated; label =", begin.Text)
		local state = lastState and lastState.State
		send(
			if state == "PREPARING" or state == "ACTIVE"
				then "Join"
				elseif state == "READY_FOR_REPLAY" then "Replay"
				else "Start"
		)
	end)
	explore.Activated:Connect(function()
		dismissed = true
		refreshVisible()
	end)
	replay.Activated:Connect(function()
		replay.Text = "READY"
		hooks.Request("Replay")
	end)
	local function goHub()
		hooks.Request("Hub")
		results.Visible = false
		GamepadNav.close(results)
		hooks.SetModal("Results", false)
		refreshVisible()
	end
	hub.Activated:Connect(goHub)

	return {
		Toggle = function()
			if lastState and lastState.Joined then
				return
			end
			dismissed = not dismissed
			refreshVisible()
		end,
		Notice = function(text: string)
			pending = nil
			begin.Text = "BEGIN MISSION"
			setStatus(text, Color.Error)
		end,
		Ack = function(message: any)
			pending = nil
			log("server ack", message.Action, message.Ok, message.Text)
			if message.Ok then
				setStatus(message.Text or "Mission starting", Color.Ok)
			else
				begin.Text = "BEGIN MISSION"
				setStatus(message.Text or "Could not start the mission", Color.Error)
			end
		end,
		State = function(message: any)
			local state = message.State
			lastState = message
			if message.Joined then
				dismissed = false
				if pending then
					pending = nil
					log("mission joined; state", state, "after", actionName)
				end
			end
			if state == "PREPARING" and message.Joined and results.Visible then
				results.Visible = false
				GamepadNav.close(results)
				hooks.SetModal("Results", false)
			end
			if not pending then
				begin.Text = if state == "PREPARING" or state == "ACTIVE"
					then "JOIN DEFENSE"
					elseif state == "READY_FOR_REPLAY" then "PLAY AGAIN"
					else "BEGIN MISSION"
				if status.TextColor3 ~= Color.Error then
					setStatus(
						if state == "ACTIVE" or state == "PREPARING"
							then string.format("A defense is under way · %d defending", message.Participants or 0)
							else ""
					)
				end
			end
			refreshVisible()
		end,
		Result = function(message: any, nextText: string)
			outcome.Text = if message.Victory then "GATEWAY HELD" else "GATEWAY LOST"
			outcome.TextColor3 = if message.Victory then Color.Gold else Color.Health
			local reward = message.Reward or {}
			earned.Text = string.format(
				"+%d XP  ·  +%d MARKS\n%d KILLS  ·  %d REPAIRS  ·  %d DEATHS",
				reward.XP or 0,
				reward.Marks or 0,
				reward.Kills or 0,
				reward.Repairs or 0,
				reward.Deaths or 0
			)
			saved.Text = nextText
			replay.Text = "PLAY AGAIN"
			results.Visible = true
			hooks.SetModal("Results", true)
			GamepadNav.open(results, goHub, replay)
			refreshVisible()
		end,
	}
end

return Lobby
