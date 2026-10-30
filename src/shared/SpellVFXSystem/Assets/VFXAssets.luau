-- Client asset resolver for the generated VFX library: manifest lookup, fallbacks and pooling.
--
-- Textures: the manifest Id when uploaded, otherwise the entry's built-in fallback texture
-- (flipbook layouts are dropped for fallbacks, which are single images).
-- Meshes, first match wins:
--   1. ReplicatedStorage.VFXAssets.Meshes.<name>  MeshPart imported in Studio (see docs)
--   2. manifest Id via AssetService:CreateMeshPartAsync (fetched once, then cloned)
--   3. a primitive Part of the entry's Fallback shape
-- Pooled parts are recycled per asset; nothing here owns gameplay state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Manifest = require(script.Parent.VFXAssetManifest)
local DirectionalSprites = require(script.Parent.DirectionalSpriteManifest)
local Styled = require(script.Parent.StyledVFXManifest)

local Assets = {}
-- Showcase toggle: false forces built-in fallbacks so custom and fallback looks can be compared.
Assets.UseCustom = true

function Assets.directionalSprite(name)
	return if Assets.UseCustom then DirectionalSprites[name] else nil
end

local BUILTIN = {
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}
local LAYOUT = {
	Grid2x2 = Enum.ParticleFlipbookLayout.Grid2x2,
	Grid4x4 = Enum.ParticleFlipbookLayout.Grid4x4,
	Grid8x8 = Enum.ParticleFlipbookLayout.Grid8x8,
}
local POOL_LIMIT = 24

local templates: { [string]: BasePart } = {}
local fetching: { [string]: boolean } = {}
local pools: { [string]: { BasePart } } = {}

-- Returns texture content, flipbook layout (or None) and whether the custom asset is in use.
function Assets.texture(name: string?, identity: string?): (string, Enum.ParticleFlipbookLayout, boolean, boolean?)
	local entry = name and Manifest.Textures[name]
	if not entry then
		return BUILTIN.Sparkle, Enum.ParticleFlipbookLayout.None, false
	end
	if Assets.UseCustom then
		local baked = if Styled.Enabled and identity and name then Styled.Textures[identity .. "/" .. name] else nil
		if baked then
			return baked, LAYOUT[entry.Flipbook or ""] or Enum.ParticleFlipbookLayout.None, true, true
		end
		if entry.Id then
			return entry.Id, LAYOUT[entry.Flipbook or ""] or Enum.ParticleFlipbookLayout.None, true
		end
	end
	return BUILTIN[entry.Fallback] or BUILTIN.Sparkle, Enum.ParticleFlipbookLayout.None, false
end

function Assets.hasCustomTexture(name: string?): boolean
	local entry = name and Manifest.Textures[name]
	return Assets.UseCustom and entry ~= nil and entry.Id ~= nil
end

function Assets.hasCustomMesh(name: string?): boolean
	return Assets.UseCustom and name ~= nil and templates[name] ~= nil
end

-- Native (authored) mesh size in studs, used to scale meshes and their fallbacks alike.
function Assets.meshSize(name: string): Vector3
	local entry = Manifest.Meshes[name]
	return if entry then entry.Size else Vector3.one
end

local function importedTemplate(name: string): BasePart?
	local folder = ReplicatedStorage:FindFirstChild("VFXAssets")
	local meshes = folder and folder:FindFirstChild("Meshes")
	local styled = script.Parent:FindFirstChild("CelMeshLibrary") or (folder and folder:FindFirstChild("CelMeshes"))
	local revised = Styled.Enabled and styled and styled:FindFirstChild(name)
	if revised and revised:IsA("MeshPart") then
		revised:SetAttribute("VFXBakedColors", true)
		return revised
	end
	local found = meshes and meshes:FindFirstChild(name)
	return if found and found:IsA("MeshPart") then found else nil
end

-- Resolve imported templates and start (non-blocking) fetches for uploaded mesh ids.
function Assets.prefetch()
	for name, entry in pairs(Manifest.Meshes) do
		if not templates[name] then
			local imported = importedTemplate(name)
			if imported then
				templates[name] = imported
			elseif entry.Id and not fetching[name] then
				fetching[name] = true
				task.spawn(function()
					local ok, result = pcall(function()
						return game:GetService("AssetService"):CreateMeshPartAsync(entry.Id, {
							CollisionFidelity = Enum.CollisionFidelity.Box,
							RenderFidelity = Enum.RenderFidelity.Automatic,
						})
					end)
					if ok and result then
						-- Templates are never parented; clones are anchored, non-colliding and pooled.
						result.Anchored = true
						result.CanCollide, result.CanTouch, result.CanQuery = false, false, false
						templates[name] = result
					else
						warn("[SpellVFX] mesh " .. name .. " unavailable, using fallback shape: " .. tostring(result))
					end
				end)
			end
		end
	end
	local ids = {}
	for _, entry in pairs(Manifest.Textures) do
		if entry.Id then
			table.insert(ids, entry.Id)
		end
	end
	if #ids > 0 then
		task.spawn(function()
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync(ids)
			end)
		end)
	end
end

local function decorate(part: BasePart)
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.Massless = true
	part.Locked = true
end

local function fallbackPart(name: string): BasePart
	local entry = Manifest.Meshes[name]
	local shape = if entry then entry.Fallback else "Ball"
	local part: BasePart
	if shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local p = Instance.new("Part")
		p.Shape = if shape == "Ball"
			then Enum.PartType.Ball
			elseif shape == "Cylinder" then Enum.PartType.Cylinder
			else Enum.PartType.Block
		part = p
	end
	return part
end

-- Acquire a pooled mesh (or its fallback). Returns the part and whether it is the custom mesh.
function Assets.acquireMesh(name: string): (BasePart, boolean)
	local custom = Assets.hasCustomMesh(name)
	local key = name .. (if custom then "#c" else "#f")
	local pool = pools[key]
	local part = pool and table.remove(pool)
	if not part then
		part = if custom then templates[name]:Clone() else fallbackPart(name)
		part.Name = "VFX_" .. name
		part:SetAttribute("VFXPoolKey", key)
		decorate(part)
	end
	return part, custom
end

-- Fallback cylinders run along X; generated ring meshes lie in XZ with Y thickness.
function Assets.place(part: BasePart, frame: CFrame, size: Vector3)
	if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
		part.Size = Vector3.new(math.max(size.Y, 0.05), size.X, size.Z)
		part.CFrame = frame * CFrame.Angles(0, 0, math.pi / 2)
	else
		part.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
		part.CFrame = frame
	end
end

function Assets.releaseMesh(part: BasePart)
	local key = part:GetAttribute("VFXPoolKey")
	if type(key) ~= "string" then
		part:Destroy()
		return
	end
	pools[key] = pools[key] or {}
	local pool = pools[key]
	if #pool >= POOL_LIMIT then
		part:Destroy()
		return
	end
	for _, child in part:GetChildren() do
		child:Destroy()
	end
	part.Transparency = 1
	part.Parent = nil
	table.insert(pool, part)
end

return Assets
