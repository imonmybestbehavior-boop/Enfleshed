assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local rs=game:GetService("ReplicatedStorage");local s=rs.Shared.SpellVFXSystem
local backup=rs:FindFirstChild("FieldMotionSourceBackup")
if not backup then backup=Instance.new("Folder");backup.Name="FieldMotionSourceBackup";backup.Parent=rs end
do local parent=s.Signature;local m=parent:FindFirstChild("FieldDynamics")
if m and not backup:FindFirstChild("FieldDynamics") then m:Clone().Parent=backup end
if not m then m=Instance.new("ModuleScript");m.Name="FieldDynamics";m.Parent=parent end
m.Source=[=[-- Grounded, timed motifs built from existing atlases/meshes. No gameplay or physics ownership.
local Assets=require(script.Parent.Parent.Assets.VFXAssets)
local Manifest=require(script.Parent.Parent.Assets.VFXAssetManifest)
local ArcBeam=require(script.Parent.ArcBeam)
local Dynamics={};Dynamics.__index=Dynamics
local TAU=math.pi*2
local function clamp(x) return math.clamp(x,0,1) end
local function hash(i) return (i*.61803398875)%1 end
local function part(parent,name)
	local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
	p.CastShadow=false;p.Transparency=1;p.Size=Vector3.one*.05;p.Parent=parent;return p
end
local function atlas(image,name,identity)
	local id=Assets.texture(name,identity);local meta=Manifest.Textures[name]
	image.Image=id
	local grid=if meta and meta.Flipbook=="Grid4x4" then 4 elseif meta and meta.Flipbook=="Grid8x8" then 8 else 1
	local cell=if meta then meta.Size.X/grid else 256
	image.ImageRectSize=Vector2.one*cell
	return {Image=image,Grid=grid,Cell=cell,Frames=grid*grid}
end
local function frame(a,index)
	index=math.clamp(index,0,a.Frames-1)
	a.Image.ImageRectOffset=Vector2.new(index%a.Grid,math.floor(index/a.Grid))*a.Cell
end
local function card(parent,name,identity,ground)
	local p=part(parent,"Motif_"..name)
	local gui
	if ground then
		gui=Instance.new("SurfaceGui");gui.Face=Enum.NormalId.Top;gui.CanvasSize=Vector2.one*256
	else
		gui=Instance.new("BillboardGui");gui.Adornee=p;gui.MaxDistance=180
	end
	gui.AlwaysOnTop=false;gui.LightInfluence=.15;gui.Enabled=false;gui.Parent=p
	local image=Instance.new("ImageLabel");image.Size=UDim2.fromScale(1,1);image.BackgroundTransparency=1
	image.ImageColor3=Color3.new(1,1,1);image.Parent=gui
	return {Part=p,Gui=gui,Atlas=atlas(image,name,identity),Ground=ground}
end
local function display(c,cf,size,opacity,index)
	c.Part.CFrame=cf
	if c.Ground then c.Part.Size=Vector3.new(size,.025,size) else c.Gui.Size=UDim2.fromScale(size,size) end
	c.Gui.Enabled=opacity>.001;c.Atlas.Image.ImageTransparency=1-clamp(opacity)
	frame(c.Atlas,index)
end

function Dynamics.new(parent,params,identity,bands,meshCapacity,trailCapacity,quality,seed)
	local self=setmetatable({Parent=parent,Params=params,Mode=params.Mode,Identity=identity,Bands=bands,
		Nodes={},Surfaces={},Meshes=0,Trails=0,Seed=seed or 0},Dynamics)
	local density=if quality=="Low" then .5 elseif quality=="Medium" then .75 else 1
	local mode=self.Mode
	local wanted=if mode=="Crystals" then 34 elseif mode=="Runes" then 48 elseif mode=="Flames" then 30
		elseif mode=="Wisps" then 20 elseif mode=="OrbitWisps" then 12 elseif mode=="Ripples" then 24
		elseif mode=="Void" then 10 elseif mode=="Gusts" then 3 else 2
	local count=math.min(math.max(2,math.floor(wanted*density)),math.max(0,meshCapacity))
	if mode=="Gusts" then count=math.min(count,trailCapacity) end
	if mode=="Storm" then count=math.min(count,math.floor(trailCapacity/3)) end
	if count<1 then return nil end
	local variants={"ice_shard_a","ice_shard_b","ice_cluster","ice_spike"}
	for i=1,count do
		local node={U=hash(i),V=hash(i*3.17),Phase=hash(i*2.31),Yaw=i*2.399963,Index=i}
		if mode=="Crystals" then
			local name=variants[(i-1)%#variants+1]
			node.Part=Assets.acquireMesh(name);node.Part.Color=Color3.new(1,1,1);node.Part.Material=Enum.Material.SmoothPlastic
			node.Part.Transparency=1
			node.Part.Parent=parent;node.Native=Assets.meshSize(name);node.Mesh=true
		elseif mode=="Storm" then
			node.Part=part(parent,"StrikeHost")
			node.Arc=ArcBeam.new(node.Part,parent,"",ColorSequence.new(bands[3]),{Width=.28,ArcSegments=6},
				math.min(6,trailCapacity-self.Trails),i*173)
			if node.Arc then self.Trails+=node.Arc.Count end
		elseif mode=="Gusts" then
			node.Part=part(parent,"GustHost")
			local a,b=Instance.new("Attachment"),Instance.new("Attachment");a.Parent=node.Part;b.Parent=node.Part
			local beam=Instance.new("Beam");beam.Name="AdvectingGust";beam.Attachment0=a;beam.Attachment1=b
			beam.FaceCamera=true;beam.Segments=12;beam.Texture=Assets.texture("gust_strokes",identity)
			beam.TextureMode=Enum.TextureMode.Stretch;beam.TextureSpeed=2;beam.Color=ColorSequence.new(Color3.new(1,1,1))
			beam.LightInfluence=.15;beam.LightEmission=.1;beam.Parent=parent
			node.Beam,node.A,node.B=beam,a,b;self.Trails+=1
		elseif mode=="Void" and i>1 then
			node.Part=Assets.acquireMesh("void_shard");node.Part.Color=Color3.new(1,1,1);node.Part.Material=Enum.Material.SmoothPlastic
			node.Part.Transparency=1
			node.Part.Parent=parent;node.Native=Assets.meshSize("void_shard");node.Mesh=true
		else
			local texture=if mode=="Flames" then "flame_tongue" elseif mode=="Ripples" then "ripple_ring"
				elseif mode=="Runes" then "rune_circle" elseif mode=="Void" then "portal_rings" else "soul_wisp"
			node.Card=card(parent,texture,identity,mode=="Runes" or mode=="Ripples" or (mode=="Void" and params.Ground~=false))
			node.Part=node.Card.Part
		end
		self.Meshes+=1;table.insert(self.Nodes,node)
	end
	if mode=="Flames" or mode=="Ripples" or (mode=="Void" and params.Ground~=false) then
		for i=1,math.min(3,math.max(0,meshCapacity-self.Meshes)) do
			local p=part(parent,"CelGroundBand");p.Shape=Enum.PartType.Cylinder;p.Material=Enum.Material.SmoothPlastic
			p.Color=if mode=="Void" then (if i==1 then bands[1] else bands[5]) else bands[if i==1 then 1 elseif i==2 then 2 else 3]
			table.insert(self.Surfaces,p);self.Meshes+=1
		end
	end
	return self
end

function Dynamics:Update(cf,size,floor,age,shown,fade,role)
	local mode=self.Mode;local opacity=if shown then 1-fade else 0
	local sx,sz=math.max(2,size.X),math.max(2,size.Z)
	local center=Vector3.new(cf.Position.X,floor,cf.Position.Z)
	if mode=="Void" and role~="Field" then
		self.VoidOrigin=self.VoidOrigin or (if self.Params.Ground==false then cf.Position else center)
		center=self.VoidOrigin
	end
	for i,p in self.Surfaces do
		local scale=({1,.87,.48})[i]
		p.Size=Vector3.new(.03,sx*scale,sz*scale)
		p.CFrame=CFrame.new(center+Vector3.new(if i==3 then sx*.12 else 0,.035+i*.025,0))*CFrame.Angles(0,0,math.pi/2)
		p.Transparency=1-opacity*(if mode=="Flames" then .9 else .78)
	end
	for i,node in self.Nodes do
		local angle=node.U*TAU;local radius=math.sqrt(node.V)*.46
		local base=center+Vector3.new(math.cos(angle)*radius*sx,0,math.sin(angle)*radius*sz)
		if role=="Field" and not node.FloorChecked then
			local hit=workspace:Raycast(base+Vector3.yAxis*5,-Vector3.yAxis*15)
			node.GroundY=if hit then hit.Position.Y else floor;node.FloorChecked=true
		end
		base=Vector3.new(base.X,node.GroundY or floor,base.Z)
		local phase=(age/(if mode=="Ripples" then 1.1 elseif mode=="Runes" then 3.5 else 2.6)+node.Phase)%1
		local born=true
		if mode=="Wisps" or mode=="OrbitWisps" then
			local localAge=age-i*.09;born=localAge>=0;phase=(math.max(0,localAge)/(2.2+node.V*.8))%1
		end
		if mode=="Crystals" then
			local scale=.65+node.V*1.7;local v=node.Native*Vector3.new(scale*(.65+node.U*.6),scale,scale*(.6+node.Phase*.8))
			local emerge=clamp((age-i*.006)/.4)
			Assets.place(node.Part,CFrame.new(base+Vector3.yAxis*(v.Y*.45-(1-emerge)*v.Y))*CFrame.Angles(.12*math.sin(i),node.Yaw,.1*math.cos(i)),v)
			node.Part.Transparency=1-opacity
		elseif mode=="Flames" then
			local h=1.8+node.V*1.5
			display(node.Card,CFrame.new(base+Vector3.yAxis*h*.42),h,opacity*(.85+.15*math.sin(age*9+i)),math.floor((age*22+i*5)%node.Card.Atlas.Frames))
		elseif mode=="Runes" then
			local a=clamp(phase/.12)*clamp((1-phase)/.18)
			display(node.Card,CFrame.new(base+Vector3.yAxis*.09)*CFrame.Angles(0,node.Yaw,0),.9+node.V*1.6,opacity*a,0)
		elseif mode=="Ripples" then
			display(node.Card,CFrame.new(base+Vector3.yAxis*.15),1.5+node.V*2.5,opacity*clamp((1-phase)*3),math.floor(phase*(node.Card.Atlas.Frames-1)))
		elseif mode=="Wisps" or mode=="OrbitWisps" then
			local h=1.1+node.V*.7;local pos
			if mode=="Wisps" then
				pos=base+Vector3.yAxis*(-h*.5+phase*(3.5+h))
			else
				local theta=phase*TAU+node.Yaw;local r=math.sin(phase*math.pi)*(1.8+node.V)
				pos=cf.Position+Vector3.new(math.cos(theta)*r,(phase-.5)*math.max(4,size.Y),math.sin(theta)*r)
			end
			local a=clamp((1-phase)/.25)*(if mode=="OrbitWisps" then clamp(phase/.12) else 1)
			display(node.Card,CFrame.new(pos),h,if born then opacity*a else 0,math.floor((age*14+i*3)%node.Card.Atlas.Frames))
		elseif mode=="Storm" then
			local cycle=math.floor(age*1.8+node.Phase)
			local t=(age*1.8+node.Phase)%1
			local x=math.sin(cycle*12.7+i)*sx*.42;local z=math.cos(cycle*5.2+i)*sz*.42
			local target=center+Vector3.new(x,.1,z)
			node.Part.CFrame=CFrame.lookAt(target+Vector3.yAxis*8,target)
			if node.Arc then node.Arc:Update(8,.65,age,shown and t<.26,if t<.26 then t/.26 else 1) end
		elseif mode=="Gusts" then
			local width=math.min(sx,sz)
			local direction=if role=="Field" then cf.RightVector else cf.LookVector
			local p=center+direction*((phase-.5)*sx)+cf.RightVector*((node.V-.5)*sz*.5)+Vector3.yAxis*(1+node.V*2)
			node.Part.CFrame=CFrame.lookAt(p,p+direction)
			node.A.CFrame=CFrame.Angles(0,0,math.pi/2);node.B.CFrame=CFrame.new(0,0,-math.max(3,width*.6))*CFrame.Angles(0,0,math.pi/2)
			node.Beam.Width0=.5+width*.06;node.Beam.Width1=.2;node.Beam.CurveSize0=width*.12;node.Beam.CurveSize1=-width*.1
			node.Beam.Transparency=NumberSequence.new(1-opacity*math.sin(phase*math.pi));node.Beam.Enabled=shown and fade<1
		elseif mode=="Void" then
			local portalSize=math.max(3,math.min(sx,sz)*.85)
			if node.Card then
				local pos=center
				local opened=age
				if role=="Projectile" then
					if not node.Fixed or age-(node.Opened or 0)>1.1 then node.Fixed=cf.Position;node.Opened=age end
					pos=node.Fixed-Vector3.yAxis*.3
					opened=age-node.Opened
				end
				self.PortalPosition=pos
				display(node.Card,CFrame.new(pos+Vector3.yAxis*.14),portalSize*clamp(opened/.25),opacity*(if role=="Projectile" then clamp((1.1-opened)/.2) else 1),0)
			else
				local pos=self.PortalPosition or center
				local a=phase*TAU+node.Yaw;local r=math.sin(phase*math.pi)*portalSize*.3
				local v=node.Native*(.15+node.V*.22)
				Assets.place(node.Part,CFrame.new(pos+Vector3.new(math.cos(a)*r,phase*5,math.sin(a)*r))*CFrame.Angles(0,a,.25),v)
				node.Part.Transparency=1-opacity*clamp((1-phase)/.3)
			end
		end
	end
end

function Dynamics:Destroy()
	for _,node in self.Nodes do
		if node.Mesh then Assets.releaseMesh(node.Part) else node.Part:Destroy() end
	end
	for _,p in self.Surfaces do p:Destroy() end
end

return Dynamics
]=];end
do local parent=s.Signature;local m=parent:FindFirstChild("StreamBeam")
if m and not backup:FindFirstChild("StreamBeam") then m:Clone().Parent=backup end
if not m then m=Instance.new("ModuleScript");m.Name="StreamBeam";m.Parent=parent end
m.Source=[=[-- Continuous intersecting ribbons: existing banded trail art flows inside a connected volume.
local StreamBeam={}
StreamBeam.__index=StreamBeam

function StreamBeam.new(host,parent,texture,colors,params,capacity,bands)
	if capacity<2 then return nil end
	local count=math.min(if params.PlainStream then 4 else 6,capacity)
	local self=setmetatable({Ribbons={},Count=count,Params=params},StreamBeam)
	for i=1,count do
		local a,b=Instance.new("Attachment"),Instance.new("Attachment")
		-- Crossed planes retain thickness as the camera orbits, without billboard spin.
		local detail=i>4
		local inner=i>2 and i<=4
		local roll=if inner then math.pi/4+(i-3)*math.pi/2 else (i-1)*math.pi/2
		a.CFrame=CFrame.Angles(0,0,roll);b.CFrame=a.CFrame;a.Parent=host;b.Parent=host
		local beam=Instance.new("Beam");beam.Name="ContinuousStreamRibbon"
		beam.Attachment0=a;beam.Attachment1=b;beam.FaceCamera=false;beam.Segments=16
		beam.Texture=if detail then texture else ""
		beam.TextureMode=Enum.TextureMode.Wrap
		beam.Color=if not detail and bands then ColorSequence.new(bands[if inner then 3 else 2]) else colors
		beam.TextureSpeed=params.FlowSpeed or 3
		beam.LightEmission=.15;beam.LightInfluence=.25
		beam.Transparency=NumberSequence.new(if detail then .12 else 0)
		beam.Parent=parent
		table.insert(self.Ribbons,{Beam=beam,Start=a,End=b,Roll=roll,Inner=inner,Detail=detail})
	end
	return self
end

function StreamBeam:Update(range,width,age,shown,fading)
	for _,ribbon in self.Ribbons do
		local scale=(if ribbon.Inner then .55 else (if ribbon.Detail then 1.25 else 1.1))*(self.Params.BodyWidth or 1)
		local w=math.max(.15,width*scale)*(1-fading)
		local offset=if ribbon.Detail then Vector3.new(.008,.008,0) else Vector3.zero
		ribbon.Start.CFrame=CFrame.new(offset)*CFrame.Angles(0,0,ribbon.Roll)
		ribbon.End.CFrame=CFrame.new(offset+Vector3.new(0,0,-range))*CFrame.Angles(0,0,ribbon.Roll)
		local swell=1+.045*math.sin(age*(self.Params.FlowPulse or 6)+ribbon.Roll)
		ribbon.Beam.Width0=w*swell;ribbon.Beam.Width1=w*(self.Params.EndWidth or 1.1)/swell
		ribbon.Beam.TextureLength=math.max(1,width*(self.Params.FlowLength or 4))
		ribbon.Beam.Enabled=shown and fading<1
	end
end

return StreamBeam
]=];end
do local parent=s.Signature;local m=parent:FindFirstChild("PathGlyphs")
if m and not backup:FindFirstChild("PathGlyphs") then m:Clone().Parent=backup end
if not m then m=Instance.new("ModuleScript");m.Name="PathGlyphs";m.Parent=parent end
m.Source=[=[-- Existing rune/rift atlases open at fixed stations; nothing is launched along the path.
local PathGlyphs={}
PathGlyphs.__index=PathGlyphs

function PathGlyphs.new(host,texture,layout,colors,params,capacity,frameTexture)
	local perStation=if frameTexture or params.Outflow then 2 else 1
	local count=math.min(params.PathGlyphCount or 7,math.floor(capacity/perStation))
	if count<1 then return nil end
	local self=setmetatable({Stations={},Count=count*perStation,Rate=if params.Outflow then count*5 else 0,Params=params},PathGlyphs)
	for i=1,count do
		local point=Instance.new("Attachment");point.Name="PathStation";point.Parent=host
		local e=Instance.new("ParticleEmitter");e.Name="StationaryPathGlyph"
		e.Texture=texture;e.FlipbookLayout=layout;e.Color=colors
		if layout~=Enum.ParticleFlipbookLayout.None then
			e.FlipbookMode=if params.OpenInPlace then Enum.ParticleFlipbookMode.OneShot else Enum.ParticleFlipbookMode.Random
			e.FlipbookStartRandom=not params.OpenInPlace
		end
		e.Speed=NumberRange.new(0);e.RotSpeed=NumberRange.new(0);e.Rotation=NumberRange.new(0)
		e.LockedToPart=true;e.Acceleration=Vector3.zero;e.Rate=0;e.Enabled=false
		e.Lifetime=NumberRange.new(params.GlyphLifetime or 1.25)
		e.LightEmission=.15;e.LightInfluence=.25;e.Brightness=1
		e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.15,0),
			NumberSequenceKeypoint.new(.75,0),NumberSequenceKeypoint.new(1,1)})
		if params.Endpoints then e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.8,0),NumberSequenceKeypoint.new(1,1)}) end
		e.Parent=point
		local frame
		if frameTexture then
			frame=e:Clone();frame.Name="GeometricRuneEnclosure";frame.Texture=frameTexture
			frame.FlipbookLayout=Enum.ParticleFlipbookLayout.None;frame.ZOffset=-.02;frame.Parent=point
		end
		local outflow
		if params.Outflow then
			outflow=Instance.new("ParticleEmitter");outflow.Name="RiftOutflow"
			outflow.Texture=require(script.Parent.Parent.Assets.VFXAssets).texture("star_mote","Space")
			outflow.Speed=NumberRange.new(1,2.5);outflow.Lifetime=NumberRange.new(.6,1)
			outflow.Rate=5;outflow.SpreadAngle=Vector2.new(55,55);outflow.Size=NumberSequence.new(.18,0)
			outflow.Transparency=NumberSequence.new(0,1);outflow.LightEmission=.2;outflow.Enabled=false;outflow.Parent=point
		end
		table.insert(self.Stations,{Point=point,Emitter=e,Frame=frame,Outflow=outflow,
			U=if params.Endpoints then (i-1)/math.max(1,count-1) else i/(count+1),Next=(i-1)*.035})
	end
	return self
end

