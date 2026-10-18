--!strict
-- Generic round-based game mode. Owns everything that is the same for every
-- mode: the round state machine, participants and late joins, replay queue,
-- client requests, feature flag, reward commit (idempotent per round id),
-- analytics, shutdown rewards, death/damage attribution and state snapshots.
-- A mode supplies only its content through the hooks in `ModeDefinition`.
--
-- States: IDLE → PREPARING → ACTIVE → (VICTORY|DEFEAT) → REWARDS → CLEANUP → READY_FOR_REPLAY
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Damage = require(script.Parent.DamageService)
local Progression = require(script.Parent.MissionProgression)
local Profiles = require(script.Parent.PlayerProfileService)
local FeatureFlags = require(script.Parent.FeatureFlagService)
local Telemetry = require(script.Parent.TelemetryService)

export type Participant = {
	Joined: number,
	Damage: number,
	Kills: number,
	Deaths: number,
	[string]: any, -- mode-specific counters (e.g. Repairs)
}

export type Reward = {
	XP: number,
	Marks: number,
	Kills: number,
	Repairs: number,
	Score: number,
	Victory: boolean,
	Deaths: number,
	Interrupted: boolean?,
}

export type ModeDefinition = {
	Id: string, -- analytics path, feature flag and default display name
	Tier: number?, -- difficulty tier for analytics (default 1)
	Remote: RemoteEvent,
	Preparation: number, -- seconds of PREPARING before ACTIVE
	Results: number, -- seconds on the results screen before cleanup
	MaxParticipants: number,
	ParticipantAttribute: string, -- Player attribute marking participants (spawn routing)
	UnavailableText: string?,
	-- Hooks (runner is passed so modes can read participants/state):
	build: (runner: Runner) -> Folder, -- create world; returns the folder used for metric attributes
	duration: (runner: Runner) -> number, -- ACTIVE length; reaching it calls timeoutOutcome
	timeoutOutcome: boolean, -- true = victory when the timer runs out
	prepare: (runner: Runner) -> (), -- reset mode state for a new round
	activate: ((runner: Runner) -> ())?, -- ACTIVE begins
	outcome: (runner: Runner, now: number) -> boolean?, -- checked first each second: true/false ends the round
	tick: (runner: Runner, now: number) -> (), -- each second while ACTIVE, after outcome and timer checks
	cleanup: (runner: Runner) -> (), -- remove round content after results / abandon
	reward: (runner: Runner, data: Participant, victory: boolean) -> Reward,
	newParticipant: (() -> { [string]: any })?, -- extra per-participant counters
	snapshot: (runner: Runner, message: { [string]: any }) -> (), -- add mode fields to MissionState
	progressLabel: ((runner: Runner) -> number)?, -- e.g. phase reached, for analytics
}

export type Runner = {
	Definition: ModeDefinition,
	State: string,
	RoundId: string,
	StartAt: number,
	EndAt: number,
	Duration: number,
	Participants: { [Player]: Participant },
	Folder: Folder?,
	metric: (name: string) -> (),
	snapshot: (player: Player?) -> (),
	finish: (victory: boolean) -> (),
	countParticipants: () -> number,
	start: () -> (),
}

local ModeRunner = {}

