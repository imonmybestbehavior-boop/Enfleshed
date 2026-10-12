--!strict
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Configuration.WorldEvents)
local Plan = require(Shared.Configuration.PhaseATopology)
local Locations = require(Shared.Configuration.AssignmentLocations)
local Runtime = require(script.Parent.EnemyRuntime)
local Spawn = require(script.Parent.WorldSpawnService)
local City = require(script.Parent.LivingCityService)
local Damage = require(script.Parent.DamageService)
local Rules = require(script.Parent.WorldEventRules)
local Director = {}
local events, cooldowns = {}, {}
local folder, nextEvent = nil, 0
local random = Random.new()
local function countLiving(event)
	local n = 0
	for _, enemy in event.Enemies do
		if enemy.IsAlive() then
			n += 1
		end
	end
	return n
end
local function state(event, value)
	event.State = value
	event.Folder:SetAttribute("State", value)
end
local function center(event)
	return if event.Traveler and event.Traveler.Model.Parent then event.Traveler.Root.Position else event.Position
end
local function resolve(event, success, now)
	if event.State ~= "Active" and event.State ~= "Preparing" then
		return
	end
	state(event, "Resolving")
	event.Success = success
	for _, player in Players:GetPlayers() do
		if Rules.claim(event.Credit, player.UserId, success, Config) then
			player:SetAttribute("MilitaryScrip", (player:GetAttribute("MilitaryScrip") or 0) + event.Definition.Reward)
			player:SetAttribute(
				"EventRewardNotice",
				event.Definition.Name .. " · +" .. event.Definition.Reward .. " scrip"
			)
		end
	end
	event.ResolvedAt = now
end
local function cleanup(event, now)
	state(event, "Cleanup")
	for _, enemy in event.Enemies do
		enemy.Destroy()
	end
	if event.Traveler then
		City.remove(event.Traveler)
	end
	if event.Companion then
		City.remove(event.Companion)
	end
	City.release(event.Id)
	cooldowns[event.LocationId] = now + (event.Definition.Cooldown or Config.LocationCooldown)
	state(event, "Cooldown")
	folder:SetAttribute(
		"Cooldown_" .. event.LocationId,
		workspace:GetServerTimeNow() + (event.Definition.Cooldown or Config.LocationCooldown)
	)
	event.Folder:Destroy()
	events[event.Id] = nil
	-- No successor wave: the location stays quiet through its cooldown.
	nextEvent = math.max(nextEvent, now + Config.GlobalCooldown / math.max(0.1, Config.FrequencyMultiplier))
end
local function spawnPoints(event)
	local points = {}
	local origin = if event.Kind == "RampartAssault" then Plan.Nodes[Config.Anchors.ArchApproach] else event.Position
	for _ = 1, event.Count do
		local point = Spawn.find(origin, Config.SpawnRadius, Config.MinimumPlayerDistance, Config.SafeRadius, points)
		if not point then
			return nil
		end
		table.insert(points, point)
	end
	return points
end
local function objective(enemy, actor)
	if not actor then
		return
	end
	local value = Instance.new("ObjectValue")
	value.Name, value.Value, value.Parent = "ObjectiveTarget", actor.Model, enemy.Model
end
local function activate(event, now)
	-- Recheck ground, player distances and occupancy after the warning period.
	local points = spawnPoints(event)
	if not points then
		resolve(event, false, now)
		return
	end
	if event.Kind == "TravelIncident" then
		event.Traveler = City.create("Supply carrier", "Worker", event.Definition.Route, true)
		event.Companion = City.create("Escort", "Guard", event.Definition.Route, true)
		if not event.Traveler or not event.Companion then
			resolve(event, false, now)
			return
		end
		event.LastPosition = event.Traveler.Root.Position
	end
	local victim = event.Traveler or City.near(event.Position, event.Kind == "RampartAssault")
	if event.Kind == "LocalAttack" or event.Kind == "RampartAssault" then
		local distance
		victim, distance = City.near(event.Position, event.Kind == "RampartAssault")
		if not victim or distance > 160 then
			resolve(event, false, now)
			return
		end
		event.Protected = victim
	end
	for _, point in points do
		local enemy = Runtime.create(point, event.Folder)
		enemy.Model:SetAttribute("Population", "WorldEvent")
		enemy.Model:SetAttribute("EventId", event.Id)
		-- Breaches hold their location; other events approach their human target.
		if event.Kind ~= "Breach" then
			objective(enemy, victim)
		end
		table.insert(event.Enemies, enemy)
	end
	event.Started = now
	event.LastTick = now
	state(event, "Active")