function PathGlyphs:Update(range,width,age,shown,ending,canEmit)
	for _,station in self.Stations do
		station.Point.Position=Vector3.new(0,0,-range*station.U)
		if station.Outflow then station.Outflow.Enabled=shown and not ending end
		local spacing=range/(#self.Stations+1)
		local size=math.min(math.clamp(width*(self.Params.GlyphSize or 2),.7,5),spacing*(if station.Frame then .45 else .85))
		if station.Size~=size then
			station.Size=size
			station.Emitter.Size=NumberSequence.new(size)
			if station.Frame then station.Frame.Size=NumberSequence.new(size*1.8) end
		end
		if shown and not ending and age>=station.Next then
			if canEmit(if station.Frame then 2 else 1) then
				station.Emitter:Emit(1)
				if station.Frame then station.Frame:Emit(1) end
			end
			station.Next=age+(self.Params.GlyphLifetime or 1.25)*1.05
		end
	end
end

return PathGlyphs
]=];end
do local parent=s.Signature;local m=parent:FindFirstChild("SignaturePlanner")
if m and not backup:FindFirstChild("SignaturePlanner") then m:Clone().Parent=backup end
if not m then m=Instance.new("ModuleScript");m.Name="SignaturePlanner";m.Parent=parent end
m.Source=[=[-- Pure: (analyzer plan, anchor phase/role, quality) -> resolved signature layers.
-- Gameplay numbers only reach this module as the analyzer's normalized features, so visual scale
-- never feeds back into hit size. No instances, no services, no randomness.
local Library = require(script.Parent.SignatureLibrary)
local Styled = require(script.Parent.Parent.Assets.StyledVFXManifest)
local Planner = {}

local function clamp01(x)
	if type(x) ~= "number" or x ~= x then
		return 0
	end
	return math.clamp(x, 0, 1)
end

-- Visual scalars (0..1) derived from the spell's mechanical features.
--   Size     body of the spell (projectile hit radius, area radius or beam width)
--   Potency  direct damage or damage-over-time total: instability and impact detail, not scale
--   Speed    projectile/aerial speed: stretch and trail behaviour
--   Charge   cast + maximum charge time: how much visibly accumulates before release
--   Range, Homing, Force, Lifetime  as named
--   Area     impact area (explode radius) or area radius
function Planner.scalars(plan)
	local f = plan.Features or {}
	local impactRadius = tonumber(plan.ImpactRadius) or 0
	local area = if impactRadius > 0 then math.sqrt(math.min(impactRadius, 20) / 20) else f.Radius or 0
	return {
		Size = clamp01(math.max(f.Size or 0, (f.Radius or 0) * 0.8, f.Width or 0)),
		Potency = clamp01(math.max(f.Direct or 0, (f.DotTotal or 0) * 0.85)),
		Speed = clamp01(f.Speed),
		Charge = clamp01(f.Cast),
		Range = clamp01(f.Range),
		Homing = clamp01(f.Homing),
		Force = clamp01(f.Force),
		Lifetime = clamp01(math.max(f.Lifetime or 0, f.Linger or 0)),
		Area = clamp01(area),
	}
end

function Planner.match(plan)
	local match = Library.Match
	local name = match.Element[plan.Element or ""]
		or match.Expression[plan.Expression or ""]
		or match.Principle[plan.Principle or ""]
		or match.Fallback
	return if name then Library.Signatures[name] else nil
end

-- Which component drives an anchor: the caster cue, a hit, or the spell's gameplay form.
function Planner.role(plan, phase, castingCue)
	if castingCue then
		return "Cast"
	elseif phase == "Impact" then
		return "Impact"
	end
	return if Library.Components[plan.Form or ""] then plan.Form else "Projectile"
end

local function slotsFor(role, phase)
	local component = Library.Components[role]
	if not component then
		return {}
	end
	return component[phase] or component.Sustain or component.Release or component.Gather or {}
end

-- Pure HSV boost (no Color3:ToHSV, so it also runs under the plain Luau test harness).
local function boost(color, saturation, value)
	local r, g, b = color.R, color.G, color.B
	local maxc, minc = math.max(r, g, b), math.min(r, g, b)
	local v = maxc
	local s = if maxc > 0 then (maxc - minc) / maxc else 0
	if maxc == minc then
		local grey = math.min(1, v * value)
		return Color3.new(grey, grey, grey)
	end
	local h
	if maxc == r then
		h = ((g - b) / (maxc - minc)) % 6
	elseif maxc == g then
		h = (b - r) / (maxc - minc) + 2
	else
		h = (r - g) / (maxc - minc) + 4
	end
	h /= 6
	s, v = math.min(1, s * saturation), math.min(1, v * value)
	local i = math.floor(h * 6) % 6
	local f = h * 6 - math.floor(h * 6)
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local rr, gg, bb
	if i == 0 then
		rr, gg, bb = v, t, p
	elseif i == 1 then
		rr, gg, bb = q, v, p
	elseif i == 2 then
		rr, gg, bb = p, v, t
	elseif i == 3 then
		rr, gg, bb = p, q, v
	elseif i == 4 then
		rr, gg, bb = t, p, v
	else
		rr, gg, bb = v, p, q
	end
	return Color3.new(rr, gg, bb)
end
Planner.boost = boost

local function tint(signature, plan)
	local colors = {}
	local bands = Styled.Enabled and Styled.Palettes[signature.Name]
	local bandTokens = { Hi=3, Mid=2, Lo=1, Smoke=1, Ink=5, WhiteHot=4, Hot=3,
		Body=2, Deep=1, Ember=3, Soot=5, Ash=1, Bone=3, Sinew=2, Bruise=1, Grit=1, Air=4 }
	local custom = plan.Color
	local style = Library.Style or {}
	for token, color in pairs(signature.Palette) do
		if bands and bandTokens[token] then
			colors[token] = bands[bandTokens[token]]
			continue
		end
		local amount = signature.Tintable[token]
		local c = if custom and amount then color:Lerp(custom, amount) else color
		-- Cel look: punchier, brighter colours; ink stays ink.
		colors[token] = if token == "Ink" then c else boost(c, style.Saturation or 1, style.Value or 1)
	end
	return colors
end

local function resolveParams(spec, scalars)
	local params = table.clone(spec.Params)
	for _, driver in ipairs(spec.Drivers) do
		local param, scalar, weight = driver[1], driver[2], driver[3]
		params[param] = (params[param] or 0) + weight * (scalars[scalar] or 0)
	end
	for param, range in pairs(spec.Limits) do
		if type(params[param]) == "number" then
			params[param] = math.clamp(params[param], range[1], range[2])
		end
	end
	return params
end

-- Returns nil when no signature covers this spell. Otherwise:
-- { Signature, Role, Slots, Scalars, Replaces, Layers = { { Id, Slot, Kind, Priority, Texture, Mesh,
--   Meshes, Colors = { Color3... }, Params } } }
function Planner.plan(plan, phase, options)
	options = options or {}
	local signature = Planner.match(plan)
	if not signature then
		return nil
	end
	local role = Planner.role(plan, phase, options.CastingCue)
	local slots = slotsFor(role, phase or "Sustain")
	local wanted = {}
	for _, slot in ipairs(slots) do
		wanted[slot] = true
	end
	local quality = Library.Quality[options.Quality or "High"] or Library.Quality.High
	local scalars = Planner.scalars(plan)
	local palette = tint(signature, plan)
	local layers = {}
	local sourceLayers = if role == "Projectile" and phase ~= "End" and signature.ProjectileLayers and options.DirectionalSprites ~= false
		then signature.ProjectileLayers else signature.Layers
	for _, slot in ipairs(Library.Slots) do
		if wanted[slot] then
			for _, spec in ipairs(sourceLayers) do
				local formOk = (spec.Forms == nil or spec.Forms[plan.Form or ""] == true)
					and (spec.Roles == nil or spec.Roles[role] == true)
				local kindOk = (spec.Kind ~= "Light" or quality.Lights or spec.Priority==1)
					and ((spec.Kind ~= "Mesh" and spec.Kind ~= "Debris") or quality.Meshes or spec.Priority == 1)
				-- Release cues acknowledge the cast; impact artwork belongs at the destination.
				if role=="Cast" and phase=="Release" and spec.Kind~="Light" then kindOk=false end
				-- Ending/culling a visual is not a hit. New clouds and debris bursts
				-- belong to the explicit Impact anchor, which already owns this slot.
				if spec.Slot=="Dissipate" and spec.Kind=="Burst" and role~="Impact" then kindOk=false end
				if spec.Slot == slot and formOk and kindOk and spec.Priority <= quality.MaxPriority then
					local params = resolveParams(spec, scalars)
					if Styled.Enabled and (spec.Kind == "Mesh" or spec.Kind == "Debris") then
						params.Material = "SmoothPlastic"
					end
					if params.Rate then
						params.Rate *= quality.Rate
					end
					if params.Count then
						params.Count = math.max(1, math.floor(params.Count * quality.Count + 0.5))
					end
					local tokens = if type(spec.Colors) == "table" then spec.Colors else { spec.Colors or "Body" }
					local colors = {}
					for i, token in ipairs(tokens) do
						colors[i] = palette[token] or Color3.new(1, 1, 1)
					end
					table.insert(layers, {
						Id = spec.Id,
						Slot = slot,
						Kind = spec.Kind,
						Priority = spec.Priority,
						Texture = spec.Texture,
						FrameTexture = spec.FrameTexture,
						DirectionalAsset = spec.DirectionalAsset,
						Mesh = spec.Mesh,
						Meshes = spec.Meshes,
						Colors = colors,
						Params = params,
					})
				end
			end
		end
	end
	return {
		Signature = signature.Name,
		Role = role,
		Slots = slots,
		Scalars = scalars,
		Replaces = signature.Replaces[role] or signature.Replaces.Default or {},
		Layers = layers,
	}
end

return Planner
]=];end
do local parent=s.Signature;local m=parent:FindFirstChild("SignatureKits")
if m and not backup:FindFirstChild("SignatureKits") then m:Clone().Parent=backup end
if not m then m=Instance.new("ModuleScript");m.Name="SignatureKits";m.Parent=parent end
m.Source=[=[-- Pure data: identity kits and the form templates that turn a kit into signature layers.
-- A kit names its assets per visual role, a four-tone palette and a few motion "feel" numbers.
-- Templates then produce Projectile, Beam, Wave, Field, Aura, SelfEnhancement, Construct,
-- Manipulation, Cast (charge/release), Impact and Dissipate layers for it. Hand-authored
-- signature layers (Fire's projectile, Body's wave) replace the template for the roles they own.
--
-- Art direction: cel-shaded dark fantasy. Bodies render with low light emission so the ink
-- outlines baked into the textures (and the `_ink` hull meshes) stay visible; only sparks,
-- flashes and cores marked Glow stay additive.
local Kits = {}

local function layer(t)
	t.Params = t.Params or {}
	t.Drivers = t.Drivers or {}
	t.Limits = t.Limits or {}
	return t
end
Kits.layer = layer

-- Palette tokens every kit defines: Hi (lit), Mid (body), Lo (shadow), Smoke, plus Ink.
local INK = Color3.fromRGB(14, 10, 14)

-- Template: one entry per (role, visual job). `a` = kit.Assets, `f` = kit.Feel.
local function templates(kit)
	local a, f, id = kit.Assets, kit.Feel, kit.Name
	local L = {}
	local function add(t)
		t.Id = id .. "." .. t.Id
		table.insert(L, layer(t))
	end
	local rise = f.Rise or 2
	local light = f.Light or 0.2
	local spin = f.Spin or 1

	-- Projectile -------------------------------------------------------------------------------
	add({
		Id = "Projectile.Core",
		Slot = "Core",
		Kind = "Sprite",
		Priority = 1,
		Roles = { Projectile = true },
		Texture = a.Core,
		Colors = { "Hi", "Mid" },
		Params = { Size = 1.35, Framerate = f.Framerate or 20, RotSpeed = 40 * spin, Light = light + 0.15 },
		Drivers = { { "Framerate", "Potency", 14 }, { "Size", "Potency", 0.25 } },
	})
	if a.CoreMesh then
		add({
			Id = "Projectile.Body",
			Slot = "Core",
			Kind = "Mesh",
			Priority = 2,
			Roles = { Projectile = true },
			Mesh = a.CoreMesh,
			Colors = "Mid",
			Params = {
				Size = f.CoreMeshSize or 0.5,
				Spin = 2.5 * spin,
				Wobble = 0.05,
				Opacity = 1,
				Material = "SmoothPlastic",
				Orient = "Travel",
				RequireAsset = 1,
				Ink = 1,
			},
			Drivers = { { "Spin", "Potency", 2 }, { "Wobble", "Potency", 0.12 } },
		})
	end
	add({
		Id = "Projectile.Stream",
		Slot = "Shell",
		Kind = "Emitter",
		Priority = 1,
		Roles = { Projectile = true },
		Texture = a.Particle,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Rate = 14,
			Lifetime = 0.36,
			Speed = 2,
			Spread = 24,
			Direction = "Back",
			Size = 1.0,
			SizeEnd = 0.3,
			Framerate = f.Framerate or 24,
			Light = light,
			RotSpeed = 60,
			Drag = f.Drag or 1,
		},
		Drivers = { { "Rate", "Size", 12 }, { "Rate", "Potency", 10 }, { "Speed", "Speed", 5 } },
		Limits = { Rate = { 6, 40 } },
	})
	add({
		Id = "Projectile.Trail",
		Slot = "Trail",
		Kind = "Trail",
		Priority = 1,
		Roles = { Projectile = true },
		Texture = a.Trail,
		Colors = { "Hi", "Mid", "Lo" },
		Params = { Width = 1.1, Lifetime = 0.22, Opacity = 1, Light = light, TextureLength = 4 },
		Drivers = { { "Lifetime", "Homing", 0.35 }, { "Lifetime", "Range", 0.1 } },
		Limits = { Lifetime = { 0.12, 0.6 } },
	})
	add({
		Id = "Projectile.Motes",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 2,
		Roles = { Projectile = true },
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Rate = 8,
			Lifetime = 0.6,
			Speed = 3,
			Spread = 70,
			Direction = "Back",
			Size = 0.32,
			SizeEnd = 0.05,
			Drag = 2,
			Rise = rise,
			Light = 0.6,
			Glow = 1,
			RandomRotation = 1,
			Framerate = 0,
		},
		Drivers = { { "Rate", "Potency", 14 } },
	})
	add({
		Id = "Projectile.Light",
		Slot = "Ambient",
		Kind = "Light",
		Priority = 3,
		Roles = { Projectile = true },
		Colors = "Mid",
		Params = { Brightness = 1.1, Range = 9 },
		Drivers = { { "Brightness", "Potency", 0.8 } },
	})

	-- Beam -------------------------------------------------------------------------------------
	if f.PathGlyphs then
		add({Id="Beam.PathGlyphs",Slot="Core",Kind="PathGlyphs",Priority=1,Roles={Beam=true},
			Texture=a.BeamGlyph or a.Particle,FrameTexture=if f.GeometricFrame then a.Sigil else nil,Colors={"Hi","Mid"},
			Params={PathGlyphCount=if f.VoidAll then 3 else 7,GlyphSize=if f.GeometricFrame then 1.6 else 4.5,
				GlyphLifetime=if f.GeometricFrame then 1.6 else 1.25,OpenInPlace=not f.GeometricFrame,
				Outflow=f.VoidAll}})
		if f.GeometricFrame then
			add({Id="Beam.ThroughSigils",Slot="Core",Kind="Beam",Priority=1,Roles={Beam=true},Texture="glow_soft",Colors={"Hi","Mid"},
				Params={ContinuousStream=true,PlainStream=true,BodyWidth=.32,FlowSpeed=3,EndWidth=1}})
		end
	else
	add({
		Id = "Beam.Core",
		Slot = "Core",
		Kind = "Beam",
		Priority = 1,
		Roles = { Beam = true },
		Texture = a.Beam,
		Colors = { "Hi", "Mid" },
		Params = {
			Width = if f.BeamArc then 0.22 else 1,
			Opacity = 1,
			Light = light + 0.2,
			TextureLength = 5,
			Scroll = f.Scroll or 3,
			Wobble = f.Wobble or 0,
			ArcSegments = f.BeamArc,
			ContinuousStream = f.StreamBeam,
			FlowSpeed = f.StreamSpeed,
			FlowLength = f.StreamLength,
			EndWidth = f.StreamEndWidth,
			PlainStream = f.BeamClocks,
		},
	})
	if not f.BeamArc and not f.StreamBeam then
	add({
		Id = "Beam.Outer",
		Slot = "Core",
		Kind = "Beam",
		Priority = 2,
		Roles = { Beam = true },
		Texture = a.Trail,
		Colors = { "Mid", "Lo" },
		Params = {
			Width = 2.1,
			Opacity = 0.7,
			Light = light,
			TextureLength = 7,
			Scroll = -(f.Scroll or 3) * 0.6,
			Wobble = (f.Wobble or 0) * 1.5,
		},
	})
	add({
		Id = "Beam.Origin",
		Slot = "Core",
		Kind = "Sprite",
		Priority = 1,
		Roles = { Beam = true },
		Texture = a.Core,
		Colors = { "Hi", "Mid" },
		Params = { Size = 1.6, Framerate = f.Framerate or 20, Light = light + 0.15 },
	})
	add({
		Id = "Beam.End",
		Slot = "Secondary",
		Kind = "Sprite",
		Priority = 2,
		Roles = { Beam = true },
		Texture = a.Core,
		Colors = { "Hi", "Mid" },
		Params = { Size = 2.2, Framerate = f.Framerate or 20, Light = light + 0.15, Placement = "End" },
	})
	-- Flow: the school's main particle streams from the caster to the beam's end.
	add({
		Id = "Beam.Flow",
		Slot = "Secondary",
		Kind = "Emitter",
		Priority = 1,
		Roles = { Beam = true },
		Texture = a.Flow or a.Particle,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Rate = 9,
			Lifetime = 0.55,
			Speed = 20,
			Spread = 5,
			Direction = "Forward",
			Size = 1.4,
			SizeEnd = 0.9,
			Light = light,
			RangeSpeed = 1,
			RotSpeed = 30,
			Framerate = f.Framerate or 20,
		},
		Drivers = { { "Rate", "Potency", 8 }, { "Size", "Size", 0.8 } },
	})
	add({
		Id = "Beam.Motes",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 3,
		Roles = { Beam = true },
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Rate = 6,
			Lifetime = 0.5,
			Speed = 2,
			Spread = 180,
			Size = 0.3,
			SizeEnd = 0.05,
			Light = 0.6,
			Glow = 1,
			Placement = "Line",
			Rise = rise,
			RandomRotation = 1,
			Framerate = 0,
		},
	})
	end -- Connected arcs fill the path; no travelling glyphs or endpoint orbs.
	end -- Path glyphs replace the entire travelling beam template.
	if f.BeamClocks then
		add({Id="Beam.ClockEnds",Slot="Secondary",Kind="PathGlyphs",Priority=1,Roles={Beam=true},Texture=a.Sigil,Colors={"Hi"},
			Params={PathGlyphCount=2,GlyphSize=2.5,GlyphLifetime=.65,Endpoints=true}})
	end
	add({
		Id = "Beam.Light",
		Slot = "Ambient",
		Kind = "Light",
		Priority = 3,
		Roles = { Beam = true },
		Colors = "Mid",
		Params = { Brightness = 1.4, Range = 12, Placement = "End" },
	})

	-- Wave (template; Body overrides with its bespoke cone) ------------------------------------
	add({
		Id = "Wave.Fronts",
		Slot = "Shell",
		Kind = "Burst",
		Priority = 1,
		Roles = { Wave = true },
		Texture = a.Wave,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Count = 3,
			Lifetime = 0.3,
			Speed = 30,
			Spread = 12,
			Direction = "Forward",
			Size = 5,
			SizeEnd = 9,
			Orientation = "VelocityPerpendicular",
			OneShot = 1,
			Light = light,
			Stagger = 0.05,
			RangeSpeed = 1,
		},
		Drivers = { { "Size", "Force", 3 }, { "Count", "Potency", 2 } },
	})
	add({
		Id = "Wave.Body",
		Slot = "Secondary",
		Kind = "Burst",
		Priority = 2,
		Roles = { Wave = true },
		Texture = a.Particle,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Count = 10,
			Lifetime = 0.45,
			Speed = 26,
			Spread = 26,
			Direction = "Forward",
			Size = 1.8,
			SizeEnd = 0.6,
			Light = light,
			RandomRotation = 1,
			Framerate = f.Framerate or 24,
			RangeSpeed = 1,
			ShapeRadius = 1.2,
		},
		Drivers = { { "Count", "Potency", 10 } },
	})
	add({
		Id = "Wave.Front",
		Slot = "Impact",
		Kind = "Mesh",
		Priority = 2,
		Roles = { Wave = true },
		Mesh = "shockwave_ring",
		Colors = "Hi",
		Params = {
			Size = 0.5,
			Grow = 1,
			Duration = 0.32,
			Opacity = 0.85,
			Material = "Neon",
			Orient = "Front",
			Fade = 1,
		},
	})
	add({
		Id = "Wave.Floor",
		Slot = "Ambient",
		Kind = "Burst",
		Priority = 3,
		Roles = { Wave = true },
		Texture = a.Smoke,
		Colors = { "Smoke", "Lo" },
		Params = {
			Count = 5,
			Lifetime = 0.9,
			Speed = 12,
			Spread = 16,
			Direction = "Forward",
			Size = 2,
			SizeEnd = 4,
			Drag = 3,
			Light = 0,
			Opacity = 0.75,
			Floor = 1,
			RandomRotation = 1,
			OneShot = 1,
		},
	})

	-- Field --------------------------------------------------------------------------------------
	if f.FieldMode then
		add({Id="Field.Dynamics",Slot="Secondary",Kind="Dynamics",Priority=1,Roles={Field=true},Colors={"Hi","Mid"},
			Params={Mode=f.FieldMode,Ground=true}})
	else
	add({
		Id = "Field.Ground",
		Slot = "Secondary",
		Kind = "Decal",
		Priority = 1,
		Roles = { Field = true },
		Texture = a.Ground,
		Colors = "Mid",
		Params = { Opacity = 0.9, Spin = 0.08 * spin, Footprint = 1, Pulse = 0.08 },
	})
	add({
		Id = "Field.Edge",
		Slot = "Secondary",
		Kind = "Mesh",
		Priority = 1,
		Roles = { Field = true },
		Mesh = "shockwave_ring",
		Colors = "Hi",
		Params = { Opacity = 0.75, Material = "Neon", Orient = "Footprint", Spin = 0.15 * spin },
	})
	add({
		Id = "Field.Body",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 2,
		Roles = { Field = true },
		Texture = a.Particle,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Rate = 24,
			RatePerArea = 0.2,
			Lifetime = 0.9,
			Speed = 2.5,
			Spread = 15,
			Size = 1.6,
			SizeEnd = 0.6,
			Light = light,
			Placement = "Area",
			Direction = "Up",
			Rise = rise,
			Framerate = f.Framerate or 20,
			RotSpeed = 0,
		},
		Drivers = { { "Rate", "Potency", 8 } },
		Limits = { Rate = { 4, 40 } },
	})
	if a.Scatter then
		add({
			Id = "Field.Scatter",
			Slot = "Ambient",
			Kind = "Mesh",
			Priority = 2,
			Roles = { Field = true },
			Mesh = a.Scatter,
			Colors = "Mid",
			Params = {
				Count = 12,
				MaxCount = 24,
				CountPerArea = 0.08,
				Size = f.ScatterSize or 0.9,
				Duration = 0.35,
				Opacity = 1,
				Material = "SmoothPlastic",
				Orient = "Scatter",
				RequireAsset = 1,
				Ink = 1,
			},
		})
	end
	add({
		Id = "Field.Motes",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 3,
		Roles = { Field = true },
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Rate = 6,
			RatePerArea = 0.06,
			Lifetime = 1.4,
			Speed = 1.5,
			Spread = 25,
			Size = 0.35,
			SizeEnd = 0.05,
			Light = 0.6,
			Glow = 1,
			Placement = "Area",
			Direction = "Up",
			Rise = rise,
			RandomRotation = 1,
			Framerate = 0,
		},
		Limits = { Rate = { 2, 24 } },
	})
	add({
		Id = "Field.Light",
		Slot = "Ambient",
		Kind = "Light",
		Priority = 3,
		Roles = { Field = true },
		Colors = "Mid",
		Params = { Brightness = 0.9, Range = 14 },
	})
	end

	-- Aura / SelfEnhancement -------------------------------------------------------------------
	if f.SpiritOrbit then
		add({Id="Aura.OrbitSpirits",Slot="Shell",Kind="Dynamics",Priority=1,Roles={Aura=true,SelfEnhancement=true},Colors={"Hi","Mid"},
			Params={Mode="OrbitWisps"}})
	else
	add({
		Id = "Aura.Mantle",
		Slot = "Shell",
		Kind = "Emitter",
		Priority = 1,
		Roles = { Aura = true, SelfEnhancement = true },
		Texture = a.Aura or a.Particle,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Rate = 14,
			Lifetime = 0.8,
			Speed = 2,
			Spread = 10,
			Size = 1.4,
			SizeEnd = 0.4,
			Light = light,
			Placement = "Body",
			Direction = "Up",
			Rise = rise,
			Framerate = f.Framerate or 20,
			RotSpeed = 20,
		},
		Drivers = { { "Rate", "Potency", 8 } },
	})
	add({
		Id = "Aura.Motes",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 2,
		Roles = { Aura = true, SelfEnhancement = true },
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Rate = 8,
			Lifetime = 1.2,
			Speed = 1,
			Spread = 40,
			Size = 0.3,
			SizeEnd = 0.05,
			Light = 0.6,
			Glow = 1,
			Placement = "Body",
			Direction = "Up",
			Rise = rise,
			RandomRotation = 1,
			Framerate = 0,
		},
	})
	add({
		Id = "Aura.Ground",
		Slot = "Ambient",
		Kind = "Decal",
		Priority = 2,
		Roles = { Aura = true },
		Texture = a.Sigil or a.Ground,
		Colors = "Mid",
		Params = { Opacity = 0.7, Spin = 0.25 * spin, Footprint = 1 },
	})
	add({
		Id = "Aura.Light",
		Slot = "Ambient",
		Kind = "Light",
		Priority = 3,
		Roles = { Aura = true, SelfEnhancement = true },
		Colors = "Mid",
		Params = { Brightness = 0.8, Range = 10 },
	})
	end

	-- Construct / Manipulation -----------------------------------------------------------------
	add({
		Id = "Construct.Surface",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 1,
		Roles = { Construct = true, Manipulation = true },
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Rate = 10,
			RatePerArea = 0.3,
			Lifetime = 0.9,
			Speed = 1,
			Spread = 30,
			Size = 0.4,
			SizeEnd = 0.05,
			Light = 0.6,
			Glow = 1,
			Placement = "Box",
			Rise = rise,
			RandomRotation = 1,
			Framerate = 0,
		},
		Limits = { Rate = { 4, 30 } },
	})
	add({
		Id = "Construct.Crest",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 2,
		Roles = { Construct = true, Manipulation = true },
		Texture = a.Particle,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Rate = 6,
			Lifetime = 0.7,
			Speed = 2,
			Spread = 15,
			Size = 1.0,
			SizeEnd = 0.3,
			Light = light,
			Placement = "Top",
			Direction = "Up",
			Rise = rise,
			Framerate = f.Framerate or 20,
		},
	})

	-- Cast: charge (Gather) and release --------------------------------------------------------
	add({
		Id = "Charge.Converge",
		Slot = "Charge",
		Kind = "Emitter",
		Priority = 2,
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Rate = 10,
			Lifetime = 0.35,
			Speed = 9,
			Size = 0.32,
			SizeEnd = 0.05,
			Direction = "In",
			ShapeRadius = 3.2,
			Light = 0.7,
			Glow = 1,
			Ramp = 1,
			OffsetZ = -1.6,
			OffsetY = 0.5,
			Framerate = 0,
			RandomRotation = 1,
		},
		Drivers = { { "Rate", "Charge", 20 } },
	})
	add({
		Id = "Charge.Point",
		Slot = "Charge",
		Kind = "Sprite",
		Priority = 1,
		Texture = a.Core,
		Colors = { "Hi", "Mid" },
		Params = {
			Size = 0.5,
			Grow = 1.3,
			Framerate = f.Framerate or 20,
			Light = light + 0.2,
			Ramp = 1,
			OffsetZ = -1.6,
			OffsetY = 0.5,
		},
		Drivers = { { "Grow", "Charge", 1 } },
	})
	add({
		Id = "Charge.Sigil",
		Slot = "Charge",
		Kind = "Decal",
		Priority = 2,
		Texture = a.Sigil or "rune_circle",
		Colors = "Mid",
		Params = { Size = 4.5, Opacity = 0.85, Spin = 0.9 * spin, Ramp = 1 },
		Drivers = { { "Spin", "Charge", 1.2 } },
	})
	add({
		Id = "Cast.Flash",
		Slot = "Cast",
		Kind = "Burst",
		Priority = 1,
		-- A small flash of the school's core at the hand (not its impact cloud).
		Texture = a.Core,
		Colors = { "Hi", "Mid" },
		Params = {
			Count = 1,
			Lifetime = 0.25,
			Speed = 0,
			Size = 1.4,
			SizeEnd = 2.2,
			Light = light + 0.25,
			Framerate = f.Framerate or 20,
			OffsetZ = -1.8,
			OffsetY = 0.5,
			RandomRotation = 1,
		},
	})
	add({
		Id = "Cast.Spray",
		Slot = "Cast",
		Kind = "Burst",
		Priority = 2,
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Count = 7,
			Lifetime = 0.4,
			Speed = 14,
			Spread = 30,
			Direction = "Forward",
			Size = 0.35,
			SizeEnd = 0.05,
			Drag = 3,
			Light = 0.7,
			Glow = 1,
			OffsetZ = -1.8,
			OffsetY = 0.5,
			RandomRotation = 1,
			Framerate = 0,
		},
	})

	-- Impact & dissipation ---------------------------------------------------------------------
	add({
		Id = "Impact.Flash",
		Slot = "Impact",
		Kind = "Burst",
		Priority = 1,
		Roles = { Impact = true },
		Texture = "impact_frame",
		Colors = { "Hi", "Mid" },
		Params = { Count = 1, Lifetime = 0.1, Speed = 0, Size = 4.5, SizeEnd = 6, Light = 0.3, RandomRotation = 1 },
		Drivers = { { "Size", "Area", 4 } },
	})
	add({
		Id = "Impact.Burst",
		Slot = "Impact",
		Kind = "Burst",
		Priority = 1,
		Roles = { Impact = true },
		Texture = a.Impact,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Count = 1,
			Lifetime = 0.6,
			Speed = 0,
			Size = 6,
			SizeEnd = 8,
			Light = light,
			OneShot = 1,
			RandomRotation = 1,
		},
		Drivers = { { "Size", "Area", 7 }, { "SizeEnd", "Area", 9 }, { "Count", "Potency", 1 } },
	})
	add({
		Id = "Impact.Ring",
		Slot = "Impact",
		Kind = "Burst",
		Priority = 2,
		Roles = { Impact = true },
		Texture = "shockwave_ring",
		Colors = { "Hi", "Mid" },
		Params = { Count = 1, Lifetime = 0.3, Speed = 0, Size = 1, SizeEnd = 11, Light = 0.4, Opacity = 0.95 },
		Drivers = { { "SizeEnd", "Area", 12 } },
	})
	add({
		Id = "Impact.Spray",
		Slot = "Impact",
		Kind = "Burst",
		Priority = 2,
		Roles = { Impact = true },
		Texture = a.Mote,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Count = 12,
			Lifetime = 0.7,
			Speed = 22,
			Spread = 180,
			Direction = "Out",
			Size = 0.4,
			SizeEnd = 0.05,
			Drag = 3.5,
			Rise = -14 + rise,
			Light = 0.6,
			Glow = 1,
			RandomRotation = 1,
			Framerate = 0,
		},
		Drivers = { { "Count", "Potency", 16 } },
	})
	add({
		Id = "Impact.Mark",
		Slot = "Impact",
		Kind = "Decal",
		Priority = 3,
		Roles = { Impact = true },
		Texture = a.Ground,
		Colors = "Lo",
		Params = { Size = 5, Opacity = 0.85, Duration = 1.2, Fade = 1 },
		Drivers = { { "Size", "Area", 6 } },
	})
	if a.Debris then
		add({
			Id = "Impact.Debris",
			Slot = "Impact",
			Kind = "Debris",
			Priority = 3,
			Roles = { Impact = true },
			Meshes = a.Debris,
			Colors = "Mid",
			Params = {
				Count = 3,
				Speed = 18,
				Spread = 70,
				Size = f.DebrisSize or 0.5,
				Gravity = 65,
				Lifetime = 0.9,
				Material = "SmoothPlastic",
				Direction = "Up",
				Ink = 1,
			},
			Drivers = { { "Count", "Potency", 3 } },
		})
	end
	add({
		Id = "Impact.Light",
		Slot = "Impact",
		Kind = "Light",
		Priority = 3,
		Roles = { Impact = true },
		Colors = "Mid",
		Params = { Brightness = 3, Range = 14, Flash = 0.35 },
	})
	add({
		Id = "Dissipate.Smoke",
		Slot = "Dissipate",
		Kind = "Burst",
		Priority = 2,
		Texture = a.Smoke,
		Colors = { "Smoke", "Lo" },
		Params = {
			Count = 3,
			Lifetime = 1.3,
			Speed = 2.5,
			Spread = 180,
			Direction = "Out",
			Size = 2.4,
			SizeEnd = 4.5,
			Rise = 1.5,
			Drag = 1.5,
			Light = 0,
			Opacity = 0.8,
			OneShot = 1,
			Delay = 0.12,
			RandomRotation = 1,
		},
		Drivers = { { "Count", "Area", 3 } },
	})
	return L
