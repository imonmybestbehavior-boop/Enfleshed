-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicTransformStateSpec.luau"))()
local CrowdControl = assert(loadfile("src/shared/Modules/MagicCrowdControlSpec.luau"))()

local caster, other = {}, {}

-- Bosses.
assert(Spec.isBoss(true, nil) and Spec.isBoss(nil, "Elite"), "MagicBoss or a DefendTheWalls Elite")
assert(not Spec.isBoss(nil, "Brute") and not Spec.isBoss(false, nil))

-- Polymorph: gating, speed, break on damage (not by the caster).
local state = Spec.new()
assert(not Spec.blocks(state, "Attack"))
Spec.polymorph(state, 0, { SpellId = "p", Caster = caster, BreakOnDamage = true }, 4)
assert(Spec.blocks(state, "Attack") and Spec.blocks(state, "Cast") and not Spec.blocks(state, "Move"))
assert(Spec.speedMultiplier(state, 0.7) == 0.7)
assert(not Spec.breaksOnDamage(state, caster), "the caster's damage never breaks it")
assert(Spec.breaksOnDamage(state, other), "anyone else's damage breaks it")
local ended = Spec.endPolymorph(state, 1)
assert(ended and ended.SpellId == "p" and not Spec.blocks(state, "Attack") and Spec.speedMultiplier(state, 0.7) == 1)
Spec.polymorph(state, 0, { SpellId = "q", Caster = caster, BreakOnDamage = false }, 4)
assert(not Spec.breaksOnDamage(state, other), "BreakOnDamage off")

-- One per mode: a new one replaces the old.
state = Spec.new()
Spec.polymorph(state, 0, { SpellId = "a", Caster = caster }, 4)
local replaced = Spec.polymorph(state, 1, { SpellId = "b", Caster = caster }, 4)
assert(replaced and replaced.SpellId == "a" and state.Polymorph.SpellId == "b")

-- Shapeshift: profile, expiry.
state = Spec.new()
Spec.shapeshift(state, 0, { SpellId = "s", Profile = "Claws" }, 10)
assert(Spec.meleeProfile(state) == "Claws")
assert(#Spec.tick(state, 5) == 0)
local done = Spec.tick(state, 10)
assert(#done == 1 and done[1].Mode == "Shapeshift" and Spec.meleeProfile(state) == nil, "restored on expiry")

-- Polymorph during Shapeshift: paused, then resumed with its remaining time.
state = Spec.new()
Spec.shapeshift(state, 0, { SpellId = "s", Profile = "Claws" }, 10)
Spec.polymorph(state, 4, { SpellId = "p", Caster = other }, 3)
assert(state.Shapeshift.ExpiresAt == nil and state.Shapeshift.Paused == 6, "6 s frozen")
assert(#Spec.tick(state, 20) == 1 and state.Shapeshift ~= nil, "only the polymorph ends while paused")
assert(state.Shapeshift.ExpiresAt == 26, "resumes with 6 s left")
-- A Shapeshift started while polymorphed starts paused.
state = Spec.new()
Spec.polymorph(state, 0, { SpellId = "p", Caster = other }, 2)
Spec.shapeshift(state, 1, { SpellId = "s", Profile = "Claws" }, 10)
assert(state.Shapeshift.Paused == 10)
Spec.endPolymorph(state, 3)
assert(state.Shapeshift.ExpiresAt == 13)

-- Durations: range, PvP cap, and Stun's diminishing returns shared with Polymorph.
assert(Spec.polymorphDuration(12, 1, 8, nil) == 8 and Spec.polymorphDuration(0.2, 1, 8, nil) == 1)
assert(Spec.polymorphDuration(6, 1, 8, 1.5) == 1.5, "PvP cap")
local history = CrowdControl.newHistory()
assert(CrowdControl.applyStun(history, 0, 2) == 2, "a stun")
assert(CrowdControl.applyStun(history, 1, Spec.polymorphDuration(6, 1, 8, nil)) == 3, "then a halved polymorph")
print(
	"Magic transform state spec: bosses, polymorph gating/break, replacement, shapeshift pause/resume and durations passed"
)
