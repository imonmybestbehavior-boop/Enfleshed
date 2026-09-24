--!strict

local Sandbox = require(script.Services.SandboxService)
local StressTest = require(script.Services.SandboxStressService)
local Assignments = require(script.Services.AssignmentService)
local ActionRouter = require(script.Networking.ActionRouter)

Sandbox.start()
ActionRouter.start()
StressTest.start()
Assignments.start()