end

-- Kit definitions. Assets reference VFXAssetManifest names. Every kit uses the same template set;
-- differences come from assets, palette and feel.
Kits.Definitions = {
	Fire = {
		Palette = {
			Hi = Color3.fromRGB(255, 226, 150),
			Mid = Color3.fromRGB(255, 112, 32),
			Lo = Color3.fromRGB(150, 30, 10),
			Smoke = Color3.fromRGB(48, 36, 34),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "core_plasma",
			CoreMesh = "fire_core",
			Particle = "flame_tongue",
			Mote = "ember_streak",
			Trail = "trail_flame",
			Beam = "trail_flame",
			Wave = "flame_tongue",
			Ground = "scorch_lichtenberg",
			Impact = "explosion_fire",
			Smoke = "smoke_billow",
			Sigil = "rune_circle",
			Debris = { "debris_rock_a", "debris_rock_c" },
		},
		Feel = { Light = 0.35, Rise = 6, Framerate = 26, Scroll = 4, Wobble = 0,
			StreamBeam=true,StreamSpeed=5,StreamLength=3,StreamEndWidth=1.5,FieldMode="Flames" },
	},
	Ice = {
		Palette = {
			Hi = Color3.fromRGB(236, 250, 255),
			Mid = Color3.fromRGB(120, 196, 255),
			Lo = Color3.fromRGB(34, 70, 140),
			Smoke = Color3.fromRGB(150, 180, 205),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "frost_mist",
			CoreMesh = "ice_spike",
			Particle = "frost_mist",
			Mote = "ice_glint",
			Trail = "ice_trail",
			Beam = "ice_trail",
			Wave = "frost_mist",
			Ground = "frost_crack",
			Impact = "ice_shatter",
			Smoke = "frost_mist",
			Sigil = "hex_seal",
			Scatter = "ice_cluster",
			Debris = { "ice_shard_a", "ice_shard_b" },
		},
		Feel = {
			Light = 0.15,
			Rise = -1,
			Framerate = 14,
			Spin = 0.5,
			Scroll = 1.5,
			CoreMeshSize = 0.45,
			ScatterSize = 0.8,
			FieldMode = "Crystals",
		},
	},
	Lightning = {
		Palette = {
			Hi = Color3.fromRGB(250, 248, 255),
			Mid = Color3.fromRGB(176, 150, 255),
			Lo = Color3.fromRGB(70, 40, 150),
			Smoke = Color3.fromRGB(60, 52, 80),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "plasma_orb",
			Particle = "arc_flicker",
			Mote = "arc_flicker",
			Trail = "bolt_strip",
			Beam = "bolt_strip",
			Wave = "spark_burst",
			Ground = "scorch_lichtenberg",
			Impact = "spark_burst",
			Smoke = "smoke_billow",
			Sigil = "rune_circle",
			Scatter = "lightning_fork",
		},
		Feel = { Light = 0.45, Rise = 0, Framerate = 30, Spin = 2, Scroll = 0, Wobble = 0, ScatterSize = 0.7, BeamArc = 9,FieldMode="Storm" },
	},
	Water = {
		Palette = {
			Hi = Color3.fromRGB(220, 246, 255),
			Mid = Color3.fromRGB(58, 148, 230),
			Lo = Color3.fromRGB(14, 52, 110),
			Smoke = Color3.fromRGB(170, 210, 235),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "water_orb",
			Particle = "water_splash",
			Flow = "droplet",
			Mote = "droplet",
			Trail = "water_trail",
			Beam = "water_trail",
			Wave = "ripple_ring",
			Ground = "caustics",
			Impact = "water_splash",
			Smoke = "ripple_ring",
			Sigil = "ripple_ring",
			Scatter = "water_crown",
			Debris = nil,
		},
		Feel = { Light = 0.12, Rise = -10, Framerate = 18, Spin = 0.6, Scroll = 2.5, Wobble = 0, ScatterSize = 1.0,
			StreamBeam=true,StreamSpeed=3,StreamLength=5,StreamEndWidth=.9,FieldMode="Ripples" },
	},
	Earth = {
		Palette = {
			Hi = Color3.fromRGB(226, 196, 150),
			Mid = Color3.fromRGB(140, 104, 70),
			Lo = Color3.fromRGB(58, 40, 30),
			Smoke = Color3.fromRGB(92, 78, 64),
		},
		Tintable = { Mid = 0.5, Lo = 0.4 },
		Assets = {
			Core = "dust_plume",
			Flow = "debris_chip",
			CoreMesh = "earth_boulder",
			Particle = "dust_plume",
			Mote = "debris_chip",
			Trail = "rubble_trail",
			Beam = "rubble_trail",
			Wave = "dust_plume",
			Ground = "earth_fissure",
			Impact = "rock_burst",
			Smoke = "dust_burst",
			Sigil = "earth_fissure",
			Scatter = "earth_spire",
			Debris = { "debris_rock_a", "debris_rock_b", "debris_rock_c" },
		},
		Feel = {
			Light = 0.0,
			Rise = -18,
			Framerate = 16,
			Spin = 0.3,
			Scroll = 1,
			CoreMeshSize = 0.6,
			ScatterSize = 0.8,
			DebrisSize = 0.6,
		},
	},
	Wind = {
		Palette = {
			Hi = Color3.fromRGB(240, 255, 250),
			Mid = Color3.fromRGB(150, 232, 205),
			Lo = Color3.fromRGB(46, 120, 110),
			Smoke = Color3.fromRGB(190, 225, 215),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "gust_strokes",
			Particle = "gust_strokes",
			Mote = "leaf_scrap",
			Trail = "gust_strokes",
			Beam = "gust_strokes",
			Wave = "pressure_wave",
			Ground = "gust_strokes",
			Impact = "pressure_wave",
			Smoke = "dust_burst",
			Sigil = "rune_circle",
			Scatter = "wind_funnel",
		},
		Feel = { Light = 0.1, Rise = 1, Framerate = 22, Spin = 0, Scroll = 6, Wobble = 0.2, ScatterSize = 0.9,
			FieldMode="Gusts",GustAll=true,NoSpin=true },
	},
	Poison = {
		Palette = {
			Hi = Color3.fromRGB(214, 255, 120),
			Mid = Color3.fromRGB(110, 190, 40),
			Lo = Color3.fromRGB(40, 70, 20),
			Smoke = Color3.fromRGB(70, 92, 40),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "miasma",
			CoreMesh = "poison_bubbles",
			Particle = "miasma",
			Mote = "toxic_bubble",
			Trail = "drip_trail",
			Beam = "drip_trail",
			Wave = "miasma",
			Ground = "toxic_pool",
			Impact = "acid_splat",
			Smoke = "miasma",
			Sigil = "toxic_pool",
			Scatter = "poison_thorn",
		},
		Feel = {
			Light = 0.1,
			Rise = 1.5,
			Framerate = 12,
			Spin = 0.5,
			Scroll = 1.2,
			CoreMeshSize = 0.5,
			ScatterSize = 0.7,
		},
	},
	Arcane = {
		Palette = {
			Hi = Color3.fromRGB(246, 226, 255),
			Mid = Color3.fromRGB(176, 110, 255),
			Lo = Color3.fromRGB(70, 30, 130),
			Smoke = Color3.fromRGB(60, 44, 80),
		},
		Tintable = { Mid = 0.7, Lo = 0.6, Hi = 0.25 },
		Assets = {
			Core = "arcane_orb",
			CoreMesh = "arcane_prism",
			Particle = "rune_circle",
			Mote = "rune_circle",
			Trail = "rune_circle",
			BeamGlyph = "arcane_glyphs",
			Beam = "glyph_chain",
			Wave = "arcane_burst",
			Ground = "hex_seal",
			Impact = "arcane_burst",
			Smoke = "smoke_billow",
			Sigil = "rune_circle",
			Scatter = "arcane_prism",
		},
		Feel = { Light = 0.3, Rise = 1, Framerate = 8, Spin = 1, Scroll = 2, CoreMeshSize = 0.4, ScatterSize = 0.6,
			PathGlyphs=true,GeometricFrame=true,FieldMode="Runes" },
	},
	Force = {
		Palette = {
			Hi = Color3.fromRGB(255, 255, 255),
			Mid = Color3.fromRGB(196, 210, 236),
			Lo = Color3.fromRGB(70, 82, 110),
			Smoke = Color3.fromRGB(150, 156, 170),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "kinetic_burst",
			Particle = "pressure_wave",
			Mote = "ember_streak",
			Trail = "force_streak",
			Beam = "force_streak",
			Wave = "pressure_wave",
			Ground = "ward_hex",
			Impact = "kinetic_burst",
			Smoke = "dust_burst",
			Sigil = "hex_seal",
			Scatter = "ward_dome",
			Aura = "ward_hex",
		},
		Feel = { Light = 0.15, Rise = 0, Framerate = 24, Spin = 0.8, Scroll = 8, ScatterSize = 1.2 },
	},
	Body = {
		Palette = {
			Hi = Color3.fromRGB(240, 222, 198),
			Mid = Color3.fromRGB(176, 52, 40),
			Lo = Color3.fromRGB(64, 22, 26),
			Smoke = Color3.fromRGB(96, 84, 74),
		},
		Tintable = { Mid = 0.55, Lo = 0.4 },
		Assets = {
			Core = "glow_soft",
			CoreMesh = "flesh_shard",
			Particle = "dust_burst",
			Mote = "debris_chip",
			Trail = "sinew_trail",
			Beam = "sinew_trail",
			Wave = "pressure_wave",
			Ground = "earth_fissure",
			Impact = "kinetic_burst",
			Smoke = "dust_burst",
			Sigil = "earth_fissure",
			Scatter = "sinew_tendril",
			Debris = { "flesh_shard", "debris_rock_a" },
			Aura = "pressure_wave",
		},
		Feel = {
			Light = 0.05,
			Rise = -2,
			Framerate = 18,
			Spin = 0.4,
			Scroll = 3,
			CoreMeshSize = 0.45,
			ScatterSize = 0.8,
		},
	},
	Spirit = {
		Palette = {
			Hi = Color3.fromRGB(220, 255, 246),
			Mid = Color3.fromRGB(80, 220, 190),
			Lo = Color3.fromRGB(16, 70, 76),
			Smoke = Color3.fromRGB(40, 60, 64),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "soul_wisp",
			CoreMesh = "soul_skull",
			Particle = "soul_wisp",
			Mote = "skull_mote",
			Trail = "ghost_trail",
			Beam = "ghost_trail",
			Wave = "soul_burst",
			Ground = "soul_sigil",
			Impact = "soul_burst",
			Smoke = "smoke_billow",
			Sigil = "soul_sigil",
			Scatter = "chain_link",
		},
		Feel = {
			Light = 0.25,
			Rise = 4,
			Framerate = 14,
			Spin = 0.6,
			Scroll = 2,
			Wobble = 0.6,
			CoreMeshSize = 0.55,
			ScatterSize = 0.6,
			FieldMode = "Wisps",
			SpiritOrbit = true,
		},
	},
	Space = {
		Palette = {
			Hi = Color3.fromRGB(236, 226, 255),
			Mid = Color3.fromRGB(130, 100, 255),
			Lo = Color3.fromRGB(16, 8, 40),
			Smoke = Color3.fromRGB(30, 22, 52),
		},
		Tintable = { Mid = 0.6, Lo = 0.3 },
		Assets = {
			Core = "void_orb",
			CoreMesh = "void_shard",
			Particle = "rift_tear",
			Mote = "star_mote",
			Trail = "shard_trail",
			Beam = "shard_trail",
			Wave = "warp_implode",
			Ground = "portal_rings",
			Impact = "warp_implode",
			Smoke = "smoke_billow",
			Sigil = "portal_rings",
			Scatter = "void_shard",
			Debris = { "void_shard" },
		},
		Feel = { Light = 0.2, Rise = 0, Framerate = 16, Spin = 1.5, Scroll = 3, CoreMeshSize = 0.45, ScatterSize = 0.7,
			PathGlyphs=true,FieldMode="Void",VoidAll=true },
	},
	Time = {
		Palette = {
			Hi = Color3.fromRGB(255, 244, 210),
			Mid = Color3.fromRGB(226, 182, 92),
			Lo = Color3.fromRGB(96, 64, 26),
			Smoke = Color3.fromRGB(150, 128, 92),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "time_ripple",
			Flow = "gear_mote",
			CoreMesh = "chrono_gear",
			Particle = "sand_trail",
			Mote = "gear_mote",
			Trail = "sand_trail",
			Beam = "sand_trail",
			Wave = "time_ripple",
			Ground = "clock_dial",
			Impact = "time_ripple",
			Smoke = "dust_burst",
			Sigil = "clock_dial",
			Scatter = "hourglass",
			Aura = "time_ripple",
		},
		Feel = { Light = 0.2, Rise = -1, Framerate = 12, Spin = 0.5, Scroll = 1, CoreMeshSize = 0.4, ScatterSize = 0.7,
			StreamBeam=true,StreamSpeed=3,StreamLength=4,StreamEndWidth=1,BeamClocks=true },
	},
}

