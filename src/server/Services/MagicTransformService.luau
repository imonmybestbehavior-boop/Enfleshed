--!strict

-- Transformation modes Polymorph (others) and Shapeshift (self). Rules live in
-- MagicTransformStateSpec; the critter swap lives in MagicTransformVisual.
-- Diminishing returns are shared with Stun (Status.diminish), and Polymorph's
-- slower walk folds into the status slow multiplier (Status.setSpeedFactor).
-- Attributes on the character model and Humanoid:
--   MagicPolymorphed (true while a critter: no melee, no casting)
--   MagicShapeshiftProfile (melee profile name while shapeshifted)
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Spec = require(Shared.Modules.MagicTransformStateSpec)
local Limits = require(Shared.Configuration.MagicLab)
local Status = require(script.Parent.MagicStatusEffectService)
local Visual = require(script.Parent.MagicTransformVisual)

local Transform = {}
-- Clock used for every timing here (the audit harness replaces it).
Transform.now = os.clock

type Record = {
	Humanoid: Humanoid,
	Model: Model,
	State: Spec.State,
	Visual: any?,
	Connections: { RBXScriptConnection },
}

local records: { [Humanoid]: Record } = setmetatable({}, { __mode = "k" }) :: any

local function setFlag(record: Record, name: string, value: any)
	record.Humanoid:SetAttribute(name, value)
	if record.Model.Parent then
		record.Model:SetAttribute(name, value)
	end
end

local clear: (Humanoid) -> ()

local function recordFor(humanoid: Humanoid): Record?
	local existing = records[humanoid]
	if existing then
		return existing
	end
	local model = humanoid.Parent
	if not model or not model:IsA("Model") then
		return nil
	end
	local record: Record = { Humanoid = humanoid, Model = model, State = Spec.new(), Visual = nil, Connections = {} }
	records[humanoid] = record
	-- Death, respawn and leaving restore everything without OnTransformEnd.
	table.insert(
		record.Connections,
		humanoid.Died:Connect(function()
			clear(humanoid)
		end)
	)
	table.insert(
		record.Connections,
		humanoid.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				clear(humanoid)
			end
		end)
	)
	return record
end

-- Applies the current Polymorph/Shapeshift state to the character.
local function sync(record: Record)
	local polymorph = record.State.Polymorph
	if polymorph and not record.Visual then
		record.Visual = Visual.apply(record.Model, polymorph.Color)
	elseif not polymorph and record.Visual then
		Visual.restore(record.Visual)
		record.Visual = nil
	end
	setFlag(record, "MagicPolymorphed", if polymorph then true else nil)
	Status.setSpeedFactor(record.Humanoid, Spec.speedMultiplier(record.State, Limits.PolymorphSpeedMultiplier))
	setFlag(record, "MagicShapeshiftProfile", Spec.meleeProfile(record.State))
	if not polymorph and not record.State.Shapeshift then
		for _, connection in record.Connections do
			connection:Disconnect()
		end
		records[record.Humanoid] = nil
	end
end

local function finish(record: Record, ended: any)
	sync(record)
	if ended and ended.OnEnd then
		task.defer(ended.OnEnd, record.Humanoid)
	end
end

-- Restores everything (death, respawn, leaving): no OnTransformEnd.
clear = function(humanoid: Humanoid)
	local record = records[humanoid]
	if not record then
		return
	end
	record.State = Spec.new()
	sync(record)
end

-- Polymorph `humanoid` for `duration` (already capped). Bosses are immune and
-- Stun's diminishing returns apply. Returns whether it took hold.
function Transform.polymorph(
	caster: Model,
	humanoid: Humanoid,
	spellId: string,
	duration: number,
	breakOnDamage: boolean,
	color: Color3?,
	onEnd: ((Humanoid) -> ())?
): boolean
	local model = humanoid.Parent
	if humanoid.Health <= 0 or not model or not model:IsA("Model") then
		return false
	end
	if Spec.isBoss(model:GetAttribute("MagicBoss"), model:GetAttribute("MissionRole")) then
		return false
	end
	local effective = Status.diminish(humanoid, duration)
	if effective <= 0 then
		return false
	end
	local record = recordFor(humanoid)
	if not record then
		return false
	end
	local entry: any =
		{ SpellId = spellId, Caster = caster, BreakOnDamage = breakOnDamage, Color = color, OnEnd = onEnd }
	Spec.polymorph(record.State, Transform.now(), entry, effective)
	sync(record)
	return true
end

-- Shapeshift the caster's own character (melee profile) for `duration`.
function Transform.shapeshift(
	humanoid: Humanoid,
	spellId: string,
	profile: string,
	duration: number,
	onEnd: ((Humanoid) -> ())?
): boolean
	if humanoid.Health <= 0 then
		return false
	end
	local record = recordFor(humanoid)
	if not record then
		return false
	end
	local entry: any = { SpellId = spellId, Profile = profile, OnEnd = onEnd }
	Spec.shapeshift(record.State, Transform.now(), entry, duration)
	sync(record)
	return true
end

-- Recast: pressing the slot of the spell that shapeshifted you ends it.
function Transform.endShapeshift(humanoid: Humanoid, spellId: string): boolean
	local record = records[humanoid]
	local shapeshift = record and record.State.Shapeshift
	if not record or not shapeshift or shapeshift.SpellId ~= spellId then
		return false
	end
	finish(record, Spec.endShapeshift(record.State))
	return true
end

-- Damage from anyone but the caster breaks a BreakOnDamage Polymorph.
function Transform.onDamaged(humanoid: Humanoid, attacker: Model?)
	local record = records[humanoid]
	if record and Spec.breaksOnDamage(record.State, attacker) then
		finish(record, Spec.endPolymorph(record.State, Transform.now()))
	end
end

-- Cleanse: Polymorph is a Bane, Shapeshift a Boon.
function Transform.cleanseCandidates(humanoid: Humanoid): { any }
	local record = records[humanoid]
	local candidates = {}
	if not record then
		return candidates
	end
	local now = Transform.now()
	local polymorph, shapeshift = record.State.Polymorph, record.State.Shapeshift
	if polymorph then
		table.insert(candidates, {
			Source = "Transformation",
			Polarity = "Bane",
			Remaining = math.max(0, (polymorph.ExpiresAt or now) - now),
			AppliedAt = 0,
			Remove = function()
				finish(record, Spec.endPolymorph(record.State, Transform.now()))
			end,
		})
	end
	if shapeshift then
		table.insert(candidates, {
			Source = "Transformation",
			Polarity = "Boon",
			Remaining = shapeshift.Paused or math.max(0, (shapeshift.ExpiresAt or now) - now),
			AppliedAt = 0,
			Remove = function()
				finish(record, Spec.endShapeshift(record.State))
			end,
		})
	end
	return candidates
end

function Transform.isPolymorphed(humanoid: Humanoid): boolean
	local record = records[humanoid]
	return record ~= nil and record.State.Polymorph ~= nil
end

function Transform.meleeProfile(humanoid: Humanoid): string?
	local record = records[humanoid]
	return if record then Spec.meleeProfile(record.State) else nil
end

-- Expiry: run out Polymorphs and Shapeshifts (a paused Shapeshift waits).
function Transform.step()
	local now = Transform.now()
	for humanoid, record in records do
		if humanoid.Health <= 0 or not humanoid:IsDescendantOf(workspace) then
			clear(humanoid)
		else
			for _, ended in Spec.tick(record.State, now) do
				finish(record, ended.Entry)
			end
		end
	end
end

RunService.Heartbeat:Connect(function()
	Transform.step()
end)

return Transform
