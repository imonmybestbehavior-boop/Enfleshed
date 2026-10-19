--!strict

-- Shared capability metadata for Magic Lab filtering and server SpellSpec validation.
-- New Forms, payloads, triggers, and behaviors declare their editor fields and
-- compatibility here; runtime execution remains in server-owned registries.
local Limits = require(script.Parent.MagicLab)
local SummonLimits = require(script.Parent.MagicSummons)
local PrincipleSpec = require(script.Parent.Parent.Modules.MagicPrincipleSpec)
local DamageRules = require(script.Parent.Parent.Modules.MagicDamageRules)
local AttributeSpec = require(script.Parent.Parent.Modules.MagicAttributeSpec)
local ConstructGeometrySpec = require(script.Parent.Parent.Modules.MagicConstructGeometrySpec)
local TargetDeathSpec = require(script.Parent.Parent.Modules.MagicTargetDeathSpec)
local AudioSpec = require(script.Parent.Parent.Modules.MagicAudioSpec)
local VisualSpec = require(script.Parent.Parent.Modules.MagicVisualSpec)
local MagicPresentation = require(script.Parent.MagicPresentation)
local VisualAssets = require(script.Parent.MagicVisualAssets)

local function set(values: { string }): { [string]: boolean }
	local result = {}
	for _, value in values do
		result[value] = true
	end
	return result
end

local Schema = {}

Schema.Sections = {
	{
		Id = "Setup",
		Label = "Form",
		Description = "Choose how the spell reaches the world, name it, and tune its element and shape.",
	},
	{
		Id = "Targeting",
		Label = "Targeting",
		Description = "Choose where to aim, who can be affected, and how far the spell can reach.",
	},
	{
		Id = "Conditions",
		Label = "Conditions",
		Description = "Set simple or nested rules that decide when a spell can be cast.",
	},
	{
		Id = "ChooseEffects",
		Label = "Choose Effects",
		Description = "Choose compatible gameplay outcomes and when they happen.",
	},
	{
		Id = "ConfigureEffects",
		Label = "Configure Effects",
		Description = "Tune only the effects you selected, with specialist options grouped below.",
	},
	{
		Id = "Casting",
		Label = "Casting",
		Description = "Choose how the spell starts, gathers, channels, or remains active.",
	},
	{
		Id = "Cost",
		Label = "Costs",
		Description = "Review cast demand, cooldowns, and ongoing resource use.",
	},
	{
		Id = "Presentation",
		Label = "Appearance",
		Description = "Choose how the spell looks and sounds: colors, particles, trails, and audio.",
	},
	{
		Id = "Test",
		Label = "Review & Test",
		Description = "Review the live summary, fix validation issues, equip, and test the spell.",
	},
}

Schema.Principles = PrincipleSpec.Order
Schema.PrincipleDefinitions = PrincipleSpec.Definitions
Schema.Elements = DamageRules.Elements
Schema.MarkElements = {}
for _, element in Schema.Elements do
	if element ~= "Neutral" then
		table.insert(Schema.MarkElements, element)
	end
end
Schema.defaultElementForExpression = DamageRules.defaultElementForExpression
Schema.CommandOrder = SummonLimits.CommandOrder
Schema.TargetDeathModes = TargetDeathSpec.Modes
Schema.AudioCues = AudioSpec.Cues
Schema.VisualOptions = {
	Materials = VisualSpec.Materials,
	CoreShapes = VisualSpec.CoreShapes,
	Palettes = VisualSpec.Palettes,
	ParticleStyles = VisualSpec.ParticleStyles,
	TrailStyles = VisualSpec.TrailStyles,
	ImpactStyles = VisualSpec.ImpactStyles,
	CastingStyles = VisualSpec.CastingStyles,
	SurfaceBehaviors = VisualSpec.SurfaceBehaviors,
	EnvironmentalVisuals = VisualSpec.EnvironmentalVisuals,
	VFXDefinitions = VisualSpec.VFXDefinitions,
}
Schema.PresentationProfiles = MagicPresentation.Profiles
Schema.VisualAssetGroups = VisualAssets.Groups
Schema.VisualAssetPresets = VisualAssets.Presets
Schema.EventOrder = {
	"OnCast",
	"OnSpawn",
	"OnImpact",
	"OnProximity",
	"OnDamageDealt",
	"OnDamageTaken",
	"OnMeleeHit",
	"OnHolderDealtDamage",
	"OnThreshold",
	"OnBreak",
	"OnTargetDeath",
	"OnCasterDeath",
	"OnCommand",
	"OnEnter",
	"OnExit",
	"OnInterval",
	"OnTick",
	"OnExpire",
}
-- Who an OnDamageTaken step acts on: the spell's holder (default) or the attacker.
Schema.TargetFromOptions = { "Holder", "Attacker" }
Schema.EventLabels = {
	OnCast = "On cast",
	OnSpawn = "On spawn",
	OnImpact = "On impact",
	OnProximity = "On target approaches",
	OnDamageDealt = "On damage dealt",
	OnDamageTaken = "On damage taken",
	OnMeleeHit = "On melee hit",
	OnHolderDealtDamage = "On holder deals spell damage",
	OnThreshold = "Target crosses health threshold",
	OnEnter = "On target enters",
	OnExit = "On target exits",
	OnInterval = "On interval",
	OnBreak = "On shield break",
	OnTick = "On each pulse",
	OnExpire = "On expire",
	OnCommand = "On command",
}
Schema.EventDescriptions = {
	OnCast = "Runs immediately when this spell is cast.",
	OnSpawn = "Runs when the spell's area or projectile is created.",
	OnImpact = "Runs when a Projectile hits something, or when a Beam resolves. Instant Beams use their server-resolved contact point, or their maximum-range endpoint if unobstructed; channeled Beams run this event on contact.",
	OnProximity = "Happens when someone gets close enough to the moving projectile, your construct, or your active self spell. The proximity settings control the distance and repeat limits.",
	OnDamageDealt = "Runs after this spell successfully deals health damage.",
	OnDamageTaken = "Runs when the active spell's caster takes health damage. A step can target the attacker instead of you.",
	OnMeleeHit = "Runs each time the holder's weapon or claw strike lands while this Enchantment, Aura, or caster-following Field is active. Its target is the creature that was hit.",
	OnHolderDealtDamage = "Runs when the Enchantment's holder deals damage with one of their own spells. Its target is the holder.",
	OnThreshold = "Runs when this spell's health damage moves a target from above its configured health percentage to that percentage or lower.",
	OnBreak = "Runs when a shield created by this spell absorbs damage and its remaining shield points reach zero.",
	OnTargetDeath = "Runs when this spell defeats a target or an active effect it applied is on the target when it dies. Each step can filter which cause should run it.",
	OnCasterDeath = "Runs when the active spell's caster dies.",
	OnEnter = "Runs when a valid target first enters an active Field or Aura, sampled at its pulse interval.",
	OnExit = "Runs when a valid target leaves an active Field or Aura, or when that area ends.",
	OnInterval = "Repeats at the pulse interval set for this spell, just like On each pulse.",
	OnTick = "Runs at the configured interval while a Channeled Beam/Wave/Field/Aura, area, traveling Pulse, or lingering projectile is active.",
	OnExpire = "Runs once when the spell's active duration ends.",
	OnCommand = "Runs when the owner gives this spell's active summon group a validated Follow, Protect, Attack, Hold, Support, or Dismiss order. A step may be limited to one command.",
}

Schema.TargetingModes = {
	AimDirection = { Label = "Aim direction", Description = "Send the spell from you along your aim." },
	EntityTarget = {
		Label = "Aimed entity",
		Description = "Guide the cast toward the living character under your crosshair; reach and optional line of sight are checked by the server.",
	},
	ObjectTarget = {
		Label = "Aimed object",
		Description = "Select a validated solid surface. Constructs and areas can attach to it; Projectile, Beam, Wave, or Manipulation can use Force, Physical control, or an authorized material Raise operation on the exact selected object.",
	},
	WorldPoint = { Label = "World point", Description = "Place or center the spell at a point in the world." },
	Area = {
		Label = "Area center",
		Description = "Place a Field at the aimed area center without selecting a character, object, or tagged material.",
	},
	Self = { Label = "Self", Description = "Center the spell on you." },
	MaterialTarget = {
		Label = "Tagged material object",
		Description = "Aim near a compatible, server-tagged object. Its configured amount is consumed when the cast succeeds; the Form still controls where and how the spell acts.",
	},
}
Schema.TargetingModeOrder =
	{ "AimDirection", "EntityTarget", "ObjectTarget", "WorldPoint", "Area", "Self", "MaterialTarget" }
Schema.TargetPolicies = {
	Aim = "Use only the living character beneath the crosshair.",
	LockOn = "Acquire the most closely aimed eligible character within spell range.",
	AimOrLockOn = "Prefer the crosshair character, then acquire an eligible target in the aim cone.",
	MaintainTarget = "Keep a projectile homing on the selected character; drop the lock if it is lost.",
}
Schema.TargetPolicyOrder = { "Aim", "LockOn", "AimOrLockOn", "MaintainTarget" }
Schema.TargetRelationships = {
	Any = "Allow any eligible target.",
	Hostile = "Only targets marked hostile by the server.",
	Ally = "Only targets allied by server team, alignment, or mutual ally tags.",
	Neutral = "Only targets not classified as an ally or hostile.",
}
Schema.TargetRelationshipOrder = { "Any", "Hostile", "Ally", "Neutral" }