-- Builds a full signature from a kit, then lets hand-authored layers (same Slot, owning Roles)
-- replace template layers for the roles they cover.
function Kits.build(name, bespoke)
	local kit = table.clone(Kits.Definitions[name])
	kit.Name = name
	local palette = table.clone(kit.Palette)
	palette.Ink = INK
	local layers = templates(kit)
	local owned = (bespoke and bespoke.Owns) or {}
	if bespoke then
		local kept = {}
		for _, t in ipairs(layers) do
			local roles = t.Roles
			local overlapped = false
			if roles then
				for role in pairs(roles) do
					if owned[role] then
						overlapped = true
					end
				end
			elseif owned.Cast and (t.Slot == "Charge" or t.Slot == "Cast") then
				overlapped = true
			end
			if not overlapped then
				table.insert(kept, t)
			end
		end
		-- Role-less authored layers (wisps, embers, dissipation) belong to the roles the author owns,
		-- except slot-wide ones (Charge/Cast/Dissipate) which replace the template's role-less layers.
		local authoredSlots = {}
		for _, t in ipairs(bespoke.Layers) do
			if not t.Roles then
				authoredSlots[t.Slot] = true
			end
		end
		layers = {}
		for _, t in ipairs(kept) do
			if t.Roles or not authoredSlots[t.Slot] then
				table.insert(layers, t)
			end
		end
		for _, t in ipairs(bespoke.Layers) do
			local copy = table.clone(t)
			-- A connected fluid body replaces legacy spinning core sprites at its source.
			if kit.Feel.StreamBeam and copy.Roles and copy.Roles.Beam then
				copy.Roles=table.clone(copy.Roles);copy.Roles.Beam=nil
			end
			if not copy.Roles and copy.Slot ~= "Charge" and copy.Slot ~= "Cast" and copy.Slot ~= "Dissipate" then
				copy.Roles = table.clone(owned)
			end
			table.insert(layers, copy)
		end
		for token, color in pairs(bespoke.Palette or {}) do
			palette[token] = color
		end
	end
	if kit.Feel.VoidAll or kit.Feel.GustAll then
		local roles=if kit.Feel.VoidAll then {Projectile="Core",Wave="Core",Aura="Shell",SelfEnhancement="Shell",Construct="Ambient",Manipulation="Ambient",Impact="Impact"}
			else {Projectile="Core",Aura="Shell",SelfEnhancement="Shell"}
		local kept={}
		for _,t in layers do
			local replace=false
			for role in roles do if t.Roles and t.Roles[role] then replace=true end end
			if kit.Feel.VoidAll and (t.Slot=="Dissipate" or t.Slot=="Charge") then replace=true end
			if not replace then table.insert(kept,t) end
		end
		layers=kept
		for role,slot in roles do
			table.insert(layers,layer({Id=name.."."..role..".DynamicMotif",Slot=slot,Kind="Dynamics",Priority=1,
				Roles={[role]=true},Colors={"Hi","Mid"},Params={Mode=if kit.Feel.VoidAll then "Void" else "Gusts",Ground=false}}))
		end
		if kit.Feel.VoidAll then
			table.insert(layers,layer({Id=name..".Charge.GroundPortal",Slot="Charge",Kind="Dynamics",Priority=1,
				Roles={Cast=true},Colors={"Hi","Mid"},Params={Mode="Void",Ground=true}}))
		end
	end
	if kit.Feel.NoSpin then
		for _,t in layers do
			t.Params=table.clone(t.Params);t.Params.RotSpeed=0;t.Params.RandomRotation=0;t.Params.Spin=0
			if t.Kind=="Emitter" or t.Kind=="Burst" then t.Params.Orientation="VelocityParallel" end
		end
	end
	local tintable = table.clone(kit.Tintable)
	table.insert(layers,layer({Id=name..".Cast.ReleaseCue",Slot="Cast",Kind="Light",Priority=1,
		Roles={Cast=true},Colors="Mid",Params={Brightness=.65,Range=4,Flash=.12,OffsetZ=-1.3,OffsetY=.5}}))
	for token, amount in pairs((bespoke and bespoke.Tintable) or {}) do
		tintable[token] = amount
	end
	local all = { Form = true, Element = true, Mechanic = true, Detail = true }
	return {
		Name = name,
		Palette = palette,
		Tintable = tintable,
		Layers = layers,
		-- Kits cover every role, so the procedural composer's layers are fully replaced; it still
		-- renders whenever a signature session cannot be created (budget, disabled).
		Replaces = { Default = all },
	}
end

-- Selection, by data only: element first, then the expression or principle for elementless
-- schools, then Arcane for everything else (Neutral, Unawakened).
Kits.Match = {
	Element = {
		Fire = "Fire",
		Ice = "Ice",
		Lightning = "Lightning",
		Water = "Water",
		Earth = "Earth",
		Wind = "Wind",
		Poison = "Poison",
	},
	Expression = {
		Force = "Force",
		BodyEnhancement = "Body",
		Spirit = "Spirit",
		SpatialFold = "Space",
		TemporalShift = "Time",
	},
	Principle = { Body = "Body", Soul = "Spirit", Space = "Space", Time = "Time" },
	Fallback = "Arcane",
}

return Kits
]=];end
do local parent=s.Signature;local m=parent:FindFirstChild("SignatureRenderer")
if m and not backup:FindFirstChild("SignatureRenderer") then m:Clone().Parent=backup end
if not m then m=Instance.new("ModuleScript");m.Name="SignatureRenderer";m.Parent=parent end
m.Source=[=[-- Client renderer for signature layers (SignaturePlanner output) on server-stamped VFX anchors.
-- Cosmetic only: never touches gameplay state, hit detection or the anchor itself (beyond hiding
-- the server's primitive projectile stand-in locally).
--
-- Layer kinds
--   Sprite  locked-to-host flipbook billboard(s) (cores, charge points, beam ends)
--   Emitter continuous ParticleEmitter (streams, motes, field/aura/construct bodies)
--   Burst   one-shot ParticleEmitter:Emit (flashes, explosions, fronts)
--   Mesh    pooled generated MeshPart(s) animated by script (cores, rings, scattered crystals)
--   Debris  a few pooled meshes flung ballistically, no physics or collisions
--   Trail   Trail on the host with a generated strip texture
--   Beam    Roblox Beam along the authoritative beam path, scrolling a strip texture
--   Decal   ground decal (field ground, casting sigil, impact mark); custom textures only
--   Light   PointLight, sustained or flashed
-- Placement (emitters, sprites, lights): Host (default), End (beam endpoint), Line (along the
-- beam), Area (field floor), Body (around the caster), Box (construct surface), Top (construct top).
-- Cel style: Mesh layers with Ink = 1 get their `<mesh>_ink` inverted hull drawn in ink colour.
-- Units: projectile layer sizes are studs at body scale 1 (a 2.2-stud hit diameter); areas use the
-- anchor's real size, impacts the real explode radius through the Area scalar.
local RunService = game:GetService("RunService")
local Planner = require(script.Parent.SignaturePlanner)
local Library = require(script.Parent.SignatureLibrary)
local Assets = require(script.Parent.Parent.Assets.VFXAssets)
local DirectionalSprite = require(script.Parent.DirectionalSprite)
local ConnectedFire = require(script.Parent.ConnectedFire)
local ArcBeam = require(script.Parent.ArcBeam)
local StreamBeam = require(script.Parent.StreamBeam)
local PathGlyphs = require(script.Parent.PathGlyphs)
local FieldDynamics = require(script.Parent.FieldDynamics)

local Renderer = {}
Renderer.Enabled = true
Renderer.Quality = "High"
-- Directional painted cards remain an opt-in study while the 3D approach is evaluated.
Renderer.UseDirectionalSprites = false
Renderer.UseConnectedFire = true

local Budget = Library.Budget
local Styled = require(script.Parent.Parent.Assets.StyledVFXManifest)
local Style = if Styled.Enabled then { LightInfluence=0.25, Brightness=1, InkScale=0 } else Library.Style or {}
local usage = { Sessions = 0, Emitters = 0, Rate = 0, Meshes = 0, Lights = 0, Trails = 0 }
local burstWindow, burstCount = 0, 0
local sessions = {}
local connection: RBXScriptConnection? = nil
local rootFolder: Folder? = nil
local INK = Color3.fromRGB(14, 10, 14)
local GOLDEN = 2.3999632

local ORIENTATION = {
	VelocityParallel = Enum.ParticleOrientation.VelocityParallel,
	VelocityPerpendicular = Enum.ParticleOrientation.VelocityPerpendicular,
	FacingCameraWorldUp = Enum.ParticleOrientation.FacingCameraWorldUp,
}
local DIRECTION = {
	Back = Enum.NormalId.Back,
	Forward = Enum.NormalId.Front,
	Up = Enum.NormalId.Top,
}
local ONE_SHOT_ROLES = { Cast = true, Impact = true, Wave = true }
local GROUNDED_ROLES = { Field = true, Aura = true, SelfEnhancement = true }
local HIDDEN_DISTANCE, DETAIL_DISTANCE = 180, 120

local function folder(): Folder
	if rootFolder and rootFolder.Parent then
		return rootFolder
	end
	local f = Instance.new("Folder")
	f.Name = "SignatureVFX"
	f.Parent = workspace
	rootFolder = f
	return f
end

local function colorSequence(colors)
	if #colors <= 1 then
		return ColorSequence.new(colors[1] or Color3.new(1, 1, 1))
	end
	local keys = {}
	for i, color in ipairs(colors) do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keys)
end

local function sizeSequence(a, b)
	a, b = math.max(0, a), math.max(0, b)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, a),
		NumberSequenceKeypoint.new(0.35, a + (b - a) * 0.6),
		NumberSequenceKeypoint.new(1, b),
	})
end

local function fadeSequence(opacity)
	local base = math.clamp(1 - opacity, 0, 1)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, math.min(1, base + 0.25)),
		NumberSequenceKeypoint.new(0.12, base),
		NumberSequenceKeypoint.new(0.7, math.min(1, base + (1 - base) * 0.3)),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function invisiblePart(name, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.Parent = parent
	return p
end

local function ease(k)
	return 1 - (1 - k) ^ 3
end

local function floorBelow(position: Vector3, ignore: { Instance }, reach: number): (Vector3?, Vector3?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = table.clone(ignore)
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	params.FilterDescendantsInstances = excluded
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 0.5, 0), Vector3.new(0, -reach, 0), params)
	if hit then
		return hit.Position, hit.Normal
	end
	return nil, nil
end

-- Footprint of an area anchor in studs, and whether it is round.
local function footprint(session)
	local size = session.Size
	return size.X, size.Z, session.Round
end

local function areaOf(session)
	local fx, fz = footprint(session)
	return fx * fz
end

-- World Y of the visible floor under the session (refreshed periodically for grounded roles).
local function floorY(session, frame)
	return session.FloorY or (frame.Position.Y - session.Size.Y * 0.5)
end

-- Shape hosts follow the composition frame and its live size.
local function placeShape(session, shape, frame)
	local p = shape.Layer.Params
	local placement = p.Placement
	local size = session.Size
	local part = shape.Part
	if placement == "End" then
		part.CFrame=frame*CFrame.new(0,p.OffsetY or 0,-(session.Range or 0))
	elseif placement == "Line" then
		local range = session.Range or 6
		local w = math.max(0.5, (session.Width or 1) * 1.2)
		part.Size = Vector3.new(w, w, math.max(0.5, range))
		part.CFrame = frame * CFrame.new(0, 0, -range * 0.5)
	elseif placement == "Area" then
		local fx, fz = footprint(session)
		part.Size = Vector3.new(math.max(0.5, fx * 0.85), 0.3, math.max(0.5, fz * 0.85))
		local y = floorY(session, frame) - frame.Position.Y
		part.CFrame = frame * CFrame.new(0, y + 0.25, 0)
	elseif placement == "Body" then
		part.Size = Vector3.new(math.max(2, size.X * 0.75), math.max(2, size.Y * 0.9), math.max(2, size.Z * 0.75))
		part.CFrame = frame
	elseif placement == "Box" then
		part.Size = size * 1.02
		part.CFrame = frame
	elseif placement == "Top" then
		part.Size = Vector3.new(size.X, 0.2, size.Z)
		part.CFrame = frame * CFrame.new(0, size.Y * 0.5, 0)
	elseif (p.Floor or 0) > 0 then
		local range = session.Range or 6
		part.Size = Vector3.new(math.max(1, (session.Width or range) * 0.4), 0.2, math.max(1, range * 0.5))
		part.CFrame = frame * CFrame.new(0, -2.3, -range * 0.3)
	else
		part.CFrame = frame * CFrame.new(0, p.OffsetY or 0, p.OffsetZ or 0)
	end
end

local function addShape(session, layer, size)
	local host = invisiblePart(layer.Id .. ".Shape", session.Folder)
	host.Size = size
	local shape = { Part = host, Layer = layer }
	table.insert(session.ShapeHosts, shape)
	-- Positioned before any immediate Emit so bursts never spawn at the world origin.
	placeShape(session, shape, session.Host.CFrame)
	return host
end

-- Particle emitter configured from a layer. Shapes that need a volume get their own host part.
local function makeEmitter(session, layer, scale)
	local p = layer.Params
	local texture, layout, _, baked = Assets.texture(layer.Texture, session.Signature)
	local parent: Instance = session.Attachment
	local direction = p.Direction or "Back"
	local placement = p.Placement
	local e = Instance.new("ParticleEmitter")
	e.Name = layer.Id
	e.Texture = texture
	e.FlipbookLayout = layout
	if layout ~= Enum.ParticleFlipbookLayout.None then
		e.FlipbookMode = if (p.OneShot or 0) > 0
			then Enum.ParticleFlipbookMode.OneShot
			else Enum.ParticleFlipbookMode.Loop
		e.FlipbookStartRandom = (p.OneShot or 0) <= 0
		if p.Framerate == 0 then
			-- Random still frame (glyph sets, scraps): pick a frame per particle, never animate.
			e.FlipbookMode = Enum.ParticleFlipbookMode.Random
		elseif (p.Framerate or 0) > 0 and (p.OneShot or 0) <= 0 then
			e.FlipbookFramerate = NumberRange.new(p.Framerate * 0.85, p.Framerate)
		end
	end
	e.Color = if baked then ColorSequence.new(Color3.new(1, 1, 1)) else colorSequence(layer.Colors)
	local light = if baked then math.min(p.Light or 0.3, 0.2) else p.Light or 0.3
	e.LightEmission = light
	-- Cel look: flat colour that scene lighting barely dims; emission stays low so ink shows.
	e.LightInfluence = Style.LightInfluence or (1 - light)
	e.Brightness = if baked then 1 else (Style.Brightness or 1) + light * 0.6
	e.Size = sizeSequence((p.Size or 1) * scale, (p.SizeEnd or p.Size or 1) * scale)
	e.Transparency = fadeSequence(p.Opacity or 1)
	local life = math.max(0.05, p.Lifetime or 0.5)
	e.Lifetime = NumberRange.new(life * 0.75, life)
	local speed = (p.Speed or 0) * (if layer.Kind == "Burst" then 1 else scale ^ 0.5)
	if (p.RangeSpeed or 0) > 0 and session.Range then
		speed = math.max(speed, session.Range / life * 0.95)
	end
	e.Speed = NumberRange.new(speed * 0.7, speed)
	e.SpreadAngle = Vector2.new(p.Spread or 0, p.Spread or 0)
	e.Drag = p.Drag or 0
	e.Acceleration = Vector3.new(0, p.Rise or 0, 0)
	e.Orientation = ORIENTATION[p.Orientation or ""] or Enum.ParticleOrientation.FacingCamera
	if (p.Stretch or 0) > 0 then
		e.Squash = NumberSequence.new(-math.clamp(p.Stretch * 0.3, 0, 2.5))
	end
	if (p.RandomRotation or 0) > 0 or (p.RotSpeed or 0) > 0 then
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-(p.RotSpeed or 30), p.RotSpeed or 30)
	end
	e.LockedToPart = layer.Kind == "Sprite"
	e.ZOffset = if layer.Kind == "Sprite" then 0.5 else 0
	if
		placement == "Line"
		or placement == "Area"
		or placement == "Body"
		or placement == "Box"
		or placement == "Top"
	then
		local host = addShape(session, layer, Vector3.one)
		if placement == "Area" then
			e.Shape = if session.Round then Enum.ParticleEmitterShape.Disc else Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		elseif placement == "Body" then
			e.Shape = Enum.ParticleEmitterShape.Cylinder
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		elseif placement == "Box" then
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		else
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		end
		e.EmissionDirection = DIRECTION[direction] or Enum.NormalId.Top
		parent = host
	elseif
		direction == "In"
		or direction == "Out"
		or direction == "Flat"
		or (p.ShapeRadius or 0) > 0
		or (p.Floor or 0) > 0
	then
		local radius = (p.ShapeRadius or 0.5) * (if direction == "In" then 1 else scale)
		local host = addShape(session, layer, Vector3.one * math.max(0.2, radius * 2))
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		if direction == "In" then
			e.Shape = Enum.ParticleEmitterShape.Sphere
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		elseif direction == "Out" then
			e.Shape = Enum.ParticleEmitterShape.Sphere
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		elseif direction == "Flat" then
			e.Shape = Enum.ParticleEmitterShape.Cylinder
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
			host.Size = Vector3.new(radius * 2, 0.2, radius * 2)
		else
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			e.EmissionDirection = DIRECTION[direction] or Enum.NormalId.Front
		end
		parent = host
	else
		e.EmissionDirection = DIRECTION[direction] or Enum.NormalId.Back
		if placement == "End" or (p.OffsetY or 0) ~= 0 or (p.OffsetZ or 0) ~= 0 then
			local offset = Instance.new("Attachment")
			offset.Position = Vector3.new(0, p.OffsetY or 0, p.OffsetZ or 0)
			offset.Parent = session.Host
			parent = offset
			if placement == "End" then
				table.insert(session.EndAttachments, offset)
			end
		end
	end
	e.Enabled = false
	e.Rate = 0
	e.Parent = parent
	return e
