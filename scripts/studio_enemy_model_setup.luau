-- Studio Command Bar (Edit mode, not Play): builds/finishes and checks the Enfleshed enemy models.
-- Works with either import route:
--   * 3D Importer: imported Models moved into ServerStorage.EnfleshedModels, or
--   * Asset Manager: the uploaded meshes (named Basic_Torso, Basic_LeftArm, ... Elite_RightLeg)
--     inserted anywhere into Workspace. They are gathered into one Model per enemy.
-- Safe to run repeatedly. It only renames/configures parts and adds SurfaceAppearances; it never
-- deletes anything. Paste the printed report back to Claude if anything is flagged.
--
-- Textures: upload the compact images from ~/Projects/Enfleshed_EnemyModels/RobloxImportCompact
-- (<Kind>_Albedo_1024.jpg, _Normal_1024.jpg, _Roughness_1024.jpg, _Metalness_1024.png) and paste the image IDs below.
-- Do NOT use the GLB's combined "Metalness-Roughness" image; SurfaceAppearance needs separate maps.
-- Leave a kind as nil to skip it. Do not guess IDs.
local TEXTURES = {
	Basic = { ColorMap = nil, NormalMap = nil, RoughnessMap = nil, MetalnessMap = nil },
	Swift = { ColorMap = nil, NormalMap = nil, RoughnessMap = nil, MetalnessMap = nil },
	Brute = { ColorMap = nil, NormalMap = nil, RoughnessMap = nil, MetalnessMap = nil },
	Elite = { ColorMap = nil, NormalMap = nil, RoughnessMap = nil, MetalnessMap = nil },
}

local ServerStorage = game:GetService("ServerStorage")
local Layouts = require(game:GetService("ReplicatedStorage").Shared.Configuration.EnemyVisuals)
local PART_NAMES = { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local report, problems = {}, 0
local function say(line)
	table.insert(report, line)
end
local function flag(line)
	problems += 1
	table.insert(report, "  !! " .. line)
end
local function key(name)
	return string.lower((string.gsub(name, "[%s_%-]", "")))
end

local folder = ServerStorage:FindFirstChild("EnfleshedModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "EnfleshedModels"
	folder.Parent = ServerStorage
	say("Created ServerStorage.EnfleshedModels. Move the four imported models into it and run again.")
end

-- Gather loose meshes inserted from Asset Manager (names like "Basic_LeftArm").
local KINDS = { "Basic", "Swift", "Brute", "Elite" }
local loose = {}
for _, root in ipairs({ workspace, ServerStorage }) do
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("MeshPart") and not descendant:IsDescendantOf(folder) then
			table.insert(loose, descendant)
		end
	end
end
for _, kind in ipairs(KINDS) do
	for _, name in ipairs(PART_NAMES) do
		local wanted = key(kind) .. key(name)
		for _, mesh in ipairs(loose) do
			local k = key(mesh.Name)
			if mesh.Parent and (k == wanted or string.sub(k, -#wanted) == wanted) then
				local model = folder:FindFirstChild(kind)
				if not model then
					model = Instance.new("Model")
					model.Name = kind
					model.Parent = folder
				end
				if not model:FindFirstChild(name) then
					mesh.Name = name
					mesh.Parent = model
					say(kind .. ": gathered loose mesh into '" .. name .. "'")
				end
				break
			end
		end
	end
end

for _, kind in ipairs(KINDS) do
	local model = folder:FindFirstChild(kind)
	if not model then
		-- Accept the importer's default name (e.g. "Enfleshed_Basic") and rename it.
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and string.find(string.lower(child.Name), string.lower(kind), 1, true) then
				child.Name = kind
				model = child
				say(kind .. ": renamed model from importer name")
				break
			end
		end
	end
	if not model or not model:IsA("Model") then
		flag(
			kind
				.. ": no Model and no loose "
				.. kind
				.. "_Torso/... meshes found. Insert its six meshes from Asset Manager into Workspace and run again."
		)
		continue
	end
	local layout = Layouts[kind]
	local meshes = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("MeshPart") then
			table.insert(meshes, descendant)
		end
	end
	local textured = 0
	for _, name in ipairs(PART_NAMES) do
		local mesh = model:FindFirstChild(name, true)
		if not (mesh and mesh:IsA("MeshPart")) then
			-- The importer may write "Left_Arm", "LeftArm", "left arm"...
			for _, candidate in ipairs(meshes) do
				if key(candidate.Name) == key(name) then
					candidate.Name = name
					mesh = candidate
					say(kind .. ": renamed MeshPart to '" .. name .. "'")
					break
				end
			end
		end
		if not (mesh and mesh:IsA("MeshPart")) then
			flag(kind .. ": missing MeshPart '" .. name .. "'")
			continue
		end
		mesh.Anchored = true
		mesh.CanCollide, mesh.CanTouch, mesh.CanQuery = false, false, false
		mesh.CollisionFidelity = Enum.CollisionFidelity.Box
		mesh.CastShadow = true
		-- Orientation check: the runtime places meshes unrotated at the layout size, so the
		-- mesh's own axes must match the layout's. Uniform scale is fine; swapped axes are not.
		local target = layout and layout.Parts[name] and layout.Parts[name].Size
		if target then
			local native = mesh.MeshSize
			local rx, ry, rz = native.X / target.X, native.Y / target.Y, native.Z / target.Z
			local spread = math.max(rx, ry, rz) / math.max(1e-6, math.min(rx, ry, rz))
			if spread > 1.25 then
				flag(
					string.format(
						"%s.%s looks rotated on import (native %.2f x %.2f x %.2f vs layout %.2f x %.2f x %.2f). Re-import and fix the importer's orientation so the face points -Z and up is +Y.",
						kind,
						name,
						native.X,
						native.Y,
						native.Z,
						target.X,
						target.Y,
						target.Z
					)
				)
			end
		end
		local ids = TEXTURES[kind]
		local surface = mesh:FindFirstChildOfClass("SurfaceAppearance")
		if ids and ids.ColorMap then
			surface = surface or Instance.new("SurfaceAppearance")
			for property, id in pairs(ids) do
				surface[property] = "rbxassetid://" .. tostring(id)
			end
			surface.Parent = mesh
		end
		if surface or mesh.TextureID ~= "" then
			textured += 1
		end
	end
	if textured < #PART_NAMES then
		flag(
			string.format(
				"%s: %d/6 parts have textures. Fill TEXTURES.%s above with uploaded image IDs and run again.",
				kind,
				textured,
				kind
			)
		)
	end
	for _, child in model:GetDescendants() do
		if child:IsA("Humanoid") or child:IsA("AnimationController") or child:IsA("Bone") then
			say(
				kind
					.. ": note - importer added "
					.. child.ClassName
					.. " '"
					.. child.Name
					.. "' (unused; safe to delete)"
			)
		end
	end
	say(string.format("%s: %d MeshParts found, %d textured", kind, #meshes, textured))
end

say(
	if problems == 0
		then "READY: start Defend the Walls; enemy Models should show attribute ImportedVisual = true."
		else problems .. " problem(s) flagged above."
)
print("[EnfleshedModels]\n" .. table.concat(report, "\n"))
