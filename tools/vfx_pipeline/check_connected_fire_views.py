"""Capture controlled Studio client frames; no source asset changes."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"assets/vfx/studies/3d_fire_v4"
parser=argparse.ArgumentParser()
parser.add_argument("--studio-id",required=True)
parser.add_argument("--view", choices=["side_01","side_13","front_13","rear_13"],required=True)
args=parser.parse_args()
frame,angle={"side_01":(1,0),"side_13":(13,0),"front_13":(13,1.57079632679),"rear_13":(13,4.71238898038)}[args.view]
code=f'''local g=game:GetService("Players").LocalPlayer.PlayerGui.ConnectedFireV4Review
g:SetAttribute("Paused",true)
g:SetAttribute("ReviewFrame",{frame})
g:SetAttribute("ReviewAngle",{angle})
task.wait(.2)
return game:GetService("HttpService"):JSONEncode(g:GetAttributes())
'''
path=OUT/(args.view+".luau"); path.write_text(code,encoding="utf-8")
base=[sys.executable,str(Path(__file__).with_name("studio_mcp.py")),"--studio-id",args.studio_id]
subprocess.run(base+["--tool","execute_luau","--code-file",str(path),"--datamodel-type","Client",
    "--output",str(OUT/(args.view+"_state.json"))],check=True)
subprocess.run(base+["--tool","screen_capture","--args-file",str(OUT/"capture.json"),
    "--image-prefix",str(OUT/("studio_"+args.view)),"--output",str(OUT/(args.view+"_capture.json"))],check=True)