end

local function canEmitBurst(count)
	local now = os.clock()
	if now - burstWindow > 1 then
		burstWindow, burstCount = now, 0
	end
	if burstCount + count > Budget.MaxBurstPerSecond then
		return false
	end
	burstCount += count
	return true
end

-- A mesh and (when requested and uploaded) its inverted-hull ink outline.
local function acquirePair(session, name, p)
	local part, custom = Assets.acquireMesh(name)
	part.Material = Enum.Material[p.Material or "SmoothPlastic"] or Enum.Material.SmoothPlastic
	part.Transparency = 1
	part.CFrame = session.Host.CFrame
	part.Parent = session.Folder
	local ink
	if (p.Ink or 0) > 0 and custom and Assets.hasCustomMesh(name .. "_ink") then
		ink = Assets.acquireMesh(name .. "_ink")
		ink.Material = Enum.Material.SmoothPlastic
		ink.Color = if ink:GetAttribute("VFXBakedColors") then Color3.new(1, 1, 1) else (Styled.Palettes[session.Signature] or {})[5] or INK
		ink.Transparency = 1
		ink.CFrame = session.Host.CFrame
		ink.Parent = session.Folder
	end
	usage.Meshes += if ink then 2 else 1
	session.Owned.Meshes += if ink then 2 else 1
	return part, ink, custom
end

-- Places a mesh and its hull. The hull is authored inflated, so it scales by the same factor.
local function placePair(name, part, ink, cf, size, transparency)
	Assets.place(part, cf, size)
	part.Transparency = transparency
	if ink then
		local native, hull = Assets.meshSize(name), Assets.meshSize(name .. "_ink")
		local ratio = Vector3.new(
			hull.X / math.max(native.X, 1e-3),
			hull.Y / math.max(native.Y, 1e-3),
			hull.Z / math.max(native.Z, 1e-3)
		)
		-- Extra InkScale thickens the rim beyond the authored hull (relative to the mesh size).
		Assets.place(ink, cf, size * ratio * (1 + (Style.InkScale or 0)))
		-- A translucent body would show the hull through it; ink only while the body is solid.
		ink.Transparency = if transparency < 0.08 then 0 else 1
	end
end

-- Builds every layer of a resolved plan into the session.
local function buildLayers(session, layers)
	for _, layer in ipairs(layers) do
		local p = layer.Params
		local critical = layer.Priority == 1
		local entry = { Layer = layer, Start = session.Clock }
		if layer.Kind == "DirectionalSprite" then
			local definition = Assets.directionalSprite(layer.DirectionalAsset)
			if definition then
				entry.Directional = DirectionalSprite.new(session.Host, session.Folder, definition, (p.Size or 4.2)*session.Scale)
			end
		elseif layer.Kind == "Sprite" or layer.Kind == "Emitter" then
			local base = if layer.Kind == "Sprite" then 3 / math.max(0.1, p.Lifetime or 0.35) else p.Rate or 0
			if (p.RatePerArea or 0) > 0 then
				base = math.min(40, base + p.RatePerArea * areaOf(session))
			end
			local rate = math.min(Budget.MaxEmitterRate, base)
			if layer.Kind == "Sprite" then
				p.Lifetime = p.Lifetime or 0.35
				p.SizeEnd = p.SizeEnd or (p.Size or 1) * 1.1
				p.Speed = 0
				p.RotSpeed = p.RotSpeed or 45
			end
			local fits = usage.Emitters < Budget.MaxEmitters and usage.Rate + rate <= Budget.MaxContinuousRate
			if fits or critical then
				usage.Emitters += 1
				usage.Rate += rate
				session.Owned.Emitters += 1
				session.Owned.Rate += rate
				entry.Emitter = makeEmitter(session, layer, session.Scale)
				entry.Rate = rate
				entry.Emitter.Rate = rate
				entry.Emitter.Enabled = true
				entry.BaseSize = (p.Size or 1) * session.Scale
				entry.EndSize = (p.SizeEnd or p.Size or 1) * session.Scale
			end
		elseif layer.Kind == "Burst" then
			local count = math.min(Budget.MaxBurstCount, math.max(1, math.floor(p.Count or 1)))
			if canEmitBurst(count) or critical then
				local scale = if session.Role == "Impact" or session.Role == "Cast" then 1 else session.Scale
				local e = makeEmitter(session, layer, scale)
				entry.Emitter = e
				local delay = p.Delay or 0
				local stagger = p.Stagger or 0
				local function fire()
					if session.Stopped or not e.Parent then
						return
					end
					if stagger > 0 then
						for i = 1, count do
							task.delay((i - 1) * stagger, function()
								if not session.Stopped and e.Parent then
									e:Emit(1)
								end
							end)
						end
					else
						e:Emit(count)
					end
				end
				if delay > 0 then
					task.delay(delay, fire)
				else
					fire()
				end
				session.Linger = math.max(session.Linger, delay + stagger * count + (p.Lifetime or 0.5))
			end
		elseif layer.Kind == "Mesh" then
			local skip = (p.RequireAsset or 0) > 0 and not Assets.hasCustomMesh(layer.Mesh)
			local count = 1
			if p.Orient == "Scatter" then
				count = math.clamp(math.floor((p.Count or 4) + (p.CountPerArea or 0) * areaOf(session) + 0.5), 1, p.MaxCount or 10)
			end
			local fits = usage.Meshes + count <= Budget.MaxMeshes
			if layer.Mesh and not skip and (fits or critical) then
				entry.Parts, entry.Inks = {}, {}
				local custom = true
				for i = 1, count do
					local part, ink, isCustom = acquirePair(session, layer.Mesh, p)
					part.Color = if part:GetAttribute("VFXBakedColors") then Color3.new(1, 1, 1) else layer.Colors[1]
					entry.Parts[i], entry.Inks[i] = part, ink
					custom = isCustom
				end
				-- Fallback primitives of open shapes (rings, cones, shells) read as solid blobs; keep them faint.
				entry.FallbackDim = if custom then 1 else 0.35
				entry.Native = Assets.meshSize(layer.Mesh)
				if (p.Duration or 0) > 0 and ONE_SHOT_ROLES[session.Role] then
					session.Linger = math.max(session.Linger, (p.Delay or 0) + p.Duration)
				end
				if p.Orient == "Ground" then
					local floor = floorBelow(session.Host.Position, { session.Folder, session.Anchor }, 9)
					entry.Floor = floor
						or (session.Host.Position - Vector3.new(0, if session.Role == "Cast" then 2.9 else 0.5, 0))
				end
			end
		elseif layer.Kind == "Decal" then
			local texture, _, custom, baked = Assets.texture(layer.Texture, session.Signature)
			-- Built-in particle textures make poor ground decals; decals need the uploaded art.
			if custom then
				local plate = invisiblePart(layer.Id, session.Folder)
				local decal = Instance.new("Decal")
				decal.Face = Enum.NormalId.Top
				decal.Texture = texture
				decal.Color3 = if baked then Color3.new(1, 1, 1) else layer.Colors[1]
				decal.Transparency = 1
				decal.Parent = plate
				entry.Plate, entry.Decal = plate, decal
				if session.Role == "Cast" or session.Role == "Impact" then
					local floor = floorBelow(session.Host.Position, { session.Folder, session.Anchor }, 9)
					if not floor and session.Role == "Impact" then
						-- Mid-air impacts leave no ground mark.
						plate:Destroy()
						entry.Plate, entry.Decal = nil, nil
					end
					entry.Floor = floor or (session.Host.Position - Vector3.new(0, 2.9, 0))
				end
				if (p.Duration or 0) > 0 then
					session.Linger = math.max(session.Linger, p.Duration)
				end
			end
		elseif layer.Kind == "Dynamics" then
			local dynamics=FieldDynamics.new(session.Folder,p,session.Signature,Styled.Palettes[session.Signature],
				Budget.MaxMeshes-usage.Meshes,Budget.MaxTrails-usage.Trails,session.Quality,session.Seed)
			if dynamics then
				entry.Dynamics=dynamics
				if session.OneShot then session.Linger=math.max(session.Linger,1.25) end
				usage.Meshes+=dynamics.Meshes;session.Owned.Meshes+=dynamics.Meshes
				usage.Trails+=dynamics.Trails;session.Owned.Trails+=dynamics.Trails
			end
		elseif layer.Kind == "PathGlyphs" then
			local texture,layout,_,baked=Assets.texture(layer.Texture,session.Signature)
			local frameTexture=if layer.FrameTexture then (Assets.texture(layer.FrameTexture,session.Signature)) else nil
			local colors=if baked then ColorSequence.new(Color3.new(1,1,1)) else colorSequence(layer.Colors)
			local glyphs=PathGlyphs.new(session.Host,texture,layout,colors,p,Budget.MaxEmitters-usage.Emitters,frameTexture)
			if glyphs then
				entry.PathGlyphs=glyphs;usage.Emitters+=glyphs.Count;session.Owned.Emitters+=glyphs.Count
				usage.Rate+=glyphs.Rate;session.Owned.Rate+=glyphs.Rate
				session.Linger=math.max(session.Linger,p.GlyphLifetime or 1.25)
			end
		elseif layer.Kind == "Beam" then
			if usage.Trails < Budget.MaxTrails or critical then
				local texture, _, _, baked = Assets.texture(layer.Texture, session.Signature)
				local colors = if baked then ColorSequence.new(Color3.new(1, 1, 1)) else colorSequence(layer.Colors)
				local stream=if p.ContinuousStream then StreamBeam.new(session.Host,session.Folder,texture,colors,p,
					math.max(0,Budget.MaxTrails-usage.Trails),Styled.Palettes[session.Signature]) else nil
				local arc = if p.ArcSegments then ArcBeam.new(session.Host, session.Folder, texture, colorSequence(layer.Colors), p,
					math.max(0, Budget.MaxTrails - usage.Trails), session.Seed) else nil
				if stream then
					entry.Stream=stream;usage.Trails+=stream.Count;session.Owned.Trails+=stream.Count
				elseif arc then
					entry.Arc=arc
					usage.Trails+=arc.Count;session.Owned.Trails+=arc.Count
				else
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Parent, a1.Parent = session.Host, session.Host
				table.insert(session.EndAttachments, a1)
				local beam = Instance.new("Beam")
				beam.Name = layer.Id
				beam.Attachment0, beam.Attachment1 = a0, a1
				local texture, _, _, baked = Assets.texture(layer.Texture, session.Signature)
				beam.Texture = texture
				beam.TextureMode = Enum.TextureMode.Wrap
				beam.TextureLength = p.TextureLength or 5
				beam.TextureSpeed = p.Scroll or 2
				beam.Color = if baked then ColorSequence.new(Color3.new(1, 1, 1)) else colorSequence(layer.Colors)
				beam.LightEmission = if baked then 0.2 else p.Light or 0.3
				beam.LightInfluence = Style.LightInfluence or (1 - (p.Light or 0.3))
				beam.FaceCamera = true
				beam.Segments = if (p.Wobble or 0) > 0 then 12 else 1
				beam.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1 - (p.Opacity or 1) * 0.7),
					NumberSequenceKeypoint.new(0.08, 1 - (p.Opacity or 1)),
					NumberSequenceKeypoint.new(0.92, 1 - (p.Opacity or 1)),
					NumberSequenceKeypoint.new(1, 1 - (p.Opacity or 1) * 0.7),
				})
				beam.Parent = session.Folder
				entry.Beam = beam
				usage.Trails += 1
				session.Owned.Trails += 1
				end
			end
		elseif layer.Kind == "Debris" then
			local count = math.min(8, math.max(1, math.floor(p.Count or 1)))
			if (usage.Meshes + count * 2 <= Budget.MaxMeshes) or critical then
				entry.Pieces = {}
				local random = Random.new((session.Seed or 0) + #session.Entries * 7919)
				local floor = floorBelow(session.Host.Position, { session.Folder, session.Anchor }, 12)
				entry.FloorY = if floor then floor.Y else session.Host.Position.Y - 6
				local frame = session.Host.CFrame
				for i = 1, count do
					local name = layer.Meshes[(i - 1) % #layer.Meshes + 1]
					local part, ink = acquirePair(session, name, p)
					part.Color = if part:GetAttribute("VFXBakedColors") then Color3.new(1, 1, 1) else layer.Colors[1]
					local spread = math.rad(p.Spread or 45)
					local yaw, pitch = random:NextNumber(-spread, spread), random:NextNumber(-spread, spread)
					local dir
					if p.Direction == "Forward" then
						dir = (frame * CFrame.Angles(pitch * 0.5, yaw, 0)).LookVector
					elseif p.Direction == "Up" then
						dir = (CFrame.Angles(pitch, 0, yaw) * CFrame.new()).UpVector
					else
						dir =
							Vector3.new(random:NextNumber(-1, 1), random:NextNumber(0, 1), random:NextNumber(-1, 1)).Unit
					end
					local size = Assets.meshSize(name) * (p.Size or 0.5) * random:NextNumber(0.6, 1.2)
					placePair(name, part, ink, frame, size, 0)
					local piece = {
						Name = name,
						Part = part,
						Ink = ink,
						Position = frame.Position + dir * 0.6,
						Velocity = dir * (p.Speed or 20) * random:NextNumber(0.6, 1),
						Spin = Vector3.new(
							random:NextNumber(-9, 9),
							random:NextNumber(-9, 9),
							random:NextNumber(-9, 9)
						),
						Rotation = CFrame.Angles(random:NextNumber(0, 6), random:NextNumber(0, 6), 0),
						Size = size,
					}
					if (p.Trail or 0) > 0 and usage.Trails < Budget.MaxTrails then
						local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
						a0.Position, a1.Position = Vector3.new(0, size.Y * 0.4, 0), Vector3.new(0, -size.Y * 0.4, 0)
						a0.Parent, a1.Parent = part, part
						local trail = Instance.new("Trail")
						trail.Attachment0, trail.Attachment1 = a0, a1
						local texture, _, _, baked = Assets.texture("force_streak", session.Signature)
						trail.Texture = texture
						trail.Color = if baked then ColorSequence.new(Color3.new(1, 1, 1)) else colorSequence(layer.Colors)
						trail.Lifetime = 0.18
						trail.FaceCamera = true
						trail.LightEmission = 0.2
						trail.Transparency = NumberSequence.new(0.35, 1)
						trail.Parent = part
					end
					table.insert(entry.Pieces, piece)
				end
				session.Linger = math.max(session.Linger, p.Lifetime or 0.8)
			end
		elseif layer.Kind == "Trail" then
			if usage.Trails < Budget.MaxTrails or critical then
				local half = (p.Width or 1) * session.Scale * 0.5
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position, a1.Position = Vector3.new(-half, 0, 0), Vector3.new(half, 0, 0)
				a0.Parent, a1.Parent = session.Host, session.Host
				local trail = Instance.new("Trail")
				trail.Name = layer.Id
				trail.Attachment0, trail.Attachment1 = a0, a1
				local texture, _, _, baked = Assets.texture(layer.Texture, session.Signature)
				trail.Texture = texture
				trail.TextureMode = Enum.TextureMode.Wrap
				trail.TextureLength = (p.TextureLength or 4) * session.Scale
				trail.Color = if baked then ColorSequence.new(Color3.new(1, 1, 1)) else colorSequence(layer.Colors)
				trail.Lifetime = p.Lifetime or 0.2
				trail.LightEmission = if baked then 0.2 else p.Light or 1
				trail.LightInfluence = Style.LightInfluence or (1 - (p.Light or 1))
				trail.FaceCamera = true
				trail.MinLength = 0.05
				trail.WidthScale = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0.15),
				})
				trail.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1 - (p.Opacity or 0.9)),
					NumberSequenceKeypoint.new(1, 1),
				})
				trail.Parent = session.Folder
				entry.Trail = trail
				usage.Trails += 1
				session.Owned.Trails += 1
				session.Linger = math.max(session.Linger, trail.Lifetime)
			end
		elseif layer.Kind == "Light" then
			if usage.Lights < Budget.MaxLights then
				local attachment = Instance.new("Attachment")
				attachment.Position = Vector3.new(0, p.OffsetY or 0, p.OffsetZ or 0)
				attachment.Parent = session.Host
				if p.Placement == "End" then
					table.insert(session.EndAttachments, attachment)
				end
				local light = Instance.new("PointLight")
				light.Color = layer.Colors[1]
				light.Shadows = false
				light.Range = math.min(24, (p.Range or 10))
				light.Brightness = 0
				light.Parent = attachment
				entry.Light = light
				usage.Lights += 1
				session.Owned.Lights += 1
				if (p.Flash or 0) > 0 then
					session.Linger = math.max(session.Linger, p.Flash)
				end
			end
		end
		table.insert(session.Entries, entry)
	end
end

local function release(session)
	usage.Emitters -= session.Owned.Emitters
	usage.Rate -= session.Owned.Rate
	usage.Meshes -= session.Owned.Meshes
	usage.Lights -= session.Owned.Lights
	usage.Trails -= session.Owned.Trails
	session.Owned = { Emitters = 0, Rate = 0, Meshes = 0, Lights = 0, Trails = 0 }
end

local Session = {}
Session.__index = Session

-- Graceful end: continuous layers stop, dissipation plays at the last transform, then cleanup.
function Session:Finish()
	if self.Ending or self.Stopped then
		return
	end
	self.Ending = self.Clock
	if self.Anchor.Parent then
		self.Frame=self.Anchor.CFrame
		if self.Role=="Beam" then
			local size=self.Options.Size or self.Anchor:GetAttribute("VFXSize") or self.Anchor.Size
			self.Range,self.Width=size.Z,size.X
		end
	end
	-- Linger now counts from the end, not the start.
	self.Linger = 0.3
	-- Cast cues end at the caster; they must never generate projectile/beam dissipation.
	for _, entry in self.Entries do
		if entry.PathGlyphs then
			self.Linger=math.max(self.Linger,entry.Layer.Params.GlyphLifetime or 1.25)
		end
		if entry.Dynamics then self.Linger=math.max(self.Linger,1.2) end
		if entry.Emitter and entry.Layer.Kind ~= "Burst" then
			entry.Emitter.Enabled = false
			self.Linger = math.max(self.Linger, entry.Layer.Params.Lifetime or 0.5)
		end
		if entry.Trail then
			entry.Trail.Enabled = true
		end
	end
	local ownsDissipation=false
	for _,entry in self.Entries do if entry.Dynamics then ownsDissipation=true end end
	if not self.OneShot and self.Role~="Cast" and not self.ConnectedFire and not ownsDissipation then
		local plan = Planner.plan(self.Plan, "End", { Quality = self.Quality })
		if plan then
			if self.Role=="Beam" then
				for _,layer in plan.Layers do
					layer.Params=table.clone(layer.Params);layer.Params.Placement="End"
				end
			end
			self.Host.CFrame=self.Frame
			local start = #self.Entries
			buildLayers(self, plan.Layers)
			for i = start + 1, #self.Entries do
				self.Entries[i].Start = self.Clock
			end
		end
	end
	-- One-shots already outlived their layers; sustained effects wait for their dissipation.
	self.EndAt = self.Clock + (if self.OneShot then 0.35 else math.min(3, self.Linger + 0.1))
end

function Session:Stop()
	if self.Stopped then
		return
	end
	self.Stopped = true
	if self.ConnectedFire then self.ConnectedFire:Destroy() end
	release(self)
	usage.Sessions -= 1
	sessions[self] = nil
	for _, entry in self.Entries do
		if entry.Dynamics then entry.Dynamics:Destroy() end
		for _, part in entry.Parts or {} do
			Assets.releaseMesh(part)
		end
		for _, ink in entry.Inks or {} do
			Assets.releaseMesh(ink)
		end
		for _, piece in entry.Pieces or {} do
			Assets.releaseMesh(piece.Part)
			if piece.Ink then
				Assets.releaseMesh(piece.Ink)
			end
		end
	end
	self.Folder:Destroy()
end

-- Scatter point i of n inside the footprint (golden-angle spiral or R2 grid), in host space.
local function scatterPoint(session, i, n)
	local fx, fz, round = footprint(session)
	if round then
		local r = math.sqrt((i - 0.5) / n) * 0.4
		local a = i * GOLDEN + (session.Seed % 100) * 0.01
		return math.cos(a) * r * fx, math.sin(a) * r * fz
	end
	return ((i * 0.7548777) % 1 - 0.5) * 0.8 * fx, ((i * 0.5698403 + 0.31) % 1 - 0.5) * 0.8 * fz
end

