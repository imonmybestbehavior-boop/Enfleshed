"""Upload the explicitly approved 24 v4 surface frames through Studio MCP."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/vfx/studies/3d_fire_v4"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--studio-id", required=True)
    args = parser.parse_args()
    receipt = OUT / "upload_receipt.json"
    if receipt.exists():
        raise RuntimeError("Inspect the existing receipt before retrying; avoid duplicate uploads")
    paths = [OUT / "flow_textures" / f"flow_{i:03d}.png" for i in range(1, 25)]
    files = {"/" + path.name: path.read_bytes() for path in paths}
    (OUT / "upload_hashes.json").write_text(json.dumps({path.name: hashlib.sha256(files["/"+path.name]).hexdigest() for path in paths}, indent=2)+"\n")

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            data = files.get(self.path)
            if data is None:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *unused):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    request = {"studio_id": args.studio_id, "imagePaths": [f"http://127.0.0.1:{server.server_port}{name}" for name in files]}
    request_path = OUT / "upload_request.json"
    request_path.write_text(json.dumps(request, indent=2)+"\n")
    try:
        result = subprocess.run([sys.executable, str(Path(__file__).with_name("studio_mcp.py")),
            "--tool", "upload_image", "--args-file", str(request_path), "--timeout", "180", "--output", str(receipt)],
            cwd=ROOT, text=True, capture_output=True, timeout=195)
        print(result.stdout, flush=True)
        if result.returncode:
            print(result.stderr, file=sys.stderr, flush=True)
        raise SystemExit(result.returncode)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