function ModeRunner.new(definition: ModeDefinition): Runner
	local runner = {} :: Runner
	runner.Definition = definition
	runner.State = "IDLE"
	runner.RoundId = ""
	runner.StartAt, runner.EndAt, runner.Duration = 0, 0, 0
	runner.Participants = {}
	local tier = definition.Tier or 1
	local remote = definition.Remote
	local ready: { [Player]: boolean } = {}
	local profiles: { [Player]: any } = {}
	local writable: { [Player]: boolean } = {}
	local lastRequest: { [Player]: number } = {}
	local participants = runner.Participants

	function runner.metric(name: string)
		local folder = runner.Folder
		if folder then
			folder:SetAttribute(name, (folder:GetAttribute(name) or 0) + 1)
		end
	end

	function runner.countParticipants(): number
		local n = 0
		for player in participants do
			if player.Parent == Players then
				n += 1
			end
		end
		return n
	end

	local function progress(): number
		return if definition.progressLabel then definition.progressLabel(runner) else 0
	end

	function runner.snapshot(player: Player?)
		if not player then
			for _, target in Players:GetPlayers() do
				runner.snapshot(target)
			end
			return
		end
		local now = workspace:GetServerTimeNow()
		local remaining = if runner.State == "PREPARING"
			then math.max(0, math.ceil(runner.StartAt - now))
			elseif runner.State == "ACTIVE" then math.max(0, math.ceil(runner.EndAt - now))
			else 0
		local message: { [string]: any } = {
			Kind = "MissionState",
			Mode = definition.Id,
			State = runner.State,
			Id = runner.RoundId,
			Remaining = remaining,
			Duration = runner.Duration,
			Participants = runner.countParticipants(),
		}
		definition.snapshot(runner, message)
		message.Joined = participants[player] ~= nil
		profiles[player] = Progression.cached(player.UserId) or profiles[player]
		message.Profile = profiles[player]
		message.SaveAvailable = writable[player] == true
		remote:FireClient(player, message)
	end

	local function enter(player: Player): boolean
		if participants[player] then
			return true
		end
		local state = runner.State
		if runner.countParticipants() >= definition.MaxParticipants then
			return false
		end
		if state ~= "IDLE" and state ~= "READY_FOR_REPLAY" and state ~= "PREPARING" and state ~= "ACTIVE" then
			return false
		end
		local data: Participant = { Joined = workspace:GetServerTimeNow(), Damage = 0, Kills = 0, Deaths = 0 }
		for key, value in (if definition.newParticipant then definition.newParticipant() else {}) do
			data[key] = value
		end
		participants[player] = data
		Telemetry.onboarding(player, "EnteredMission")
		if state == "ACTIVE" then
			Telemetry.missionStart(player, definition.Id, tier)
		end
		player:SetAttribute("MissionSandbox", false)
		player:SetAttribute(definition.ParticipantAttribute, true)
		if state == "PREPARING" or state == "ACTIVE" then
			player:LoadCharacter()
		end
		return true
	end

	local function startRound()
		if runner.State ~= "IDLE" and runner.State ~= "READY_FOR_REPLAY" then
			return
		end
		runner.State = "PREPARING"
		runner.metric("RunsStarted")
		runner.RoundId = HttpService:GenerateGUID(false)
		runner.Duration = definition.duration(runner)
		definition.prepare(runner)
		runner.StartAt = workspace:GetServerTimeNow() + definition.Preparation
		runner.EndAt = runner.StartAt + runner.Duration
		local extra = if definition.newParticipant then definition.newParticipant else nil
		for player, data in participants do
			data.Joined, data.Damage, data.Kills, data.Deaths = workspace:GetServerTimeNow(), 0, 0, 0
			for key, value in (if extra then extra() else {}) do
				data[key] = value
			end
			player:SetAttribute(definition.ParticipantAttribute, true)
			player:LoadCharacter()
		end
		runner.snapshot(nil)
	end

	local function resetToReplay(reason: string)
		runner.metric(reason)
		runner.State = "CLEANUP"
		definition.cleanup(runner)
		runner.State = "READY_FOR_REPLAY"
	end

	local function reportEnd(player: Player, reward: Reward, saved: any, ok: boolean, outcome: string)
		runner.metric(if ok then "RewardsCommitted" else "RewardFailures")
		Telemetry.missionEnd(player, definition.Id, tier, outcome, progress())
		if ok and saved then
			Telemetry.economy(player, "Source", "Marks", reward.Marks, saved.Marks, "Gameplay", definition.Id)
			Telemetry.economy(player, "Source", "XP", reward.XP, saved.XP, "Gameplay", definition.Id)
		end
	end

	function runner.finish(victory: boolean)
		if runner.State ~= "ACTIVE" then
			return
		end
		runner.State = if victory then "VICTORY" else "DEFEAT"
		runner.metric(if victory then "RunsWon" else "RunsLost")
		runner.snapshot(nil)
		runner.State = "REWARDS"
		local completedId = runner.RoundId
		local results: { [Player]: Reward } = {}
		for player, data in participants do
			if player.Parent == Players then
				results[player] = definition.reward(runner, data, victory)
			end
		end
		for player, reward in results do
			local saved, ok = Progression.commit(player.UserId, completedId, reward)
			reportEnd(player, reward, saved, ok, if victory then "Victory" else "Defeat")
			Telemetry.onboarding(player, "FinishedMission")
			if player.Parent == Players then
				if saved then
					profiles[player] = saved
				end
				writable[player] = ok
				remote:FireClient(player, {
					Kind = "MissionResult",
					Mode = definition.Id,
					Id = completedId,
					Victory = victory,
					Reward = reward,
					Saved = ok,
					Profile = profiles[player],
				})
			end
		end
		runner.snapshot(nil)
		task.delay(definition.Results, function()
			if runner.RoundId ~= completedId or runner.State ~= "REWARDS" then
				return
			end
			runner.State = "CLEANUP"
			definition.cleanup(runner)
			for player in participants do
				player:SetAttribute(definition.ParticipantAttribute, false)
				if player.Parent == Players then
					player:LoadCharacter()
				end
			end
			table.clear(participants)
			runner.State = "READY_FOR_REPLAY"
			runner.snapshot(nil)
			local queued = ready
			ready = {}
			for player in queued do
				if player.Parent == Players then
					enter(player)
				end
			end
			if runner.countParticipants() > 0 then
				startRound()
			end
		end)
	end

	-- Server shutdown mid-round: participants keep a participation reward (defeat
	-- tier, scaled by time played), counted as played but neither won nor lost.
	-- Runs before profiles are flushed, so the commit needs no extra write.
	local function grantInterrupted()
		if runner.State ~= "ACTIVE" then
			return
		end
		runner.State = "CLEANUP"
		runner.metric("RunsInterrupted")
		for player, data in participants do
			if player.Parent == Players and Profiles.peek(player.UserId) then
				local reward = definition.reward(runner, data, false)
				reward.Interrupted = true
				local saved, ok = Progression.commit(player.UserId, runner.RoundId, reward, true)
				reportEnd(player, reward, saved, ok, "Interrupted")
			end
		end
	end

	local function tick()
		if runner.State == "PREPARING" and workspace:GetServerTimeNow() >= runner.StartAt then
			runner.State = "ACTIVE"
			for participant in participants do
				Telemetry.missionStart(participant, definition.Id, tier)
			end
			if definition.activate then
				definition.activate(runner)
			end
			runner.snapshot(nil)
		end
		if runner.State ~= "ACTIVE" then
			return
		end
		local now = workspace:GetServerTimeNow()
		local outcome = definition.outcome(runner, now)
		if runner.State ~= "ACTIVE" then
			return -- the hook already finished the round
		end
		if outcome ~= nil then
			runner.finish(outcome)
		elseif now >= runner.EndAt then
			runner.finish(definition.timeoutOutcome)
		else
			definition.tick(runner, now)
		end
	end

	local function trackDeaths(player: Player)
		local function watch(character: Model)
			local health = character:WaitForChild("Humanoid", 10)
			if health and health:IsA("Humanoid") then
				health.Died:Connect(function()
					if participants[player] and runner.State == "ACTIVE" then
						participants[player].Deaths += 1
						runner.metric("PlayerDeaths")
					end
				end)
			end
		end
		player.CharacterAdded:Connect(watch)
		if player.Character then
			task.spawn(watch, player.Character)
		end
	end

	local function loadProfile(player: Player)
		task.spawn(function()
			local profile, ok = Progression.load(player.UserId)
			if player.Parent == Players then
				if not profiles[player] then
					profiles[player], writable[player] = profile, ok
				end
				runner.snapshot(player)
			end
		end)
	end

	local verbose = RunService:IsStudio()
	local function ack(player: Player, action: string, ok: boolean, text: string)
		if verbose then
			print(string.format("[Mission/server] %s %s → %s (%s)", player.Name, action, tostring(ok), text))
		end
		remote:FireClient(player, { Kind = "Ack", Action = action, Ok = ok, Text = text })
	end
	local function handleRequest(player: Player, action: any)
		if type(action) ~= "string" or #action > 20 then
			warn("[Mission/server] rejected malformed request from", player.Name, action)
			return
		end
		if verbose and action ~= "State" then
			print("[Mission/server] request", player.Name, action, "state", runner.State)
		end
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 0.3 then
			if action ~= "State" then
				ack(player, action, false, "Too fast, try again")
			end
			return
		end
		lastRequest[player] = now
		local state = runner.State
		if action == "State" then
			runner.snapshot(player)
			return
		elseif
			(action == "Start" or action == "Join" or action == "Replay")
			and not FeatureFlags.enabled(definition.Id, player)
		then
			remote:FireClient(player, {
				Kind = "Notice",
				Text = definition.UnavailableText or "This mode is temporarily unavailable",
			})
		elseif action == "Start" then
			if state == "PREPARING" or state == "ACTIVE" then
				local joined = enter(player)
				ack(player, action, joined, if joined then "Joined the defense" else "The defense is full")
			elseif enter(player) and (runner.State == "IDLE" or runner.State == "READY_FOR_REPLAY") then
				startRound()
				ack(player, action, true, "Mission starting")
			else
				ack(player, action, false, "Cannot start now (" .. tostring(runner.State) .. ")")
			end
		elseif action == "Join" then
			local joined = (state == "PREPARING" or state == "ACTIVE") and enter(player)
			ack(player, action, joined, if joined then "Joined the defense" else "No defense to join")
		elseif action == "Replay" then
			if state == "REWARDS" and participants[player] then
				ready[player] = true
				runner.metric("ReplaySelections")
			elseif state == "READY_FOR_REPLAY" then
				if enter(player) then
					startRound()
				end
			end
		elseif action == "Hub" then
			ready[player] = nil
			if state ~= "ACTIVE" and state ~= "PREPARING" then
				participants[player] = nil
				player:SetAttribute(definition.ParticipantAttribute, false)
				player:LoadCharacter()
			end
		end
		runner.snapshot(player)
	end

	function runner.start()
		runner.Folder = definition.build(runner)
		runner.Duration = definition.duration(runner)
		Profiles.beforeShutdown(grantInterrupted)
		-- Participant damage and kills on this round's content (any model tagged with the round id).
		Damage.Applied:Connect(function(attacker: Model, target: Humanoid, amount: number, killed: boolean)
			if runner.State ~= "ACTIVE" then
				return
			end
			local model = target.Parent
			if not model or model:GetAttribute("MissionId") ~= runner.RoundId then
				return
			end
			local player = Players:GetPlayerFromCharacter(attacker)
			if not player then
				local owner = attacker:GetAttribute("MagicSummonOwnerUserId")
				if type(owner) == "number" then
					player = Players:GetPlayerByUserId(owner)
				end
			end
			local data = player and participants[player]
			if data then
				data.Damage += amount
				if killed then
					data.Kills += 1
				end
			end
		end)
		remote.OnServerEvent:Connect(handleRequest)
		local function added(player: Player)
			player:SetAttribute(definition.ParticipantAttribute, false)
			trackDeaths(player)
			loadProfile(player)
		end
		Players.PlayerAdded:Connect(added)
		for _, player in Players:GetPlayers() do
			added(player)
		end
		Players.PlayerRemoving:Connect(function(player)
			Progression.release(player.UserId)
			participants[player], ready[player], profiles[player], writable[player], lastRequest[player] =
				nil, nil, nil, nil, nil
			if runner.countParticipants() == 0 and (runner.State == "ACTIVE" or runner.State == "PREPARING") then
				resetToReplay("RunsAbandoned")
			end
		end)
		task.spawn(function()
			while true do
				tick()
				if runner.State == "PREPARING" or runner.State == "ACTIVE" then
					runner.snapshot(nil)
				end
				task.wait(1)
			end
		end)
	end

	return runner
end

return ModeRunner
