-- Optional Roblox audio asset IDs used by the reusable magic presentation runtime.
local Spec = {}

Spec.Cues = {
	{ Key = "CastSoundId", Label = "Cast sound", Mode = "OneShot" },
	{ Key = "ChargeSoundId", Label = "Charge sound", Mode = "OneShot" },
	{ Key = "TravelSoundId", Label = "Travel loop", Mode = "Loop" },
	{ Key = "ImpactSoundId", Label = "Impact sound", Mode = "OneShot" },
	{ Key = "AmbientLoopSoundId", Label = "Active effect loop", Mode = "Loop" },
	{ Key = "EndSoundId", Label = "End sound", Mode = "OneShot" },
	{ Key = "BreakSoundId", Label = "Break sound", Mode = "OneShot" },
}

Spec.Defaults = {
	CastSoundId = "",
	ChargeSoundId = "",
	TravelSoundId = "",
	ImpactSoundId = "",
	AmbientLoopSoundId = "",
	EndSoundId = "",
	BreakSoundId = "",
	Volume = 0.6,
	RollOffMaxDistance = 80,
}

local allowed = { Volume = true, RollOffMaxDistance = true }
for _, cue in ipairs(Spec.Cues) do
	allowed[cue.Key] = true
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Spec.validate(audio)
	if type(audio) ~= "table" then
		return false, "Audio settings must be a table"
	end
	for key, value in pairs(audio) do
		if not allowed[key] then
			return false, "Unsupported audio setting"
		end
		if key == "Volume" then
			if not finite(value) or value < 0 or value > 1 then
				return false, "Audio volume must be between 0 and 1"
			end
		elseif key == "RollOffMaxDistance" then
			if not finite(value) or value < 10 or value > 250 then
				return false, "Audio distance must be between 10 and 250 studs"
			end
		elseif type(value) ~= "string" or #value > 20 or (value ~= "" and not string.match(value, "^%d+$")) then
			return false, "Sound IDs must be blank or numeric Roblox asset IDs"
		end
	end
	return true, nil
end

return Spec