end
local function begin(kind, locationId, location, now)
	local definition = Config.Definitions[kind]
	local count = random:NextInteger(definition.CountRange[1], definition.CountRange[2])
	local active, enemies = 0, 0
	for _, e in events do
		active += 1
		enemies += e.Count
	end
	if
		not Rules.available(now, cooldowns[locationId] or 0, active, Config.ActiveCap, enemies, count, Config.EnemyCap)
	then
		return false
	end
	if not Spawn.safe(location.Position, Config.SafeRadius) then
		return false
	end
	local nearby = false
	for _, root in Spawn.players() do
		local d = (root.Position - location.Position).Magnitude
		if d >= Config.MinimumPlayerDistance and d <= Config.MaximumDiscoveryDistance then
			nearby = true
		end
	end
	if not nearby then
		return false
	end
	local event = {
		Id = Http:GenerateGUID(false),
		Kind = kind,
		Definition = definition,
		LocationId = locationId,
		Position = location.Position,
		Count = count,
		Enemies = {},
		Credit = {},
		PreparedAt = now,
		State = "Preparing",
		PlayerPositions = {},
	}
	if not spawnPoints(event) then
		return false
	end
	if kind == "LocalAttack" or kind == "RampartAssault" then
		local human, distance = City.near(location.Position, kind == "RampartAssault")
		if not human or distance > 160 then
			return false
		end
	end
	if kind == "TravelIncident" and locationId ~= "Checkpoint_Market" then
		return false
	end
	local instance = Instance.new("Folder")
	instance.Name, instance.Parent = event.Id, folder
	instance:SetAttribute("DefinitionId", kind)
	instance:SetAttribute("LocationId", locationId)
	event.Folder = instance
	state(event, "Preparing")
	events[event.Id] = event
	cooldowns[locationId] = math.huge
	if kind == "RampartAssault" then
		City.mobilize(
			event.Id,
			Plan.Nodes[Config.Anchors.RampartDefenseLine],
			Plan.Nodes[Config.Anchors.CivilianRetreatArea]
		)
	end
	nextEvent = now + Config.GlobalCooldown / math.max(0.1, Config.FrequencyMultiplier)
	return true
