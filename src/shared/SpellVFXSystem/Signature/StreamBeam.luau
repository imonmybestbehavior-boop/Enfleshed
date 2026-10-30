-- Continuous intersecting ribbons: existing banded trail art flows inside a connected volume.
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
