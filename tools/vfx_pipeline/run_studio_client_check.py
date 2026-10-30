"""Run a check as a real LocalScript, then collect its result through Studio MCP."""
import argparse
from pathlib import Path
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"assets/vfx/studies/3d_fire_v4"
p=argparse.ArgumentParser();p.add_argument("--code-file",type=Path,required=True);p.add_argument("--output",type=Path,required=True);p.add_argument("--studio-id",required=True)
p.add_argument("--keep-alive",action="store_true",help="Keep a visual check's callbacks alive until the playtest ends")
args=p.parse_args()
body=args.code_file.read_text(encoding="utf-8")
source='''local output=script.Parent
local ok,result=xpcall(function()
__BODY__
end,debug.traceback)
output:SetAttribute("Result",tostring(result))
output:SetAttribute("OK",ok)
output:SetAttribute("Finished",true)
'''.replace("__BODY__",body)
eq="="
while "]"+eq+"]" in source: eq+="="
literal="["+eq+"["+source+"]"+eq+"]"
wrapper='''local pg=game:GetService("Players").LocalPlayer.PlayerGui
local previous=pg:FindFirstChild("__HARNESS__")
if previous and previous:GetAttribute("Finished") then
 local review=pg:FindFirstChild("ConnectedFireRuntimeReview")
 if review then review:Destroy() end
 previous:Destroy()
end
assert(not pg:FindFirstChild("__HARNESS__"),"A check is already running")
local output=Instance.new("Folder");output.Name="__HARNESS__";output.Parent=pg
local runner=Instance.new("LocalScript");runner.Name="ConnectedFireClientCheck";runner.Source=__SOURCE__;runner.Parent=output
local deadline=os.clock()+35
while not output:GetAttribute("Finished") and os.clock()<deadline do task.wait(.1) end
local finished,ok,result=output:GetAttribute("Finished"),output:GetAttribute("OK"),output:GetAttribute("Result")
if not finished or not ok then
 local gui=pg:FindFirstChild("ConnectedFireBenchmarkReview")
 if gui then gui:Destroy() end
end
if not __KEEPALIVE__ or not ok then output:Destroy() end
assert(finished,"Client check timed out")
assert(ok,result)
return result
'''.replace("__SOURCE__",literal).replace("__HARNESS__","ConnectedFireVisualCheckHarness" if args.keep_alive else "ConnectedFireCheckHarness").replace("__KEEPALIVE__","true" if args.keep_alive else "false")
path=OUT/"client_check_driver.luau";path.write_text(wrapper,encoding="utf-8")
subprocess.run([sys.executable,str(Path(__file__).with_name("studio_mcp.py")),"--tool","execute_luau",
    "--studio-id",args.studio_id,"--code-file",str(path),"--datamodel-type","Client","--timeout","60",
    "--output",str(args.output)],check=True)
