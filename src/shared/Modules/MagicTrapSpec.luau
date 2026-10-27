--!strict
-- Pure rules for Field trap options:
--   ArmDelay: entry/exit/pulse effects wait until the Field is armed; anyone
--     inside when it arms counts as entering then. OnCast/OnSpawn do not wait.
--   ConsumeOnTrigger: the first entry with a target runs, then the Field ends.
--   Hidden: no marker is replicated; only players who cannot fight the caster
--     (the caster, allies, anyone outside PvP) are sent a local marker.
local Spec = {}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Arm delay in use: authored (0 by default) and, for a Hidden trap cast while
-- the caster can fight players, at least the PvP minimum of their zone.
function Spec.armDelay(authored: number?, hidden: boolean?, pvpMinimum: number?): number
	local delay = if finite(authored) then math.max(0, authored :: number) else 0
	if hidden and finite(pvpMinimum) then
		delay = math.max(delay, pvpMinimum :: number)
	end
	return delay
end

function Spec.armed(age: number, armDelay: number): boolean
	return age >= armDelay
end

-- Whether this pulse's entries end the Field (ConsumeOnTrigger).
function Spec.consumes(consumeOnTrigger: boolean?, enteredCount: number): boolean
	return consumeOnTrigger == true and enteredCount > 0
end

-- Whether a viewer is sent a Hidden trap's marker.
function Spec.canSee(viewerUserId: number, ownerUserId: number?, viewerCanFightOwner: boolean): boolean
	return viewerUserId == ownerUserId or not viewerCanFightOwner
end

-- Marker messages needed to move from `current` (viewer -> true) to the
-- `desired` viewer list. Returns (show, hide).
function Spec.diffViewers(current: { [any]: boolean }, desired: { any }): ({ any }, { any })
	local wanted = {}
	local show, hide = {}, {}
	for _, viewer in desired do
		wanted[viewer] = true
		if not current[viewer] then
			table.insert(show, viewer)
		end
	end
	for viewer in current do
		if not wanted[viewer] then
			table.insert(hide, viewer)
		end
	end
	return show, hide
end

return Spec
