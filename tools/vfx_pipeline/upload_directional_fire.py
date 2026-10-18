"""Upload the FOUR explicitly approved directional fire exports via Studio MCP.

Only hash-matched PNGs listed in the packed manifest are served over loopback.
The raw MCP receipt is preserved. No place is published and no source is changed.
Do not rerun after a partial/ambiguous receipt without inspecting it for created IDs.
"""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[2]
BUNDLE = ROOT / "assets/vfx/generated/painted_fire_v1"
NAMES = ("front", "three_quarter", "side", "rear")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--studio-id",required=True)
    args = parser.parse_args()
    receipt = BUNDLE/"upload_receipt.json"
    if receipt.exists():
        raise RuntimeError("Upload receipt already exists. Inspect it before another upload to avoid duplicates.")
    manifest = json.loads((BUNDLE/"manifest.json").read_text())
    if set(manifest["assets"]) != set(NAMES):
        raise ValueError("Authorization covers exactly the four reviewed directional sheets")
    files = {}
    for name in NAMES:
        entry = manifest["assets"][name]
        path = (ROOT/entry["file"]).resolve()
        if path.parent != BUNDLE.resolve() or path.suffix.lower() != ".png":
            raise ValueError("Upload path outside the approved packed bundle")
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError(f"Export changed since review: {name}")
        files["/"+path.name] = path.read_bytes()

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            data = files.get(self.path)
            if data is None:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type","image/png")
            self.send_header("Content-Length",str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self,*unused):
            pass

    server = ThreadingHTTPServer(("127.0.0.1",0),Handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    request = {"studio_id":args.studio_id,"imagePaths":[f"http://127.0.0.1:{server.server_port}{path}" for path in files]}
    request_path = BUNDLE/"upload_request.json"
    request_path.write_text(json.dumps(request,indent=2)+"\n",encoding="utf-8")
    try:
        print("Uploading only the four approved directional fire sheets...",flush=True)
        result = subprocess.run([sys.executable,str(Path(__file__).with_name("studio_mcp.py")),"--tool","upload_image",
            "--args-file",str(request_path),"--timeout","180","--output",str(receipt)],
            cwd=ROOT,text=True,capture_output=True,timeout=195)
        print(result.stdout,flush=True)
        if result.returncode:
            print(result.stderr,file=sys.stderr,flush=True)
        raise SystemExit(result.returncode)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