end
local function attempt(kind)
	if not Config.Definitions[kind] then
		return false, "Unknown event definition"
	end
	local choices = {}
	if kind == "RampartAssault" then
		choices = {
			{
				Id = "RampartDefenseLine",
				Position = Plan.Nodes[Config.Anchors.RampartDefenseLine],
				Category = "Defense",
			},
		}
	else
		for id, location in Locations do
			if table.find(Config.Definitions[kind].Categories, location.Category) then
				table.insert(choices, { Id = id, Position = location.Position, Category = location.Category })
			end
		end
	end
	-- Randomized rotation, rather than starving the last valid location in a table.
	local offset = if #choices > 0 then random:NextInteger(1, #choices) else 1
	for i = 1, #choices do
		local location = choices[(offset + i - 2) % #choices + 1]
		if begin(kind, location.Id, location, os.clock()) then
			return true, "Preparing " .. kind .. " at " .. location.Id
		end
	end
	return false, "No eligible location: check player distance, safe/clear ground, humans, caps and cooldowns"
end
function Director.start()
	if folder then
		return
	end
	folder = Instance.new("Folder")
	folder.Name, folder.Parent = "WorldEvents", workspace
	local anchors = Instance.new("Folder")
	anchors.Name, anchors.Parent = "Anchors", folder
	for name, node in Config.Anchors do
		local anchor = Instance.new("Vector3Value")
		anchor.Name, anchor.Value, anchor.Parent = name, Plan.Nodes[node], anchors
	end
	nextEvent = os.clock() + Config.InitialDelay
	Damage.Applied:Connect(function(attacker, target, amount)
		local player = Players:GetPlayerFromCharacter(attacker)
		local model = target.Parent
		if not player or not model or model:GetAttribute("Population") ~= "WorldEvent" then
			return
		end
		local event = events[model:GetAttribute("EventId")]
		if not event or event.State ~= "Active" then
			return
		end
		-- Attributes alone are insufficient: require membership in this event's owned roster.
		for _, enemy in event.Enemies do
			if enemy.Model == model then
				Rules.credit(event.Credit, player.UserId, amount, 0, 0)
				break
			end
		end
	end)
	if Run:IsStudio() and Config.Development.Enabled then
		local force = Instance.new("BindableFunction")
		force.Name, force.Parent = "Force", folder
		force.OnInvoke = attempt
		if Config.Development.ForceEvent ~= "" then
			-- Wait for a player to finish opening before the one-shot configured test.
			task.spawn(function()
				while #Spawn.players() == 0 do
					task.wait(1)
				end
				local ok, reason = attempt(Config.Development.ForceEvent)
				print("World event force:", ok, reason)
			end)
		end
	end
	local nextTick = 0
	Run.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextTick then
			return
		end
		nextTick = now + Config.Tick
		for _, event in events do
			if
				event.State == "Preparing"
				and now - event.PreparedAt >= (event.Definition.Preparation or Config.Preparation)
			then
				activate(event, now)
			elseif event.State == "Active" then
				local living = countLiving(event)
				local protected = event.Traveler or event.Protected
				local alive = not protected or (protected.Model.Parent ~= nil and protected.Humanoid.Health > 0)
				if event.Traveler and alive then
					local position = event.Traveler.Root.Position
					local traveled = (position - event.LastPosition).Magnitude
					local dt = math.min(now - event.LastTick, Config.Tick * 2)
					-- Stationary proximity and teleports are not escort participation.
					for _, root in Spawn.players() do
						local player = Players:GetPlayerFromCharacter(root.Parent)
						local last = event.PlayerPositions[player.UserId]
						if last then
							local seconds, distance = Rules.escortStep(
								traveled,
								(root.Position - last).Magnitude,
								(last - event.LastPosition).Magnitude < 35,
								(root.Position - position).Magnitude < 35,
								dt
							)
							if seconds > 0 then
								Rules.credit(event.Credit, player.UserId, 0, seconds, distance)
							end
						end
						event.PlayerPositions[player.UserId] = root.Position
					end
					event.LastPosition = position
				end
				event.LastTick = now
				local result = Rules.outcome(
					living,
					alive,
					event.Traveler and event.Traveler.Finished,
					event.Kind == "TravelIncident",
					now - event.Started > event.Definition.Duration
				)
				if result then
					resolve(event, result == "Completed", now)
				end
			elseif event.State == "Resolving" then
				state(event, if event.Success then "Completed" else "Failed")
			elseif
				(event.State == "Completed" or event.State == "Failed")
				and now - event.ResolvedAt >= Config.CleanupDelay
			then
				cleanup(event, now)
			end
		end
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local relevant, nearest = nil, math.huge
			if player:GetAttribute("OpeningComplete") and root then
				for _, event in events do
					local distance = (root.Position - center(event)).Magnitude
					if distance < event.Definition.DiscoveryRadius and distance < nearest then
						relevant, nearest = event, distance
					end
				end
			end
			local message = ""
			if relevant then
				message = relevant.Definition.Name .. " · " .. relevant.State
				if relevant.State == "Active" then
					message ..= "\nEnfleshed remaining: " .. countLiving(relevant)
				end
			end
			player:SetAttribute("NearbyWorldEvent", message)
		end
		if Config.RandomEnabled and Config.FrequencyMultiplier > 0 and now >= nextEvent then
			nextEvent = now + 15 -- Back off when every candidate is ineligible.
			local total = 0
			for _, definition in Config.Definitions do
				total += definition.Weight
			end
			local roll = random:NextNumber(0, total)
			for kind, definition in Config.Definitions do
				roll -= definition.Weight
				if roll <= 0 then
					attempt(kind)
					break
				end
			end
		end
	end)
end
return Director
