-- Existing rune/rift atlases open at fixed stations; nothing is launched along the path.
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
