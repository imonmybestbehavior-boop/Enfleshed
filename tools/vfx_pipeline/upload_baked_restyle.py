"""Upload the user-approved baked library in resumable, hash-checked batches."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[2]
BAKED = ROOT / 'assets/vfx/studies/style_unification_v1/baked'
RECEIPTS = BAKED / 'studio_uploads'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--studio-id')
    parser.add_argument('--preflight', action='store_true')
    parser.add_argument('--batch-size', type=int, default=8)
    parser.add_argument('--representatives', action='store_true')
    args = parser.parse_args()
    if not 1 <= args.batch_size <= 12:
        parser.error('batch-size must be between 1 and 12')
    entries = json.loads((BAKED / 'manifest.json').read_text(encoding='utf-8'))['entries']
    for entry in entries:
        path = (BAKED / entry['file']).resolve()
        assert path.is_relative_to(BAKED.resolve())
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], entry['file']
    print(f'Verified all {len(entries)} approved baked image hashes.', flush=True)
    if args.preflight:
        return
    if not args.studio_id:
        parser.error('--studio-id required for uploads')
    RECEIPTS.mkdir(exist_ok=True)
    mapping_path = RECEIPTS / 'uploaded.json'
    mapping = json.loads(mapping_path.read_text(encoding='utf-8')) if mapping_path.exists() else {}
    pending = []
    for entry in entries:
        previous = mapping.get(entry['file'])
        if previous:
            assert previous['sha256'] == entry['sha256'], 'Previously uploaded bytes differ'
        elif not args.representatives or (entry['identity'], entry['name']) in {
            ('Spirit', 'soul_wisp'), ('Fire', 'flame_tongue')
        }:
            pending.append(entry)
    for offset in range(0, len(pending), args.batch_size):
        batch = pending[offset:offset + args.batch_size]
        token = hashlib.sha256(json.dumps([(e['file'], e['sha256']) for e in batch]).encode()).hexdigest()[:16]
        receipt = RECEIPTS / f'{token}.receipt.json'
        request_path = RECEIPTS / f'{token}.request.json'
        # An interrupted or failed request may already have uploaded assets. Never retry blindly.
        if receipt.exists() or request_path.exists():
            raise RuntimeError(f'Inspect/reconcile existing upload attempt before retrying: {request_path}')
        files = {'/' + Path(e['file']).name: (BAKED / e['file']).read_bytes() for e in batch}

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                data = files.get(self.path)
                if data is None:
                    self.send_error(404)
                    return
                self.send_response(200)
                self.send_header('Content-Type', 'image/png')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def log_message(self, *unused):
                pass

        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        urls = [f'http://127.0.0.1:{server.server_port}/' + Path(e['file']).name for e in batch]
        request_path.write_text(json.dumps({'studio_id': args.studio_id, 'imagePaths': urls}, indent=2), encoding='utf-8')
        try:
            result = subprocess.run([sys.executable, str(Path(__file__).with_name('studio_mcp.py')),
                '--tool', 'upload_image', '--args-file', str(request_path), '--timeout', '180',
                '--output', str(receipt)], cwd=ROOT, capture_output=True, text=True, encoding='utf-8', timeout=195)
            if result.returncode:
                raise RuntimeError(f'Upload failed; inspect {receipt}: {result.stderr}')
            response = json.loads(receipt.read_text(encoding='utf-8'))
            assert not response.get('isError'), response
            uploaded = {}
            for block in response.get('content', []):
                if block.get('type') == 'text':
                    try:
                        value = json.loads(block['text'])
                    except ValueError:
                        continue
                    if isinstance(value, dict):
                        uploaded.update(value)
            for entry, url in zip(batch, urls):
                asset_id = uploaded.get(url)
                if not isinstance(asset_id, str) or not asset_id.startswith('rbxassetid://') or not asset_id[13:].isdigit():
                    raise RuntimeError(f'Unexpected receipt format; reconcile {receipt} before continuing')
                mapping[entry['file']] = dict(id=asset_id, sha256=entry['sha256'], receipt=receipt.name)
            temporary = mapping_path.with_suffix('.tmp')
            temporary.write_text(json.dumps(mapping, indent=2) + '\n', encoding='utf-8')
            temporary.replace(mapping_path)
            print(f'Recorded {len(mapping)}/{len(entries)} uploaded images.', flush=True)
        finally:
            server.shutdown()
            server.server_close()


if __name__ == '__main__':
    main()
