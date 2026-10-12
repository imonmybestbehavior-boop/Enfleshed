--!strict
-- Server-owned test preference storage with dormant discovery compatibility.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Configuration.MagicLab)
local Spec = require(Shared.Modules.MagicDiscoverySpec)
local LocusConfig = require(Shared.Configuration.MagicLocus)
local LocusProgression = require(Shared.Modules.MagicLocusProgressionSpec)
local MagicProfiles = require(Shared.Configuration.MagicProfiles)
local Service = {}

local profiles: { [Player]: any } = {}
local sessionProgress: { [Player]: any } = {}
local loaded: { [Player]: boolean } = {}
local writable: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local revisions: { [Player]: number } = {}
local pendingProfileSelections: { [Player]: string } = {}
local store
local storeReady, storeResult = pcall(function()
	return DataStoreService:GetDataStore(Config.DiscoveryDataStoreName)
end)
if storeReady then
	store = storeResult
end

local function empty()
	return Spec.decode(nil)
end

local function key(player: Player): string
	return "u:" .. tostring(player.UserId)
end

local function refreshAttributes(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local progressionEnabled = Config.ProgressionEnabled == true
	local progress = Spec.progress(profile, progressionEnabled)
	local locus = LocusProgression.profile(LocusConfig.Default, LocusConfig.Progression, progress.TotalCasts)
	player:SetAttribute("MagicDiscoveryLoaded", loaded[player] == true)
	player:SetAttribute("MagicDiscoveryTotalCasts", progress.TotalCasts)
	player:SetAttribute("MagicLocusRank", locus.Rank)
	player:SetAttribute("MagicLocusRankProgress", locus.Progress)
	player:SetAttribute("MagicLocusCastsToNextRank", locus.CastsToNextRank)
	for name, value in locus.Metrics do
		player:SetAttribute("MagicLocus" .. name, value)
	end
	for name, count in progress.Principles do
		player:SetAttribute("MagicDiscoveryPrinciple_" .. name, count)
	end
	for name, count in progress.Forms do
		player:SetAttribute("MagicDiscoveryForm_" .. name, count)
	end
	for name, unlocked in progress.Palettes do
		player:SetAttribute("MagicUnlockPalette_" .. name, unlocked)
	end
	for name, unlocked in progress.Shapes do
		player:SetAttribute("MagicUnlockShape_" .. name, unlocked)
	end
	for _, name in Spec.ExpressionOrder do
		player:SetAttribute("MagicDiscoveryExpression_" .. name, profiles[player].Expressions[name] or 0)
		player:SetAttribute("MagicUnlockExpression_" .. name, progress.Expressions[name] == true)
	end
	local selectedProfileId = profiles[player].AwakeningProfileId
	if not Spec.awakeningProfileUnlocked(profiles[player], selectedProfileId, MagicProfiles, progressionEnabled) then
		selectedProfileId = "RecruitGeneric"
		profiles[player].AwakeningProfileId = selectedProfileId
	end
	player:SetAttribute("MagicAwakeningProfileId", selectedProfileId)
	for profileId, definition in MagicProfiles do
		player:SetAttribute(
			"MagicUnlockAwakening_" .. profileId,
			Spec.awakeningProfileUnlocked(profiles[player], profileId, MagicProfiles, progressionEnabled)
		)
	end
end

local function markDirty(player: Player)
	if not loaded[player] or not writable[player] or not store then
		return
	end
	dirty[player] = true
	revisions[player] = (revisions[player] or 0) + 1
	local revision = revisions[player]
	task.delay(Config.DiscoverySaveDebounce, function()
		if player.Parent ~= Players or revisions[player] ~= revision or not dirty[player] then
			return
		end
		local snapshot = Spec.encode(profiles[player])
		if not snapshot then
			writable[player] = false
			return
		end
		local rejected = false
		local ok, result = pcall(function()
			return store:UpdateAsync(key(player), function(existing)
				rejected = false
				if existing ~= nil then
					local _, safe = Spec.decode(existing)
					if not safe then
						rejected = true
						return nil
					end
				end
				return snapshot
			end)
		end)
		if not ok then
			return
		end
		if rejected or result == nil then
			writable[player] = false
			return
		end
		if revisions[player] == revision then
			dirty[player] = nil
		end
	end)
end

local function bind(player: Player)
	if profiles[player] then
		return
	end
	profiles[player] = empty()
	sessionProgress[player] = empty()
	loaded[player] = false
	writable[player] = false
	refreshAttributes(player)
	task.spawn(function()
		if not store then
			loaded[player], writable[player] = true, false
			local pendingProfileId = pendingProfileSelections[player]
			pendingProfileSelections[player] = nil
			if pendingProfileId then
				local selected = Spec.selectAwakeningProfile(
					profiles[player],
					pendingProfileId,
					MagicProfiles,
					Config.ProgressionEnabled == true
				)
				if selected then
					profiles[player] = selected
				end
			end
			refreshAttributes(player)
			return
		end
		local ok, raw = pcall(function()
			return store:GetAsync(key(player))
		end)
		if player.Parent ~= Players then
			return
		end
		if ok then
			local saved, safe = Spec.decode(raw)
			if safe then
				local delta = sessionProgress[player]
				saved.TotalCasts += delta.TotalCasts
				for principle, count in delta.Principles do
					saved.Principles[principle] += count
				end
				for form, count in delta.Forms do
					saved.Forms[form] += count
				end
				for expression, count in delta.Expressions do
					saved.Expressions[expression] += count
				end
				profiles[player] = saved
				loaded[player], writable[player] = true, true
			else
				loaded[player], writable[player] = true, false
			end
		else
			loaded[player], writable[player] = true, false
		end
		local pendingProfileId = pendingProfileSelections[player]
		pendingProfileSelections[player] = nil
		if pendingProfileId then
			local selected, accepted = Spec.selectAwakeningProfile(
				profiles[player],
				pendingProfileId,
				MagicProfiles,
				Config.ProgressionEnabled == true
			)
			if accepted and selected then
				profiles[player] = selected
			end
		end
		refreshAttributes(player)
		if sessionProgress[player].TotalCasts > 0 or pendingProfileId ~= nil then
			markDirty(player)
		end
	end)
end

local function remove(player: Player)
	-- Debounced saves are best-effort. A final snapshot avoids losing a quick Studio session.
	if dirty[player] and writable[player] and store and loaded[player] then
		local snapshot = Spec.encode(profiles[player])
		if snapshot then
			pcall(function()
				store:UpdateAsync(key(player), function(existing)
					if existing ~= nil then
						local _, safe = Spec.decode(existing)
						if not safe then
							return nil
						end
					end
					return snapshot
				end)
			end)
		end
	end
	profiles[player], sessionProgress[player], loaded[player], writable[player], dirty[player], revisions[player], pendingProfileSelections[player] =
		nil, nil, nil, nil, nil, nil, nil
end

function Service.start()
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(remove)
	game:BindToClose(function()
		for player in profiles do
			remove(player)
		end
	end)
	for _, player in Players:GetPlayers() do
		bind(player)
	end
end

function Service.recordCast(player: Player, definition)
	if Config.ProgressionEnabled ~= true then
		return
	end
	if not profiles[player] then
		bind(player)
	end
	local principle = definition and definition.Source and definition.Source.Principle
	local form = definition and definition.Form
	local expression = definition and definition.Source and definition.Source.Expression
	if type(principle) ~= "string" or type(form) ~= "string" or type(expression) ~= "string" then
		return
	end
	profiles[player] = Spec.recordCast(profiles[player], principle, form, expression)
	sessionProgress[player] = Spec.recordCast(sessionProgress[player], principle, form, expression)
	refreshAttributes(player)
	markDirty(player)
end

function Service.isUnlocked(player: Player, kind: string, id: string): boolean
	return Config.ProgressionEnabled ~= true or player:GetAttribute("MagicUnlock" .. kind .. "_" .. id) == true
end

function Service.selectAwakeningProfile(player: Player, profileId: any): (boolean, string?)
	if type(profileId) ~= "string" or not MagicProfiles[profileId] then
		return false, "Choose a valid Magic Focus profile"
	end
	if not profiles[player] then
		bind(player)
	end
	local selected, accepted, reason =
		Spec.selectAwakeningProfile(profiles[player], profileId, MagicProfiles, Config.ProgressionEnabled == true)
	if not accepted or not selected then
		return false, reason
	end
	profiles[player] = selected
	if not loaded[player] then
		pendingProfileSelections[player] = profileId
		refreshAttributes(player)
		return true, nil
	end
	refreshAttributes(player)
	markDirty(player)
	return true, nil
end

function Service.awakeningProfileId(player: Player): string?
	local profileId = profiles[player] and profiles[player].AwakeningProfileId
	return if type(profileId) == "string" and MagicProfiles[profileId] then profileId else "RecruitGeneric"
end

function Service.validateVisual(player: Player, visual, previous): (boolean, string?)
	if type(visual) ~= "table" then
		return false, "Visual settings must be a table"
	end
	if Config.ProgressionEnabled ~= true then
		return true, nil
	end
	local palette = visual.Palette
	if palette and palette ~= "LegacyCustom" and not Service.isUnlocked(player, "Palette", palette) then
		local priorPalette = previous and previous.Visual and previous.Visual.Palette
		if priorPalette ~= palette then
			local data = Spec.Palettes[palette]
			return false, data and ("Palette locked · " .. data.Requirement) or "Unknown palette"
		end
	end
	local shape = visual.CoreShape
	if shape and not Service.isUnlocked(player, "Shape", shape) then
		local priorShape = previous and previous.Visual and previous.Visual.CoreShape
		if priorShape ~= shape then
			local data = Spec.Shapes[shape]
			return false, data and ("Shape undiscovered · " .. data.Requirement) or "Unknown shape"
		end
	end
	return true, nil
end

function Service.validateExpression(player: Player, principle: string, expression: string, previous): (boolean, string?)
	local requirement = Spec.Expressions[expression]
	if not requirement or requirement.Principle ~= principle then
		return false, "Expression does not belong to the selected Principle"
	end
	if Config.ProgressionEnabled ~= true then
		return true, nil
	end
	if Service.isUnlocked(player, "Expression", expression) then
		return true, nil
	end
	local previousSource = previous and previous.Source
	if previousSource and previousSource.Principle == principle and previousSource.Expression == expression then
		return true, nil
	end
	return false, "Expression locked · " .. requirement.Requirement
end

function Service.progress(player: Player)
	local progress = Spec.progress(profiles[player] or empty(), Config.ProgressionEnabled == true)
	progress.AwakeningProfileId = Service.awakeningProfileId(player) or "RecruitGeneric"
	return progress
end

return Service
