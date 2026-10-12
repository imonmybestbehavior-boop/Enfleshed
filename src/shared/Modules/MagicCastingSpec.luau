-- Casting modes that currently have meaningful server runtime implementations.
local Spec = {}
Spec.ToggleForms = {
	Field = true,
	Aura = true,
	SelfEnhancement = true,
	Construct = true,
}
Spec.ChargeModes = { Charged = true, HoldAndRelease = true }
Spec.CommandForms = { Projectile = true, Beam = true, Wave = true, Field = true, Aura = true }
Spec.SustainedForms = { Construct = true }
Spec.ChanneledForms = {
	Projectile = true,
	Beam = true,
	Wave = true,
	Field = true,
	Aura = true,
	SelfEnhancement = true,
}

function Spec.supportsChannel(form)
	return Spec.ChanneledForms[form] == true
end

function Spec.supportsToggle(form)
	return Spec.ToggleForms[form] == true
end

function Spec.isChargeMode(mode)
	return Spec.ChargeModes[mode] == true
end

function Spec.supportsCommandCast(form)
	return Spec.CommandForms[form] == true
end

function Spec.supportsSustained(form)
	return Spec.SustainedForms[form] == true
end

function Spec.isHeldMode(mode)
	return mode == "Channeled" or mode == "Sustained"
end

function Spec.supportsAimUpdate(form, mode)
	return (form == "Beam" or form == "Projectile") and mode == "Channeled"
end

function Spec.movementMultiplier(casting)
	if casting.CanMoveWhileCasting == false then
		return 0
	end
	return 1 - (casting.MovementPenalty or 0)
end

function Spec.rotationLocked(casting)
	return casting.CanRotateWhileCasting == false
end

function Spec.hasFreeHand(casting, freeHandCount)
	return casting.RequiresFreeHand ~= true or (type(freeHandCount) == "number" and freeHandCount >= 1)
end

return Spec
