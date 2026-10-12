--!strict

-- Timed, composable projectile motion phases. Movement still resolves through
-- the server's ordinary swept hit-detection path.
local Limits = require(script.Parent.Parent.Configuration.MagicLab)
local Motion = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function supportedMode(mode)
	for _, candidate in ipairs(Limits.ProjectileMotionModes or { "Linear" }) do
		if candidate == mode then
			return true
		end
	end
	return false
end

function Motion.validate(phases, lifetime, baseRadius)
	if type(phases) ~= "table" then
		return false, "Projectile motion phases must be an array"
	end
	local count = 0
	local totalDuration = 0
	for key in pairs(phases) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > Limits.MaxProjectileMotionPhases then
			return false, "Projectile motion phase list is malformed or exceeds its size limit"
		end
		count = count + 1
	end
	if count ~= #phases then
		return false, "Projectile motion phases must be a dense array"
	end
	for index, phase in ipairs(phases) do
		if type(phase) ~= "table" then
			return false, "Projectile motion phase " .. index .. " must be a table"
		end
		for key in pairs(phase) do
			if
				key ~= "Mode"
				and key ~= "Duration"
				and key ~= "SpeedMultiplier"
				and key ~= "Acceleration"
				and key ~= "Gravity"
				and key ~= "ArcHeight"
				and key ~= "BezierSide"
				and key ~= "BezierHeight"
				and key ~= "OrbitRadius"
				and key ~= "OrbitAngularSpeed"
				and key ~= "ExpandMultiplier"
			then
				return false, "Unknown projectile motion phase setting: " .. tostring(key)
			end
		end
		local mode = phase.Mode or "Linear"
		if not supportedMode(mode) then
			return false, "Unsupported projectile motion mode"
		elseif mode == "Arcing" then
			if
				not finite(phase.ArcHeight)
				or phase.ArcHeight < 0.1
				or phase.ArcHeight > Limits.MaxProjectileArcHeight
			then
				return false, "Projectile arc height exceeds its safety limit"
			end
		elseif mode == "Bezier" then
			if
				not finite(phase.BezierSide or 0)
				or math.abs(phase.BezierSide or 0) > Limits.MaxProjectileBezierOffset
				or not finite(phase.BezierHeight or 0)
				or math.abs(phase.BezierHeight or 0) > Limits.MaxProjectileBezierOffset
				or math.abs(phase.BezierSide or 0) + math.abs(phase.BezierHeight or 0) < 0.1
			then
				return false, "Bezier phases need a visible, bounded side or height offset"
			elseif (phase.Acceleration or 0) ~= 0 or (phase.Gravity or 0) ~= 0 then
				return false, "Bezier phases cannot also apply acceleration or gravity"
			end
		elseif mode == "Falling" then
			if not finite(phase.Gravity) or phase.Gravity < 1 or phase.Gravity > Limits.MaxGravity then
				return false, "Falling projectile phases need bounded positive gravity"
			end
		elseif mode == "Orbiting" then
			if
				not finite(phase.OrbitRadius)
				or phase.OrbitRadius < 0.5
				or phase.OrbitRadius > Limits.MaxProjectileOrbitRadius
				or not finite(phase.OrbitAngularSpeed)
				or math.abs(phase.OrbitAngularSpeed) < 0.1
				or math.abs(phase.OrbitAngularSpeed) > Limits.MaxProjectileOrbitSpeed
			then
				return false, "Orbit radius or angular speed exceeds its safety limit"
			end
		elseif mode == "Expanding" then
			if
				not finite(phase.ExpandMultiplier)
				or phase.ExpandMultiplier < 1.1
				or phase.ExpandMultiplier > Limits.MaxProjectileExpansion
			then
				return false, "Projectile expansion exceeds its safety limit"
			elseif
				(baseRadius or 1) * (phase.ExpandMultiplier - 1) / phase.Duration
				> Limits.MaxProjectileExpansionSpeed
			then
				return false, "Projectile collision growth is too fast for reliable swept hit detection"
			end
		end
		if not finite(phase.Duration) or phase.Duration < Limits.MinInterval or phase.Duration > Limits.MaxDuration then
			return false, "Projectile motion phase duration is outside its safety limit"
		end
		if
			phase.SpeedMultiplier ~= nil
			and (not finite(phase.SpeedMultiplier) or phase.SpeedMultiplier < 0.1 or phase.SpeedMultiplier > 3)
		then
			return false, "Projectile phase speed multiplier must be 0.1–3"
		end
		if
			phase.Acceleration ~= nil
			and (not finite(phase.Acceleration) or math.abs(phase.Acceleration) > Limits.MaxAcceleration)
		then
			return false, "Projectile phase acceleration exceeds its safety limit"
		end
		if
			phase.Gravity ~= nil
			and (not finite(phase.Gravity) or phase.Gravity < 0 or phase.Gravity > Limits.MaxGravity)
		then
			return false, "Projectile phase gravity exceeds its safety limit"
		end
		totalDuration = totalDuration + phase.Duration
	end
	if totalDuration > lifetime then
		return false, "Projectile motion phases outlast the projectile lifetime"
	end
	return true
end

function Motion.advance(phases, index, elapsed, delta)
	if #phases == 0 then
		return nil, 0, nil
	end
	index = math.max(1, math.min(index or 1, #phases))
	elapsed = (elapsed or 0) + math.max(delta, 0)
	while index < #phases and elapsed >= phases[index].Duration do
		elapsed = elapsed - phases[index].Duration
		index = index + 1
	end
	return index, elapsed, phases[index]
end

function Motion.initialSpeed(projectileSpeed, phases)
	local first = phases and phases[1]
	return projectileSpeed * (first and first.SpeedMultiplier or 1)
end

function Motion.arcOffset(height, duration, elapsed)
	local alpha = math.max(0, math.min(elapsed / duration, 1))
	return 4 * height * alpha * (1 - alpha)
end

function Motion.expansion(multiplier, duration, elapsed)
	local alpha = math.max(0, math.min(elapsed / duration, 1))
	return 1 + (multiplier - 1) * alpha
end

function Motion.bezierPosition(origin, direction, sideAxis, distance, sideOffset, heightOffset, alpha)
	local t = math.max(0, math.min(alpha, 1))
	local inverse = 1 - t
	local p0 = origin
	local p1 = origin + direction * (distance / 3) + sideAxis * sideOffset + Vector3.yAxis * heightOffset
	local p2 = origin + direction * (distance * 2 / 3) + sideAxis * sideOffset + Vector3.yAxis * heightOffset
	local p3 = origin + direction * distance
	return p0 * (inverse ^ 3) + p1 * (3 * inverse ^ 2 * t) + p2 * (3 * inverse * t ^ 2) + p3 * (t ^ 3)
end

function Motion.bezierTangent(direction, sideAxis, distance, sideOffset, heightOffset, alpha)
	local t = math.max(0, math.min(alpha, 1))
	local inverse = 1 - t
	local control = sideAxis * sideOffset + Vector3.yAxis * heightOffset
	local p0 = Vector3.zero
	local p1 = direction * (distance / 3) + control
	local p2 = direction * (distance * 2 / 3) + control
	local p3 = direction * distance
	return (p1 - p0) * (3 * inverse ^ 2) + (p2 - p1) * (6 * inverse * t) + (p3 - p2) * (3 * t ^ 2)
end

return Motion