local function updateMesh(session, entry, t, frame, shown, opacity)
	local layer = entry.Layer
	local p = layer.Params
	local native = entry.Native
	local age = session.Clock - entry.Start
	local delay = p.Delay or 0
	local k = if (p.Duration or 0) > 0 then math.clamp((age - delay) / p.Duration, 0, 1) else 1
	if (p.Fade or 0) > 0 then
		opacity *= 1 - math.clamp((k - 0.35) / 0.65, 0, 1)
	end
	if age < delay then
		opacity = 0
	end
	local wobble = p.Wobble or 0
	local jitter = Vector3.new(
		1 + wobble * math.sin(t * 13.1),
		1 + wobble * math.sin(t * 11.7 + 1.3),
		1 + wobble * math.sin(t * 9.3 + 2.1)
	)
	local transparency = if shown then math.clamp(1 - opacity, 0, 1) else 1
	local n = #entry.Parts
	for i, part in entry.Parts do
		local size, cf
		if p.Orient == "Scatter" then
			-- Upright bodies spread over the footprint, growing in (and sinking away on end).
			local x, z = scatterPoint(session, i, n)
			local variation = 0.7 + 0.6 * ((i * 0.618034 + (session.Seed % 37) * 0.01) % 1)
			local grow = ease(math.clamp((age - i * 0.05) / math.max(0.05, p.Duration or 0.35), 0, 1))
			if session.Ending then
				grow *= 1 - math.clamp((session.Clock - session.Ending) / 0.35, 0, 1)
			end
			local s = (p.Size or 1) * variation * math.max(0.02, grow)
			size = native * s
			local y = floorY(session, frame) - frame.Position.Y
			local yaw = i * GOLDEN
			local lean = 0.12 * math.sin(i * 1.7)
			cf = frame
				* CFrame.new(x, y + size.Y * 0.45, z)
				* CFrame.Angles(lean, yaw + t * (p.Spin or 0) * 0.1, lean * 0.5)
		elseif p.Orient == "Footprint" then
			local fx, fz = footprint(session)
			size = Vector3.new(fx, native.Y * math.min(fx, fz) / math.max(native.X, 0.01) * 0.5, fz)
			local y = floorY(session, frame) - frame.Position.Y
			cf = frame * CFrame.new(0, y + 0.08, 0) * CFrame.Angles(0, t * (p.Spin or 0), 0)
		elseif p.Orient == "Ground" then
			local s = (p.Size or 1) + ((p.Grow or p.Size or 1) - (p.Size or 1)) * ease(k)
			size = Vector3.new(s, native.Y * s / math.max(native.X, 0.01), s)
			cf = CFrame.new(entry.Floor + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, t * (p.Spin or 0), 0)
		elseif p.Orient == "Area" then
			-- The force cone is stretched to the real wave range, overshoots, then settles.
			local range = session.Range or 10
			local reach = ease(k) * (1 + (p.Overshoot or 0) * math.sin(math.min(k, 1) * math.pi))
			local width = math.min(session.Width or range, range * 1.6)
			local length = math.max(0.3, range * reach)
			size = Vector3.new(width * (0.35 + 0.65 * ease(k)), math.max(2.5, width * 0.4), length)
			cf = frame * CFrame.new(0, 0, -length * 0.5)
		elseif p.Orient == "Front" then
			local range = session.Range or 10
			local width = math.min(session.Width or range, range * 1.6)
			local d = width * (0.3 + 0.7 * ease(k))
			size = Vector3.new(d, native.Y * d * 0.5, d * 0.62)
			cf = frame * CFrame.new(0, 0, -range * (0.55 + 0.4 * ease(k))) * CFrame.Angles(math.pi / 2, 0, 0)
		else
			local body = (p.Size or 1) * session.Scale
			local stretch = p.Stretch or 1
			size = native * body * jitter * Vector3.new(1, 1, stretch)
			cf = frame * CFrame.Angles(0, 0, t * (p.Spin or 0)) * CFrame.Angles(t * 0.7, t * 0.45, 0)
			if stretch ~= 1 then
				-- Shells streak backwards from the core instead of tumbling.
				cf = frame * CFrame.new(0, 0, size.Z * 0.12) * CFrame.Angles(0, 0, t * (p.Spin or 0))
			end
		end
		placePair(layer.Mesh, part, entry.Inks[i], cf, size, transparency)
	end
end

local function updateEntry(session, entry, t, dt, frame, tier)
	local layer = entry.Layer
	local p = layer.Params
	local shown = tier >= layer.Priority
	local age = session.Clock - entry.Start
	local ramp = if (p.Ramp or 0) > 0 then session.Ramp else 1
	local fading = if session.Ending then math.clamp((session.Clock - session.Ending) / 0.3, 0, 1) else 0
	if entry.Dynamics then
		entry.Dynamics:Update(frame,session.Size,floorY(session,frame),age,shown,fading,session.Role)
	end
	if entry.Directional then
		entry.Directional:Update(frame, workspace.CurrentCamera, t, shown, (p.Opacity or 1)*(1-fading))
	end
	if entry.Emitter and layer.Kind ~= "Burst" then
		entry.Emitter.Enabled = shown and not session.Ending and ramp > 0.02
		if layer.Kind == "Sprite" then
			local throb = 1 + (if (p.Throb or 0) > 0 then 0.12 * math.sin(t * p.Throb * math.pi) else 0)
			local grow = 1 + ((p.Grow or 1) - 1) * ramp
			local s = entry.BaseSize * grow * throb * (0.35 + 0.65 * ramp)
			if not entry.LastSize or math.abs(entry.LastSize - s) > 0.03 then
				entry.LastSize = s
				entry.Emitter.Size = sizeSequence(s, s * 1.1)
			end
		elseif (p.Ramp or 0) > 0 then
			entry.Emitter.Rate = entry.Rate * (0.25 + 0.75 * ramp)
		end
		if (p.RangeSpeed or 0) > 0 and session.Range then
			-- Streams travel the live beam length in one lifetime, so they end where the beam ends.
			local speed = math.max(p.Speed or 0, session.Range / math.max(0.05, p.Lifetime or 0.5) * 0.95)
			if not entry.LastSpeed or math.abs(entry.LastSpeed - speed) > 0.5 then
				entry.LastSpeed = speed
				entry.Emitter.Speed = NumberRange.new(speed * 0.92, speed)
			end
		end
	end
	if entry.Parts then
		updateMesh(session, entry, t, frame, shown, (p.Opacity or 0.8) * ramp * (1 - fading) * entry.FallbackDim)
	end
	if entry.Plate then
		local fx, fz
		if (p.Footprint or 0) > 0 then
			fx, fz = footprint(session)
			fx, fz = fx * 0.98, fz * 0.98
		else
			fx = (p.Size or 4)
			fz = fx
		end
		local y
		if entry.Floor then
			y = entry.Floor.Y
		else
			y = floorY(session, frame)
		end
		local opacity = (p.Opacity or 0.8) * ramp * (1 - fading)
		if (p.Duration or 0) > 0 and (p.Fade or 0) > 0 then
			opacity *= 1 - math.clamp((age - p.Duration * 0.5) / (p.Duration * 0.5), 0, 1)
		end
		if (p.Pulse or 0) > 0 then
			opacity *= 1 - p.Pulse + p.Pulse * math.sin(t * 2.4) ^ 2
		end
		local pos = if entry.Floor
			then Vector3.new(entry.Floor.X, y + 0.04, entry.Floor.Z)
			else Vector3.new(frame.Position.X, y + 0.04, frame.Position.Z)
		local _, yaw0 = frame:ToOrientation()
		entry.Plate.Size = Vector3.new(math.max(0.2, fx), 0.05, math.max(0.2, fz))
		entry.Plate.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw0 + t * (p.Spin or 0), 0)
		entry.Decal.Transparency = if shown then math.clamp(1 - opacity, 0, 1) else 1
	end
	if entry.Stream then
		entry.Stream:Update(session.Range or 10,session.Width or 1,age,shown,fading)
	end
	if entry.PathGlyphs then
		entry.PathGlyphs:Update(session.Range or 10,session.Width or 1,age,shown,session.Ending~=nil,canEmitBurst)
	end
	if entry.Arc then
		entry.Arc:Update(session.Range or 10, session.Width or 1, age, shown, fading)
	end
	if entry.Beam then
		local beam = entry.Beam
		local width = math.max(0.15, (p.Width or 1) * (session.Width or 1))
		local surge = 1 + 0.12 * math.sin(t * 9 + (p.Width or 1))
		beam.Width0, beam.Width1 = width * surge * (1 - fading), width * 0.85 * surge * (1 - fading)
		if (p.Wobble or 0) > 0 then
			local range = session.Range or 10
			beam.CurveSize0 = math.sin(t * 7.3) * p.Wobble * range * 0.06
			beam.CurveSize1 = math.cos(t * 6.1) * p.Wobble * range * 0.06
		end
		beam.Enabled = shown
	end
	if entry.Pieces then
		local life = p.Lifetime or 0.8
		local fade = math.clamp((age - life * 0.6) / (life * 0.4), 0, 1)
		for _, piece in entry.Pieces do
			piece.Velocity += Vector3.new(0, -(p.Gravity or 50) * dt, 0)
			local nextPosition = piece.Position + piece.Velocity * dt
			if nextPosition.Y < entry.FloorY + piece.Size.Y * 0.3 then
				nextPosition = Vector3.new(nextPosition.X, entry.FloorY + piece.Size.Y * 0.3, nextPosition.Z)
				piece.Velocity =
					Vector3.new(piece.Velocity.X * 0.55, math.abs(piece.Velocity.Y) * 0.25, piece.Velocity.Z * 0.55)
				piece.Spin *= 0.5
			end
			piece.Position = nextPosition
			piece.Rotation *= CFrame.Angles(piece.Spin.X * dt, piece.Spin.Y * dt, piece.Spin.Z * dt)
			placePair(
				piece.Name,
				piece.Part,
				piece.Ink,
				CFrame.new(piece.Position) * piece.Rotation,
				piece.Size * (1 - fade * 0.5),
				if shown then fade else 1
			)
		end
	end
	if entry.Light then
		local brightness = p.Brightness or 1
		if (p.Flash or 0) > 0 then
			brightness *= math.max(0, 1 - age / p.Flash) ^ 2
		end
		entry.Light.Brightness = brightness * ramp * (1 - fading)
		entry.Light.Enabled = shown and brightness > 0.01
	end
	if entry.Trail then
		entry.Trail.Enabled = shown
	end
end

local function refreshSize(session)
	local anchor = session.Anchor
	local size
	if session.Options.Size then
		size = session.Options.Size
	elseif session.Role == "Construct" or session.Role == "Manipulation" then
		size = anchor.Size
	else
		size = anchor:GetAttribute("VFXSize") or anchor.Size
	end
	if typeof(size) ~= "Vector3" then
		size = anchor.Size
	end
	session.Size = size
	if session.Role == "Wave" or session.Role == "Beam" then
		session.Range = size.Z
		session.Width = size.X
	end
end

local function step(dt)
	local camera = workspace.CurrentCamera
	local now = os.clock()
	for session in pairs(sessions) do
		session.Clock = now - session.Born
		local t = session.Clock
		local anchor = session.Anchor
		local alive = anchor.Parent ~= nil
		if alive then
			session.Frame = anchor.CFrame
			if session.Options.Travel then
				session.Frame *= CFrame.new(0, 0, -t * 5)
			end
			refreshSize(session)
			local phase = anchor:GetAttribute("VFXPhase")
			if phase == "End" and not session.Ending then
				session:Finish()
			end
		elseif not session.Ending and not session.OneShot then
			session:Finish()
		end
		if session.Options.Duration and t > session.Options.Duration and not session.Ending then
			session:Finish()
		end
		if session.OneShot and not session.Ending and t > session.Linger + 0.05 then
			session:Finish()
		end
		if session.EndAt and t > session.EndAt then
			session:Stop()
			continue
		end
		if session.Stopped then
			continue
		end
		-- Projectiles face their actual motion so trails, streaks and stretched shells follow
		-- curved/homing paths; everything else uses the anchor's authoritative frame.
		local frame = session.Frame
		if session.Role == "Projectile" then
			local position = frame.Position
			if session.LastPosition and dt > 0 then
				local velocity = (position - session.LastPosition) / dt
				if velocity.Magnitude > 2 then
					local target = velocity.Unit
					session.Heading = if session.Heading
						then session.Heading:Lerp(target, math.min(1, dt * 18))
						else target
				end
			end
			session.LastPosition = position
			if session.Heading and session.Heading.Magnitude > 0.01 then
				frame = CFrame.lookAt(position, position + session.Heading)
			end
		end
		session.Host.CFrame = frame
		if GROUNDED_ROLES[session.Role] and (session.FloorAt == nil or t - session.FloorAt > 0.5) then
			session.FloorAt = t
			local top = frame.Position + Vector3.new(0, session.Size.Y * 0.5, 0)
			local floor = floorBelow(top, { session.Folder, anchor }, session.Size.Y + 8)
			session.FloorY = if floor then floor.Y else nil
		end
		for _, attachment in session.EndAttachments do
			attachment.Position = Vector3.new(0, 0, -(session.Range or 10))
		end
		for _, shape in session.ShapeHosts do
			placeShape(session, shape, frame)
		end
		if session.Role == "Cast" and session.Phase == "Gather" then
			session.Ramp = math.clamp(t / session.ChargeTime, 0, 1) ^ 0.7
		end
		local distance = if camera then (camera.CFrame.Position - frame.Position).Magnitude else 0
		local tier = if distance > HIDDEN_DISTANCE then 0 elseif distance > DETAIL_DISTANCE then 1 else 3
		if session.ConnectedFire then
			local fade = if session.Ending then 1 - math.clamp((t - session.Ending) / 0.3, 0, 1) else 1
			session.ConnectedFire:Update(frame, t, tier > 0, fade, session.Quality, distance > DETAIL_DISTANCE)
		end
		for _, entry in session.Entries do
			updateEntry(session, entry, t, dt, frame, tier)
		end
	end
end

function Renderer.start()
	if connection and connection.Connected then
		return
	end
	Assets.prefetch()
	ConnectedFire.prefetch()
	connection = RunService.Heartbeat:Connect(step)
end

-- Returns a session (with .Replaces for the composer) or nil when no signature covers the plan.
function Renderer.attach(anchor: BasePart, plan, options)
	options = options or {}
	if not Renderer.Enabled or usage.Sessions >= Budget.MaxSessions then
		return nil
	end
	local phase = anchor:GetAttribute("VFXPhase") or plan.Phase or "Sustain"
	local quality = options.Quality or Renderer.Quality
	local resolved = Planner.plan(plan, phase, { CastingCue = plan.CastingCue, Quality = quality, DirectionalSprites = Renderer.UseDirectionalSprites and Assets.UseCustom })
	if not resolved or #resolved.Layers == 0 then
		return nil
	end
	if not connection or not connection.Connected then
		Renderer.start()
	end
	local f = Instance.new("Folder")
	f.Name = "Signature_" .. resolved.Signature .. "_" .. resolved.Role
	f.Parent = options.Parent or folder()
	local host = invisiblePart("Host", f)
	host.CFrame = anchor.CFrame
	local attachment = Instance.new("Attachment")
	attachment.Parent = host
	local geometry = plan.Geometry or "Sphere"
	local session = setmetatable({
		Anchor = anchor,
		Plan = plan,
		Options = options,
		Quality = quality,
		Role = resolved.Role,
		Signature = resolved.Signature,
		Phase = phase,
		Replaces = resolved.Replaces,
		Scalars = resolved.Scalars,
		Folder = f,
		Host = host,
		Attachment = attachment,
		Entries = {},
		ShapeHosts = {},
		EndAttachments = {},
		Owned = { Emitters = 0, Rate = 0, Meshes = 0, Lights = 0, Trails = 0 },
		Born = os.clock(),
		Clock = 0,
		Linger = 0.2,
		Ramp = if resolved.Role == "Cast" and phase == "Gather" then 0 else 1,
		-- Inverse of the extractor's sqrt(cast / 5) curve, so the ramp tracks the real charge time.
		ChargeTime = math.max(0.25, (resolved.Scalars.Charge ^ 2) * 5),
		Seed = tonumber(plan.Seed) or 0,
		Frame = anchor.CFrame,
		OneShot = ONE_SHOT_ROLES[resolved.Role] == true,
		Round = geometry ~= "Box" and geometry ~= "Plane" and geometry ~= "Line",
	}, Session)
	refreshSize(session)
	-- Body scale follows the real hit size (diameter 2.2 = scale 1); areas keep their own extents.
	-- Small darts keep a readable floor so their signature doesn't shrink to a speck.
	if resolved.Role == "Projectile" then
		local size = session.Size
		session.Scale = math.clamp(math.min(size.X, size.Y, size.Z) / 2.2, 0.65, 3.5)
	else
		session.Scale = 1
	end
	if GROUNDED_ROLES[session.Role] then
		local top = anchor.Position + Vector3.new(0, session.Size.Y * 0.5, 0)
		local floor = floorBelow(top, { f, anchor }, session.Size.Y + 8)
		session.FloorY = if floor then floor.Y else nil
		session.FloorAt = 0
	end
	for _, a in session.EndAttachments do
		a.Position = Vector3.new(0, 0, -(session.Range or 10))
	end
	usage.Sessions += 1
	sessions[session] = true
	local layers = resolved.Layers
	if Renderer.UseConnectedFire and Assets.UseCustom and resolved.Signature == "Fire" and resolved.Role == "Projectile"
		and phase ~= "End" and usage.Meshes < Budget.MaxMeshes then
		session.ConnectedFire = ConnectedFire.new(f, session.Scale)
		if session.ConnectedFire then
			usage.Meshes += 1
			session.Owned.Meshes += 1
			-- The approved body includes its wake; retain only the existing budgeted light.
			layers = {}
			for _, layer in resolved.Layers do
				if layer.Kind == "Light" then table.insert(layers, layer) end
			end
			session.ConnectedFire:Update(anchor.CFrame, 0, true, 1, quality, false)
		end
	end
	buildLayers(session, layers)
	for _, a in session.EndAttachments do
		a.Position = Vector3.new(0, 0, -(session.Range or 10))
	end
	-- The server's projectile part is a primitive stand-in; hide it locally (it still exists and
	-- moves authoritatively) whenever this signature draws the projectile body instead.
	if resolved.Role == "Projectile" and resolved.Replaces.Form then
		anchor.LocalTransparencyModifier = 1
		for _, child in anchor:GetChildren() do
			if child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("PointLight") then
				child.Enabled = false
			end
		end
	end
	-- Field/aura markers are translucent Neon volumes stamped as the anchor itself (capsules carry
	-- welded caps, cones edge beams). The signature draws the area instead, so hide them locally.
	if (resolved.Role == "Field" or resolved.Role == "Aura") and resolved.Replaces.Form then
		if anchor.Transparency < 1 then
			anchor.LocalTransparencyModifier = 1
		end
		for _, child in anchor:GetDescendants() do
			if child:IsA("BasePart") then
				child.LocalTransparencyModifier = 1
			elseif child:IsA("Beam") then
				child.Enabled = false
			end
		end
	end
	return session
end

function Renderer.stats()
	return table.clone(usage)
end

function Renderer.stopAll()
	for session in pairs(sessions) do
		session:Stop()
	end
end

