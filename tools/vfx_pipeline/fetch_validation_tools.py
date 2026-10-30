"""Fetch the project's pinned validation tools from their official GitHub releases."""
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"tools/.validation-tools"
OUT.mkdir(exist_ok=True)
records={}
for name,repo,tag in [("luau","luau-lang/luau","0.742"),("rojo","rojo-rbx/rojo","v7.7.0")]:
    req=urllib.request.Request(f"https://api.github.com/repos/{repo}/releases/tags/{tag}",headers={"User-Agent":"Enfleshed-validation"})
    release=json.load(urllib.request.urlopen(req,timeout=30))
    asset=next(a for a in release["assets"] if a["name"]==("luau-windows.zip" if name=="luau" else "rojo-7.7.0-windows-x86_64.zip"))
    data=urllib.request.urlopen(asset["browser_download_url"],timeout=60).read()
    archive=zipfile.ZipFile(io.BytesIO(data))
    for member in archive.namelist():
        base=Path(member).name
        if base in {"luau.exe","luau-compile.exe","rojo.exe"}: (OUT/base).write_bytes(archive.read(member))
    records[name]={"release":tag,"source":asset["browser_download_url"],"sha256":hashlib.sha256(data).hexdigest()}
    print(f"Fetched {name} {tag} from its official release",flush=True)
(OUT/"receipts.json").write_text(json.dumps(records,indent=2)+"\n")