Schema.Forms = {
	Projectile = {
		Label = "Projectile",
		Description = "A spell that travels through the air before hitting something. Set its speed and size here, then choose what happens when it hits on Effects.",
		Geometry = "Sphere",
		Motion = "Linear",
		Draft = {
			Targeting = "AimDirection",
			Lifetime = { Mode = "FixedDuration", Duration = 2.2 },
			Mechanics = {
				Speed = 80,
				Radius = 1,
				MaxDistance = 160,
				Gravity = 0,
				Acceleration = 0,
				ChannelInterval = 0.4,
			},
		},
		Targeting = set({ "AimDirection", "EntityTarget", "ObjectTarget", "MaterialTarget" }),
		TargetTypes = set({ "Humanoid" }),
		Events = set({
			"OnCast",
			"OnSpawn",
			"OnImpact",
			"OnTick",
			"OnDamageDealt",
			"OnDamageTaken",
			"OnTargetDeath",
			"OnCasterDeath",
			"OnExpire",
		}),
		EffectEvents = set({
			"OnImpact",
			"OnTick",
			"OnDamageDealt",
			"OnDamageTaken",
			"OnTargetDeath",
			"OnCasterDeath",
		}),
		DefaultEvent = "OnImpact",
		TargetRules = true,
		Mechanics = {
			{
				Object = "Projectile",
				Key = "Speed",
				Label = "Travel speed",
				Min = 1,
				Max = Limits.MaxSpeed,
				Help = "How quickly the projectile moves.",
			},
			{
				Object = "Projectile",
				Key = "Radius",
				Label = "Projectile size",
				Min = 0.1,
				Max = Limits.MaxRadius,
				Help = "Radius used for collision and hit detection.",
			},
			{
				Object = "Projectile",
				Key = "MaxDistance",
				Label = "Maximum travel distance",
				Min = 1,
				Max = Limits.MaxRange,
				Help = "Projectile stops after this distance.",
			},
			{
				Object = "Projectile",
				Key = "Gravity",
				Label = "Gravity",
				Min = 0,
				Max = Limits.MaxGravity,
				Help = "Downward acceleration in studs per second squared.",
			},
			{
				Object = "Projectile",
				Key = "Acceleration",
				Label = "Acceleration",
				Min = -Limits.MaxAcceleration,
				Max = Limits.MaxAcceleration,
				Help = "Acceleration along the projectile's travel direction.",
			},
			{
				Object = "Projectile",
				Key = "ChannelInterval",
				Label = "Channel shot interval",
				Min = Limits.MinInterval,
				Max = 1,
				Help = "Time between additional server-created projectiles while a Channeled Projectile is held.",
			},
		},
	},
	Beam = {
		Label = "Beam",
		Description = "A Beam reaches its target and stops at an obstacle; Instant Beams can also schedule a bounded Cascade of vertical strikes around the aimed point. Impact effects run at each server-resolved contact.",
		Geometry = "Line",
		Motion = "Instantaneous",
		Draft = {
			Targeting = "AimDirection",
			Lifetime = { Mode = "Instantaneous" },
			Mechanics = {
				Range = 90,
				Width = 0.6,
				DebugDuration = 0.25,
				Interval = 0.15,
				Pattern = "Single",
				StrikeCount = 5,
				SpreadRadius = 12,
				DropHeight = 36,
				StrikeInterval = 0.18,
			},
		},
		Targeting = set({ "AimDirection", "EntityTarget", "ObjectTarget", "MaterialTarget" }),
		TargetTypes = set({ "Humanoid" }),
		Events = set({
			"OnCast",
			"OnImpact",
			"OnTick",
			"OnExpire",
			"OnDamageDealt",
			"OnDamageTaken",
			"OnTargetDeath",
			"OnCasterDeath",
		}),
		EffectEvents = set({
			"OnCast",
			"OnImpact",
			"OnTick",
			"OnExpire",
			"OnDamageDealt",
			"OnDamageTaken",
			"OnTargetDeath",
			"OnCasterDeath",
		}),
		DefaultEvent = "OnCast",
		TargetRules = true,
		Mechanics = {
			{
				Object = "Beam",
				Key = "Range",
				Label = "Beam length",
				Min = 1,
				Max = Limits.MaxRange,
				Help = "Maximum distance the beam can reach.",
			},
			{
				Object = "Beam",
				Key = "Width",
				Label = "Beam width",
				Min = 0,
				Max = 10,
				Help = "Zero uses a ray; larger values create a wider hit volume.",
			},
			{
				Object = "Beam",
				Key = "Interval",
				Label = "Channel pulse interval",
				Min = 0.05,
				Max = 1,
				Help = "Time between server hit checks while a Channeled Beam is held.",
			},
			{
				Object = "Beam",
				Key = "Pattern",
				Label = "Beam pattern",
				Options = { "Single", "Cascade" },
				Help = "Single resolves one aimed Beam. Cascade calls a bounded sequence of vertical Beams around its server-resolved aim point.",
			},
			{
				Object = "Beam",
				Key = "StrikeCount",
				Label = "Cascade strikes",
				Min = 2,
				Max = 8,
				Help = "Number of vertical Beam strikes in a Cascade.",
			},
			{
				Object = "Beam",
				Key = "SpreadRadius",
				Label = "Cascade spread",
				Min = 0,
				Max = 30,
				Help = "Radius in studs for the deterministic strike pattern around the aim point.",
			},
			{
				Object = "Beam",
				Key = "DropHeight",
				Label = "Drop height",
				Min = 5,
				Max = 80,
				Help = "Vertical ray start height above each strike point; solid ceilings still block each Beam.",
			},
			{
				Object = "Beam",
				Key = "StrikeInterval",
				Label = "Strike interval",
				Min = 0.1,
				Max = 1,
				Help = "Delay between server-resolved strikes in a Cascade.",
			},
			{
				Object = "Beam",
				Key = "GrowthStartScale",
				Label = "Expansion start scale",
				Min = 0.1,
				Max = 2,
				Help = "Optional. Set all three expansion values to grow or shrink Channeled Beam length and width.",
			},
			{
				Object = "Beam",
				Key = "GrowthEndScale",
				Label = "Expansion end scale",
				Min = 0.1,
				Max = 2,
				Help = "Final length and width relative to their authored values.",
			},
			{
				Object = "Beam",
				Key = "GrowthDuration",
				Label = "Expansion time (seconds)",
				Min = 0.1,
				Max = 30,
				Help = "Time after channel start to reach the end scale; the Beam holds that size afterward.",
			},
		},
	},
	Wave = {
		Label = "Wave",
		Description = "A burst that reaches targets in a cone in front of you or a sphere around you. It happens in place, without traveling through the air. Channeled repeats the burst while held.",
		Geometry = "Cone",
		GeometryOptions = { "Cone", "Sphere" },
		Motion = "Stationary",
		Draft = {
			Targeting = "Self",
			Lifetime = { Mode = "Instantaneous" },
			Mechanics = { Range = 10, Dot = 0.3, Interval = 0.4, DebugDuration = 0.2 },
		},
		Targeting = set({ "Self", "EntityTarget", "ObjectTarget", "MaterialTarget" }),
		TargetTypes = set({ "Humanoid" }),
		CanIncludeCaster = true,
		Events = set({
			"OnCast",
			"OnTick",
			"OnExpire",
			"OnDamageDealt",
			"OnDamageTaken",
			"OnTargetDeath",
			"OnCasterDeath",
		}),
		EffectEvents = set({
			"OnCast",
			"OnTick",
			"OnExpire",
			"OnDamageDealt",
			"OnDamageTaken",
			"OnTargetDeath",
			"OnCasterDeath",
		}),
		DefaultEvent = "OnCast",
		TargetRules = true,
		Mechanics = {
			{
				Object = "Wave",
				Key = "Range",
				Label = "Wave reach",
				Min = 1,
				Max = Limits.MaxRadius,
				Help = "Maximum distance from you.",
			},
			{
				Object = "Wave",
				Key = "Dot",
				Label = "Wave spread",
				Min = -1,
				Max = 1,
				Help = "Lower values spread farther to the sides; higher values make a narrower cone.",
			},
			{
				Object = "Wave",
				Key = "Interval",
				Label = "Channel pulse interval",
				Min = Limits.MinInterval,
				Max = 1,
				Help = "Time between cone hit checks while a Channeled Wave is held.",
			},
			{
				Object = "Wave",
				Key = "GrowthStartScale",
				Label = "Expansion start scale",
				Min = 0.1,
				Max = 2,
				Help = "Optional. Set all three expansion values to grow or shrink the Channeled Wave hit cone.",
			},
			{
				Object = "Wave",
				Key = "GrowthEndScale",
				Label = "Expansion end scale",
				Min = 0.1,
				Max = 2,
				Help = "Final reach relative to the authored Wave range.",
			},
			{
				Object = "Wave",
				Key = "GrowthDuration",
				Label = "Expansion time (seconds)",
				Min = 0.1,
				Max = 30,
				Help = "Time after channel start to reach the end scale; the Wave holds that reach afterward.",
			},
		},
	},
	Field = {
		Label = "Field",
		Description = "An area placed where you aim. It checks for targets repeatedly while it lasts. You can leave it in place or make it follow a target.",
		Geometry = "Sphere",
		GeometryOptions = { "Sphere", "Capsule", "Cylinder", "Box", "Cone", "Ring", "Plane", "Line" },
		Motion = "Stationary",
		Draft = {
			Targeting = "WorldPoint",
			Lifetime = { Mode = "FixedDuration", Duration = 8 },
			Mechanics = { Radius = 8, Interval = 0.6, DebugHeight = 0.2, Yaw = 0, FollowTarget = false },
		},
		-- A Field may be placed on a world point or centered on a living entity.
		-- It remains at cast-time position by default; FollowTarget opts into attachment.
		Targeting = set({ "WorldPoint", "Area", "EntityTarget", "ObjectTarget", "MaterialTarget" }),
		TargetTypes = set({ "Humanoid" }),
		CanIncludeCaster = true,
		Events = set({
			"OnCast",
			"OnSpawn",
			"OnDamageDealt",
			"OnDamageTaken",
			"OnMeleeHit",
			"OnTargetDeath",
			"OnCasterDeath",
			"OnEnter",
			"OnExit",
			"OnTick",
			"OnExpire",
		}),
		EffectEvents = set({
			"OnCast",
			"OnSpawn",
			"OnDamageDealt",
			"OnDamageTaken",
			"OnMeleeHit",
			"OnTargetDeath",
			"OnCasterDeath",
			"OnEnter",
			"OnExit",
			"OnTick",
			"OnExpire",
		}),
		DefaultEvent = "OnTick",
		TargetRules = true,
		Mechanics = {
			{
				Object = "Field",
				Key = "Radius",
				Label = "Field radius",
				Min = 0.1,
				Max = Limits.MaxRadius,
				Help = "Radius around the chosen world point.",
			},
			{
				Object = "Field",
				Key = "Range",
				Label = "Cone reach",
				Min = 0.1,
				Max = Limits.MaxRadius,
				Help = "Forward distance from the cone's origin.",
			},
			{
				Object = "Field",
				Key = "Angle",
				Label = "Cone angle",
				Min = 5,
				Max = 120,
				Help = "Full horizontal angle of the cone.",
			},
			{
				Object = "Field",
				Key = "Height",
				Label = "Cone height",
				Min = 0.1,
				Max = Limits.MaxRadius,
				Help = "Vertical thickness of the cone volume.",
			},
			{
				Object = "Field",
				Key = "InnerRadius",
				Label = "Ring safe radius",
				Min = 0.1,
				Max = Limits.MaxRadius,
				Help = "Targets closer than this distance to the center are excluded.",
			},
			{
				Object = "Field",
				Key = "OuterRadius",
				Label = "Ring outer radius",
				Min = 0.2,
				Max = Limits.MaxRadius,
				Help = "Maximum distance from the center affected by this annular area.",
			},
			{
				Object = "Field",
				Key = "Width",
				Label = "Plane width",
				Min = 0.1,
				Max = Limits.MaxRadius,
				Help = "Horizontal width of a vertical Plane hit volume.",
			},
			{
				Object = "Field",
				Key = "Thickness",
				Label = "Plane thickness",
				Min = 0.1,
				Max = 4,
				Help = "Depth of the vertical hit volume; this does not block world movement.",
			},
			{
				Object = "Field",
				Key = "Interval",
				Label = "Pulse interval",
				Min = Limits.MinInterval,
				Max = 5,
				Help = "Time between repeated field effects.",
			},
			{
				Object = "Field",
				Key = "GrowthStartScale",
				Label = "Expansion start scale",
				Min = 0.1,
				Max = 2,
				Help = "Optional. Set all three expansion values to make the hit volume grow or shrink over time.",
			},
			{
				Object = "Field",
				Key = "GrowthEndScale",
				Label = "Expansion end scale",
				Min = 0.1,
				Max = 2,
				Help = "Final size relative to the authored area dimensions.",
			},
			{
				Object = "Field",
				Key = "GrowthDuration",
				Label = "Expansion time (seconds)",
				Min = 0.1,
				Max = 30,
				Help = "Time to reach the end scale; the area holds that size afterward.",
			},
		},
	},
	Aura = {
		Label = "Aura",
		Description = "An area that moves with you or a chosen target. It repeatedly checks who is nearby; add damage, healing, or other effects on Effects.",
		Geometry = "Sphere",
		GeometryOptions = { "Sphere", "Capsule", "Cylinder", "Box", "Cone", "Ring", "Plane", "Line" },
		Motion = "FollowCaster",
		Draft = {
			Targeting = "Self",
			Lifetime = { Mode = "FixedDuration", Duration = 8 },
			Mechanics = { Radius = 8, Interval = 0.6, Yaw = 0 },
		},
		Targeting = set({ "Self", "EntityTarget", "ObjectTarget", "MaterialTarget" }),
		TargetTypes = set({ "Humanoid" }),
		CanIncludeCaster = true,
		Events = set({
			"OnCast",
			"OnSpawn",
			"OnDamageDealt",
			"OnDamageTaken",
			"OnMeleeHit",
			"OnTargetDeath",
			"OnCasterDeath",
			"OnEnter",
			"OnExit",
			"OnTick",
			"OnExpire",
		}),
		EffectEvents = set({
			"OnCast",
			"OnSpawn",
			"OnDamageDealt",
			"OnDamageTaken",
			"OnMeleeHit",
			"OnTargetDeath",
			"OnCasterDeath",
			"OnEnter",
			"OnExit",
			"OnTick",
			"OnExpire",
		}),
		DefaultEvent = "OnTick",
		TargetRules = true,
		Mechanics = {
			{
				Object = "Aura",
				Key = "Radius",
				Label = "Aura radius",
				Min = 0.1,
				Max = Limits.MaxRadius,
				Help = "Distance around you where the aura can affect targets.",
			},
			{
				Object = "Aura",
				Key = "Range",
				Label = "Cone reach",
				Min = 0.1,
				Max = Limits.MaxRadius,
				Help = "Forward distance from the cone's origin.",
			},
			{
				Object = "Aura",
				Key = "Angle",
				Label = "Cone angle",
				Min = 5,
				Max = 120,
				Help = "Full horizontal angle of the cone.",
			},
			{
				Object = "Aura",
				Key = "Height",
				Label = "Cone height",
				Min = 0.1,
				Max = Limits.MaxRadius,
				Help = "Vertical thickness of the cone volume.",
			},
			{
				Object = "Aura",
				Key = "InnerRadius",
				Label = "Ring safe radius",
				Min = 0.1,
				Max = Limits.MaxRadius,
				Help = "Targets closer than this distance to the center are excluded.",
			},
			{
				Object = "Aura",
				Key = "OuterRadius",
				Label = "Ring outer radius",
				Min = 0.2,
				Max = Limits.MaxRadius,
				Help = "Maximum distance from the center affected by this annular area.",
			},
			{
				Object = "Aura",
				Key = "Width",
				Label = "Plane width",
				Min = 0.1,
				Max = Limits.MaxRadius,
				Help = "Horizontal width of a vertical Plane hit volume.",
			},
			{
				Object = "Aura",
				Key = "Thickness",
				Label = "Plane thickness",
				Min = 0.1,
				Max = 4,
				Help = "Depth of the vertical hit volume; it does not block world movement.",
			},
			{
				Object = "Aura",
				Key = "Interval",
				Label = "Pulse interval",
				Min = Limits.MinInterval,
				Max = 5,
				Help = "Time between repeated aura effects.",
			},
			{
				Object = "Aura",
				Key = "GrowthStartScale",
				Label = "Expansion start scale",
				Min = 0.1,
				Max = 2,
				Help = "Optional. Set all three expansion values to make the hit volume grow or shrink over time.",
			},
			{
				Object = "Aura",
				Key = "GrowthEndScale",
				Label = "Expansion end scale",
				Min = 0.1,
				Max = 2,
				Help = "Final size relative to the authored area dimensions.",
			},
			{
				Object = "Aura",
				Key = "GrowthDuration",
				Label = "Expansion time (seconds)",
				Min = 0.1,
				Max = 30,
				Help = "Time to reach the end scale; the area holds that size afterward.",
			},
		},
	},
	SelfEnhancement = {
		Label = "Enchantment",
		Description = "An enchantment on yourself or on another character. Add Swiftness to run faster or jump higher, or choose other supported effects. Its events happen from the holder's point of view: when they take damage, land a melee hit, deal spell damage, or when someone approaches them.",
		Geometry = "Self",
		Motion = "Stationary",
		Draft = {
			Targeting = "Self",
			Lifetime = { Mode = "FixedDuration", Duration = 10 },
			Mechanics = {},
		},
		-- Self by default; EntityTarget puts it on an ally or enemy (the holder).
		Targeting = set({ "Self", "EntityTarget" }),
		TargetTypes = set({ "Humanoid" }),
		Events = set({
			"OnCast",
			"OnExpire",
			"OnDamageTaken",
			"OnMeleeHit",
			"OnHolderDealtDamage",
			"OnTargetDeath",
			"OnCasterDeath",
			"OnProximity",
		}),
		EffectEvents = set({
			"OnCast",
			"OnExpire",
			"OnDamageTaken",
			"OnMeleeHit",
			"OnHolderDealtDamage",
			"OnTargetDeath",
			"OnCasterDeath",
			"OnProximity",
		}),
		DefaultEvent = "OnCast",
		TargetRules = true,
		Mechanics = {},
	},
	Construct = {
		Label = "Construct",
		Description = "Creates a solid shape, such as a wall or platform. Place it in the air without needing a surface, or attach it to a surface or character. Set its size and lifetime here; nearby effects are optional.",
		Geometry = "Box",
		GeometryOptions = ConstructGeometrySpec.Order,
		Motion = "Stationary",
		Draft = {
			Targeting = "AimDirection",
			Lifetime = { Mode = "FixedDuration", Duration = 10 },
			Mechanics = { Width = 8, Height = 8, Depth = 1, Distance = 12, Components = {} },
		},
		-- Air placement is the default; explicit object/entity attachment is optional.
		Targeting = set({ "AimDirection", "WorldPoint", "EntityTarget", "ObjectTarget" }),
		TargetTypes = set({ "Humanoid" }),
		Events = set({ "OnCast", "OnExpire", "OnProximity", "OnDamageTaken", "OnCasterDeath" }),
		EffectEvents = set({ "OnCast", "OnExpire", "OnProximity", "OnDamageTaken", "OnCasterDeath" }),
		DefaultEvent = nil,
		TargetRules = true,
		Mechanics = {
			{
				Object = "Construct",
				Key = "Width",
				Label = "Width",
				Min = 0.5,
				Max = 20,
				Help = "Width of the temporary shape.",
			},
			{
				Object = "Construct",
				Key = "Height",
				Label = "Height",
				Min = 0.5,
				Max = 20,
				Help = "Height of the temporary shape.",
			},
			{
				Object = "Construct",
				Key = "Depth",
				Label = "Depth",
				Min = 0.5,
				Max = 20,
				Help = "Depth of the temporary shape.",
			},
			{
				Object = "Construct",
				Key = "Distance",
				Label = "Placement distance",
				Min = 4,
				Max = 40,
				Help = "Open-air placement distance. No object or material is required; a surface or character in your aim path is used as an optional attachment point.",
			},
			{
				Object = "Construct",
				Key = "GrowthStartScale",
				Label = "Growth start scale",
				Min = 0.1,
				Max = 2,
				Help = "Optional. Set all three growth values to make the solid geometry expand or contract over time.",
			},
			{
				Object = "Construct",
				Key = "GrowthEndScale",
				Label = "Growth end scale",
				Min = 0.1,
				Max = 2,
				Help = "Final geometry size relative to the authored Width, Height, and Depth.",
			},
			{
				Object = "Construct",
				Key = "GrowthDuration",
				Label = "Growth time (seconds)",
				Min = 0.1,
				Max = 30,
				Help = "Time to reach the end scale. Growth pauses if the expanded geometry would overlap another solid or character.",
			},
		},
	},
	Manipulation = {
		Label = "Manipulation",
		Description = "Acts on prepared world objects or materials. Add an effect to move or change the target; ordinary scenery may not be eligible.",
		Geometry = "Point",
		Motion = "Instantaneous",
		Draft = {
			Targeting = "MaterialTarget",
			Lifetime = { Mode = "Instantaneous" },
			Mechanics = {},
			Material = { Material = "Earth", SearchRadius = 12 },
		},
		Targeting = set({ "MaterialTarget", "ObjectTarget" }),
		Events = set({ "OnCast" }),
		EffectEvents = set({ "OnCast" }),
		DefaultEvent = "OnCast",
		TargetRules = false,
		Mechanics = {},
	},
}

