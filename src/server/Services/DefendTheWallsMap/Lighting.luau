--!strict
-- Night scene: cold moonlight, thick blue-grey fog and warm local light pools.
-- Technology = Future is set in default.project.json (not writable from scripts).
-- Values are tuned to stay readable on a Steam Deck panel; see Config.Map.Lighting.
local Lighting = game:GetService("Lighting")
local Config = require(game:GetService("ReplicatedStorage").Shared.Configuration.DefendTheWalls)

local Scene = {}

local function child(className: string, name: string): any
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing
	end
	local object = Instance.new(className)
	object.Name, object.Parent = name, Lighting
	return object
end

function Scene.apply()
	local tune = Config.Map.Lighting
	Lighting:SetAttribute("SceneOwner", "DefendTheWalls")
	Lighting.ClockTime = tune.ClockTime
	Lighting.Brightness = tune.Brightness
	Lighting.Ambient = tune.Ambient
	Lighting.OutdoorAmbient = tune.OutdoorAmbient
	Lighting.ColorShift_Top = Color3.fromRGB(120, 140, 170)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ExposureCompensation = tune.Exposure
	Lighting.GlobalShadows = true
	local atmosphere = child("Atmosphere", "SiegeAtmosphere")
	atmosphere.Density, atmosphere.Offset = tune.FogDensity, 0.12
	atmosphere.Color, atmosphere.Decay = Color3.fromRGB(78, 88, 104), Color3.fromRGB(34, 38, 52)
	atmosphere.Glare, atmosphere.Haze = 0, 2.1
	local battle = Lighting:FindFirstChild("BattleMapAtmosphere")
	if battle then
		battle:Destroy()
	end
	local grade = child("ColorCorrectionEffect", "SiegeGrade")
	grade.Contrast, grade.Saturation, grade.TintColor = 0.12, -0.18, Color3.fromRGB(226, 232, 255)
	local bloom = child("BloomEffect", "SiegeBloom")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.55, 28, 1.6
	local sky = child("Sky", "SiegeSky")
	sky.StarCount, sky.MoonAngularSize, sky.CelestialBodiesShown = 1800, 14, true
end

return Scene
