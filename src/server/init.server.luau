--!strict

local Sandbox = require(script.Services.SandboxService)
local StressTest = require(script.Services.SandboxStressService)
local ActionRouter = require(script.Networking.ActionRouter)

Sandbox.start()
ActionRouter.start()
StressTest.start()
