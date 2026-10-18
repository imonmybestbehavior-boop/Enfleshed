--!strict
-- Thin, failure-proof wrapper over AnalyticsService. Every call is pcall'd:
-- analytics must never break gameplay. Event names and fields are documented in
-- docs/ANALYTICS.md; keep them stable so dashboards keep working.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local Spec = require(game:GetService("ReplicatedStorage").Shared.Modules.TelemetrySpec)

local Telemetry = {}
local F1, F2, F3 =
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name

local onboarded: { [Player]: { [number]: boolean } } = {}
local usage: { [Player]: Spec.SpellUsage } = {}
local joinedAt: { [Player]: number } = {}
local started = false

local function safe(callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then
		warn("[Telemetry] " .. tostring(err))
	end
end

local function fields(a: string?, b: string?, c: string?): { [string]: string }
	local result = {}
	if a then
		result[F1] = a
	end
	if b then
		result[F2] = b
	end
	if c then
		result[F3] = c
	end
	return result
end

function Telemetry.onboarding(player: Player, stepName: string)
	local step = Spec.onboardingStep(stepName)
	local seen = onboarded[player]
	if not step or not seen or seen[step] then
		return
	end
	seen[step] = true
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

-- currency: "Marks" | "XP"; flow: "Source" | "Sink"; transaction: Enum name, e.g. "Gameplay", "Shop".
function Telemetry.economy(
	player: Player,
	flow: string,
	currency: string,
	amount: number,
	balance: number,
	transaction: string,
	sku: string?
)
	if amount <= 0 then
		return
	end
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			(Enum.AnalyticsEconomyFlowType :: any)[flow],
			currency,
			amount,
			balance,
			(Enum.AnalyticsEconomyTransactionType :: any)[transaction].Name,
			sku
		)
	end)
end

-- Mission progression; `path` is the mode ("DefendTheWalls"), `level` the difficulty tier.
function Telemetry.missionStart(player: Player, path: string, level: number)
	safe(function()
		AnalyticsService:LogProgressionStartEvent(player, path, level)
	end)
end

function Telemetry.missionEnd(player: Player, path: string, level: number, outcome: string, phase: number)
	safe(function()
		local custom = fields(outcome, "Phase" .. tostring(phase))
		if outcome == "Victory" then
			AnalyticsService:LogProgressionCompleteEvent(player, path, level, nil, custom)
		else
			AnalyticsService:LogProgressionFailEvent(player, path, level, nil, custom)
		end
	end)
end

function Telemetry.custom(player: Player, name: string, value: number, a: string?, b: string?, c: string?)
	safe(function()
		AnalyticsService:LogCustomEvent(player, name, value, fields(a, b, c))
	end)
end

function Telemetry.spellCast(player: Player, definition: any)
	local session = usage[player]
	if session then
		Spec.recordCast(session, definition)
	end
	Telemetry.onboarding(player, "CastSpell")
end

local function flush(player: Player, reason: string)
	local session = usage[player]
	usage[player] = nil
	if session then
		for _, entry in session do
			Telemetry.custom(player, "SpellUsage", entry.Count, entry.Form, entry.Element, entry.Effect)
		end
	end
	local since = joinedAt[player]
	joinedAt[player] = nil
	onboarded[player] = nil
	if since then
		local where = if player:GetAttribute("MissionDefender") == true then "Mission" else "Hub"
		Telemetry.custom(player, "SessionEnd", math.floor(os.clock() - since), reason, where)
	end
end

function Telemetry.start()
	if started then
		return
	end
	started = true
	local function added(player: Player)
		onboarded[player], usage[player], joinedAt[player] = {}, {}, os.clock()
		Telemetry.onboarding(player, "Joined")
	end
	Players.PlayerAdded:Connect(added)
	for _, player in Players:GetPlayers() do
		added(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		flush(player, "Left")
	end)
	game:BindToClose(function()
		for player in usage do
			flush(player, "Shutdown")
		end
	end)
end

return Telemetry