Schema.FormOrder = { "Projectile", "Beam", "Wave", "Field", "Aura", "SelfEnhancement", "Construct", "Manipulation" }

-- Commands are lifecycle events on summon-producing spell definitions. A
-- group retains the validated definition independently of the original cast.
for _, form in Schema.Forms do
	form.Events.OnCommand = true
	form.EffectEvents.OnCommand = true
	if form.Events.OnTick then
		form.Events.OnInterval = true
		form.EffectEvents.OnInterval = true
	end
end

Schema.Forms.Projectile.Events.OnProximity = true
Schema.Forms.Projectile.EffectEvents.OnProximity = true

-- A shield-break event is available only to Forms that can target Humanoids.
for _, form in Schema.Forms do
	if form.TargetTypes and form.TargetTypes.Humanoid then
		form.Events.OnBreak = true
		form.EffectEvents.OnBreak = true
		form.Events.OnThreshold = true
		form.EffectEvents.OnThreshold = true
	end
end

local function formsForTargetType(targetType: string): ({ [string]: boolean }, { [string]: { [string]: boolean } })
	local forms, events = {}, {}
	for formName, definition in Schema.Forms do
		if definition.TargetTypes and definition.TargetTypes[targetType] then
			forms[formName] = true
			events[formName] = definition.EffectEvents
		end
	end
	return forms, events
