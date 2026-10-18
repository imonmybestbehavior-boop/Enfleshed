"""Record real upload IDs and prepare a bounded, isolated Studio surface-frame bank."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/vfx/studies/3d_fire_v4"
receipt = json.loads((OUT / "upload_receipt.json").read_text())
assert not receipt.get("isError"), "Upload failed; inspect receipt"
mapping = {}
for block in receipt.get("content", []):
    if block.get("type") == "text":
        mapping.update(json.loads(block["text"]))
assets = []
hashes = json.loads((OUT / "upload_hashes.json").read_text())
for index in range(1, 25):
    name = f"flow_{index:03d}.png"
    ids = [value for url, value in mapping.items() if url.endswith("/"+name)]
    assert len(ids) == 1 and re.fullmatch(r"rbxassetid://[1-9][0-9]*", ids[0]), name
    assert hashlib.sha256((OUT / "flow_textures" / name).read_bytes()).hexdigest() == hashes[name]
    assets.append({"frame": index, "file": name, "id": ids[0], "sha256": hashes[name]})
(OUT / "published_assets.json").write_text(json.dumps({"status": "uploaded; fetch check pending",
    "authorization": "User explicitly approved upload of all 24 v4 surface frames in this chat",
    "assets": assets}, indent=2)+"\n")
ids = ",\n".join('    "'+entry["id"]+'"' for entry in assets)
code = '''-- Isolated test resources only. Does not replace existing spell effects.
assert(not game:GetService("RunService"):IsRunning(), "Prepare frame bank in Edit mode")
local storage = game:GetService("ReplicatedStorage")
assert(not storage:FindFirstChild("ConnectedFireV4Study"), "Frame bank already exists; inspect before rerunning")
local ids = {
__IDS__
}
local statuses = {}
local fetchOK, fetchError = pcall(function()
    game:GetService("ContentProvider"):PreloadAsync(ids, function(id, status)
        table.insert(statuses, {Id=id, Status=status.Name})
    end)
end)
local bank = Instance.new("Folder")
bank.Name = "ConnectedFireV4Study"
bank:SetAttribute("Scope", "Isolated test assets; runtime integration pending")
bank:SetAttribute("TextureFPS", 12)
for index, id in ids do
    local surface = Instance.new("SurfaceAppearance")
    surface.Name = string.format("Frame_%03d", index)
    surface.AlphaMode = Enum.AlphaMode.Transparency
    surface.ColorMap = id -- Studio/plugin preparation only; never set by the gameplay loop.
    surface.Parent = bank
end
bank.Parent = storage
return game:GetService("HttpService"):JSONEncode({Bank=bank:GetFullName(), Frames=#bank:GetChildren(),
    FetchOK=fetchOK, FetchError=if fetchOK then nil else tostring(fetchError), Statuses=statuses,
    MeshImported=false, PlaybackVerified=false})
'''.replace("__IDS__", ids)
(ROOT / "scripts/studio_connected_fire_prepare.luau").write_text(code)
print("Recorded 24 real upload IDs and prepared isolated surface-frame bank script")
