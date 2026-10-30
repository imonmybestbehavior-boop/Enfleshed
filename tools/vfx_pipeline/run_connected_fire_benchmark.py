"""Run one bounded production-renderer benchmark case through Studio MCP."""
import argparse
from pathlib import Path
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"assets/vfx/studies/3d_fire_v4"
p=argparse.ArgumentParser();p.add_argument("--count",type=int,choices=[0,1,4,8,12],required=True)
p.add_argument("--quality",choices=["High","Low"],default="High");p.add_argument("--studio-id",required=True)
p.add_argument("--suffix",default="",choices=["","foreground"])
args=p.parse_args()
code=(ROOT/"scripts/studio_connected_fire_benchmark.luau").read_text(encoding="utf-8")
stem=f"benchmark_{args.count}_{args.quality}"+(f"_{args.suffix}" if args.suffix else "")
path=OUT/f"{stem}.luau"
path.write_text(code.replace("__COUNT__",str(args.count)).replace("__QUALITY__",args.quality),encoding="utf-8")
subprocess.run([sys.executable,str(Path(__file__).with_name("run_studio_client_check.py")),
    "--studio-id",args.studio_id,"--code-file",str(path),
    "--output",str(OUT/f"{stem}.json")],check=True)