end

local HumanoidTargetForms, HumanoidTargetEvents = formsForTargetType("Humanoid")

Schema.Payloads = {
	Damage = {
		Label = "Damage",
		Category = "Impact",
		Polarity = "Bane",
		Description = "Removes health immediately.",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement" }),
		Events = {
			Projectile = set({ "OnImpact", "OnTick" }),
			Beam = set({ "OnCast", "OnTick" }),
			Wave = set({ "OnCast", "OnTick" }),
			Field = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Aura = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Construct = set({ "OnProximity", "OnExpire" }),
			SelfEnhancement = set({ "OnProximity", "OnExpire" }),
		},
		Defaults = {
			Amount = 20,
			DamageChannel = "Elemental",
			HeadMultiplier = 1,
			TorsoMultiplier = 1,
			ArmMultiplier = 1,
			LegMultiplier = 1,
			OtherMultiplier = 1,
		},
		Fields = {
			{
				Key = "DamageChannel",
				Label = "Damage channel",
				Options = { "Elemental", "Physical", "Soul" },
				Required = false,
				Help = "Elemental uses the spell's selected element. Physical and Soul use their matching target defenses.",
			},
			{
				Key = "Amount",
				Label = "Damage amount",
				Min = 0,
				Max = Limits.MaxDamage,
				Required = true,
				Help = "Health damage applied to each valid target.",
			},
			{
				Key = "HeadMultiplier",
				Label = "Head damage multiplier",
				Min = 0,
				Max = 4,
				Required = false,
				Help = "Damage scale when a direct hit strikes the head. Omitted values use 1x.",
			},
			{
				Key = "TorsoMultiplier",
				Label = "Torso damage multiplier",
				Min = 0,
				Max = 4,
				Required = false,
				Help = "Damage scale for torso hits and area effects. Omitted values use 1x.",
			},
			{
				Key = "ArmMultiplier",
				Label = "Arm damage multiplier",
				Min = 0,
				Max = 4,
				Required = false,
				Help = "Damage scale when a direct hit strikes an arm or hand. Omitted values use 1x.",
			},
			{
				Key = "LegMultiplier",
				Label = "Leg damage multiplier",
				Min = 0,
				Max = 4,
				Required = false,
				Help = "Damage scale when a direct hit strikes a leg or foot. Omitted values use 1x.",
			},
			{
				Key = "OtherMultiplier",
				Label = "Other-part damage multiplier",
				Min = 0,
				Max = 4,
				Required = false,
				Help = "Damage scale for custom rig parts. Omitted values use 1x.",
			},
		},
	},
	DamageOverTime = {
		Label = "Damage over time",
		Category = "Impact",
		Polarity = "Bane",
		Description = "Applies repeated health damage for a limited time.",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement" }),
		Events = {
			Projectile = set({ "OnImpact", "OnTick" }),
			Beam = set({ "OnCast", "OnTick" }),
			Wave = set({ "OnCast", "OnTick" }),
			Field = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Aura = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Construct = set({ "OnProximity", "OnExpire" }),
			SelfEnhancement = set({ "OnProximity", "OnExpire" }),
		},
		Defaults = {
			Amount = 5,
			Duration = 4,
			Interval = 1,
			DamageChannel = "Elemental",
			HeadMultiplier = 1,
			TorsoMultiplier = 1,
			ArmMultiplier = 1,
			LegMultiplier = 1,
			OtherMultiplier = 1,
		},
		Fields = {
			{
				Key = "DamageChannel",
				Label = "Damage channel",
				Options = { "Elemental", "Physical", "Soul" },
				Required = false,
				Help = "Elemental uses the spell's selected element. Physical and Soul use their matching target defenses.",
			},
			{
				Key = "Amount",
				Label = "Damage per tick",
				Min = 0.1,
				Max = Limits.MaxDamage,
				Required = true,
				Help = "Health damage dealt each tick.",
			},
			{
				Key = "HeadMultiplier",
				Label = "Head damage multiplier",
				Min = 0,
				Max = 4,
				Required = false,
				Help = "Damage scale when the effect was applied by a direct head hit. Omitted values use 1x.",
			},
			{
				Key = "TorsoMultiplier",
				Label = "Torso damage multiplier",
				Min = 0,
				Max = 4,
				Required = false,
				Help = "Damage scale for torso and area-effect applications. Omitted values use 1x.",
			},
			{
				Key = "ArmMultiplier",
				Label = "Arm damage multiplier",
				Min = 0,
				Max = 4,
				Required = false,
				Help = "Damage scale when the effect was applied by a direct arm or hand hit. Omitted values use 1x.",
			},
			{
				Key = "LegMultiplier",
				Label = "Leg damage multiplier",
				Min = 0,
				Max = 4,
				Required = false,
				Help = "Damage scale when the effect was applied by a direct leg or foot hit. Omitted values use 1x.",
			},
			{
				Key = "OtherMultiplier",
				Label = "Other-part damage multiplier",
				Min = 0,
				Max = 4,
				Required = false,
				Help = "Damage scale for custom rig parts. Omitted values use 1x.",
			},
			{
				Key = "Duration",
				Label = "Effect duration",
				Min = 0.1,
				Max = Limits.MaxDuration,
				Required = true,
				Help = "Maximum time the repeated effect remains active.",
			},
			{
				Key = "Interval",
				Label = "Time between ticks",
				Min = Limits.MinInterval,
				Max = 5,
				Required = true,
				Help = "How often the damage tick occurs.",
			},
		},
	},
	ElementalMark = {
		Label = "Elemental mark",
		Category = "Condition",
		Polarity = "Bane",
		Description = "Adds stacks of this spell's selected element. Each element has a configurable starter interaction; other spell steps can check or consume its mark.",
		Forms = HumanoidTargetForms,
		Events = HumanoidTargetEvents,
		Defaults = { Stacks = 1, Duration = 6 },
		Fields = {
			{
				Key = "Stacks",
				Label = "Stacks added",
				Min = 1,
				Max = Limits.MaxElementalMarkStacks,
				Integer = true,
				Required = true,
				Help = "Adds this many stacks, up to the per-element target cap. Reapplying also refreshes the duration.",
			},
			{
				Key = "Duration",
				Label = "Mark duration",
				Min = 0.1,
				Max = Limits.MaxDuration,
				Required = true,
				Help = "How long the mark remains unless another spell consumes it first.",
			},
		},
	},
	ConsumeElementalMark = {
		Label = "Consume elemental mark",
		Category = "Condition",
		Polarity = "Neutral",
		Description = "Removes stacks of an element from each target. Defaults to this spell's selected element, with an optional element override.",
		Forms = HumanoidTargetForms,
		Events = HumanoidTargetEvents,
		Defaults = { Stacks = 1 },
		Fields = {
			{
				Key = "Element",
				Label = "Element to consume",
				Options = Schema.MarkElements,
				Required = false,
				Help = "Optional. Defaults to this spell's selected element; automatic interactions can consume a different element.",
			},
			{
				Key = "Stacks",
				Label = "Stacks to consume",
				Min = 1,
				Max = Limits.MaxElementalMarkStacks,
				Integer = true,
				Required = true,
				Help = "Consumes up to this many stacks. Use a Has ElementalMarks condition to run follow-up effects only when the target is marked.",
			},
		},
	},
	Force = {
		Label = "Force",
		Category = "Impact",
		Polarity = "Neutral",
		Description = "Pushes a character or explicitly targeted movable world object with a short physical impulse.",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement", "Manipulation" }),
		Events = {
			Projectile = set({ "OnImpact", "OnTick" }),
			Beam = set({ "OnCast", "OnTick" }),
			Wave = set({ "OnCast", "OnTick" }),
			Field = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Aura = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Construct = set({ "OnProximity", "OnExpire" }),
			SelfEnhancement = set({ "OnProximity", "OnExpire" }),
			Manipulation = set({ "OnCast" }),
		},
		Defaults = { Magnitude = 10, Upward = 0 },
		Fields = {
			{
				Key = "Magnitude",
				Label = "Push strength",
				Min = 0,
				Max = Limits.MaxForce,
				Required = true,
				Help = "Strength of the impulse.",
			},
			{
				Key = "Upward",
				Label = "Upward push",
				Min = 0,
				Max = 30,
				Required = false,
				Help = "Additional vertical impulse.",
			},
		},
	},
	Heal = {
		Label = "Healing",
		Category = "Support",
		Polarity = "Boon",
		Description = "Restores missing health to valid targets.",
		Forms = HumanoidTargetForms,
		Events = HumanoidTargetEvents,
		Defaults = { Amount = 20 },
		Fields = {
			{
				Key = "Amount",
				Label = "Healing amount",
				Min = 0,
				Max = Limits.MaxHeal,
				Required = true,
				Help = "Health restored, up to the target's maximum health.",
			},
		},
	},
	Restoration = {
		Label = "Restoration over time",
		Category = "Support",
		Polarity = "Boon",
		Description = "Restores health in server-timed pulses while its duration remains active.",
		Forms = HumanoidTargetForms,
		Events = HumanoidTargetEvents,
		Defaults = { Amount = 4, Duration = 5, Interval = 1 },
		Fields = {
			{
				Key = "Amount",
				Label = "Health per pulse",
				Min = 0.1,
				Max = Limits.MaxHeal,
				Required = true,
				Help = "Health restored on each pulse, capped by missing health.",
			},
			{
				Key = "Duration",
				Label = "Restoration duration",
				Min = 0.1,
				Max = Limits.MaxDuration,
				Required = true,
				Help = "The maximum time the periodic restoration remains active.",
			},
			{
				Key = "Interval",
				Label = "Time between pulses",
				Min = Limits.MinInterval,
				Max = 5,
				Required = true,
				Help = "How often the server restores health.",
			},
		},
	},
	Shield = {
		Label = "Shield",
		Category = "Support",
		Polarity = "Boon",
		Description = "Adds a temporary damage-absorbing shield to valid targets.",
		Forms = HumanoidTargetForms,
		Events = HumanoidTargetEvents,
		Defaults = { Amount = 25, Duration = 8 },
		Fields = {
			{
				Key = "Amount",
				Label = "Shield points",
				Min = 0,
				Max = Limits.MaxShield,
				Required = true,
				Help = "Damage the shield can absorb before it breaks.",
			},
			{
				Key = "Duration",
				Label = "Shield duration",
				Min = 0.1,
				Max = Limits.MaxDuration,
				Required = true,
				Help = "Maximum time the shield remains active.",
			},
		},
	},
	ModifyAttribute = {
		Label = "Modify attribute",
		Category = "Support",
		Polarity = "Neutral",
		Description = "Temporarily changes a whitelisted target attribute: armor, elemental resistance, damage taken, healing received, cast speed, cooldown rate or mana regeneration.",
		Forms = HumanoidTargetForms,
		Events = HumanoidTargetEvents,
		Defaults = { Attribute = "MagicArmor", Amount = 15, Duration = 8 },
		Fields = {
			{
				Key = "Attribute",
				Label = "Attribute",
				Options = table.clone(AttributeSpec.Order),
				Required = true,
				Help = "Only explicitly supported numeric attributes can be modified by spells.",
			},
			{
				Key = "Element",
				Label = "Resistance element",
				Options = table.clone(AttributeSpec.Elements),
				Required = false,
				ShowWhen = { Key = "Attribute", Values = { "Resistance" } },
				Help = "The element this resistance applies to. Required for Resistance; not used by other attributes.",
			},
			{
				-- Min/Max here are the widest range; each attribute's own range comes
				-- from MagicAttributeSpec (Schema.resolveField, SpellSpec validation).
				Key = "Amount",
				Label = "Modifier amount",
				Min = -100,
				Max = 100,
				Required = true,
				Help = "Armor: points of mitigation. Strength: % outgoing damage. Resistance: -1 to 1 (negative = vulnerability). Damage taken, healing received, cast speed, cooldown rate and mana regeneration: percent.",
			},
			{
				Key = "Duration",
				Label = "Modifier duration",
				Min = 0.1,
				Max = Limits.MaxDuration,
				Required = true,
				Help = "The modifier is removed automatically when this duration ends.",
			},
		},
	},
	Transformation = {
		Label = "Transformation",
		Category = "Support",
		Polarity = "Neutral",
		Description = "Temporarily scales a target's full character model, then restores its original size.",
		Forms = HumanoidTargetForms,
		Events = HumanoidTargetEvents,
		Defaults = { Mode = "Scale", Multiplier = 1.15, Duration = 6 },
		Fields = {
			{
				Key = "Mode",
				Label = "Transform",
				Options = { "Scale" },
				Required = true,
				Help = "Scale changes the target's complete character model while preserving its original scale for cleanup.",
			},
			{
				Key = "Multiplier",
				Label = "Scale multiplier",
				Min = Limits.MinTransformScale,
				Max = Limits.MaxTransformScale,
				Required = true,
				Help = "1 keeps the current size; values below or above 1 shrink or enlarge the model.",
			},
			{
				Key = "Duration",
				Label = "Transform duration",
				Min = 0.1,
				Max = Limits.MaxDuration,
				Required = true,
				Help = "The target returns to its original size when this duration ends.",
			},
		},
	},
	Slow = {
		Label = "Slow",
		Category = "Control",
		Polarity = "Bane",
		Description = "Temporarily reduces a target's movement speed.",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement" }),
		Events = {
			Projectile = set({ "OnImpact", "OnTick" }),
			Beam = set({ "OnCast", "OnTick" }),
			Wave = set({ "OnCast", "OnTick" }),
			Field = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Aura = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Construct = set({ "OnProximity" }),
			SelfEnhancement = set({ "OnCast", "OnProximity" }),
		},
		Defaults = { Multiplier = 0.65, Duration = 4 },
		Fields = {
			{
				Key = "Multiplier",
				Label = "Remaining speed",
				Min = Limits.MinSlowMultiplier,
				Max = 1,
				Required = true,
				Help = "0.65 means 65% of normal speed; lower values slow more.",
			},
			{
				Key = "Duration",
				Label = "Slow duration",
				Min = 0.1,
				Max = Limits.MaxDuration,
				Required = true,
				Help = "Maximum time the slow remains active.",
			},
		},
	},
	Bind = {
		Label = "Bind",
		Category = "Control",
		Polarity = "Bane",
		Description = "Temporarily prevents target movement. It does not add damage or stun behavior to other payloads.",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement" }),
		Events = {
			Projectile = set({ "OnImpact", "OnTick" }),
			Beam = set({ "OnCast", "OnTick" }),
			Wave = set({ "OnCast", "OnTick" }),
			Field = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Aura = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Construct = set({ "OnProximity" }),
			SelfEnhancement = set({ "OnProximity" }),
		},
		Defaults = { Duration = 1.5 },
		Fields = {
			{
				Key = "Duration",
				Label = "Bind duration",
				Min = 0.1,
				Max = Limits.MaxBindDuration,
				Required = true,
				Help = "Prevents walking, jumping and dashing until the duration ends.",
			},
		},
	},
	Stun = {
		Label = "Stun",
		Category = "Control",
		Polarity = "Bane",
		Description = "Briefly stops the target from moving, attacking and casting. A second stun on the same target within 8 s lasts half as long; a third makes them immune for 8 s.",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement" }),
		Events = {
			Projectile = set({ "OnImpact", "OnTick" }),
			Beam = set({ "OnCast", "OnTick" }),
			Wave = set({ "OnCast", "OnTick" }),
			Field = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Aura = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Construct = set({ "OnProximity" }),
			SelfEnhancement = set({ "OnProximity" }),
		},
		Defaults = { Duration = 0.8 },
		Fields = {
			{
				Key = "Duration",
				Label = "Stun duration",
				Min = 0.1,
				Max = Limits.MaxStunDuration,
				Required = true,
				Help = "Up to 1.5 s against creatures; at most 0.5 s against players in PvP.",
			},
		},
	},
	Silence = {
		Label = "Silence",
		Category = "Control",
		Polarity = "Bane",
		Description = "Stops a player from casting or channeling spells and cancels the channel they are holding. Monster attacks are not spells and are never silenced.",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement" }),
		Events = {
			Projectile = set({ "OnImpact", "OnTick" }),
			Beam = set({ "OnCast", "OnTick" }),
			Wave = set({ "OnCast", "OnTick" }),
			Field = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Aura = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Construct = set({ "OnProximity" }),
			SelfEnhancement = set({ "OnProximity" }),
		},
		Defaults = { Duration = 2 },
		Fields = {
			{
				Key = "Duration",
				Label = "Silence duration",
				Min = 0.1,
				Max = Limits.MaxSilenceDuration,
				Required = true,
				Help = "How long the target cannot cast or channel spells.",
			},
		},
	},
	Cleanse = {
		Label = "Cleanse",
		Category = "Support",
		Polarity = "Neutral",
		Description = "Removes Banes from an ally or Boons from an enemy, including periodic effects and Enchantments, longest-lasting first.",
		Forms = HumanoidTargetForms,
		Events = HumanoidTargetEvents,
		Defaults = { Remove = "Banes", Count = 1 },
		Fields = {
			{
				Key = "Remove",
				Label = "Remove",
				Options = { "Banes", "Boons" },
				Required = true,
				Help = "Banes: harmful effects such as Slow, Stun or damage over time. Boons: helpful ones such as Shield or Swiftness.",
			},
			{
				Key = "Count",
				Label = "Effects removed",
				Min = 1,
				Max = Limits.MaxCleanseCount,
				Integer = true,
				Required = true,
				Help = "How many matching effects to remove, longest-lasting first.",
			},
			{
				Key = "Element",
				Label = "Only this element",
				Options = { "Fire", "Ice", "Lightning", "Earth", "Water", "Wind", "Poison" },
				Required = false,
				Help = "Optional: only remove effects of this element, such as Fire marks.",
			},
		},
	},
	Reveal = {
		Label = "Reveal",
		Category = "Detection",
		Polarity = "Neutral",
		Description = "Temporarily highlights valid targets through world obstruction for the spell's owner only.",
		Forms = HumanoidTargetForms,
		Events = HumanoidTargetEvents,
		Defaults = { Duration = 8 },
		Fields = {
			{
				Key = "Duration",
				Label = "Reveal duration",
				Min = 0.1,
				Max = Limits.MaxRevealDuration,
				Required = true,
				Help = "How long the caster can see the target's outline through obstacles.",
			},
		},
	},
	Control = {
		Label = "Physical control",
		Category = "Control",
		Polarity = "Neutral",
		Description = "Maintains a bounded horizontal pull or push on a character or explicitly targeted movable world object. It does not stun or lock movement.",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement", "Manipulation" }),
		Events = {
			Projectile = set({ "OnImpact", "OnTick" }),
			Beam = set({ "OnCast", "OnTick" }),
			Wave = set({ "OnCast", "OnTick" }),
			Field = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Aura = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Construct = set({ "OnProximity" }),
			SelfEnhancement = set({ "OnProximity" }),
			Manipulation = set({ "OnCast" }),
		},
		Defaults = { Mode = "Pull", Acceleration = 24, Duration = 2, MaxSpeed = 32, MaxMass = 500 },
		Fields = {
			{
				Key = "Mode",
				Label = "Influence direction",
				Options = { "Pull", "Push" },
				Required = true,
				Help = "Pull draws the target horizontally toward the caster; Push moves it away.",
			},
			{
				Key = "Acceleration",
				Label = "Influence strength",
				Min = 1,
				Max = Limits.MaxAcceleration,
				Required = true,
				Help = "Horizontal acceleration in studs per second squared; it never disables target movement.",
			},
			{
				Key = "Duration",
				Label = "Influence duration",
				Min = 0.1,
				Max = Limits.MaxDuration,
				Required = true,
				Help = "How long this caster maintains the physical influence.",
			},
			{
				Key = "MaxSpeed",
				Label = "Influence speed cap",
				Min = 1,
				Max = Limits.MaxSpeed,
				Required = true,
				Help = "The influence stops adding force once horizontal target speed reaches this value.",
			},
			{
				Key = "MaxMass",
				Label = "Maximum controlled mass",
				Min = 1,
				Max = Limits.MaxControlledMass,
				Required = true,
				Help = "Rejects targets above this assembly mass; the server rechecks mass while control is active.",
			},
		},
	},
	Displacement = {
		Label = "Displacement",
		Category = "Movement",
		Polarity = "Neutral",
		Description = "Moves a valid living target through clear space to a nearby grounded position. Walls, occupied destinations, and unsafe drops prevent the move.",
		Principle = "Space",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement" }),
		Events = {
			Projectile = set({ "OnImpact", "OnTick" }),
			Beam = set({ "OnCast", "OnTick" }),
			Wave = set({ "OnCast", "OnTick" }),
			Field = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Aura = set({ "OnCast", "OnSpawn", "OnEnter", "OnExit", "OnTick", "OnExpire" }),
			Construct = set({ "OnProximity" }),
			SelfEnhancement = set({ "OnProximity" }),
		},
		Defaults = { Mode = "AwayFromCaster", Distance = 8 },
		Fields = {
			{
				Key = "Mode",
				Label = "Displacement direction",
				Options = { "TowardCaster", "AwayFromCaster", "AlongAim", "AgainstAim" },
				Required = true,
				Help = "Toward/Away use the caster's position; Along/Against use the validated cast direction.",
			},
			{
				Key = "Distance",
				Label = "Displacement distance",
				Min = 1,
				Max = Limits.MaxDisplacementDistance,
				Required = true,
				Help = "Maximum movement in studs. The server shortens it only through potency scaling and rejects unsafe destinations.",
			},
		},
	},
	TimeDilation = {
		Label = "Time dilation",
		Category = "Temporal",
		Polarity = "Neutral",
		Description = "Changes a target's movement speed and the rate of its ongoing status and periodic magic effects. Below 1 slows; above 1 accelerates.",
		Principle = "Time",
		Forms = HumanoidTargetForms,
		Events = HumanoidTargetEvents,
		Defaults = { Rate = 0.5, Duration = 5 },
		Fields = {
			{
				Key = "Rate",
				Label = "Target time rate",
				Min = Limits.MinTimeRate,
				Max = Limits.MaxTimeRate,
				Required = true,
				Help = "0.5 makes the target experience ongoing effects at half rate; 1.5 accelerates them. Movement is scaled by the same rate.",
			},
			{
				Key = "Duration",
				Label = "Dilation duration",
				Min = 0.1,
				Max = Limits.MaxDuration,
				Required = true,
				Help = "World-time duration of this rate effect; the dilation does not extend its own duration.",
			},
		},
	},
	Enhancement = {
		Label = "Swiftness",
		Category = "Movement",
		Polarity = "Boon",
		Description = "Improves your movement while this Enchantment is active.",
		Forms = set({ "SelfEnhancement" }),
		Events = { SelfEnhancement = set({ "OnCast" }) },
		Defaults = { SpeedMultiplier = 1.2, WalkSpeedBonus = 0, JumpPowerBonus = 0 },
		Fields = {
			{
				Key = "SpeedMultiplier",
				Label = "Speed multiplier",
				Min = 1,
				Max = Limits.MaxMultiplier,
				Required = false,
				Help = "Multiplies your current movement speed.",
			},
			{
				Key = "WalkSpeedBonus",
				Label = "Flat speed bonus",
				Min = 0,
				Max = 30,
				Required = false,
				Help = "Adds speed after normal sprint and enhancement calculations.",
			},
			{
				Key = "JumpPowerBonus",
				Label = "Jump-power bonus",
				Min = 0,
				Max = Limits.MaxJumpBonus,
				Required = false,
				Help = "Adds to your jump power while active.",
			},
		},
	},
	AerialMovement = {
		Label = "Aerial movement",
		Category = "Movement",
		Polarity = "Boon",
		Description = "Lets you steer in three dimensions while this Enchantment is active. WASD moves horizontally; Space rises and Left Control descends.",
		Forms = set({ "SelfEnhancement" }),
		Events = { SelfEnhancement = set({ "OnCast" }) },
		Defaults = { Speed = 32 },
		Fields = {
			{
				Key = "Speed",
				Label = "Flight speed",
				Min = 8,
				Max = Limits.MaxAerialSpeed,
				Required = true,
				Help = "Maximum movement speed in any direction while airborne. The server clamps movement to this speed.",
			},
		},
	},
	Manipulation = {
		Label = "Material manipulation",
		Category = "World interaction",
		Polarity = "Neutral",
		Description = "Performs the currently supported discrete operation on authorized tagged material.",
		Forms = set({ "Manipulation", "Projectile", "Beam", "Wave" }),
		Events = {
			Manipulation = set({ "OnCast" }),
			Projectile = set({ "OnImpact" }),
			Beam = set({ "OnCast", "OnTick" }),
			Wave = set({ "OnCast", "OnTick" }),
		},
		Defaults = { Operation = "Raise", Distance = 3 },
		Fields = {
			{
				Key = "Operation",
				Label = "Operation",
				Required = true,
				Options = { "Raise", "Lower" },
				Help = "Move authorized tagged material vertically up or down.",
			},
			{
				Key = "Distance",
				Label = "Movement distance",
				Min = 0.1,
				Max = 15,
				Required = true,
				Help = "How far the eligible material moves vertically.",
			},
		},
	},
	Summon = {
		Label = "Summon",
		Category = "Summoning",
		Polarity = "Neutral",
		Description = "Calls a bounded companion when its trigger fires. The trigger decides when it appears; spawn position decides whether it appears beside you or at the event point.",
		TargetIndependent = true,
		Forms = (function()
			local forms = {}
			for formName, definition in Schema.Forms do
				if next(definition.EffectEvents) then
					forms[formName] = true
				end
			end
			return forms
		end)(),
		Events = (function()
			local events = {}
			for formName, definition in Schema.Forms do
				if next(definition.EffectEvents) then
					local summonEvents = table.clone(definition.EffectEvents)
					-- A target-independent summon can happen as soon as a cast starts,
					-- without waiting for a projectile to collide with something.
					if definition.Events.OnCast then
						summonEvents.OnCast = true
					end
					if definition.Events.OnSpawn then
						summonEvents.OnSpawn = true
					end
					events[formName] = summonEvents
				end
			end
			return events
		end)(),
		Defaults = {
			Archetype = "Wisp",
			Role = SummonLimits.DefaultRole,
			SpawnAt = "Caster",
			Count = 1,
			LifetimeMode = "FixedDuration",
			RespawnPolicy = "DismissOnDeath",
			Duration = 30,
			SpellSlot = "None",
		},
		Fields = {
			{
				Key = "Archetype",
				Label = "Summon type",
				Required = true,
				Options = SummonLimits.ArchetypeOrder,
				Help = "Wisp is quick and light; Sentinel is slower and more durable. Both use the same role and assigned-spell controls.",
			},
			{
				Key = "Role",
				Label = "Role",
				Required = false,
				Options = SummonLimits.RoleOrder,
				Help = "Guardian protects you from visible nearby hostiles; Hunter searches farther. Medic only heals/protects allies and needs an Ally spell; Controller only uses hostile control spells. Z Follow suspends targeting, X Protect restores defense, C Attack orders the aimed target, and G Support uses an Ally spell.",
			},
			{
				Key = "SpawnAt",
				Label = "Spawn position",
				Required = false,
				Options = { "Caster", "Event" },
				Help = "This controls where the summon appears, not when. Caster places it beside you. Event places each new unit near the server-resolved trigger point. A Projectile OnImpact trigger still requires a collision; use OnCast for an immediate summon.",
			},
			{
				Key = "Count",
				Label = "Number summoned",
				Min = 1,
				Max = SummonLimits.MaxCountPerCast,
				Integer = true,
				Required = true,
				Help = "Caster placement uses this as the desired group size. Event placement adds this many units per trigger, up to the per-spell and per-player caps.",
			},
			{
				Key = "LifetimeMode",
				Label = "Summon lifetime",
				Options = SummonLimits.LifetimeModes,
				Required = false,
				Help = "FixedDuration cleans up automatically; UntilCommanded stays until you issue Dismiss.",
			},
			{
				Key = "Duration",
				Label = "Summon duration",
				Min = SummonLimits.MinDuration,
				Max = SummonLimits.MaxDuration,
				Required = false,
				Help = "How long the group remains before automatic cleanup.",
			},
			{
				Key = "RespawnPolicy",
				Label = "Owner death behavior",
				Options = SummonLimits.RespawnPolicies,
				Required = false,
				Help = "PersistUntilDismissed keeps this UntilCommanded party through your death and rebinds it after respawn. It waits up to one minute for you to return; otherwise the party is dismissed.",
			},
			{
				Key = "SpellSlot",
				Label = "Companion spell to cast",
				Required = false,
				Options = { "None", "1", "2", "3", "4", "5", "6", "7", "8", "9" },
				Help = "This is a separate equipped spell slot the summon may cast. Projectile, Beam, Wave, Field, Aura, and targeted Construct spells can work. Instant casts when ready; Charged/HoldAndRelease auto-charge and release; bounded Channeled spells run to their set duration. None uses the basic attack for Guardian/Hunter; Medic/Controller need a compatible assignment.",
			},
		},
	},
}

