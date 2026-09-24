--!strict

local Sandbox = require(script.Services.SandboxService)
local Enemy = require(script.Services.EnemyService)
local ActionRouter = require(script.Networking.ActionRouter)

Sandbox.start()
ActionRouter.start()
Enemy.start()
