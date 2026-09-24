--!strict

-- Development entry point. Each world phase is a designed assembly, while the
-- reusable helpers keep this from becoming another monolithic world function.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Configuration.LowerLayerGraybox)
local Context = require(script.Parent.LowerLayer.BuildContext)
local PhaseA = require(script.Parent.LowerLayer.PhaseA)

local Graybox = {}

function Graybox.start()
	if not Config.Enabled then
		return
	end
	local existing = workspace:FindFirstChild("LowerLayerGraybox")
	if existing then
		existing:Destroy()
	end
	local context = Context.new(Config)
	PhaseA.build(context)
	context:finish()
end

return Graybox
