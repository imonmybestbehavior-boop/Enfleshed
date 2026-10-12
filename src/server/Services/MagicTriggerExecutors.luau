--!strict
local Payloads = require(script.Parent.MagicPayloadExecutors)
local Behaviors = require(script.Parent.MagicBehaviorExecutors)
local Commands = require(script.Parent.MagicCommandSpec)
local TargetDeath = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicTargetDeathSpec)
local Dispatch = require(script.Parent.MagicTriggerDispatch)
local Triggers = {}
function Triggers.execute(definition: any, event: string, context: any)
	Dispatch.execute(definition, event, context, Payloads, Behaviors, Commands, TargetDeath)
end
return Triggers
