--!strict

local ActionRouter = require(script.Networking.ActionRouter)
local Config = require(game:GetService("ReplicatedStorage").Shared.Configuration.Sandbox)

local Arena = require(script.Services.CombatSandboxService)
if Arena.enabled() then
	Arena.start()
else
	require(script.Services.SandboxService).start()
end
require(script.Services.EnemyRuntime).start()
ActionRouter.start()
if Config.StressTest.Enabled then
	require(script.Services.SandboxStressService).start()
end
if not Arena.enabled() then
	require(script.Services.AssignmentService).start()
	require(script.Services.AmbientEnemyService).start()
	require(script.Services.LivingCityService).start()
	require(script.Services.WorldEventService).start()
end
