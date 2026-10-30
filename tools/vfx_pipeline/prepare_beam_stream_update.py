"""Prepare a targeted update for continuous beams and fixed path motifs."""
from pathlib import Path
from prepare_baked_restyle_install import literal

ROOT=Path(__file__).resolve().parents[2]
code=['assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")',
      'local rs=game:GetService("ReplicatedStorage");local s=rs.Shared.SpellVFXSystem',
      'local backup=rs:FindFirstChild("BeamStreamSourceBackup")',
      'if not backup then backup=Instance.new("Folder");backup.Name="BeamStreamSourceBackup";backup.Parent=rs end']
for name in ['StreamBeam','PathGlyphs','SignaturePlanner','SignatureKits','SignatureRenderer']:
    code += ['do local parent=s.Signature;local m=parent:FindFirstChild("'+name+'")',
        'if m and not backup:FindFirstChild("'+name+'") then m:Clone().Parent=backup end',
        'if not m then m=Instance.new("ModuleScript");m.Name="'+name+'";m.Parent=parent end',
        'm.Source='+literal((ROOT/'src/shared/SpellVFXSystem/Signature'/(name+'.luau')).read_text(encoding='utf-8'))+';end']
code+=['return "Installed continuous fire/water, stationary enclosed runes/rifts, and endpoint dissipation"']
(ROOT/'scripts/studio_beam_stream_install.luau').write_text('\n'.join(code)+'\n',encoding='utf-8')
