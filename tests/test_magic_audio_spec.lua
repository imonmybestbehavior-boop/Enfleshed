local spec = assert(loadfile("src/shared/Modules/MagicAudioSpec.luau", "t", _G))()

assert(spec.validate(spec.Defaults))
assert(spec.validate({ CastSoundId = "12345678901234567890", Volume = 0, RollOffMaxDistance = 250 }))
assert(not spec.validate({ CastSoundId = "https://www.roblox.com/asset/?id=123" }))
assert(not spec.validate({ TravelSoundId = "rbxassetid://123" }))
assert(not spec.validate({ CastSoundId = "123", Volume = 1.01 }))
assert(not spec.validate({ CastSoundId = "123", RollOffMaxDistance = 9 }))
assert(not spec.validate({ UnknownCue = "123" }))
assert(not spec.validate({ CastSoundId = "123", Volume = 0 / 0 }))

print("Magic audio spec tests passed")
