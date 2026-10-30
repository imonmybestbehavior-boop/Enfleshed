-- Pure, deterministic cosmetic seed from canonical gameplay features.
-- Never reads spell names, SpellId, time, or math.random.
local Fingerprint = {}

local MOD = 4294967296 -- 2^32

-- Exact 32-bit multiply without exceeding double precision.
local function mul32(a, b)
	local aLow, aHigh = a % 65536, math.floor(a / 65536)
	return (aLow * b + ((aHigh * b) % 65536) * 65536) % MOD
end

local function mix(h)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x45D9F3B)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x45D9F3B)
	return bit32.bxor(h, bit32.rshift(h, 16))
end

function Fingerprint.hash(text)
	local h = 2166136261
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % MOD
	end
	return mix(h)
end

function Fingerprint.canonical(element, form, geometry, encodedFeatures)
	return table.concat(
		{ element or "Neutral", form or "Projectile", geometry or "Sphere", encodedFeatures or "" },
		"|"
	)
end

function Fingerprint.seed(element, form, geometry, encodedFeatures)
	return Fingerprint.hash(Fingerprint.canonical(element, form, geometry, encodedFeatures))
end

-- Stable value in [0, 1) for a named purpose ("phase", "tilt", ...).
function Fingerprint.unit(seed, salt)
	local h = mix(bit32.bxor(seed % MOD, Fingerprint.hash(salt or "")))
	return h / MOD
end

function Fingerprint.pick(seed, salt, options)
	if #options == 0 then
		return nil
	end
	return options[math.floor(Fingerprint.unit(seed, salt) * #options) + 1]
end

return Fingerprint
