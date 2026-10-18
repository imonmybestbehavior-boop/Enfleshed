-- Defend the Walls performance report. Paste into Studio's SERVER Command Bar
-- during Play, after pressing BEGIN MISSION (the mission must be ACTIVE).
-- Prints map part/light counts, then spawns a full three-lane wave and samples
-- server Heartbeat for SECONDS. Copy the printed report back to Claude.
local WAVE, SECONDS = 30, 60
local RunService = game:GetService("RunService")
local root = workspace:WaitForChild("DefendTheWalls")
local parts, meshes, lights, shadowed, billboards = 0, 0, 0, 0, 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		if d:IsA("MeshPart") then
			meshes += 1
		end
	elseif d:IsA("Light") then
		lights += 1
		if d.Shadows then
			shadowed += 1
		end
	elseif d:IsA("BillboardGui") then
		billboards += 1
	end
end
print(string.format("[DTW perf] map parts=%d meshparts=%d lights=%d shadowLights=%d billboards=%d workspaceParts=%d",
	parts, meshes, lights, shadowed, billboards, #workspace:GetDescendants()))
require(game.ServerScriptService.Server.Services.DefendTheWallsService).debugWave(WAVE)
local samples, started = {}, os.clock()
local connection = RunService.Heartbeat:Connect(function(dt)
	table.insert(samples, dt)
end)
task.wait(SECONDS)
connection:Disconnect()
table.sort(samples)
local sum = 0
for _, dt in samples do
	sum += dt
end
local function pct(p)
	return samples[math.max(1, math.floor(#samples * p))] * 1000
end
local enemies = #root.MissionEnemies:GetChildren()
local guardsAlive = 0
for _, g in root.MissionGuards:GetChildren() do
	local h = g:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		guardsAlive += 1
	end
end
print(string.format("[DTW perf] %.0fs heartbeat: avg %.2f ms (%.1f Hz), p50 %.2f, p95 %.2f, p99 %.2f, worst %.2f ms",
	os.clock() - started, sum / #samples * 1000, #samples / (os.clock() - started), pct(0.5), pct(0.95), pct(0.99),
	samples[#samples] * 1000))
print(string.format("[DTW perf] end: enemies alive=%d guards alive=%d wall level=%s breached=%d",
	enemies, guardsAlive, tostring(root:GetAttribute("WallLevel")), root:GetAttribute("WallsBreached") or 0))
