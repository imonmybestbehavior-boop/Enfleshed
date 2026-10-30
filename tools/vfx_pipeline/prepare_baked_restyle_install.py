"""Generate the runtime manifest and a targeted, backed-up Studio module update."""
import hashlib
import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/vfx/studies/style_unification_v1'
SYSTEM = ROOT / 'src/shared/SpellVFXSystem'


def literal(value):
    eq = '='
    while ']' + eq + ']' in value:
        eq += '='
    return '[' + eq + '[' + value + ']' + eq + ']'


def main():
    manifest = json.loads((OUT / 'baked/manifest.json').read_text(encoding='utf-8'))
    uploaded = json.loads((OUT / 'baked/studio_uploads/uploaded.json').read_text(encoding='utf-8'))
    profile = json.loads((OUT / 'baked/style_profile.json').read_text(encoding='utf-8'))
    lines = ['-- Approved existing artwork; IDs point to the exact baked bytes in the receipt ledger.',
             'return {', '\tEnabled = true,', '\tTextures = {']
    for entry in manifest['entries']:
        row = uploaded.get(entry['file'])
        assert row and row['sha256'] == entry['sha256'], entry['file']
        # A compound key prevents shared smoke/glow sources selecting another identity palette.
        lines.append(f'\t\t["{entry["identity"]}/{entry["name"]}"] = "{row["id"]}",')
    lines += ['\t},', '\tPalettes = {']
    for identity, colors in profile['palettes'].items():
        values = ', '.join('Color3.fromRGB(' + ', '.join(map(str, c)) + ')' for c in colors)
        lines.append(f'\t\t{identity} = {{ {values} }},')
    lines += ['\t},', '}']
    (SYSTEM / 'Assets/StyledVFXManifest.luau').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    receipt = json.loads((OUT / 'studio_mesh_import.json').read_text(encoding='utf-8'))
    meshes = json.loads(receipt['content'][0]['text'])
    expected = json.loads((OUT / 'baked/mesh_import_counts.json').read_text(encoding='utf-8'))
    assert len(meshes) == len(expected) == 60 and {m['Name'] for m in meshes} == set(expected)
    xml = ET.Element('roblox', version='4')
    model = ET.SubElement(xml, 'Item', {'class':'Model'})
    props = ET.SubElement(model, 'Properties')
    ET.SubElement(props, 'string', name='Name').text = 'CelMeshLibrary'
    for mesh in meshes:
        item = ET.SubElement(model, 'Item', {'class':'MeshPart'})
        props = ET.SubElement(item, 'Properties')
        ET.SubElement(props, 'string', name='Name').text = mesh['Name']
        content = ET.SubElement(props, 'Content', name='MeshId')
        ET.SubElement(content, 'url').text = mesh['MeshId']
        size = ET.SubElement(props, 'Vector3', name='size')
        for axis, value in zip('XYZ', mesh['Size']):
            ET.SubElement(size, axis).text = str(value / 100)
        mesh_size = ET.SubElement(props, 'Vector3', name='MeshSize')
        for axis, value in zip('XYZ', mesh['Size']):
            ET.SubElement(mesh_size, axis).text = str(value)
        for name, value in [('Anchored','true'),('CanCollide','false'),('CanTouch','false'),('CanQuery','false'),('CastShadow','false')]:
            ET.SubElement(props, 'bool', name=name).text = value
        color = ET.SubElement(props, 'Color3', name='Color')
        for channel in 'RGB': ET.SubElement(color, channel).text = '1'
    ET.indent(xml)
    (SYSTEM / 'Assets/CelMeshLibrary.rbxmx').write_text(ET.tostring(xml, encoding='unicode'), encoding='utf-8')
    modules = ['Assets/StyledVFXManifest', 'Assets/VFXAssets', 'Core/SpellVFXComposer', 'Signature/SignaturePlanner', 'Signature/ArcBeam', 'Signature/StreamBeam', 'Signature/PathGlyphs', 'Signature/FieldDynamics', 'Signature/SignatureKits', 'Signature/SignatureRenderer']
    code = ['assert(not game:GetService("RunService"):IsRunning(), "Install in Edit mode")',
        'local rs=game:GetService("ReplicatedStorage")', 'local system=rs.Shared.SpellVFXSystem',
        'local backup=rs:FindFirstChild("VFXRestyleSourceBackup")',
        'if not backup then backup=Instance.new("Folder"); backup.Name="VFXRestyleSourceBackup"; backup.Parent=rs end']
    for relative in modules:
        parent, name = relative.split('/')
        source = (SYSTEM / (relative + '.luau')).read_text(encoding='utf-8')
        code += [f'do local parent=system.{parent}; local m=parent:FindFirstChild("{name}")',
            f'if m and not backup:FindFirstChild("{name}") then m:Clone().Parent=backup end',
            f'if not m then m=Instance.new("ModuleScript"); m.Name="{name}"; m.Parent=parent end',
            f'm.Source={literal(source)}; end']
    code += ['local imported=workspace:FindFirstChild("Enfleshed_Cel_Existing_Meshes")',
        'assert(imported,"Import the approved existing mesh library first")',
        'assert(not system.Assets:FindFirstChild("CelMeshLibrary"),"Mesh library already installed")',
        'local parts={}; for _,p in imported:GetDescendants() do if p:IsA("MeshPart") then table.insert(parts,p) end end',
        'assert(#parts==60,"Expected exactly 60 existing mesh variants")',
        'for _,p in parts do p.Size*=0.01; p.CFrame=CFrame.new(); p.Color=Color3.new(1,1,1); p.Material=Enum.Material.SmoothPlastic;',
        'p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false; p:SetAttribute("VFXBakedColors",true) end',
        'imported.Name="CelMeshLibrary"; imported.Parent=system.Assets']
    code += ['return "Installed approved baked texture resolver and palettes; connected fire source and rig untouched"']
    (ROOT / 'scripts/studio_baked_restyle_install.luau').write_text('\n'.join(code)+'\n', encoding='utf-8')
    print(f'Prepared targeted install for {len(uploaded)} baked texture variants')


if __name__ == '__main__':
    main()
