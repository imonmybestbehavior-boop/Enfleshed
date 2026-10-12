-- Versioned, DataStore-safe records for static world-persistent Constructs.
local Spec = { Version = 1, MaxRecords = 128, MaxPerOwner = 8, MaxComponents = 5 }

local shapes = { Block = true, Ball = true, Cylinder = true, Wedge = true }
local materials = { Auto = true, Neon = true, ForceField = true, Glass = true, SmoothPlastic = true, Slate = true }
local particles = { Sparks = true, Smoke = true, Embers = true, None = true }

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function vector(values, minimum, maximum)
	if type(values) ~= "table" or #values ~= 3 then
		return false
	end
	for index = 1, 3 do
		if not finite(values[index]) or values[index] < minimum or values[index] > maximum then
			return false
		end
	end
	for key in pairs(values) do
		if type(key) ~= "number" or key < 1 or key > 3 or key % 1 ~= 0 then
			return false
		end
	end
	return true
end

local function onlyKeys(value, allowed)
	if type(value) ~= "table" then
		return false
	end
	for key in pairs(value) do
		if not allowed[key] then
			return false
		end
	end
	return true
end

function Spec.validateRecord(record)
	if
		not onlyKeys(record, {
			Id = true,
			OwnerUserId = true,
			CreatedAt = true,
			Position = true,
			RotationDegrees = true,
			Components = true,
			Visual = true,
		})
		or type(record.Id) ~= "string"
		or #record.Id < 8
		or #record.Id > 64
		or not finite(record.OwnerUserId)
		or record.OwnerUserId < 0
		or record.OwnerUserId % 1 ~= 0
		or not finite(record.CreatedAt)
		or record.CreatedAt < 0
		or record.CreatedAt % 1 ~= 0
		or not vector(record.Position, -1000000, 1000000)
		or not vector(record.RotationDegrees, -180, 180)
	then
		return false, "Persistent Construct identity or transform is invalid"
	end
	local components = record.Components
	if type(components) ~= "table" or #components < 1 or #components > Spec.MaxComponents then
		return false, "Persistent Construct component count is invalid"
	end
	local componentKeys = 0
	for key in pairs(components) do
		if type(key) ~= "number" or key < 1 or key > Spec.MaxComponents or key % 1 ~= 0 then
			return false, "Persistent Construct component list is malformed"
		end
		componentKeys = componentKeys + 1
	end
	if componentKeys ~= #components then
		return false, "Persistent Construct component list is sparse"
	end
	for _, component in ipairs(components) do
		if
			not onlyKeys(component, { Shape = true, Size = true, Offset = true, RotationDegrees = true })
			or not shapes[component.Shape]
			or not vector(component.Size, 0.05, 20)
			or not vector(component.Offset, -10, 10)
			or not vector(component.RotationDegrees, -180, 180)
		then
			return false, "Persistent Construct component is invalid"
		end
	end
	local visual = record.Visual
	if
		not onlyKeys(visual, {
			Color = true,
			SecondaryColor = true,
			AccentColor = true,
			MaterialAppearance = true,
			Opacity = true,
			Emission = true,
			ParticleStyle = true,
		})
		or not vector(visual.Color, 0, 1)
		or (visual.SecondaryColor ~= nil and not vector(visual.SecondaryColor, 0, 1))
		or (visual.AccentColor ~= nil and not vector(visual.AccentColor, 0, 1))
		or not materials[visual.MaterialAppearance]
		or not finite(visual.Opacity)
		or visual.Opacity < 0.2
		or visual.Opacity > 1
		or not finite(visual.Emission)
		or visual.Emission < 0
		or visual.Emission > 1
		or not particles[visual.ParticleStyle]
	then
		return false, "Persistent Construct presentation is invalid"
	end
	return true
end

function Spec.emptyProfile()
	return { Version = Spec.Version, Records = {} }
end

function Spec.decode(raw)
	if raw == nil then
		return Spec.emptyProfile(), true
	end
	if not onlyKeys(raw, { Version = true, Records = true }) or raw.Version ~= Spec.Version then
		return Spec.emptyProfile(), false, "Persistent Construct profile version is invalid"
	end
	local records = raw.Records
	if type(records) ~= "table" or #records > Spec.MaxRecords then
		return Spec.emptyProfile(), false, "Persistent Construct profile exceeds its record limit"
	end
	local owners, ids = {}, {}
	local recordKeys = 0
	for key in pairs(records) do
		if type(key) ~= "number" or key < 1 or key > Spec.MaxRecords or key % 1 ~= 0 then
			return Spec.emptyProfile(), false, "Persistent Construct profile list is malformed"
		end
		recordKeys = recordKeys + 1
	end
	if recordKeys ~= #records then
		return Spec.emptyProfile(), false, "Persistent Construct profile list is sparse"
	end
	local copy = {}
	for index, record in ipairs(records) do
		local valid, reason = Spec.validateRecord(record)
		if not valid or ids[record.Id] then
			return Spec.emptyProfile(), false, reason or "Persistent Construct IDs must be unique"
		end
		ids[record.Id] = true
		owners[record.OwnerUserId] = (owners[record.OwnerUserId] or 0) + 1
		if owners[record.OwnerUserId] > Spec.MaxPerOwner then
			return Spec.emptyProfile(), false, "Persistent Construct owner limit is invalid"
		end
		local cloned = {}
		for key, value in pairs(record) do
			if type(value) == "table" then
				local sub = {}
				for subKey, subValue in pairs(value) do
					if type(subValue) == "table" then
						local nested = {}
						for nestedKey, nestedValue in pairs(subValue) do
							nested[nestedKey] = nestedValue
						end
						sub[subKey] = nested
					else
						sub[subKey] = subValue
					end
				end
				cloned[key] = sub
			else
				cloned[key] = value
			end
		end
		copy[index] = cloned
	end
	return { Version = Spec.Version, Records = copy }, true
end

return Spec