for kind, payload in Schema.Payloads do
	if kind ~= "Summon" and payload.Events.Projectile then
		payload.Events.Projectile.OnProximity = true
	end
end

-- Reactive events are shared by payloads on Forms that actually own the
-- corresponding runtime lifecycle. Instantaneous Forms receive damage events
-- during their resolving payload; lifetime Forms additionally observe damage
-- taken and caster death while active.
local reactiveEvents = {
	"OnDamageDealt",
	"OnDamageTaken",
	"OnMeleeHit",
	"OnHolderDealtDamage",
	"OnThreshold",
	"OnBreak",
	"OnTargetDeath",
	"OnCasterDeath",
	"OnCommand",
}
for kind, payload in Schema.Payloads do
	if kind ~= "Summon" then
		for formName, events in payload.Events do
			local form = Schema.Forms[formName]
			for _, event in reactiveEvents do
				if form and form.Events[event] then
					events[event] = true
				end
			end
		end
	end
end

Schema.PayloadOrder = {
	"Damage",
	"DamageOverTime",
	"Force",
	"Heal",
	"Restoration",
	"Shield",
	"ModifyAttribute",
	"Transformation",
	"Slow",
	"Bind",
	"Stun",
	"Silence",
	"Cleanse",
	"Reveal",
	"Control",
	"Displacement",
	"TimeDilation",
	"Enhancement",
	"Manipulation",
	"Summon",
}
-- Effect pickers group payloads by Polarity first, then by Category.
Schema.PolarityOrder = { "Boon", "Bane", "Neutral" }
Schema.PolarityLabels = { Boon = "Boons", Bane = "Banes", Neutral = "Other" }
Schema.PayloadCategories =
	{ "Support", "Impact", "Control", "Detection", "Movement", "Temporal", "World interaction", "Summoning" }

