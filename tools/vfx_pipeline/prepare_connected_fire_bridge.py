"""Sync the existing composer/controller bridge needed by the connected projectile renderer."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def literal(text):
    eq="="
    while "]"+eq+"]" in text: eq+="="
    return "["+eq+"["+text+"]"+eq+"]"
composer=(ROOT/"src/shared/SpellVFXSystem/Core/SpellVFXComposer.luau").read_text(encoding="utf-8")
controller=(ROOT/"src/client/Controllers/SpellVFXController.luau").read_text(encoding="utf-8")
code='''assert(not game:GetService("RunService"):IsRunning(),"Sync source in Edit mode")
local composer=game:GetService("ReplicatedStorage").Shared.SpellVFXSystem.Core.SpellVFXComposer
local controller=game:GetService("StarterPlayer").StarterPlayerScripts.Client.Controllers.SpellVFXController
composer.Source=__COMPOSER__
controller.Source=__CONTROLLER__
return "Synced the existing composer/controller bridge; gameplay services unchanged"
'''.replace("__COMPOSER__",literal(composer)).replace("__CONTROLLER__",literal(controller))
(ROOT/"scripts/studio_connected_fire_bridge_install.luau").write_text(code,encoding="utf-8")
print("Prepared the missing live controller/composer source bridge")
