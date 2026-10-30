"""Use the locally installed Studio MCP stdio server from the asset pipeline.

Read-only discovery: python tools/vfx_pipeline/studio_mcp.py
Call a discovered tool: ... --tool NAME --args-file path.json
Tool arguments must be chosen from the discovered schema, never guessed.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import queue
import subprocess
import threading
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool")
    parser.add_argument("--args-file",type=Path)
    parser.add_argument("--timeout",type=int,default=45)
    parser.add_argument("--filter",help="Comma-separated tool names to show during discovery")
    parser.add_argument("--studio-id")
    parser.add_argument("--connect-wait",type=float,default=12,help="Keep the bridge alive before discovery so Studio can reconnect")
    parser.add_argument("--code-file",type=Path)
    parser.add_argument("--datamodel-type",choices=["Edit","Client","Server"],default="Edit")
    parser.add_argument("--output",type=Path)
    parser.add_argument("--image-prefix",type=Path,help="Save returned image blocks locally instead of printing their base64 data")
    args = parser.parse_args()
    launcher = Path(os.environ["LOCALAPPDATA"])/"Roblox/mcp.bat"
    process = subprocess.Popen(["cmd.exe","/c",str(launcher)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL,text=True,encoding="utf-8",creationflags=subprocess.CREATE_NO_WINDOW)
    messages = queue.Queue()

    def read():
        for line in process.stdout:
            try:
                messages.put(json.loads(line))
            except json.JSONDecodeError:
                pass
    threading.Thread(target=read,daemon=True).start()

    def send(message):
        process.stdin.write(json.dumps(message)+"\n")
        process.stdin.flush()

    def request(ident,method,params):
        send({"jsonrpc":"2.0","id":ident,"method":method,"params":params})
        deadline = time.monotonic()+args.timeout
        while time.monotonic()<deadline:
            try:
                message = messages.get(timeout=min(1,max(.01,deadline-time.monotonic())))
            except queue.Empty:
                if process.poll() is not None:
                    raise RuntimeError(f"Studio MCP exited ({process.returncode}) before replying to {method}")
                continue
            if message.get("id")==ident:
                if "error" in message:
                    raise RuntimeError(json.dumps(message["error"]))
                return message.get("result")
        raise TimeoutError(f"Studio MCP did not reply to {method} within {args.timeout}s")

    try:
        initialized = request(1,"initialize",{"protocolVersion":"2024-11-05","capabilities":{},
                              "clientInfo":{"name":"enfleshed-local-vfx-pipeline","version":"1"}})
        send({"jsonrpc":"2.0","method":"notifications/initialized"})
        if args.connect_wait:
            time.sleep(min(30, max(0, args.connect_wait)))
        if args.tool:
            parameters = json.loads(args.args_file.read_text(encoding="utf-8-sig")) if args.args_file else {}
            if args.studio_id:
                parameters["studio_id"] = args.studio_id
            if args.code_file:
                parameters.update(code=args.code_file.read_text(encoding="utf-8"),datamodel_type=args.datamodel_type)
            result = request(2,"tools/call",{"name":args.tool,"arguments":parameters})
        else:
            result = {"server":initialized,"tools":request(2,"tools/list",{})}
            if args.filter:
                names = set(args.filter.split(","))
                result["tools"]["tools"] = [tool for tool in result["tools"]["tools"] if tool["name"] in names]
        if args.image_prefix and isinstance(result,dict):
            for index, block in enumerate(result.get("content",[])):
                if block.get("type") == "image":
                    suffix = ".jpg" if block.get("mimeType") == "image/jpeg" else ".png"
                    destination = args.image_prefix.with_name(args.image_prefix.name+f"_{index}"+suffix)
                    destination.parent.mkdir(parents=True,exist_ok=True)
                    destination.write_bytes(base64.b64decode(block["data"],validate=True))
                    result["content"][index] = {"type":"text","text":f"Saved Studio capture: {destination}"}
        if args.output:
            args.output.parent.mkdir(parents=True,exist_ok=True)
            args.output.write_text(json.dumps(result,ensure_ascii=True,indent=2)+"\n",encoding="utf-8")
        print(json.dumps(result,ensure_ascii=True,indent=2))
        if isinstance(result,dict) and result.get("isError"):
            raise SystemExit(1)
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()


if __name__ == "__main__":
    main()