return Renderer
]=];end
do local m=s.Core.SpellVFXComposer;if not backup:FindFirstChild("SpellVFXComposer") then m:Clone().Parent=backup end;m.Source=[=[-- Shared client renderer: normal play and world previews use these exact layers.
-- Instantiates a pure SpellVisualPlanBuilder render plan; owns lifecycle, distance tiers and cleanup.
local RunService = game:GetService("RunService")
local Analyzer = require(script.Parent.SpellVFXAnalyzer)
local Builder = require(script.Parent.Parent.Visual.SpellVisualPlanBuilder)
local Library = require(script.Parent.Parent.Visual.SpellVisualAssetLibrary)
local Colors = require(script.Parent.Parent.Parent.Configuration.MagicElements)
local Composer = {}
local Global = Library.Budget.Global
local active = 0
local emitterCount = 0
local continuousRate = 0
local fireCount = 0
local lightCount = 0
local tau = math.pi * 2
local golden = 0.6180339
-- Client quality preset; lower tiers keep silhouettes and drop detail first.
Composer.Quality = "High"
-- Optional signature renderer (Signature/SignatureRenderer), injected by the client controller.
-- When it covers a spell, its asset-based layers replace the composer layers it names in
-- `Replaces` (Form = priority 1, Element = 2, Mechanic = 3, Detail = 4).
Composer.Signatures = nil
local REPLACED_PRIORITY = { [1] = "Form", [2] = "Element", [3] = "Mechanic", [4] = "Detail" }

local TEXTURES = {
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}
local ELEMENT_TEXTURE = {}
for name, element in pairs(Library.Elements) do
	ELEMENT_TEXTURE[name] = element.Texture
end
local WEDGE = { Crystal = true, Flame = true, Wedge = true, Shard = true }
local BALL = { Bubble = true, Ripple = true, Sphere = true }

local function part(parent, color, motif)
	local p = Instance.new(if WEDGE[motif] then "WedgePart" else "Part")
	p.Name = "Element" .. motif
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.CastShadow = false
	p.Material = if motif == "Stone" or motif == "Slab"
		then Enum.Material.Slate
		elseif motif == "Shell" or motif == "Band" then Enum.Material.ForceField
		else Enum.Material.Neon
	p.Color = color
	if p:IsA("Part") then
		if BALL[motif] or motif == "Shell" then
			p.Shape = Enum.PartType.Ball
		elseif motif == "Band" or motif == "Disc" then
			p.Shape = Enum.PartType.Cylinder
		end
	end
	p.Transparency = 1
	p.Parent = parent
	return p
end

-- Footprint samples, normalized in gameplay's forward (-Z), Y-up frame. Boundaries sit at
-- +/-0.49; cosmetic volumes stay inside it so they never imply a larger hit area.
local function geometrySample(plan, i, count, t, height)
	local a = i / count * tau
	local level = (i * golden) % 1
	local geometry = plan.Geometry
	if geometry == "Cone" then
		local depth = 0.2 + level * 0.8
		return Vector3.new(math.cos(a) * depth * 0.45, (level - 0.5) * height * 0.7, -depth)
	elseif geometry == "Box" or geometry == "Plane" or geometry == "Line" then
		local side = i % 4
		return Vector3.new(side < 2 and -0.46 or 0.46, (level - 0.5) * height, side % 2 == 0 and -0.46 or 0.46)
	elseif geometry == "Ring" then
		local inner = math.max(0.1, (plan.RingInner or 0.5) * 0.5)
		local r = if i % 2 == 0 then 0.47 else math.min(0.47, inner + 0.02)
		return Vector3.new(math.cos(a) * r, (level - 0.5) * height * 0.6, math.sin(a) * r)
	end
	local y = (level - 0.5) * height
	local r = (if i % 3 == 0 then 0.24 else 0.46) * math.sqrt(math.max(0, 1 - (y * 2) ^ 2))
	return Vector3.new(math.cos(a + t * 0.12) * r, y, math.sin(a + t * 0.12) * r)
end

local function boundarySample(plan, i)
	local angle = i / 8 * tau
	local offset
	if plan.Geometry == "Cone" then
		local perimeter = {
			Vector3.new(0, 0, 0),
			Vector3.new(-0.25, 0, -0.5),
			Vector3.new(-0.5, 0, -1),
			Vector3.new(-0.25, 0, -1),
			Vector3.new(0, 0, -1),
			Vector3.new(0.25, 0, -1),
			Vector3.new(0.5, 0, -1),
			Vector3.new(0.25, 0, -0.5),
		}
		offset = perimeter[(i - 1) % 8 + 1]
	elseif plan.Geometry == "Box" or plan.Geometry == "Plane" or plan.Geometry == "Line" then
		local x, z = math.cos(angle), math.sin(angle)
		local denominator = math.max(math.abs(x), math.abs(z))
		offset = Vector3.new(x / denominator * 0.49, 0, z / denominator * 0.49)
	else
		offset = Vector3.new(math.cos(angle) * 0.49, 0, math.sin(angle) * 0.49)
	end
	return Vector3.new(offset.X, -0.48, offset.Z)
end

-- Even, deterministic spread over the authoritative ground footprint (x, z in -0.5..0.5).
-- Golden-angle spiral for round areas, an R2 low-discrepancy grid for boxes; inside 0.46.
local function groundPoint(plan, i, n, phase)
	local geometry = plan.Geometry
	local u = (i - 0.5) / math.max(n, 1)
	if geometry == "Box" or geometry == "Plane" or geometry == "Line" then
		return ((i * 0.7548777 + phase / tau) % 1 - 0.5) * 0.9, ((i * 0.5698403 + 0.31) % 1 - 0.5) * 0.9
	elseif geometry == "Cone" then
		local depth = 0.15 + math.sqrt(u) * 0.8
		local across = ((i * golden + phase / tau) % 1 - 0.5) * depth * 0.85
		return across, -depth
	end
	local a = i * 2.3999632 + phase
	local r
	if geometry == "Ring" then
		local inner = math.max(0.1, (plan.RingInner or 0.5) * 0.5)
		r = inner + (0.46 - inner) * ((i * golden) % 1)
	else
		r = math.sqrt(u) * 0.46
	end
	return math.cos(a) * r, math.sin(a) * r
end

-- Footprint point from two unit values. Used when something resurfaces each cycle, so
-- successive spots scatter instead of walking outward along the ordered spiral.
local function groundScatter(plan, u, v)
	local geometry = plan.Geometry
	if geometry == "Box" or geometry == "Plane" or geometry == "Line" then
		return (u - 0.5) * 0.9, (v - 0.5) * 0.9
	elseif geometry == "Cone" then
		local depth = 0.15 + math.sqrt(u) * 0.8
		return (v - 0.5) * depth * 0.85, -depth
	end
	local r
	if geometry == "Ring" then
		local inner = math.max(0.1, (plan.RingInner or 0.5) * 0.5)
		r = inner + (0.46 - inner) * u
	else
		r = math.sqrt(u) * 0.46
	end
	return math.cos(v * tau) * r, math.sin(v * tau) * r
end

-- Arrangements that rest on the field floor and stay upright instead of tumbling.
local GROUNDED = { Ground = true, Carpet = true, GroundRadial = true, EdgeBeat = true }
-- Floating accents become ground marks inside a field footprint.
local FIELD_ACCENT = {
	Branches = "GroundRadial",
	Wings = "GroundRadial",
	Seeker = "GroundRadial",
	Lance = "GroundRadial",
	Satellites = "Ground",
	Echo = "Ground",
	Crown = "Ground",
}

-- Offset for node i of a layer at animation time t.
local function sample(plan, layer, i, n, t)
	local p = layer.Params
	local arrangement = layer.Arrangement
	local a = i / n * tau + layer.Phase
	local spin = t * (p.RotationSpeed or 0.5)
	if arrangement == "Core" or arrangement == "Shell" or arrangement == "BeamCore" or arrangement == "BeamAura" then
		return Vector3.zero
	elseif arrangement == "Comet" then
		local r = (p.Spread or 0.55) * 0.5
		return Vector3.new(math.cos(a + spin) * r, math.sin(a + spin) * r, (i % 3) * 0.2 * (1 + (plan.Stretch or 0)))
	elseif arrangement == "Helix" then
		local r = p.Spread or 0.35
		local twist = a * 2 + spin
		return Vector3.new(math.cos(twist) * r, math.sin(twist) * r, -i / n)
	elseif arrangement == "Boundary" then
		return boundarySample(plan, i)
	elseif arrangement == "Volume" or arrangement == "Crest" or arrangement == "Lattice" then
		if arrangement == "Lattice" then
			local side = i % 4
			local level = (i * golden) % 1
			return Vector3.new(side < 2 and -0.48 or 0.48, level - 0.5, side % 2 == 0 and -0.48 or 0.48)
		end
		return geometrySample(plan, i, n, t, p.Height or 0.8)
	elseif arrangement == "Orbit" or arrangement == "Mantle" then
		local r = if arrangement == "Mantle" then 0.5 else 0.42
		local level = (i * golden) % 1
		return Vector3.new(math.cos(a + spin) * r, (level - 0.5) * (p.Height or 0.6), math.sin(a + spin) * r)
	elseif arrangement == "Branches" then
		local elevation = (((i * golden + layer.Curve) % 1) - 0.5) * 1.2
		local dir =
			Vector3.new(math.cos(a) * math.cos(elevation), math.sin(elevation), math.sin(a) * math.cos(elevation))
		return dir * (p.Length or 0.5)
	elseif arrangement == "Satellites" then
		local r = (p.Spread or 0.7) * 0.5
		return Vector3.new(math.cos(a + spin) * r, math.sin(a + spin) * r * 0.6, math.sin(a + spin) * r * 0.4)
	elseif arrangement == "Ascent" then
		local rise = ((t * (p.Speed or 0.5) + i / n) % 1) - 0.5
		return Vector3.new(math.cos(a) * 0.28, rise * 0.9, math.sin(a) * 0.28)
	elseif arrangement == "Bands" then
		return Vector3.new(0, (i / (n + 1) - 0.5) * 0.8, 0)
	elseif arrangement == "Wings" then
		local side = if i % 2 == 0 then 1 else -1
		local rank = math.floor((i - 1) / 2)
		local flap = math.sin(t * (p.Speed or 1) * 3 + layer.Phase) * 0.06
		return Vector3.new(side * (0.3 + rank * 0.12), 0.08 + flap + rank * 0.05, 0.2 + rank * 0.12)
	elseif arrangement == "Seeker" then
		return Vector3.new(0, 0, -(0.45 + (p.Lead or 0.1) + (i - 1) * 0.12))
	elseif arrangement == "Lance" then
		return Vector3.new(0, 0, -(0.5 + (p.Length or 0.6) * 0.5))
	elseif arrangement == "Echo" then
		return Vector3.new(0, 0, i * 0.45)
	elseif arrangement == "Runes" then
		return Vector3.new(math.cos(a + spin) * 0.4, -0.47, math.sin(a + spin) * 0.4)
	elseif arrangement == "Crown" then
		return Vector3.new(math.cos(a + spin) * 0.3, 0.5, math.sin(a + spin) * 0.3)
	elseif arrangement == "Ring" then
		local swell = 1 + (p.PulseAmplitude or 0.1) * math.sin(t * (p.PulseFrequency or 1) * tau + layer.Phase)
		local base = if plan.Form == "Projectile" then 0.32 else 0.42
		local r = math.min(0.49, base * swell)
		local y = if plan.Form == "Projectile" then 0 else -0.47
		return Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
	end
	return Vector3.zero
end

local function elongation(layer)
	local motif, arrangement, p = layer.Motif, layer.Arrangement, layer.Params
	local e = Vector3.one
	if WEDGE[motif] then
		local stretch = p.Elongation or 2.4
		e = Vector3.new(0.6, stretch, 0.8)
	elseif motif == "Ribbon" or motif == "Fork" then
		e = Vector3.new(0.18, 0.3, 3)
	elseif motif == "Rune" or motif == "Glyph" then
		e = Vector3.new(1, 0.12, 1)
	elseif motif == "Slab" then
		e = Vector3.new(1.4, 0.5, 1)
	end
	if arrangement == "Lance" then
		e = Vector3.new(0.3, 0.3, (p.Length or 0.6) * 3)
	elseif arrangement == "Wings" then
		e = Vector3.new((p.Length or 0.4) * 3, 0.12, 0.6)
	elseif arrangement == "Seeker" then
		e = Vector3.new(0.4, 0.4, 1.6)
	end
	return e
end

-- Cosmetic only: finds the visible floor under a field. Gameplay areas are centred on the
-- cast point, so the lower half of the hit volume is usually below the terrain.
local function probeFloor(frame, size, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = table.clone(ignore)
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	params.FilterDescendantsInstances = excluded
	local top = frame.Position + Vector3.new(0, size.Y * 0.5, 0)
	local hit = workspace:Raycast(top, Vector3.new(0, -(size.Y + 6), 0), params)
	if not hit then
		return -size.Y * 0.5
	end
	return math.clamp(frame:PointToObjectSpace(hit.Position).Y, -size.Y * 0.5, size.Y * 0.45)
end

local function maxPriorityAt(distance)
	for _, tier in ipairs(Library.Budget.DistanceTiers) do
		if distance < tier[1] then
			return tier[2]
		end
	end
	return 0
end

function Composer.attach(anchor, plan, options)
	options = options or {}
	plan = Analyzer.forPhase(plan, anchor:GetAttribute("VFXPhase") or plan.Phase, anchor.Name)
	local castingCue = plan.CastingCue
	if active >= Global.MaxSessions then
		return nil
	end
	active += 1
	local render = Builder.build(plan, { Quality = options.Quality or Composer.Quality })
	-- A release at the caster is an acknowledgement, never an impact. Enforce this
	-- even if the signature renderer is disabled or has exhausted its budget.
	if castingCue and anchor:GetAttribute("VFXPhase") == "Release" then
		render.Layers = {}
	end
	local signature = Composer.Signatures and Composer.Signatures.attach(anchor, plan, options)
	if signature then
		local kept = {}
		for _, layer in ipairs(render.Layers) do
			if not signature.Replaces[REPLACED_PRIORITY[layer.Priority] or ""] then
				table.insert(kept, layer)
			end
		end
		render.Layers = kept
	end
	local folder = Instance.new("Folder")
	folder.Name = "ComposedSpellLayers"
	folder.Parent = options.Parent or workspace
	local primary = plan.Color or Colors[plan.Element] or Colors.Neutral
	local secondary = plan.SecondaryColor or primary:Lerp(Color3.new(0.1, 0.1, 0.2), 0.35)
	local accent = plan.AccentColor or primary:Lerp(Color3.new(1, 1, 1), 0.75)
	-- One invisible host carries emitters, light and trails at the composition centre.
	local host = part(folder, primary, "Host")
	host.Size = Vector3.one * 0.2
	local hostAttachment = Instance.new("Attachment")
	hostAttachment.Parent = host
	-- Fields emit from their whole floor so particles rise across the real footprint.
	local grounded = plan.Form == "Field" and not castingCue
	local areaHost
	if grounded then
		areaHost = part(folder, primary, "Host")
		areaHost.Size = Vector3.one * 0.2
		for _, layer in ipairs(render.Layers) do
			if layer.Priority == 3 and FIELD_ACCENT[layer.Arrangement] then
				layer.Arrangement = FIELD_ACCENT[layer.Arrangement]
			elseif layer.Arrangement == "Ring" then
				-- Tick/DoT/growth pulses add no objects; they make the field's own outline and
				-- floor throb at the pulse frequency.
				layer.Arrangement = "EdgeBeat"
			end
		end
	end
	local round = plan.Geometry ~= "Box"
		and plan.Geometry ~= "Plane"
		and plan.Geometry ~= "Line"
		and plan.Geometry ~= "Cone"
	local layers = {}
	local owned = { Emitters = 0, Rate = 0, Fire = 0, Lights = 0 }
	local flameHosts = {}
	for _, layer in ipairs(render.Layers) do
		local p = layer.Params
		local entry = { Layer = layer, Nodes = {}, Links = {}, Emitters = {}, Fires = {}, Trails = {} }
		if layer.Kind == "Nodes" then
			local motif = layer.Motif
			if layer.Arrangement == "Shell" then
				motif = "Shell"
			elseif layer.Arrangement == "Bands" then
				motif = "Band"
			end
			local nodeCount = p.Count
			if layer.Arrangement == "EdgeBeat" then
				entry.Beat = true
				nodeCount = 0
			end
			for i = 1, nodeCount do
				local isAccent = layer.Priority == 3 or i % 3 == 0 or layer.Arrangement == "Core"
				local color = if isAccent then accent else primary
				local nodeMotif = motif
				if grounded and layer.Arrangement == "Carpet" then
					-- Murky floor in the element's darker tone; boxy footprints get a block.
					color = if i == 1 then secondary else primary:Lerp(secondary, 0.5)
					if i == 1 and not round and plan.Geometry ~= "Ring" then
						nodeMotif = "Floor"
					end
				elseif grounded and (motif == "Bubble" or motif == "Ripple") then
					color = if i % 3 == 0 then primary:Lerp(accent, 0.3) else primary:Lerp(secondary, 0.25)
				end
				local node = part(folder, color, nodeMotif)
				local attachment = Instance.new("Attachment")
				attachment.Parent = node
				entry.Nodes[i] = { Part = node, Attachment = attachment, Motif = nodeMotif }
				if layer.Id == "Fire.Flames" then
					table.insert(flameHosts, node)
				end
			end
			-- Scattered ground bodies are not a chain: linking them draws random streaks across
			-- the field. Only lightning keeps links there, as flickering arcs.
			local links = p.LinkCount or 0
			if grounded and GROUNDED[layer.Arrangement] and layer.Motif ~= "Fork" then
				links = 0
			end
			for i = 1, links do
				local beam = Instance.new("Beam")
				local closed = layer.Arrangement == "Boundary" or layer.Arrangement == "Crest"
				local j = if closed or i < p.Count then i % p.Count + 1 else i
				beam.Attachment0, beam.Attachment1 = entry.Nodes[i].Attachment, entry.Nodes[j].Attachment
				beam.Color = ColorSequence.new(primary, accent)
				beam.FaceCamera = true
				beam.LightEmission = 0.8
				beam.Transparency = NumberSequence.new(0.18)
				beam.Segments = 8
				beam.Parent = folder
				entry.Links[i] = beam
			end
		elseif layer.Kind == "Emitter" then
			local rate = p.Rate
			if emitterCount < Global.MaxEmitters and continuousRate + rate <= Global.MaxContinuousRate then
				emitterCount += 1
				continuousRate += rate
				owned.Emitters += 1
				owned.Rate += rate
				local e = Instance.new("ParticleEmitter")
				local texture = if layer.Texture == "Element" then ELEMENT_TEXTURE[plan.Element] else layer.Texture
				e.Texture = TEXTURES[texture or "Sparkle"] or TEXTURES.Sparkle
				e.Color = ColorSequence.new(accent, secondary)
				e.LightEmission = if texture == "Smoke" then 0.2 else 0.8
				e.Rate = rate
				e.Lifetime = NumberRange.new(p.Lifetime * 0.7, p.Lifetime)
				e.Speed = NumberRange.new((p.Speed or 1) * 0.6, p.Speed or 1)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Transparency = NumberSequence.new(1 - (p.Opacity or 0.88), 1)
				e.Acceleration = Vector3.new(0, p.Rise or 0, 0)
				if areaHost then
					e.Shape = if round then Enum.ParticleEmitterShape.Disc else Enum.ParticleEmitterShape.Box
					e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
					e.EmissionDirection = Enum.NormalId.Top
					e.SpreadAngle = Vector2.new(18, 18)
					e.Parent = areaHost
				else
					e.Parent = host
				end
				entry.Emitters[1] = e
			end
		elseif layer.Kind == "Fire" then
			for i = 1, p.Count do
				if fireCount >= Global.MaxFire then
					break
				end
				local flame = Instance.new("Fire")
				flame.Color, flame.SecondaryColor = primary, accent
				flame.Heat = p.Heat
				flame.Size = p.Size
				flame.Parent = flameHosts[i] or host
				fireCount += 1
				owned.Fire += 1
				entry.Fires[i] = flame
			end
		elseif layer.Kind == "Light" then
			if lightCount < Global.MaxLights then
				lightCount += 1
				owned.Lights += 1
				local light = Instance.new("PointLight")
				light.Color, light.Shadows = primary, false
				light.Parent = host
				entry.Light = light
			end
		elseif layer.Kind == "Trail" and not castingCue then
			for i = 1, p.Count do
				local half = p.Width * (if i == 1 then 0.6 else 1.4) * 0.5
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position, a1.Position = Vector3.new(-half, 0, 0), Vector3.new(half, 0, 0)
				a0.Parent, a1.Parent = host, host
				local trail = Instance.new("Trail")
				trail.Attachment0, trail.Attachment1 = a0, a1
				trail.Color = ColorSequence.new(accent, primary)
				trail.Lifetime = p.Lifetime
				trail.LightEmission = 1
				trail.FaceCamera = true
				trail.Transparency = NumberSequence.new(1 - (p.Opacity or 0.85), 1)
				trail.Parent = folder
				entry.Trails[i] = { Trail = trail, A0 = a0, A1 = a1, Half = half }
			end
		end
		table.insert(layers, entry)
	end
	local start, ending, ended = os.clock(), nil, false
	local lastFrame = anchor.CFrame
	local lastSize = if plan.Form == "Construct" and not options.Size
		then anchor.Size
		else anchor:GetAttribute("VFXSize") or options.Size or anchor.Size
	local connection
	local floorY, lastProbe = nil, -math.huge
	-- Render plan and live layer handles are exposed read-only for tooling and tests.
	local session = { Render = render, Layers = layers, Signature = signature }
	function session:Finish()
		if not ending then
			ending = os.clock() - start
		end
		if signature then
			signature:Finish()
		end
	end
	function session:Stop(cancel)
		if ended then
			return
		end
		ended = true
		active -= 1
		emitterCount -= owned.Emitters
		continuousRate -= owned.Rate
		fireCount -= owned.Fire
		lightCount -= owned.Lights
		if connection then
			connection:Disconnect()
		end
		-- Visibility cancellation must not masquerade as a spell ending or hit.
		if signature then
			if cancel then signature:Stop() else signature:Finish() end
		end
		folder:Destroy()
	end
	connection = RunService.Heartbeat:Connect(function()
		if not folder.Parent then
			session:Stop()
			return
		end
		local t = os.clock() - start
		if not anchor.Parent then
			session:Finish()
		end
		local phase = anchor:GetAttribute("VFXPhase") or plan.Phase
		if phase == "End" and not ending then
			ending = t
		end
		if ending and t - ending > 0.6 then
			session:Stop()
			return
		end
		if options.Duration and t > options.Duration then
			session:Finish()
		end
		local camera = workspace.CurrentCamera
		local distance = camera and (camera.CFrame.Position - lastFrame.Position).Magnitude or 0
		local visible = distance < Library.Budget.HiddenDistance
		local tierPriority = maxPriorityAt(distance)
		local fade = ending and math.clamp((t - ending) / 0.6, 0, 1) or 0
		local envelope = math.min(1, t / 0.16) * (1 - fade)
		if anchor.Parent then
			lastSize = if plan.Form == "Construct" and not options.Size
				then anchor.Size
				else anchor:GetAttribute("VFXSize") or options.Size or anchor.Size
			lastFrame = anchor.CFrame
		end
		local size, frame = lastSize, lastFrame
		if castingCue then
			size *= 0.35
		end
		if options.Travel then
			frame *= CFrame.new(0, 0, -t * 5)
		end
		if anchor:GetAttribute("VFXRotated") then
			frame *= CFrame.Angles(0, 0, -math.pi / 2)
		end
		host.CFrame = frame
		if grounded and (floorY == nil or t - lastProbe > 0.5) then
			lastProbe = t
			floorY = probeFloor(frame, size, { folder, anchor })
		end
		local floor = floorY or -size.Y * 0.5
		if areaHost then
			if plan.Geometry == "Cone" then
				areaHost.Size = Vector3.new(size.X * 0.4, 0.2, size.Z * 0.7)
				areaHost.CFrame = frame * CFrame.new(0, floor + 0.1, -size.Z * 0.55)
			else
				areaHost.Size = Vector3.new(size.X * 0.88, 0.2, size.Z * 0.88)
				areaHost.CFrame = frame * CFrame.new(0, floor + 0.1, 0)
			end
		end
		if phase == "Gather" then
			envelope *= 0.55 + math.min(t, 1) * 0.45
		end
		-- Slow/time dilation make the whole composition move heavier.
		local anim = t * render.TimeScale
		-- Field throb: the strongest pulse accent (DoT tick, channel tick, growth) at its
		-- real frequency, sharpened so each tick reads as a beat.
		local beat = 0
		for _, entry in layers do
			if entry.Beat then
				local p = entry.Layer.Params
				local wave = math.max(0, math.sin(anim * (p.PulseFrequency or 1) * tau + entry.Layer.Phase))
				beat = math.max(beat, math.min(1, (p.PulseAmplitude or 0.2) * 2.4) * wave ^ 3)
			end
		end
		local minDim = math.min(size.X, size.Y, size.Z)
		local base = math.clamp(math.min(size.X, math.max(size.Y, 2), size.Z) * 0.17, 0.45, 3)
		for _, entry in layers do
			local layer = entry.Layer
			local p = layer.Params
			local shown = visible and layer.Priority <= math.max(1, tierPriority)
			local speed = render.ElementSpeed * (if plan.Form == "Projectile" then render.MotionRate else 1)
			local n = #entry.Nodes
			for i, node in entry.Nodes do
				local arrangement = layer.Arrangement
				local pulse = 1
					+ (p.PulseAmplitude or 0.08)
						* math.sin(anim * (p.PulseFrequency or plan.Speed or 1) * tau * 0.5 + layer.Phase + i)
				local offset = sample(plan, layer, i, n, anim * speed * 0.4)
				if p.Turbulence then
					offset += Vector3.new(
						math.sin(anim * 3.1 + i),
						math.sin(anim * 2.3 + i * 1.7),
						math.cos(anim * 2.7 + i)
					) * p.Turbulence * 0.06
				end
				if phase == "Gather" and layer.Priority ~= 1 then
					local angle = i / n * tau + anim * 2
					offset = Vector3.new(math.cos(angle) * 0.6, math.sin(angle) * 0.4, 0)
				end
				if phase == "Impact" then
					offset *= (0.35 + t * 2.5) * (p.BurstSize or 1)
				end
				if arrangement == "Crest" then
					offset *= math.min(1, 0.2 + t * 2)
				end
				if grounded and (arrangement == "Boundary" or arrangement == "Ring" or arrangement == "Runes") then
					offset = Vector3.new(offset.X, (floor + 0.05) / math.max(size.Y, 0.01), offset.Z)
				end
				local partSize
				local groundOpacity
				local cframe = frame * CFrame.new(offset * size)
				if grounded and GROUNDED[arrangement] then
					-- Grounded field layers: evenly spread inside the footprint, resting on the
					-- visible ground and never above the top of the authoritative volume.
					local x, z = groundPoint(plan, i, n, layer.Phase)
					local footprint = math.min(size.X, size.Z)
					local yaw = i * 2.3999632 + layer.Phase
					local variation = 0.65 + 0.7 * ((i * golden + layer.Phase / tau) % 1)
					local ceiling = size.Y * 0.5 - floor
					local motif = layer.Motif
					if arrangement == "Carpet" then
						if i == 1 then
							-- One faint surface that fills the real footprint (rings stay open).
							local inset = if plan.Geometry == "Cone" then 0.7 else 0.94
							if node.Motif == "Floor" then
								partSize = Vector3.new(size.X * inset, 0.05, size.Z * inset) * envelope
								local zOffset = if plan.Geometry == "Cone" then -size.Z * 0.5 else 0
								cframe = frame * CFrame.new(0, floor + 0.03, zOffset)
							else
								local d = footprint * 0.94
								partSize = Vector3.new(0.05, d, d) * envelope
								cframe = frame * CFrame.new(0, floor + 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2)
							end
							-- Ring fields keep their open centre, so they get no full surface.
							groundOpacity = if plan.Geometry == "Ring"
								then 0
								else (p.Opacity or 0.22) * 0.9 * (1 + 0.8 * beat)
						else
							-- A few dim, irregular blotches for texture rather than bright pads.
							local d = footprint * 0.16 * variation * pulse
							local aspect = 0.55 + 0.4 * ((i * 0.37 + layer.Phase / tau) % 1)
							partSize = Vector3.new(0.05, d, d * aspect) * envelope
							cframe = frame
								* CFrame.new(x * size.X, floor + 0.04 + i * 0.003, z * size.Z)
								* CFrame.Angles(0, yaw, math.pi / 2)
							groundOpacity = (p.Opacity or 0.22) * 0.55
						end
					elseif arrangement == "GroundRadial" then
						local length = footprint * (0.12 + (p.Length or 0.4) * 0.25)
						local width = math.max(0.15, base * (p.Scale or 0.4) * 0.5)
						partSize = Vector3.new(width, 0.08, length) * envelope
						cframe = frame
							* CFrame.new(x * size.X, floor + 0.05, z * size.Z)
							* CFrame.Angles(0, math.atan2(-x, -z) + math.pi, 0)
					elseif motif == "Bubble" or motif == "Ripple" then
						-- Cyclic surface events: bubbles swell then pop, ripples spread then fade.
						-- Faster DoT ticks bubble faster; each cycle surfaces somewhere new.
						local rate = math.max(0.35, (p.PulseFrequency or 0.8) * 0.45)
						local cycle = anim * rate * render.TimeScale + (i * golden)
						local k = math.floor(cycle)
						local f = cycle - k
						local u = (i * golden + k * 0.7548777 + layer.Phase / tau) % 1
						local v = (i * 0.5698403 + k * 0.3819660 * 1.7 + 0.71) % 1
						x, z = groundScatter(plan, u, v)
						if motif == "Bubble" then
							local maxD = math.clamp(footprint * 0.05 * (p.Scale or 0.6), 0.25, 1.2) * variation
							local grow = if f < 0.8 then (f / 0.8) ^ 0.7 else 1 + (f - 0.8) * 1.5
							local d = maxD * grow * (if f > 0.92 then 0 else 1) * envelope
							partSize = Vector3.one * math.max(0.02, d)
							local rise = math.min(f * 0.35 * maxD, math.max(0, ceiling - d))
							cframe = frame * CFrame.new(x * size.X, floor + d * 0.3 + rise, z * size.Z)
							groundOpacity = 0.55 * (1 - math.max(0, f - 0.75) * 2)
						else
							local d = footprint * 0.28 * variation * f
							partSize = Vector3.new(0.04, math.max(0.05, d), math.max(0.05, d)) * envelope
							cframe = frame
								* CFrame.new(x * size.X, floor + 0.05, z * size.Z)
								* CFrame.Angles(0, 0, math.pi / 2)
							groundOpacity = 0.6 * (1 - f)
						end
					elseif motif == "Rune" or motif == "Glyph" then
						-- Glyphs lie flat on the ground and turn slowly.
						local d = math.clamp(footprint * 0.12 * (p.Scale or 0.5) * variation, 0.6, 3) * pulse
						partSize = Vector3.new(d, 0.06, d) * envelope
						cframe = frame
							* CFrame.new(x * size.X, floor + 0.05, z * size.Z)
							* CFrame.Angles(0, yaw + anim * (p.RotationSpeed or 0.5) * 0.3, 0)
					elseif motif == "Stone" or motif == "Slab" then
						-- Rubble rests half-buried; it does not sway or spin.
						local d = math.clamp(footprint * 0.08 * (p.Scale or 0.8) * variation, 0.5, ceiling)
						partSize = Vector3.new(d, d * (if motif == "Slab" then 0.4 else 0.75), d * 0.85) * envelope
						cframe = frame
							* CFrame.new(x * size.X, floor + partSize.Y * 0.25, z * size.Z)
							* CFrame.Angles(layer.Tilt, yaw, layer.Tilt * 0.5)
					else
						-- Upright bodies (flames, crystals, forks, ribbons) surge in height with their
						-- pulse (DoT tick rate/strength) and sway rather than tumble.
						local stretch = if WEDGE[motif]
							then (p.Elongation or 2.2)
							else (if motif == "Ribbon" or motif == "Fork" then 2 else 1)
						local maxHeight = math.max(0.5, ceiling * 0.95)
						local height = math.clamp(
							footprint * 0.15 * (p.Scale or 0.6) * variation * pulse,
							0.8,
							maxHeight
						) * envelope
						local width = math.max(0.3, height / stretch * 1.3)
						if motif == "Fork" or motif == "Ribbon" then
							width *= 0.35
						end
						partSize = Vector3.new(width * 0.8, math.max(0.05, height), width * 0.55)
						local sway = math.sin(anim * 1.7 + i * 1.3) * 0.12 * ((p.Turbulence or 0.2) + 0.2)
						cframe = frame
							* CFrame.new(x * size.X, floor + height * 0.5, z * size.Z)
							* CFrame.Angles(sway, yaw, sway * 0.6)
					end
				elseif grounded and arrangement == "Bands" then
					-- Drag/bind bands hug the floor of a field instead of floating.
					local r = (p.Spread or 0.45) * 2 * math.min(size.X, size.Z)
					partSize = Vector3.new(0.05, r, r) * envelope
					cframe = frame
						* CFrame.new(0, floor + 0.08 + i * 0.12, 0)
						* CFrame.Angles(0, anim * (p.Speed or 0.2), math.pi / 2)
				elseif arrangement == "Core" then
					local d = math.max(0.1, minDim * p.Scale * envelope * pulse)
					partSize = Vector3.new(d, d, d * (1 + (p.Stretch or 0) * 2))
					cframe *= CFrame.Angles(anim, anim * 0.6, 0)
				elseif arrangement == "BeamCore" or arrangement == "BeamAura" then
					local scale = p.Scale * (if arrangement == "BeamCore" then envelope * pulse else 1)
					partSize = Vector3.new(math.max(0.08, size.X * scale), math.max(0.08, size.Y * scale), size.Z)
					cframe = frame * CFrame.new(0, 0, -size.Z / 2)
				elseif arrangement == "Shell" then
					local cap = if plan.Form == "Projectile" then 0.75 else 0.98
					local d = minDim * math.min(cap, 0.6 + (i - 1) * p.Thickness * 2) * envelope
					partSize = Vector3.one * math.max(0.1, d)
				elseif arrangement == "Bands" then
					local r = (p.Spread or 0.45) * 2 * math.min(size.X, size.Z)
					partSize = Vector3.new(math.max(0.05, minDim * 0.04), r, r) * envelope
					cframe = frame * CFrame.new(offset * size) * CFrame.Angles(0, anim * (p.Speed or 0.2), math.pi / 2)
				else
					local s = if arrangement == "Helix" then math.clamp(size.X * 0.18, 0.12, 0.5) else base
					partSize = elongation(layer) * math.max(0.02, s * (p.Scale or 0.6) * pulse * envelope)
					cframe *= CFrame.Angles(
						anim * 0.4 + layer.Tilt,
						i + anim * (p.RotationSpeed or 0.5) * speed,
						i * 0.7 + layer.Tilt
					)
				end
				node.Part.Size = partSize
				node.Part.CFrame = cframe
				local opacity = p.Opacity or (if layer.Priority == 3 then 0.75 else 0.85)
				if grounded and arrangement == "Boundary" then
					-- The outline line carries the boundary; no orbs at its corners.
					opacity = 0
				elseif groundOpacity then
					opacity = math.max(0, groundOpacity)
				elseif arrangement == "Shell" then
					opacity *= 1 - (i - 1) * 0.15
				elseif arrangement == "Echo" then
					opacity *= 1 - i * 0.18
				end
				node.Part.Transparency = if shown then math.clamp(1 - opacity * (1 - fade), 0, 1) else 1
			end
			for i, beam in entry.Links do
				beam.Enabled = shown and (distance < 90 or i % 2 == 0)
				local s = if layer.Arrangement == "Helix" then math.clamp(size.X * 0.18, 0.12, 0.5) else base
				beam.Width0 = math.max(0.01, s * (p.LinkWidth or 0.6) * envelope)
				beam.Width1 = beam.Width0 * 0.45
				if grounded and layer.Arrangement == "Boundary" then
					beam.Width0 *= 1 + 1.2 * beat
					beam.Width1 = beam.Width0
					beam.Transparency = NumberSequence.new(math.clamp(0.35 - 0.3 * beat, 0, 1))
				end
				local curl = (layer.Motif == "Ribbon" or layer.Motif == "Ripple") and s * 2 or 0
				beam.CurveSize0, beam.CurveSize1 = curl * math.sin(anim + i + layer.Curve), -curl
				if p.Flicker then
					local hop = math.floor(anim * (p.PulseFrequency or 12))
					beam.Attachment1 = entry.Nodes[(i + hop) % n + 1].Attachment
					beam.Enabled = shown and (i + hop) % 3 ~= 0
				end
			end
			for _, e in entry.Emitters do
				e.Enabled = shown and not ending
				e.Rate = if distance < 70 then p.Rate else p.Rate * 0.5
				local particle = math.clamp(minDim * 0.25, 0.5, 2.5) * (p.Size or 1)
				e.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, particle),
					NumberSequenceKeypoint.new(0.5, particle * 1.6),
					NumberSequenceKeypoint.new(1, 0),
				})
			end
			for i, flame in entry.Fires do
				flame.Enabled = shown and not ending and (distance < 90 or i % 2 == 1)
				local footprint = math.clamp(math.max(size.X, size.Z) / 4, 0.5, 1.5)
				flame.Size = math.clamp(p.Size * footprint * envelope, 2, 14)
			end
			if entry.Light then
				entry.Light.Enabled = shown and distance < 90
				entry.Light.Brightness = p.Brightness * envelope
				entry.Light.Range = math.min(p.Range, math.max(8, math.max(size.X, size.Z) * 1.2))
			end
			for _, trail in entry.Trails do
				trail.Trail.Enabled = shown
				trail.A0.Position = Vector3.new(-trail.Half * minDim, 0, 0)
				trail.A1.Position = Vector3.new(trail.Half * minDim, 0, 0)
			end
		end
	end)
	return session
