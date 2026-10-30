--!strict
-- Pure per-character rules for Transformation modes Polymorph and Shapeshift
-- (Scale stays in MagicTransformationSpec).
--   Polymorph (others): a harmless critter for a few seconds; it can move but
--     not melee or cast; it may break when someone other than the caster
--     damages it. Bosses (MagicBoss, or a DefendTheWalls Elite) are immune.
--   Shapeshift (self): melee uses another MeleeProfiles profile.
-- At most one of each per character; a new one replaces the old. A Polymorph
-- pauses a running Shapeshift (its remaining time is frozen) and the
-- Shapeshift resumes when the Polymorph ends.
local Spec = {}

export type Entry = {
	SpellId: string,
	Caster: any?,
	ExpiresAt: number?, -- nil while a Shapeshift is paused
	Paused: number?, -- remaining seconds of a paused Shapeshift
	BreakOnDamage: boolean?,
	Profile: string?,
}

export type State = { Polymorph: Entry?, Shapeshift: Entry? }

function Spec.new(): State
	return { Polymorph = nil, Shapeshift = nil }
end

-- Bosses never turn into critters.
function Spec.isBoss(magicBoss: any, missionRole: any): boolean
	return magicBoss == true or missionRole == "Elite"
end

local function pause(entry: Entry?, now: number)
	if entry and entry.ExpiresAt then
		entry.Paused = math.max(0, entry.ExpiresAt - now)
		entry.ExpiresAt = nil
	end
end

local function resume(entry: Entry?, now: number)
	if entry and entry.Paused then
		entry.ExpiresAt = now + entry.Paused
		entry.Paused = nil
	end
end

-- Starts a Polymorph; returns the Polymorph it replaced, if any.
function Spec.polymorph(state: State, now: number, entry: Entry, duration: number): Entry?
	local previous = state.Polymorph
	entry.ExpiresAt = now + duration
	state.Polymorph = entry
	pause(state.Shapeshift, now)
	return previous
end

-- Starts a Shapeshift (paused if a Polymorph is running); returns the one it replaced.
function Spec.shapeshift(state: State, now: number, entry: Entry, duration: number): Entry?
	local previous = state.Shapeshift
	entry.ExpiresAt = now + duration
	state.Shapeshift = entry
	if state.Polymorph then
		pause(entry, now)
	end
	return previous
end

-- Ends the Polymorph (break, Cleanse, expiry) and resumes a paused Shapeshift.
function Spec.endPolymorph(state: State, now: number): Entry?
	local ended = state.Polymorph
	state.Polymorph = nil
	if ended then
		resume(state.Shapeshift, now)
	end
	return ended
end

function Spec.endShapeshift(state: State): Entry?
	local ended = state.Shapeshift
	state.Shapeshift = nil
	return ended
end

-- Ends whatever has run out. Returns { { Mode, Entry } } in end order.
function Spec.tick(state: State, now: number): { any }
	local ended = {}
	if state.Polymorph and state.Polymorph.ExpiresAt and now >= state.Polymorph.ExpiresAt then
		table.insert(ended, { Mode = "Polymorph", Entry = Spec.endPolymorph(state, now) })
	end
	if state.Shapeshift and state.Shapeshift.ExpiresAt and now >= state.Shapeshift.ExpiresAt then
		table.insert(ended, { Mode = "Shapeshift", Entry = Spec.endShapeshift(state) })
	end
	return ended
end

-- Whether damage from `attacker` breaks the Polymorph.
function Spec.breaksOnDamage(state: State, attacker: any): boolean
	local polymorph = state.Polymorph
	return polymorph ~= nil and polymorph.BreakOnDamage == true and attacker ~= polymorph.Caster
end

-- Action gating while polymorphed: no melee ("Attack") and no casting ("Cast");
-- moving and dashing ("Move") stay allowed.
function Spec.blocks(state: State, category: string): boolean
	return state.Polymorph ~= nil and (category == "Attack" or category == "Cast")
end

-- The melee profile while shapeshifted (nil: use the equipped weapon).
function Spec.meleeProfile(state: State): string?
	return state.Shapeshift and state.Shapeshift.Profile or nil
end

function Spec.speedMultiplier(state: State, polymorphSpeed: number): number
	return if state.Polymorph then polymorphSpeed else 1
end

-- Polymorph duration: authored within [min, max], then the PvP cap on players.
function Spec.polymorphDuration(authored: number, minimum: number, maximum: number, pvpCap: number?): number
	local duration = math.clamp(if authored == authored then authored else minimum, minimum, maximum)
	if type(pvpCap) == "number" then
		duration = math.min(duration, pvpCap)
	end
	return duration
end

return Spec
