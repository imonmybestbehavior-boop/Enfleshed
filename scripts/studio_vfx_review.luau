-- Paste into Studio's CLIENT Command Bar during Play. Cosmetic previews only.
local Shared = game:GetService("ReplicatedStorage").Shared
local Starters = require(Shared.Modules.GrimoireStarters)
local Composer = require(Shared.SpellVFXSystem.Core.SpellVFXComposer)
local camera = workspace.CurrentCamera
local root = game:GetService("Players").LocalPlayer.Character:WaitForChild("HumanoidRootPart")
local previousType, previousFrame = camera.CameraType, camera.CFrame
local spells = {}
for _, build in { Starters.buildShowcase, Starters.buildShowcaseExpansion } do
	for _, record in build() do
		spells[record.Definition.Name] = record.Definition
	end
end
local names = {
	"Cinder Comet",
	"Bell of Cinders",
	"Glasswing Seeker",
	"Thunderhead",
	"Undertow Ring",
	"Gale Reversal",
	"Stone Bastion",
	"Gravemire",
	"Aegis Beacon",
	"Dawnward",
	"Stonewake",
}
local session
local ok, err = pcall(function()
	camera.CameraType = Enum.CameraType.Scriptable
	local frame = root.CFrame * CFrame.new(0, 0, -18)
	camera.CFrame = CFrame.lookAt(frame.Position + Vector3.new(22, 14, 28), frame.Position)
	for _, name in names do
		print("[VFX review] " .. name .. " — inspect silhouette, volume, boundary and ending")
		session = Composer.preview(assert(spells[name]), frame)
		task.wait(4.5)
		if session then
			session:Stop()
		end
	end
end)
if session then
	session:Stop()
end
camera.CameraType, camera.CFrame = previousType, previousFrame
if not ok then
	warn(err)
end
print("[VFX review] Preview sequence ended. Test real casts, cancellation and effect expiry separately.")
