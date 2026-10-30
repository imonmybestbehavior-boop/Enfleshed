"""Preserve the actually imported skin in a Rojo model and export measured poses."""
import copy
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
STUDY=ROOT/"assets/vfx/studies/3d_fire_v4"
DEST=ROOT/"src/shared/SpellVFXSystem/Assets"

def name(item):
    for prop in item.find("Properties"):
        if prop.get("name")=="Name": return prop.text

def prop(item,tag,key,value):
    properties=item.find("Properties")
    for old in list(properties):
        if old.get("name")==key: properties.remove(old)
    element=ET.SubElement(properties,tag,{"name":key})
    if tag=="Content": ET.SubElement(element,"url").text=value
    else: element.text=value
    return element

def main():
    place=ET.parse(ROOT/"Enfleshed-Defend-The-Walls.rbxlx").getroot()
    source=next(i for i in place.iter("Item") if i.get("class")=="MeshPart" and name(i)=="ConnectedFireVolume")
    mesh=copy.deepcopy(source)
    assert any(p.get("name")=="MeshId" and p.findtext("url")=="rbxassetid://135760105803974" for p in mesh.find("Properties"))
    print("Imported mesh properties:",[(p.tag,p.get("name")) for p in mesh.find("Properties")])
    for child in list(mesh.findall("Item")):
        if child.get("class")!="Bone": mesh.remove(child)
    assert sum(i.get("class")=="Bone" for i in mesh.iter("Item"))==73
    prop(mesh,"bool","Anchored","true")
    for key in ("CanCollide","CanTouch","CanQuery","CastShadow"): prop(mesh,"bool",key,"false")
    prop(mesh,"float","Transparency","0")
    cf=prop(mesh,"CoordinateFrame","CFrame",None)
    for key,value in zip(["X","Y","Z","R00","R01","R02","R10","R11","R12","R20","R21","R22"],[0,0,0,1,0,0,0,1,0,0,0,1]):
        ET.SubElement(cf,key).text=str(value)
    for bone in mesh.iter("Item"):
        if bone.get("class")=="Bone":
            for p in list(bone.find("Properties")):
                if p.get("name")=="Transform": bone.find("Properties").remove(p)
    model=ET.Element("Item",{"class":"Model","referent":"CFV4_Model"})
    ET.SubElement(model,"Properties");prop(model,"string","Name","ConnectedFireRig")
    model.append(mesh)
    frames=ET.SubElement(model,"Item",{"class":"Folder","referent":"CFV4_Frames"})
    ET.SubElement(frames,"Properties");prop(frames,"string","Name","Frames")
    assets=json.loads((STUDY/"published_assets.json").read_text())["assets"]
    for entry in assets:
        frame=ET.SubElement(frames,"Item",{"class":"SurfaceAppearance","referent":f'CFV4_Surface_{entry["frame"]}'})
        ET.SubElement(frame,"Properties")
        prop(frame,"string","Name",f'Frame_{entry["frame"]:03d}')
        prop(frame,"Content","ColorMap",entry["id"])
        prop(frame,"token","AlphaMode","1")
    # All references are local to the authored model; strip imported package/asset metadata.
    refs={item.get("referent"):f"CFV4_Item_{n}" for n,item in enumerate(model.iter("Item"))}
    for item in model.iter("Item"):
        item.set("referent",refs[item.get("referent")])
        for p in list(item.find("Properties")):
            if p.get("name") in {"SourceAssetId","HistoryId","UniqueId","Capabilities","Sandboxed","AttributesSerialize","Tags","AssetId"}:
                item.find("Properties").remove(p)
            elif p.tag=="Ref": p.text=refs.get(p.text,"null")
    root=ET.Element("roblox",{"version":"4"});root.append(model)
    needed={p.text for p in model.iter("SharedString") if p.text}
    if needed:
        shared=ET.SubElement(root,"SharedStrings")
        available={item.get("md5"):item for item in place.findall("./SharedStrings/SharedString")}
        assert needed<=available.keys(),"Missing serialized shared mesh data"
        for key in sorted(needed): shared.append(copy.deepcopy(available[key]))
    ET.indent(root,space="\t")
    ET.ElementTree(root).write(DEST/"ConnectedFireRig.rbxmx",encoding="utf-8",xml_declaration=True)
    poses=json.loads((STUDY/"pose_probe.json").read_text())
    mapping=json.loads((STUDY/"bind_mapping.json").read_text())
    assert mapping["max_bind_error"]<1e-5
    m=mapping["matrix"]
    lines=["-- Generated from approved v4 source poses and measured Studio bind mapping.","return {", "\tNames = {"]
    lines.extend('\t\t"'+n+'",' for n in poses["names"])
    lines.extend(["\t},","\tFrames = {"])
    for row in poses["frames"]:
        values=[]
        for delta in row:
            values.append("Vector3.new("+", ".join(f"{sum(delta[i]*m[i][j] for i in range(3)):.8f}" for j in range(3))+")")
        lines.append("\t\t{"+", ".join(values)+"},")
    lines.extend(["\t},","}"])
    (DEST/"ConnectedFirePoses.luau").write_text("\n".join(lines)+"\n",encoding="utf-8")
    print("Packaged the imported 73-bone mesh, 24 prepared surfaces and measured animation poses")

if __name__=="__main__": main()