-- Any Beam payload can run at its server-resolved contact point. Keeping this
-- event capability derived from the Form registry prevents every payload from
-- growing a separate Beam-impact branch in the editor and validator.
for _, payload in Schema.Payloads do
	if payload.Forms.Beam and payload.Events.Beam then
		payload.Events.Beam.OnImpact = true
	end
end

-- Channeled Beam and Wave resolve a final hit set when they expire
-- (MagicService emitExpiry). Schema.supportsEvent still rejects OnExpire for
-- instant casts, so this only opens the event where it can actually run.
for kind, payload in Schema.Payloads do
	if kind ~= "Summon" then
		for _, formName in { "Beam", "Wave" } do
			local events = payload.Events[formName]
			if payload.Forms[formName] and events and Schema.Forms[formName].Events.OnExpire then
				events.OnExpire = true
			end
		end
	end
end

Schema.Behaviors = {
	Explode = {
		Label = "Explode at event location",
		Description = "Creates a bounded area effect where this trigger occurred and applies its effects to everything inside.",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement" }),
		Events = {
			Projectile = set({
				"OnCast",
				"OnSpawn",
				"OnImpact",
				"OnExpire",
				"OnDamageDealt",
				"OnDamageTaken",
				"OnTargetDeath",
				"OnCasterDeath",
			}),
			Beam = set({
				"OnImpact",
				"OnTick",
				"OnExpire",
				"OnDamageDealt",
				"OnDamageTaken",
				"OnTargetDeath",
				"OnCasterDeath",
			}),
			Wave = set({ "OnExpire", "OnDamageDealt", "OnDamageTaken", "OnTargetDeath", "OnCasterDeath" }),
			Field = set({
				"OnExpire",
				"OnDamageDealt",
				"OnDamageTaken",
				"OnMeleeHit",
				"OnTargetDeath",
				"OnCasterDeath",
			}),
			Aura = set({ "OnExpire", "OnDamageDealt", "OnDamageTaken", "OnMeleeHit", "OnTargetDeath", "OnCasterDeath" }),
			Construct = set({ "OnProximity", "OnExpire", "OnDamageTaken", "OnCasterDeath" }),
			SelfEnhancement = set({
				"OnExpire",
				"OnDamageTaken",
				"OnMeleeHit",
				"OnHolderDealtDamage",
				"OnTargetDeath",
				"OnCasterDeath",
			}),
		},
		Defaults = { Radius = 7 },
		-- Any payload that acts on the Humanoids inside the blast. Caster-only
		-- (Enhancement, AerialMovement), object (Manipulation) and spawning
		-- (Summon) payloads have no per-target meaning here.
		PayloadKinds = {
			"Damage",
			"DamageOverTime",
			"Heal",
			"Restoration",
			"Shield",
			"ModifyAttribute",
			"Transformation",
			"Slow",
			"Bind",
			"Reveal",
			"Control",
			"Force",
			"Displacement",
			"TimeDilation",
			"ElementalMark",
			"ConsumeElementalMark",
		},
		DefaultPayloadKinds = { "Damage" },
		MinimumPayloads = 1,
		Fields = {
			{
				Key = "Radius",
				Label = "Blast radius",
				Min = 0.1,
				Max = Limits.MaxRadius,
				Required = true,
				Help = "Distance from the triggering event that can be affected.",
			},
		},
	},
}

