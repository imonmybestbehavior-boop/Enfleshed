"""Record only IDs present in the saved Studio upload receipt and generate a fetch check.

This records an upload result, not successful availability or visual acceptance.
"""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
BUNDLE = ROOT/"assets/vfx/generated/painted_fire_v1"


def main():
    receipt = json.loads((BUNDLE/"upload_receipt.json").read_text())
    if receipt.get("isError"):
        raise ValueError("Upload receipt reports failure")
    mappings = {}
    for block in receipt.get("content",[]):
        if block.get("type") == "text":
            mappings.update(json.loads(block["text"]))
    manifest = json.loads((BUNDLE/"manifest.json").read_text())
    assets = {}
    for name,entry in manifest["assets"].items():
        matches = [value for url,value in mappings.items() if url.endswith("/"+Path(entry["file"]).name)]
        if len(matches) != 1 or not re.fullmatch(r"rbxassetid://[1-9][0-9]*",matches[0]):
            raise ValueError(f"Missing or ambiguous returned ID for {name}")
        assets[name] = {"id":matches[0],"export_sha256":entry["sha256"],"file":entry["file"],
            "fetch_status":"pending","studio_visual_verified":False}
    publication = {"version":1,"authorization":"User approved upload of the four packed sheets in this chat",
        "receipt_sha256":hashlib.sha256((BUNDLE/"upload_receipt.json").read_bytes()).hexdigest(),
        "status":"uploaded_fetch_pending","assets":assets}
    out = BUNDLE/"published_assets.json"
    if out.exists():
        old = json.loads(out.read_text())
        if {n:e["id"] for n,e in old["assets"].items()} == {n:e["id"] for n,e in assets.items()}:
            print("Existing publication record preserved")
            return
        raise ValueError("Different publication record already exists")
    out.write_text(json.dumps(publication,indent=2)+"\n",encoding="utf-8")
    lua = ["-- Generated from the actual saved Studio upload receipt. Read-only fetch check.","local assets = {"]
    for name,entry in assets.items():
        lua.append(f'\t{{ Name = "{name}", Id = "{entry["id"]}" }},')
    lua += ["}","local ids, names, statuses = {}, {}, {}","for _, entry in assets do",
        "\ttable.insert(ids, entry.Id)","\tnames[entry.Id] = entry.Name","end",
        'local ok, err = pcall(function()',
        '\tgame:GetService("ContentProvider"):PreloadAsync(ids, function(content, status)',
        '\t\ttable.insert(statuses, { Name = names[content] or content, Content = content, Status = status.Name })',
        '\tend)', 'end)',
        'local result = { PreloadOK = ok, Statuses = statuses, PlaceId = game.PlaceId, UniverseId = game.GameId, IsRunning = game:GetService("RunService"):IsRunning() }',
        'if not ok then result.Error = tostring(err) end',
        'local identityOK, identity = pcall(function() return game:GetService("StudioService"):GetUserId() end)',
        'if identityOK then result.StudioUserId = identity end',
        'return game:GetService("HttpService"):JSONEncode(result)']
    (ROOT/"scripts/studio_directional_fire_verify.luau").write_text("\n".join(lua)+"\n",encoding="utf-8")
    print("Recorded four returned IDs and generated read-only Studio fetch check")


if __name__ == "__main__":
    main()