end
function Composer.preview(spell, frame)
	local plan = Analyzer.resolve(spell)
	local anchor = Instance.new("Part")
	anchor.Name = "SpellCompositionPreview"
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
	anchor.Transparency = 1
	anchor.CFrame = frame
	anchor.Parent = workspace
	local config = spell[plan.Form] or {}
	local size
	if plan.Form == "Projectile" then
		-- Hit diameter only: cosmetic scale never implies a larger hitbox.
		size = Vector3.one * (config.Radius or 1) * 2
	elseif plan.Form == "Beam" then
		size = Vector3.new((config.Width or 1) * 2, (config.Width or 1) * 2, math.min(config.Range or 18, 30))
	elseif plan.Form == "Field" or plan.Form == "Aura" then
		local areaConfig = table.clone(config)
		local defaults = {
			Radius = 6,
			Height = 8,
			Width = 12,
			Depth = 12,
			Range = 12,
			Angle = 60,
			InnerRadius = 3,
			OuterRadius = 6,
			Thickness = 1,
		}
		for key, value in pairs(defaults) do
			if areaConfig[key] == nil then
				areaConfig[key] = value
			end
		end
		size = require(script.Parent.Parent.Parent.Modules.MagicGeometry).areaSize(plan.Geometry, areaConfig)
	elseif plan.Form == "Construct" then
		size = Vector3.new(config.Width or 8, config.Height or 10, config.Depth or 4)
	elseif plan.Form == "Wave" then
		local range = config.Range or 10
		size = plan.Geometry == "Sphere" and Vector3.one * range * 2 or Vector3.new(range * 2, 5, range)
	else
		size = Vector3.new(5, 6, 5)
	end
	local session = Composer.attach(anchor, plan, { Size = size, Duration = 3.4, Travel = plan.Form == "Projectile" })
	game:GetService("Debris"):AddItem(anchor, 4.1)
	return session
end
return Composer
]=];end
do local m=game.StarterPlayer.StarterPlayerScripts.Client.Controllers.SpellVFXController;if not backup:FindFirstChild("SpellVFXController") then m:Clone().Parent=backup end;m.Source=[=[--!strict
-- Plays allowlisted cosmetic definitions received from the server and owns their lifecycle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Rojo maps src/shared beneath ReplicatedStorage.Shared.
local Shared = ReplicatedStorage:WaitForChild("Shared")
local System = Shared:WaitForChild("SpellVFXSystem")
local Service = require(System.Core.VFXService)
local Definitions = require(System.Data.VFXDefinitions)
local Analyzer = require(System.Core.SpellVFXAnalyzer)
local Composer = require(System.Core.SpellVFXComposer)
local Signatures = require(System.Signature.SignatureRenderer)
local CollectionService = game:GetService("CollectionService")
local Controller = {}
local started = false

-- Visual quality: "SpellVFXQuality" player attribute (Low/Medium/High) wins; otherwise touch
-- devices and low graphics levels start lower. Gameplay-critical layers render at every tier.
local QUALITY = { Low = true, Medium = true, High = true }
local function applyQuality()
	local player = game:GetService("Players").LocalPlayer
	local chosen = player and player:GetAttribute("SpellVFXQuality")
	local quality = if type(chosen) == "string" and QUALITY[chosen] then chosen else nil
	if not quality then
		local level = 10
		pcall(function()
			local saved = UserSettings():GetService("UserGameSettings").SavedQualityLevel
			if saved ~= Enum.SavedQualitySetting.Automatic then
				level = saved.Value
			end
		end)
		local touch = game:GetService("UserInputService").TouchEnabled
		quality = if level <= 3 then "Low" elseif level <= 6 or touch then "Medium" else "High"
	end
	Composer.Quality = quality
	Signatures.Quality = quality
end
Controller.applyQuality = applyQuality

function Controller.start(remotes: Instance)
	if started then
		return
	end
	started = true
	-- Generated asset layers (Fire, Body...) join the procedural composer for every anchor and preview.
	Composer.Signatures = Signatures
	Signatures.start()
	applyQuality()
	local localPlayer = game:GetService("Players").LocalPlayer
	localPlayer:GetAttributeChangedSignal("SpellVFXQuality"):Connect(applyQuality)
	local active = {}
	local composed = {}
	local function reconcile()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local candidates = {}
		for _, part in CollectionService:GetTagged("ComposedSpellVFX") do
			if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
				local distance = (camera.CFrame.Position - part.Position).Magnitude
				if distance < 180 and part:GetAttribute("VFXPhase") ~= "End" then
					table.insert(candidates, { Part = part, Distance = distance })
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a.Distance < b.Distance
		end)
		local selected = {}
		for index = 1, math.min(28, #candidates) do
			selected[candidates[index].Part] = true
		end
		for part, session in pairs(composed) do
			if not selected[part] then
				if part:GetAttribute("VFXPhase")=="End" or not part:IsDescendantOf(workspace) then
					session:Finish()
				else
					-- Distance/selection budgets only hide an effect; they never imply impact.
					session:Stop(true)
				end
				composed[part] = nil
			end
		end
		for part in pairs(selected) do
			if not composed[part] then
				composed[part] = Composer.attach(part, Analyzer.read(part))
			end
		end
	end
	CollectionService:GetInstanceAddedSignal("ComposedSpellVFX"):Connect(reconcile)
	CollectionService:GetInstanceRemovedSignal("ComposedSpellVFX"):Connect(function(part)
		if composed[part] then
			if part:GetAttribute("VFXPhase")=="End" or not part:IsDescendantOf(workspace) then
				composed[part]:Finish()
			else
				composed[part]:Stop(true)
			end
			composed[part] = nil
		end
	end)
	local elapsed = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.25 then
			elapsed = 0
			reconcile()
		end
	end)
	reconcile()
	remotes:WaitForChild("SpellVFX").OnClientEvent:Connect(function(id, target, context)
		if type(id) ~= "string" or not Definitions[id] then
			return
		end
		if typeof(target) ~= "Vector3" and typeof(target) ~= "Instance" then
			return
		end
		local visualContext = type(context) == "table" and table.clone(context) or {}
		local session = Service:Play(Definitions[id], target, visualContext)
		table.insert(active, session)
		local duration = if id == "FireBurst" then 1.5 elseif id == "FrostCharge" then 1.8 else 3
		task.delay(duration, function()
			session:Stop()
			local index = table.find(active, session)
			if index then
				table.remove(active, index)
			end
		end)
	end)
	game:GetService("Players").LocalPlayer.CharacterRemoving:Connect(function()
		for _, session in active do
			session:Stop()
		end
		table.clear(active)
	end)
end

return Controller
]=];end
return "Installed grounded elemental fields, source-only cast cue, and connected beam motifs"