for formName, events in Schema.Behaviors.Explode.Events do
	if Schema.Forms[formName] and Schema.Forms[formName].Events.OnBreak then
		events.OnBreak = true
	end
end

-- Starts a separate Projectile, Field, or Wave at the event, with its own
-- settings and triggers (step.Effect; see SpellSpec.expandSpawnEffect). It is
-- offered at the same timings as Explode.
Schema.Behaviors.SpawnEffect = {
	Label = "Spawn an effect at event location",
	Description = "Starts a separate Projectile, Field, or Wave where this trigger occurred. It has its own settings and its own effects.",
	Forms = Schema.Behaviors.Explode.Forms,
	Events = (function()
		local events = {}
		for formName, formEvents in Schema.Behaviors.Explode.Events do
			events[formName] = table.clone(formEvents)
		end
		-- Unlike Explode, spawning also fits area entry/exit and pulses (a
		-- Field that reacts to entry, or fires a Projectile on each pulse).
		-- Active-effect caps and the cascade budget bound how many start.
		for _, formName in { "Field", "Aura" } do
			events[formName].OnEnter = true
			events[formName].OnExit = true
			events[formName].OnTick = true
		end
		events.Projectile.OnTick = true
		return events
	end)(),
	Defaults = { Count = 1, SpreadAngle = 0 },
	PayloadKinds = {},
	MinimumPayloads = 0,
	Fields = {
		{
			Key = "Count",
			Label = "Projectiles spawned",
			Min = 1,
			Max = Limits.MaxSpawnCount,
			Integer = true,
			Help = "Only spawned Projectiles can use more than one.",
		},
		{
			Key = "SpreadAngle",
			Label = "Fan angle (degrees)",
			Min = 0,
			Max = Limits.MaxSpawnSpreadAngle,
			Help = "Total angle the spawned Projectiles fan across.",
		},
	},
}

