-- Offline-generated from export_manifest.json. Run only inside an existing Studio session.
-- Preflight completes before any scene changes. Import hierarchy and transforms are preserved.
local root = workspace:FindFirstChild("StorefrontStreetPilot")
assert(root and root:IsA("Model"), "StorefrontStreetPilot must contain both imports")
local expected = {
["VIS_StreetSurface"] = true,
["VIS_Shop01_Hearth"] = true,
["VIS_Shop02_Rations"] = true,
["VIS_Shop03_Repair"] = true,
["VIS_Shop04_Dispensary"] = true,
["VIS_Shop05_Cloth"] = true,
["VIS_Shop06_Court17"] = true,
["VIS_UpperBuildingsAndProps"] = true,
["VIS_OppositeStreet"] = true,
["VIS_Checkpoint"] = true,
["VIS_SecretRoute"] = true,
["COL_StreetFloor"] = true,
["COL_CourtyardFloor"] = true,
["COL_CatwalkFloor"] = true,
["COL_CourtyardLanding"] = true,
["COL_Shop01_Floor"] = true,
["COL_Shop01_LeftPier"] = true,
["COL_Shop01_RightPier"] = true,
["COL_Shop01_Ceiling"] = true,
["COL_Shop01_BackWall"] = true,
["COL_Shop02_Floor"] = true,
["COL_Shop02_LeftPier"] = true,
["COL_Shop02_RightPier"] = true,
["COL_Shop02_Ceiling"] = true,
["COL_Shop02_BackWall"] = true,
["COL_Shop03_Floor"] = true,
["COL_Shop03_LeftPier"] = true,
["COL_Shop03_RightPier"] = true,
["COL_Shop03_Ceiling"] = true,
["COL_Shop03_BackWall"] = true,
["COL_Shop04_Floor"] = true,
["COL_Shop04_LeftPier"] = true,
["COL_Shop04_RightPier"] = true,
["COL_Shop04_Ceiling"] = true,
["COL_Shop04_BackWall"] = true,
["COL_Shop05_Floor"] = true,
["COL_Shop05_LeftPier"] = true,
["COL_Shop05_RightPier"] = true,
["COL_Shop05_Ceiling"] = true,
["COL_Shop05_BackWall"] = true,
["COL_Shop06_Floor"] = true,
["COL_Shop06_LeftPier"] = true,
["COL_Shop06_RightPier"] = true,
["COL_Shop06_Ceiling"] = true,
["COL_Court17_BackLeft"] = true,
["COL_Court17_BackRight"] = true,
["COL_Court17_BackLintel"] = true,
["COL_NorthUpperMass01"] = true,
["COL_NorthUpperMass02"] = true,
["COL_NorthUpperMass03"] = true,
["COL_NorthUpperMass04"] = true,
["COL_NorthUpperMass05"] = true,
["COL_NorthUpperMass06"] = true,
["COL_OppositeWall"] = true,
["COL_CheckpointTowerWest"] = true,
["COL_CheckpointTowerEast"] = true,
["COL_CheckpointBarrierLeft"] = true,
["COL_CheckpointBarrierRight"] = true,
["COL_CourtEastWall"] = true,
["COL_CourtRearWall"] = true,
["COL_AlleyWestWall"] = true,
["COL_AlleyEastWall"] = true,
["COL_CourtStairRamp"] = true,
["COL_AlleyStairRamp"] = true,
}
local groups, parts = {}, {}
local function classify(p)
    local a = p
    while a and a ~= root do
        if expected[a.Name] then return a.Name end
        for name in pairs(expected) do
            if a.Name:sub(1, #name + 1) == name .. "_" then return name end
        end
        a = a.Parent
    end
end
for _, p in ipairs(root:GetDescendants()) do
    if p:IsA("BasePart") then
        local name = classify(p)
        if name then
            groups[name] = groups[name] or {}
            table.insert(groups[name], p)
            table.insert(parts, {part=p, name=name})
        end
    end
end
for name in pairs(expected) do
    assert(groups[name], "Missing imported source group: " .. name)
    if name:sub(1,4) == "COL_" then
        assert(#groups[name] == 1, "Duplicate/split collider requires inspection: " .. name)
    end
end
local street = groups.COL_StreetFloor[1]
local dims = {street.Size.X, street.Size.Y, street.Size.Z}
table.sort(dims)
assert(dims[2] >= 22 and dims[2] <= 28, "Street scale is incorrect; no changes made")
local function bounds(prefix)
    local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge,-math.huge,-math.huge)
    for _, entry in ipairs(parts) do
        if entry.name:sub(1,4) == prefix then
            local p = entry.part
            for _, x in ipairs({-1,1}) do for _, y in ipairs({-1,1}) do for _, z in ipairs({-1,1}) do
                local v = p.CFrame:PointToWorldSpace(p.Size * Vector3.new(x,y,z) / 2)
                lo = Vector3.new(math.min(lo.X,v.X), math.min(lo.Y,v.Y), math.min(lo.Z,v.Z))
                hi = Vector3.new(math.max(hi.X,v.X), math.max(hi.Y,v.Y), math.max(hi.Z,v.Z))
            end end end
        end
    end
    return lo, hi
end
local vlo,vhi = bounds("VIS_")
local clo,chi = bounds("COL_")
assert(( (vlo+vhi)/2 - (clo+chi)/2 ).Magnitude < 15, "Visual/collision alignment needs inspection; no changes made")
local size = vhi-vlo
assert(size.Y >= 35 and size.Y <= 50, "Visual height/orientation is incorrect; no changes made")
local flat = {size.X,size.Z}
table.sort(flat)
assert(flat[1] >= 60 and flat[1] <= 82 and flat[2] >= 100 and flat[2] <= 120,
    "Visual scale/orientation is incorrect; no changes made")

for _, entry in ipairs(parts) do
    local p = entry.part
    local collider = entry.name:sub(1,4) == "COL_"
    p.Anchored = true
    p.CanCollide = collider
    p.CanTouch = false
    p.CanQuery = true
    if collider then
        p.Transparency = 1
        p.CastShadow = false
        if p:IsA("MeshPart") then p.CollisionFidelity = Enum.CollisionFidelity.Box end
    end
end
-- Earlier helpers guessed these positions. Disable them until floor clearance is verified.
local spawn = root:FindFirstChild("PilotSpawn")
if spawn and spawn:IsA("SpawnLocation") then spawn.Enabled=false; spawn.CanCollide=false; spawn.Transparency=1 end
local markers = root:FindFirstChild("PilotMarkers")
if markers then for _, p in ipairs(markers:GetDescendants()) do
    if p:IsA("BasePart") then p.Transparency=1; p.CanCollide=false end
end end
root:SetAttribute("Configured", true)
root:SetAttribute("PilotCheckPassed", false)
root:SetAttribute("TraversalVerified", false)
print("STOREFRONT SETTINGS APPLIED. Run the checker. Saving and traversal remain unverified.")
