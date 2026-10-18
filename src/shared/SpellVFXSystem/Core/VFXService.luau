--!strict
-- Cosmetic-only composition runner. No gameplay or hit-detection code belongs here.
local Registry = require(script.Parent.VFXRegistry)
local Session = require(script.Parent.VFXSession)
local Effects = script.Parent.Parent.Effects
local VFXService = {}

local builtIns = {
	"Composition",
	"Attachment",
	"Particles",
	"Color",
	"Mesh",
	"Trail",
	"Beam",
	"Light",
	"Tween",
	"Animation",
	"Sound",
	"CameraShake",
	"Wait",
	"Scripted",
}
for _, name in builtIns do
	local moduleScript = Effects:FindFirstChild(name)
	if moduleScript and moduleScript:IsA("ModuleScript") then
		Registry:Register(name, require(moduleScript))
	end
end

function VFXService:RegisterEffect(name: string, module: any)
	Registry:Register(name, module)
end

function VFXService:Play(vfxConfig: any, target: any, context: any?)
	assert(type(vfxConfig) == "table" and type(vfxConfig.Effects) == "table", "VFX config must contain Effects")
	local effectsParent = workspace:FindFirstChild("TemporaryEffects")
	if not effectsParent then
		effectsParent = Instance.new("Folder")
		effectsParent.Name = "TemporaryEffects"
		effectsParent.Parent = workspace
	end
	local session = Session.new(target, context, effectsParent)
	local function run(effectData)
		if not session.Active or type(effectData) ~= "table" then
			return
		end
		local module = Registry:Get(effectData.Type)
		if module then
			local config = table.clone(effectData.Config or {})
			if config.InstanceName and config.Template and config.Template ~= "" and not config.AssetsFolder then
				config.AssetsFolder = config.AssetsFolder or "SpellVFXAssets"
			end
			local ok, err = pcall(module.Run, session, config, target, session.Context)
			if not ok then
				warn("[SpellVFX] " .. tostring(effectData.Type) .. " failed: " .. tostring(err))
			end
		end
	end
	if vfxConfig.Parallel == true then
		for _, effectData in vfxConfig.Effects do
			local thread = task.spawn(run, effectData)
			table.insert(session.Tasks, thread)
		end
	else
		local thread = task.spawn(function()
			for _, effectData in vfxConfig.Effects do
				if not session.Active then
					break
				end
				run(effectData)
			end
		end)
		table.insert(session.Tasks, thread)
	end
	return session
end

return VFXService