Schema.Conditions = {
	{
		Id = "OnGround",
		Label = "Require caster on ground",
		Description = "Only cast while standing on a surface.",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "SelfEnhancement", "Construct", "Manipulation" }),
	},
	{
		Id = "TargetWithinRange",
		Label = "Limit target range",
		Description = "Reject targets beyond the configured targeting range.",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura" }),
	},
	{
		Id = "HasLineOfSight",
		Label = "Require clear line of sight",
		Description = "Reject targets blocked by collidable world geometry.",
		Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "Manipulation" }),
	},
	{
		Id = "TargetIsSelf",
		Label = "Target only yourself",
		Description = "Exclude all targets except the caster.",
		Forms = set({ "SelfEnhancement" }),
	},
}

function Schema.supportsPrincipleForm(principle: string, form: string): boolean
	return Schema.Forms[form] ~= nil and PrincipleSpec.supportsForm(principle, form)
end

function Schema.expressionsFor(principle: string): { string }
	local definition = PrincipleSpec.Definitions[principle]
	return if definition then definition.Expressions else {}
end

function Schema.defaultExpression(principle: string): string?
	local definition = PrincipleSpec.Definitions[principle]
	return definition and definition.DefaultExpression or nil
end

function Schema.expressionMatches(principle: string, expression: string): boolean
	return PrincipleSpec.expressionMatches(principle, expression)
end

function Schema.expressionDescription(expression: string): string?
	return PrincipleSpec.ExpressionDescriptions[expression]
end

function Schema.supportsPayload(kind: string, form: string, event: string, principle: string?): boolean
	local definition = Schema.Payloads[kind]
	event = if event == "OnInterval" then "OnTick" else event
	local events = definition and definition.Events and definition.Events[form]
	return definition ~= nil
		and (definition.Principle == nil or definition.Principle == principle)
		and definition.Forms[form] == true
		and events ~= nil
		and events[event] == true
end

-- Authoring availability is based on Form and event capabilities. Required
-- runtime defaults are resolved after selection, so they never hide a choice.
function Schema.supportsPayloadCapability(kind: string, form: string, event: string): boolean
	local definition = Schema.Payloads[kind]
	event = if event == "OnInterval" then "OnTick" else event
	local events = definition and definition.Events and definition.Events[form]
	return definition ~= nil and definition.Forms[form] == true and events ~= nil and events[event] == true
end

function Schema.supportsBehavior(kind: string, form: string, event: string): boolean
	local definition = Schema.Behaviors[kind]
	event = if event == "OnInterval" then "OnTick" else event
	local events = definition and definition.Events[form]
	return definition ~= nil and definition.Forms[form] == true and events ~= nil and events[event] == true
end

function Schema.supportsEvent(form: string, event: string, castingMode: string?): boolean
	event = if event == "OnInterval" then "OnTick" else event
	local definition = Schema.Forms[form]
	if not definition or definition.Events[event] ~= true then
		return false
	end
	if
		(form == "Beam" or form == "Wave")
		and (event == "OnExpire" or event == "OnDamageTaken" or event == "OnCasterDeath")
	then
		return castingMode == "Channeled"
	end
	return true
end

-- Timings that fire without resolving a target. Under ObjectTarget, payloads
-- marked TargetIndependent (Summon) may use these in addition to the events
-- that resolve the selected object.
Schema.TargetIndependentEvents = set({ "OnCast", "OnSpawn" })

function Schema.eventsForEffects(form: string, castingMode: string?, targeting: string?): { string }
	local events = {}
	local definition = Schema.Forms[form]
	local available = definition and definition.Events or {}
	local objectEvents = nil
	if targeting == "ObjectTarget" then
		if form == "Projectile" then
			objectEvents = set({ "OnImpact" })
		elseif form == "Beam" or form == "Wave" then
			objectEvents = set({ "OnCast" })
			if castingMode == "Channeled" then
				objectEvents.OnTick = true
			end
			if form == "Beam" then
				objectEvents.OnImpact = true
			end
		elseif form == "Manipulation" then
			objectEvents = set({ "OnCast" })
		end
	end
	for _, event in Schema.EventOrder do
		local runtimeEvent = if event == "OnInterval" then "OnTick" else event
		if not available[runtimeEvent] or not Schema.supportsEvent(form, event, castingMode) then
			continue
		end
		local supported = false
		for _, kind in Schema.PayloadOrder do
			local payload = Schema.Payloads[kind]
			local objectEventAllowed = objectEvents == nil or objectEvents[runtimeEvent] == true
			if
				Schema.supportsPayloadCapability(kind, form, event)
				and (
					objectEventAllowed
					or (
						payload
						and payload.TargetIndependent == true
						and Schema.TargetIndependentEvents[runtimeEvent] == true
					)
				)
			then
				supported = true
				break
			end
		end
		if not supported and (objectEvents == nil or objectEvents[runtimeEvent] == true) then
			for kind in Schema.Behaviors do
				if Schema.supportsBehavior(kind, form, event) then
					supported = true
					break
				end
			end
		end
		if supported then
			table.insert(events, event)
		end
	end
	return events
end

function Schema.payloadsFor(form: string, event: string, category: string?): { string }
	local result = {}
	for _, kind in Schema.PayloadOrder do
		local definition = Schema.Payloads[kind]
		if
			Schema.supportsPayloadCapability(kind, form, event)
			and (category == nil or definition.Category == category)
		then
			table.insert(result, kind)
		end
	end
	return result
end

-- Payload fields can depend on another field (Element only for Resistance) and
-- on per-attribute ranges. Editors call these instead of reading Fields raw.
function Schema.fieldVisible(object: any, field: any): boolean
	local rule = field.ShowWhen
	if not rule then
		return true
	end
	return type(object) == "table" and table.find(rule.Values, object[rule.Key]) ~= nil
end

function Schema.resolveField(object: any, field: any): any
	if
		type(object) == "table"
		and object.Kind == "ModifyAttribute"
		and field.Key == "Amount"
		and AttributeSpec.supports(object.Attribute)
	then
		local definition = AttributeSpec.Definitions[object.Attribute]
		local resolved = table.clone(field)
		resolved.Min, resolved.Max = definition.Minimum, definition.Maximum
		return resolved
	end
	return field
end

-- Keeps a ModifyAttribute payload consistent after its Attribute changes:
-- Element only for Resistance, Amount inside the attribute's range.
function Schema.normalizePayload(payload: any)
	if type(payload) ~= "table" or payload.Kind ~= "ModifyAttribute" then
		return
	end
	local definition = AttributeSpec.Definitions[payload.Attribute]
	if not definition then
		return
	end
	if AttributeSpec.requiresElement(payload.Attribute) then
		if not AttributeSpec.validElement(payload.Element) then
			payload.Element = AttributeSpec.Elements[1]
		end
	else
		payload.Element = nil
	end
	local amount = payload.Amount
	if type(amount) ~= "number" or amount < definition.Minimum or amount > definition.Maximum then
		payload.Amount = definition.Default
	end
end

return Schema
