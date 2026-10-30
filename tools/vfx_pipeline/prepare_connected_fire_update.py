"""Prepare updates to the existing runtime modules, leaving rig resources intact."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def literal(text):
    eq="="
    while "]"+eq+"]" in text: eq+="="
    return "["+eq+"["+text+"]"+eq+"]"
code=['assert(not game:GetService("RunService"):IsRunning(),"Update in Edit mode")',
    'local system=game:GetService("ReplicatedStorage").Shared.SpellVFXSystem']
for rel in ["Signature/ConnectedFire","Signature/SignatureRenderer"]:
    parent,name=rel.split("/")
    code.append(f'system.{parent}.{name}.Source='+literal((ROOT/"src/shared/SpellVFXSystem"/(rel+".luau")).read_text(encoding="utf-8")))
code.append('return "Updated connected-body pooling and renderer connection recovery"')
(ROOT/"scripts/studio_connected_fire_runtime_update.luau").write_text("\n".join(code)+"\n",encoding="utf-8")
