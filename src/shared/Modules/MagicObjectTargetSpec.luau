--!strict

-- Pure allowlist checks shared by server ObjectTarget acquisition and revalidation.
local Spec = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Spec.isValidInteractionTarget(target, hasPhysics, hasManipulation)
	if
		type(target) ~= "table"
		or target.InWorkspace ~= true
		or target.CanCollide ~= true
		or target.HasHumanoidAncestor == true
		or target.Tagged ~= true
		or (hasPhysics ~= true and hasManipulation ~= true)
	then
		return false
	end
	if hasPhysics then
		if target.Anchored == true or not finite(target.AssemblyMass) or target.AssemblyMass <= 0 then
			return false
		end
	end
	if hasManipulation then
		return target.MaterialMatches == true and target.RaiseAuthorized == true
	end
	return true
end

function Spec.isSolidWorldSurfaceTarget(target)
	return type(target) == "table"
		and target.InWorkspace == true
		and target.CanCollide == true
		and target.HasHumanoidAncestor ~= true
end

function Spec.isValidManipulationTarget(target, hasOperation, hasPhysics)
	if
		type(target) ~= "table"
		or target.InWorkspace ~= true
		or target.HasHumanoidAncestor == true
		or target.Tagged ~= true
		or (hasOperation ~= true and hasPhysics ~= true)
	then
		return false
	end
	if hasOperation and (target.MaterialMatches ~= true or target.RaiseAuthorized ~= true) then
		return false
	end
	if hasPhysics then
		return target.CanCollide == true
			and target.Anchored ~= true
			and finite(target.AssemblyMass)
			and target.AssemblyMass > 0
	end
	return true
end

return Spec
