"""Upload ONLY the seven approved fire-study textures via connected Studio MCP.

Requires explicit user authorization. Serves those exact PNGs over loopback only;
records the unmodified MCP receipt. Does not edit existing asset IDs or publish a place.
"""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[2]
STUDY = ROOT / "assets/vfx/studies/illustrated_fire_v1"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--studio-id",required=True)
    args = parser.parse_args()
    manifest = json.loads((STUDY/"manifest.json").read_text())
    files = {"/"+Path(entry["file"]).name: ROOT/entry["file"] for entry in manifest["assets"].values()}
    if len(files) != 7:
        raise ValueError("Upload authorization covers exactly seven study textures")
    for entry in manifest["assets"].values():
        path = (ROOT/entry["file"]).resolve()
        if not path.is_relative_to((STUDY/"textures").resolve()):
            raise ValueError("Upload path escapes the approved study texture directory")
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError("Artwork changed since manifest generation; review before uploading")

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            path = files.get(self.path)
            if path is None:
                self.send_error(404)
                return
            data = path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type","image/png")
            self.send_header("Content-Length",str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self,*values):
            pass

    server = ThreadingHTTPServer(("127.0.0.1",0),Handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    parameters = {"studio_id":args.studio_id,"imagePaths":[f"http://127.0.0.1:{server.server_port}{path}" for path in files]}
    request_path = STUDY/"studio_upload_request.json"
    request_path.write_text(json.dumps(parameters,indent=2)+"\n")
    try:
        print("Uploading the seven approved fire-study textures through local Studio MCP...",flush=True)
        result = subprocess.run([sys.executable,str(Path(__file__).with_name("studio_mcp.py")),"--tool","upload_image",
            "--args-file",str(request_path),"--timeout","180","--output",str(STUDY/"upload_receipt.json")],
            cwd=ROOT,text=True,capture_output=True,timeout=195)
        print(result.stdout)
        if result.returncode:
            print(result.stderr,file=sys.stderr)
        raise SystemExit(result.returncode)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
