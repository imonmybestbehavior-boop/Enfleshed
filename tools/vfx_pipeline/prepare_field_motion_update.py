"""Targeted cosmetic update for grounded fields, casts and elemental motion."""
from pathlib import Path
from prepare_baked_restyle_install import literal
ROOT=Path(__file__).resolve().parents[2]
code=['assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")',
      'local rs=game:GetService("ReplicatedStorage");local s=rs.Shared.SpellVFXSystem',
      'local backup=rs:FindFirstChild("FieldMotionSourceBackup")',
      'if not backup then backup=Instance.new("Folder");backup.Name="FieldMotionSourceBackup";backup.Parent=rs end']
for name in ['FieldDynamics','StreamBeam','PathGlyphs','SignaturePlanner','SignatureKits','SignatureRenderer']:
    code += ['do local parent=s.Signature;local m=parent:FindFirstChild("'+name+'")',
        'if m and not backup:FindFirstChild("'+name+'") then m:Clone().Parent=backup end',
        'if not m then m=Instance.new("ModuleScript");m.Name="'+name+'";m.Parent=parent end',
        'm.Source='+literal((ROOT/'src/shared/SpellVFXSystem/Signature'/(name+'.luau')).read_text(encoding='utf-8'))+';end']
code+=['return "Installed grounded elemental fields, source-only cast cue, and connected beam motifs"']
source=(ROOT/'src/shared/SpellVFXSystem/Core/SpellVFXComposer.luau').read_text(encoding='utf-8')
code.insert(-1,'do local m=s.Core.SpellVFXComposer;if not backup:FindFirstChild("SpellVFXComposer") then m:Clone().Parent=backup end;m.Source='+literal(source)+';end')
source=(ROOT/'src/client/Controllers/SpellVFXController.luau').read_text(encoding='utf-8')
code.insert(-1,'do local m=game.StarterPlayer.StarterPlayerScripts.Client.Controllers.SpellVFXController;if not backup:FindFirstChild("SpellVFXController") then m:Clone().Parent=backup end;m.Source='+literal(source)+';end')
(ROOT/'scripts/studio_field_motion_install.luau').write_text('\n'.join(code)+'\n',encoding='utf-8')
