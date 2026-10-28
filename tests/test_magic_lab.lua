-- Pure-data validation; engine casts require Studio.
local env = setmetatable({}, { __index = _G })
env.table = setmetatable({
	freeze = function(t)
		return t
	end,
	find = function(values, wanted)
		for index, value in ipairs(values) do
			if value == wanted then
				return index
			end
		end
	end,
}, { __index = table })
env.Vector3 = {
	new = function(x, y, z)
		return { X = x, Y = y, Z = z }
	end,
}
env.Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255, _color = true }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b, _color = true }
	end,
}
env.typeof = function(v)
	return type(v) == "table" and v._color and "Color3" or type(v)
end
local function load(path)
	return assert(loadfile(path, "t", env))()
end
local sandbox = load("src/shared/Configuration/Sandbox.luau")
local limits = load("src/shared/Configuration/MagicLab.luau")
local locusConfig = load("src/shared/Configuration/MagicLocus.luau")
local summonLimits = load("src/shared/Configuration/MagicSummons.luau")
local specialResourceSpec = load("src/shared/Modules/MagicSpecialResourceSpec.luau")
local principleSpec = load("src/shared/Modules/MagicPrincipleSpec.luau")
local companionPolicy = load("src/shared/Modules/MagicCompanionSpellPolicy.luau")
local damageRules = load("src/shared/Modules/MagicDamageRules.luau")
local constructGeometrySpec = load("src/shared/Modules/MagicConstructGeometrySpec.luau")
local constructGrowthSpec = load("src/shared/Modules/MagicConstructGrowthSpec.luau")
local locusRequirementSpec = load("src/shared/Modules/MagicLocusRequirementSpec.luau")
local targetDeathSpec = load("src/shared/Modules/MagicTargetDeathSpec.luau")
local audioSpec = load("src/shared/Modules/MagicAudioSpec.luau")
local visualSpec = load("src/shared/Modules/MagicVisualSpec.luau")
local visualAssets = load("src/shared/Configuration/MagicVisualAssets.luau")
local poseSpec = load("src/shared/Modules/MagicPoseSpec.luau")
env.script = { Parent = { Parent = { Modules = { MagicPoseSpec = "poseSpec" } } } }
env.require = function(value)
	if value == "poseSpec" then
		return poseSpec
	end
	error(value)
end
local magicPresentation = load("src/shared/Configuration/MagicPresentation.luau")
env.script = {
	Parent = {
		Sandbox = "sandbox",
		Parent = {
			MagicPresentation = "magicPresentation",
			MagicVisualAssets = "visualAssets",
			Configuration = { MagicLab = "limits", MagicSummons = "summonLimits" },
			Modules = {
				MagicPrincipleSpec = "principles",
				MagicDamageRules = "damageRules",
				MagicConstructGeometrySpec = "constructGeometrySpec",
				MagicConstructGrowthSpec = "constructGrowthSpec",
				MagicTargetDeathSpec = "targetDeathSpec",
				MagicAudioSpec = "audioSpec",
				MagicVisualSpec = "visualSpec",
			},
		},
	},
}
env.require = function(v)
	if v == "sandbox" then
		return sandbox
	elseif v == "limits" then
		return limits
	elseif v == "summonLimits" then
		return summonLimits
	elseif v == "principles" then
		return principleSpec
	elseif v == "damageRules" then
		return damageRules
	elseif v == "constructGeometrySpec" then
		return constructGeometrySpec
	elseif v == "constructGrowthSpec" then
		return constructGrowthSpec
	elseif v == "targetDeathSpec" then
		return targetDeathSpec
	elseif v == "audioSpec" then
		return audioSpec
	elseif v == "visualSpec" then
		return visualSpec
	elseif v == "magicPresentation" then
		return magicPresentation
	elseif v == "visualAssets" then
		return visualAssets
	elseif v == "poseSpec" then
		return poseSpec
	end
	error(v)
end
local spells = load("src/shared/Configuration/Spells.luau")
env.script = {
	Parent = {
		MagicLab = "limits",
		MagicSummons = "summonLimits",
		MagicPresentation = "magicPresentation",
		MagicVisualAssets = "visualAssets",
	},
}
env.script.Parent.Parent = {
	Modules = {
		MagicPrincipleSpec = "principles",
		MagicDamageRules = "damageRules",
		MagicConstructGeometrySpec = "constructGeometrySpec",
		MagicTargetDeathSpec = "targetDeathSpec",
		MagicAudioSpec = "audioSpec",
		MagicVisualSpec = "visualSpec",
	},
}
local schemaScript = env.script
env.script = { Parent = { MagicDamageRules = "damageRules", Parent = { Configuration = { MagicLab = "limits" } } } }
local attributeSpec = load("src/shared/Modules/MagicAttributeSpec.luau")
env.script = schemaScript
env.script.Parent.Parent.Modules.MagicAttributeSpec = "attributeSpec"
env.script.Parent.MagicLocus = "locusConfig"
local schemaRequire = env.require
env.require = function(v)
	if v == "attributeSpec" then
		return attributeSpec
	elseif v == "locusConfig" then
		return locusConfig
	end
	return schemaRequire(v)
end
local schema = load("src/shared/Configuration/MagicSchema.luau")
local scaleSpec = load("src/shared/Modules/MagicScaleSpec.luau")
assert(#schema.Principles == 6, "Magic Lab should expose all six Principles")
assert(schema.supportsPrincipleForm("Matter", "Manipulation"))
assert(not schema.supportsPrincipleForm("Energy", "Manipulation"))
assert(schema.supportsPrincipleForm("Soul", "Projectile"))
assert(schema.supportsPrincipleForm("Soul", "Construct"))
assert(schema.supportsPrincipleForm("Soul", "SelfEnhancement"))
assert(schema.supportsPrincipleForm("Time", "Projectile"))
assert(schema.supportsPrincipleForm("Time", "Construct"))
assert(schema.supportsPrincipleForm("Time", "SelfEnhancement"))
assert(schema.supportsPrincipleForm("Space", "Projectile"))
assert(schema.supportsPrincipleForm("Space", "Construct"))
assert(schema.supportsPrincipleForm("Space", "SelfEnhancement"))
assert(table.find(schema.expressionsFor("Energy"), "Force"), "Magic Lab should expose the Force Energy expression")
assert(table.find(schema.Forms.Field.GeometryOptions, "Plane"), "Fields should expose Plane/Wall geometry")
assert(table.find(schema.Forms.Aura.GeometryOptions, "Plane"), "Auras should expose Plane/Wall geometry")
assert(table.find(schema.Forms.Field.GeometryOptions, "Capsule"), "Fields should expose capsule hit geometry")
assert(table.find(schema.Forms.Aura.GeometryOptions, "Capsule"), "Auras should expose capsule hit geometry")
assert(table.find(schema.Forms.Field.GeometryOptions, "Line"), "Fields should expose forward Line geometry")
assert(table.find(schema.Forms.Aura.GeometryOptions, "Line"), "Auras should expose forward Line geometry")
assert(schema.Forms.Construct.Targeting.AimDirection, "Constructs should place into open air by default")
assert(schema.Forms.Construct.Targeting.WorldPoint, "Constructs should support explicit free-space placement")
assert(not schema.Forms.Construct.Targeting.MaterialTarget, "Construct placement must not require a material source")
assert(schema.Forms.Construct.Events.OnExpire, "Constructs should expose their active-effect expiry event")
assert(schema.Forms.SelfEnhancement.Events.OnExpire, "Self Enhancements should expose their expiry event")
assert(schema.supportsPayload("Heal", "Construct", "OnExpire"), "Constructs should support expiry healing")
assert(
	schema.supportsPayload("Shield", "SelfEnhancement", "OnExpire"),
	"Self Enhancements should support expiry shields"
)
assert(
	string.find(schema.Forms.Construct.Description, "without needing a surface", 1, true),
	"Construct help should explain that open-air placement needs no surface"
)
assert(schema.supportsPayload("Damage", "Construct", "OnProximity"), "Constructs should support proximity damage")
assert(schema.supportsPayload("ElementalMark", "Projectile", "OnImpact"))
assert(schema.supportsPayload("ConsumeElementalMark", "Field", "OnEnter"))
assert(schema.supportsBehavior("Explode", "Construct", "OnProximity"), "Construct proximity should support Explode")
assert(
	schema.supportsPayload("DamageOverTime", "Construct", "OnProximity"),
	"Constructs should support proximity damage over time"
)
assert(
	not schema.supportsPayload("Damage", "Construct", "OnCast"),
	"Constructs should not deal proximity damage during placement"
)
assert(
	schema.supportsPayload("Damage", "SelfEnhancement", "OnProximity"),
	"Self Enhancements should support server-sampled proximity damage"
)
assert(
	schema.supportsPayload("DamageOverTime", "SelfEnhancement", "OnProximity"),
	"Self Enhancements should support proximity damage over time"
)
for _, kind in ipairs({ "Force", "Control", "Slow" }) do
	assert(schema.supportsPayload(kind, "Construct", "OnProximity"), kind .. " should support Construct proximity")
	assert(
		schema.supportsPayload(kind, "SelfEnhancement", "OnProximity"),
		kind .. " should support SelfEnhancement proximity"
	)
end
assert(
	schema.supportsPayload("Displacement", "Construct", "OnProximity", "Space"),
	"Space Displacement should support Construct proximity"
)
assert(
	schema.supportsPayload("Displacement", "SelfEnhancement", "OnProximity", "Space"),
	"Space Displacement should support SelfEnhancement proximity"
)
assert(
	not schema.supportsPayload("Displacement", "Construct", "OnProximity", "Energy"),
	"Proximity Displacement should remain Space-only"
)
env.script = { Parent = { Parent = { Configuration = { MagicLab = "limits" } } } }
local projectileBehaviorSpec = load("src/shared/Modules/ProjectileBehaviorSpec.luau")
local conditionSpec = load("src/shared/Modules/MagicConditionSpec.luau")
conditionSpec.configureSpecialResources(locusConfig.SpecialResources)
local lifetimeSpec = load("src/shared/Modules/MagicLifetimeSpec.luau")
local proximitySpec = load("src/shared/Modules/MagicProximitySpec.luau")
local castingSpec = load("src/shared/Modules/MagicCastingSpec.luau")
local materialSpec = load("src/shared/Modules/MagicMaterialSpec.luau")
local projectileMotion = load("src/shared/Modules/MagicProjectileMotion.luau")
local areaSpec = load("src/shared/Modules/MagicAreaSpec.luau")
local identitySpec = load("src/shared/Modules/MagicSpellIdentitySpec.luau")
local triggerSpec = load("src/shared/Modules/MagicTriggerSpec.luau")
local zoneSpec = load("src/shared/Modules/MagicEnvironmentZoneSpec.luau")
env.script.Parent.MagicEnvironmentZoneSpec = "zoneSpec"
local previousRequire = env.require
env.require = function(value)
	if value == "zoneSpec" then
		return zoneSpec
	end
	return previousRequire(value)
end
local environmentSpec = load("src/shared/Modules/MagicEnvironmentRequirementSpec.luau")

env.script = {
	Parent = {
		ProjectileBehaviorSpec = "projectileBehaviorSpec",
		MagicProjectileMotion = "projectileMotion",
		MagicConstructGrowthSpec = "constructGrowthSpec",
		MagicAreaSpec = "areaSpec",
		MagicEnvironmentRequirementSpec = "environmentSpec",
		MagicSpellIdentitySpec = "identitySpec",
		MagicTriggerSpec = "triggerSpec",
		MagicConditionSpec = "conditionSpec",
		MagicLifetimeSpec = "lifetimeSpec",
		MagicProximitySpec = "proximitySpec",
		MagicCastingSpec = "castingSpec",
		MagicMaterialSpec = "materialSpec",
		MagicAudioSpec = "audioSpec",
		MagicConstructGeometrySpec = "constructGeometrySpec",
		MagicLocusRequirementSpec = "locusRequirementSpec",
		MagicSpecialResourceSpec = "specialResourceSpec",
		MagicVisualSpec = "visualSpec",
		MagicAttributeSpec = "attributeSpec",
		MagicScaleSpec = "scaleSpec",
		MagicInterceptionSpec = "interceptionSpec",
		Parent = {
			Configuration = {
				MagicLab = "limits",
				MagicSchema = "schema",
				MagicLocus = "locusConfig",
				MagicSummons = "summonLimits",
			},
		},
	},
}
local interceptionSpec = load("src/shared/Modules/MagicInterceptionSpec.luau")
env.require = function(v)
	if v == "limits" then
		return limits
	elseif v == "interceptionSpec" then
		return interceptionSpec
	elseif v == "schema" then
		return schema
	elseif v == "projectileBehaviorSpec" then
		return projectileBehaviorSpec
	elseif v == "projectileMotion" then
		return projectileMotion
	elseif v == "constructGrowthSpec" then
		return constructGrowthSpec
	elseif v == "areaSpec" then
		return areaSpec
	elseif v == "environmentSpec" then
		return environmentSpec
	elseif v == "identitySpec" then
		return identitySpec
	elseif v == "triggerSpec" then
		return triggerSpec
	elseif v == "proximitySpec" then
		return proximitySpec
	elseif v == "summonLimits" then
		return summonLimits
	elseif v == "conditionSpec" then
		return conditionSpec
	elseif v == "lifetimeSpec" then
		return lifetimeSpec
	elseif v == "castingSpec" then
		return castingSpec
	elseif v == "materialSpec" then
		return materialSpec
	elseif v == "constructGeometrySpec" then
		return constructGeometrySpec
	elseif v == "locusRequirementSpec" then
		return locusRequirementSpec
	elseif v == "specialResourceSpec" then
		return specialResourceSpec
	elseif v == "locusConfig" then
		return locusConfig
	elseif v == "audioSpec" then
		return audioSpec
	elseif v == "visualSpec" then
		return visualSpec
	elseif v == "attributeSpec" then
		return attributeSpec
	elseif v == "scaleSpec" then
		return scaleSpec
	end
	error(v)
end
local spec = load("src/shared/Modules/SpellSpec.luau")
do
	local elementalMark = spec.createDraft("Projectile", "Energy")
	elementalMark.Element = "Fire"
	elementalMark.Triggers.OnImpact = {
		{ Payloads = { { Kind = "ElementalMark", Stacks = 2, Duration = 5 } } },
	}
	assert(spec.validate(elementalMark), "A non-neutral spell should validate its elemental mark payload")
	elementalMark.Element = "Neutral"
	assert(not spec.validate(elementalMark), "Neutral spells must reject elemental marks with a clear invalid state")
	local openAirConstructDraft = spec.createDraft("Construct", "Energy")
	assert(openAirConstructDraft.Targeting == "AimDirection", "New Constructs should cast without selecting a target")
	assert(openAirConstructDraft.Material == nil, "New Constructs should not carry a material-source requirement")
	assert(spec.validate(openAirConstructDraft), "A new Construct should validate for target-free open-air casting")
	local expiryHeal = spec.createDraft("SelfEnhancement", "Body")
	expiryHeal.Triggers.OnExpire = { { Payloads = { { Kind = "Heal", Amount = 5 } } } }
	assert(spec.validate(expiryHeal), "Self Enhancements should validate an OnExpire support payload")
	local constructExpiryShield = spec.createDraft("Construct", "Energy")
	constructExpiryShield.Triggers.OnExpire = { { Payloads = { { Kind = "Shield", Amount = 5, Duration = 4 } } } }
	assert(spec.validate(constructExpiryShield), "Constructs should validate an OnExpire support payload")
	local instantBeamExpiry = spec.createDraft("Beam", "Energy")
	instantBeamExpiry.Triggers.OnExpire = { { Payloads = { { Kind = "Damage", Amount = 5 } } } }
	assert(not spec.validate(instantBeamExpiry), "Instant Beams must reject an expiry trigger that cannot execute")
	local channeledBeamExpiry = spec.copy(instantBeamExpiry)
	channeledBeamExpiry.Casting.Mode = "Channeled"
	channeledBeamExpiry.Casting.ManaUpkeepPerSecond = 1
	channeledBeamExpiry.Lifetime = { Mode = "FixedDuration", Duration = 3 }
	local beamValid, beamReason = spec.validate(channeledBeamExpiry)
	assert(beamValid, "Channeled Beams should support expiry triggers: " .. tostring(beamReason))
	local cascadeBeam = spec.createDraft("Beam", "Energy")
	cascadeBeam.Beam.Pattern = "Cascade"
	cascadeBeam.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	assert(spec.validate(cascadeBeam), "An Instant Beam Cascade should validate with ordinary impact payloads")
	assert(
		spec.estimate(cascadeBeam).ManaDemand > spec.estimate(spec.createDraft("Beam", "Energy")).ManaDemand,
		"Cascade strikes should contribute to the ordinary resource estimate"
	)
	local legacyBeam = spec.createDraft("Beam", "Energy")
	legacyBeam.Beam.Pattern = nil
	legacyBeam.Beam.StrikeCount = nil
	legacyBeam.Beam.SpreadRadius = nil
	legacyBeam.Beam.DropHeight = nil
	legacyBeam.Beam.StrikeInterval = nil
	legacyBeam.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	assert(spec.validate(legacyBeam), "Older version-3 Beam data should retain the Single default")
	local channeledCascade = spec.copy(cascadeBeam)
	channeledCascade.Casting.Mode = "Channeled"
	channeledCascade.Casting.ManaUpkeepPerSecond = 1
	channeledCascade.Lifetime = { Mode = "FixedDuration", Duration = 3 }
	assert(not spec.validate(channeledCascade), "Cascade and Channeled modes should not overlap")
	local fractionalCascade = spec.copy(cascadeBeam)
	fractionalCascade.Beam.StrikeCount = 4.5
	assert(not spec.validate(fractionalCascade), "Cascade strike count must be a whole number")
	local shortRangeCascade = spec.copy(cascadeBeam)
	shortRangeCascade.TargetRules.Range = 40
	assert(not spec.validate(shortRangeCascade), "The target range must reach the cascade drop and impact surface")
	local instantWaveExpiry = spec.createDraft("Wave", "Energy")
	instantWaveExpiry.Triggers.OnExpire = { { Payloads = { { Kind = "Damage", Amount = 5 } } } }
	assert(not spec.validate(instantWaveExpiry), "Instant Waves must reject an expiry trigger that cannot execute")
	local channeledWaveExpiry = spec.copy(instantWaveExpiry)
	channeledWaveExpiry.Casting.Mode = "Channeled"
	channeledWaveExpiry.Casting.ManaUpkeepPerSecond = 1
	channeledWaveExpiry.Lifetime = { Mode = "FixedDuration", Duration = 3 }
	assert(spec.validate(channeledWaveExpiry), "Channeled Waves should support expiry triggers")
	openAirConstructDraft.Targeting = "WorldPoint"
	assert(spec.validate(openAirConstructDraft), "Constructs should validate with a free-space WorldPoint target")
	openAirConstructDraft.Lifetime = { Mode = "Persistent" }
	assert(spec.validate(openAirConstructDraft), "Static Constructs should allow place-persistent lifetime")
	local activePersistentConstruct = spec.copy(openAirConstructDraft)
	activePersistentConstruct.Triggers = {
		OnProximity = { { Payloads = { { Kind = "Damage", Amount = 1 } } } },
	}
	assert(not spec.validate(activePersistentConstruct), "Persistent Constructs must reject active gameplay triggers")
	activePersistentConstruct = spec.copy(openAirConstructDraft)
	activePersistentConstruct.Casting.Mode = "Sustained"
	assert(not spec.validate(activePersistentConstruct), "Persistent Constructs must reject held casting")
	local specialResourceDraft = spec.createDraft("Projectile", "Energy")
	specialResourceDraft.Cost.SpecialResources.Focus = 12
	specialResourceDraft.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	assert(spec.validate(specialResourceDraft), "Configured named-resource costs should validate")
	local unknownResourceDraft = spec.copy(specialResourceDraft)
	unknownResourceDraft.Cost.SpecialResources.UnknownPool = 1
	assert(not spec.validate(unknownResourceDraft), "Unknown named-resource costs should be rejected")
	local excessiveResourceDraft = spec.copy(specialResourceDraft)
	excessiveResourceDraft.Cost.SpecialResources.Focus = limits.MaxSpecialResourceCost + 1
	assert(not spec.validate(excessiveResourceDraft), "Named-resource costs should respect configured bounds")
	local objectForce = spec.createDraft("Manipulation", "Matter")
	objectForce.Targeting = "ObjectTarget"
	objectForce.Material = { SearchRadius = 12 }
	objectForce.Triggers.OnCast = { { Payloads = { { Kind = "Force", Magnitude = 10, Upward = 0 } } } }
	local objectForceValid, objectForceReason = spec.validate(objectForce)
	assert(
		objectForceValid,
		"Force should target a whitelisted movable object without a Matter source: " .. tostring(objectForceReason)
	)
	local objectControl = spec.copy(objectForce)
	objectControl.Triggers.OnCast = {
		{
			Payloads = {
				{ Kind = "Control", Mode = "Pull", Acceleration = 24, Duration = 2, MaxSpeed = 32, MaxMass = 500 },
			},
		},
	}
	local objectControlValid, objectControlReason = spec.validate(objectControl)
	assert(
		objectControlValid,
		"Control should target a whitelisted movable object without a Matter source: " .. tostring(objectControlReason)
	)
	local unconfiguredObjectOperation = spec.copy(objectForce)
	unconfiguredObjectOperation.Triggers.OnCast = {
		{ Payloads = { { Kind = "Manipulation", Operation = "Raise", Distance = 3 } } },
	}
	assert(
		not spec.validate(unconfiguredObjectOperation),
		"Discrete material operations must retain their exact material gate"
	)
	local objectOperation = spec.copy(unconfiguredObjectOperation)
	objectOperation.Material = { Material = "Earth", SearchRadius = 12 }
	assert(spec.validate(objectOperation), "Discrete operations should remain valid for configured tagged materials")
	local audioDraft = spec.createDraft("Projectile", "Energy")
	audioDraft.Audio.CastSoundId = "1234567890"
	audioDraft.Audio.TravelSoundId = "9876543210"
	audioDraft.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	assert(spec.validate(audioDraft), "Numeric audio asset IDs should validate on new spell drafts")
	local legacyAudio = spec.normalize(spells.Fireball)
	assert(legacyAudio.Audio.CastSoundId == "", "Legacy spells should receive silent audio defaults")
	audioDraft.Audio.CastSoundId = "https://example.com/sound"
	assert(not spec.validate(audioDraft), "Audio URLs must be rejected; only numeric Roblox asset IDs are accepted")
	audioDraft.Audio.CastSoundId = "1234567890"
	audioDraft.Audio.Volume = 1.1
	assert(not spec.validate(audioDraft), "Audio volume must remain bounded")
	audioDraft.Audio.Volume = 0.6
	audioDraft.Audio.Unrecognized = "123"
	assert(not spec.validate(audioDraft), "Unknown audio fields must be rejected")
	local waterExpression = spec.normalize(spells.Fireball)
	waterExpression.Source = { Principle = "Matter", Expression = "Water" }
	local waterValid, waterReason = spec.validate(waterExpression)
	assert(waterValid, "Matter/Water should be representable on generic Projectiles: " .. tostring(waterReason))
	local waterElementDefault = spec.copy(spells.Fireball)
	waterElementDefault.Source = { Principle = "Matter", Expression = "Water" }
	waterElementDefault.Element = nil
	assert(
		spec.normalize(waterElementDefault).Element == "Water",
		"Legacy Water expression should use the shared Water damage default"
	)
	assert(table.find(spec.Elements, "Water"), "Water should be available in the elemental damage picker")
	local waterProjectile = spec.createDraft("Projectile", "Matter")
	waterProjectile.Source.Expression = "Water"
	waterProjectile.Targeting = "MaterialTarget"
	waterProjectile.Material = { Material = "Water", Amount = 2, SearchRadius = 12 }
	waterProjectile.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	assert(spec.validate(waterProjectile), "A Water-backed Matter Projectile should validate")
	waterProjectile.Material.Material = "Earth"
	assert(not spec.validate(waterProjectile), "Water source drafts must not request Earth material")
	local sustainedField = spec.normalize(spells.BurningGround)
	sustainedField.Casting.ManaUpkeepPerSecond = 12
	sustainedField.Casting.StrainPerSecond = 3
	local sustainedValid, sustainedReason = spec.validate(sustainedField)
	assert(
		sustainedValid,
		"An active Field should accept generic ongoing resource costs: " .. tostring(sustainedReason)
	)
	sustainedField.Lifetime = { Mode = "UntilResourceDepleted" }
	assert(spec.validate(sustainedField), "Resource-bound Fields require upkeep and should validate")
	sustainedField.Lifetime = {
		Mode = "UntilConditionFails",
		EndWhen = { Family = "Resource", Property = "Mana", Operator = ">", Value = 0 },
	}
	assert(spec.validate(sustainedField), "Condition-bound Fields require a valid keep-alive predicate")
	local conditionAndTimer = spec.copy(sustainedField)
	conditionAndTimer.Lifetime.Duration = 6
	assert(
		spec.validate(conditionAndTimer),
		"A condition-bound Field may combine its keep-alive predicate with a maximum duration"
	)
	conditionAndTimer.Lifetime.Duration = limits.MaxDuration + 0.1
	assert(not spec.validate(conditionAndTimer), "Condition-bound maximum duration must remain within the safety limit")
	local conditionBoundWithoutRule = spec.copy(sustainedField)
	conditionBoundWithoutRule.Lifetime.EndWhen = nil
	assert(not spec.validate(conditionBoundWithoutRule), "Condition-bound Fields must include a keep-alive predicate")
	local conditionBoundProjectile = spec.createDraft("Projectile", "Energy")
	conditionBoundProjectile.Projectile.MaxDistance = 80
	conditionBoundProjectile.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	conditionBoundProjectile.Lifetime = {
		Mode = "UntilConditionFails",
		Duration = 4,
		EndWhen = { Family = "Resource", Property = "Mana", Operator = ">", Value = 0 },
	}
	assert(spec.validate(conditionBoundProjectile), "Condition-bound Projectiles require a hard maximum flight time")
	conditionBoundProjectile.Lifetime.Duration = nil
	assert(not spec.validate(conditionBoundProjectile), "Condition-bound Projectiles must remain time bounded")
	for _, formName in ipairs({ "Beam", "Wave" }) do
		local conditionBoundChannel = spec.createDraft(formName, "Energy")
		conditionBoundChannel.Casting.Mode = "Channeled"
		conditionBoundChannel.Casting.ManaUpkeepPerSecond = 10
		conditionBoundChannel.Lifetime = {
			Mode = "UntilConditionFails",
			Duration = 8,
			EndWhen = { Family = "Resource", Property = "Mana", Operator = ">", Value = 0 },
		}
		conditionBoundChannel.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 2 } } } }
		assert(
			spec.validate(conditionBoundChannel),
			formName .. " channels should allow a keep-alive condition with a bounded maximum duration"
		)
		conditionBoundChannel.Lifetime.Duration = nil
		assert(not spec.validate(conditionBoundChannel), formName .. " condition-bound channels must be time bounded")
	end
	local freeResourceBoundField = spec.copy(sustainedField)
	freeResourceBoundField.Lifetime = { Mode = "UntilResourceDepleted" }
	freeResourceBoundField.Casting.ManaUpkeepPerSecond = 0
	assert(not spec.validate(freeResourceBoundField), "Resource-bound effects must have positive mana upkeep")
	local instantUpkeep = spec.normalize(spells.LightningLance)
	assert(instantUpkeep.Lifetime.Mode == "Instantaneous", "Upkeep fixture must use an Instantaneous lifetime")
	instantUpkeep.Casting.ManaUpkeepPerSecond = 1
	assert(not spec.validate(instantUpkeep), "Instantaneous spells cannot declare ongoing resource costs")
	local earthInteraction = spec.normalize(spells.StoneRaise)
	earthInteraction.Source.Expression = "Water"
	assert(not spec.validate(earthInteraction), "Current Earth manipulation cannot be mislabeled as Water")
	local soulDraft = spec.createDraft("Projectile", "Soul")
	soulDraft.Triggers.OnImpact = {
		{ Payloads = { { Kind = "Damage", Amount = 12, DamageChannel = "Soul" } } },
	}
	assert(spec.validate(soulDraft), "Soul/Spirit projectiles should support Soul-channel damage")
	local locusGated = spec.createDraft("Projectile", "Energy")
	locusGated.LocusRequirements.Capacity = 500
	locusGated.LocusRequirements.Potency = 1.5
	locusGated.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	assert(spec.validate(locusGated), "Finite minimum Locus metrics should validate")
	locusGated.LocusRequirements.Capacity = -1
	assert(not spec.validate(locusGated), "Negative Locus requirements must be rejected")
	local physicalBodyDraft = spec.createDraft("Wave", "Body")
	physicalBodyDraft.Triggers.OnCast = {
		{ Payloads = { { Kind = "Damage", Amount = 8, DamageChannel = "Physical" } } },
	}
	assert(spec.validate(physicalBodyDraft), "Body spells should support Physical-channel damage")
	physicalBodyDraft.Triggers.OnCast[1].Payloads[2] = {
		Kind = "DamageOverTime",
		Amount = 2,
		Duration = 2,
		Interval = 1,
		DamageChannel = "Physical",
	}
	assert(spec.validate(physicalBodyDraft), "Damage-over-time should preserve its Physical channel")
	local physicalEnergyDraft = spec.createDraft("Projectile", "Energy")
	physicalEnergyDraft.Triggers.OnImpact = {
		{ Payloads = { { Kind = "Damage", Amount = 8, DamageChannel = "Physical" } } },
	}
	assert(not spec.validate(physicalEnergyDraft), "Physical damage must be restricted to Body spells")
	local nonSoulChannel = spec.normalize(spells.Fireball)
	nonSoulChannel.Triggers.OnImpact[1].Payloads[1].DamageChannel = "Soul"
	local nonSoulValid, nonSoulReason = spec.validate(nonSoulChannel)
	assert(
		not nonSoulValid and string.find(nonSoulReason, "Soul damage requires the Soul Principle", 1, true),
		"Soul-channel damage must be rejected on a non-Soul spell: " .. tostring(nonSoulReason)
	)
	assert(schema.supportsPayload("Damage", "Projectile", "OnImpact", "Soul"))
	assert(schema.supportsPayload("Damage", "Projectile", "OnImpact", "Energy"))
	local displacement = spec.createDraft("Wave", "Space")
	displacement.Triggers.OnCast = {
		{ Payloads = { { Kind = "Displacement", Mode = "AwayFromCaster", Distance = 8 } } },
	}
	assert(spec.validate(displacement), "Space Wave should support validated displacement")
	assert(schema.supportsPayload("Displacement", "Wave", "OnCast", "Space"))
	assert(not schema.supportsPayload("Displacement", "Wave", "OnCast", "Energy"))
	local constructDisplacement = spec.createDraft("Construct", "Space")
	constructDisplacement.Proximity = { Radius = 8, Interval = 0.5, MaxTargets = 4 }
	constructDisplacement.Triggers.OnProximity = {
		{ Payloads = { { Kind = "Displacement", Mode = "AwayFromCaster", Distance = 8 } } },
	}
	assert(spec.validate(constructDisplacement), "Space should support safe proximity displacement through a Construct")
	local constructSoulDamage = spec.createDraft("Construct", "Soul")
	constructSoulDamage.Proximity = { Radius = 8, Interval = 0.5, MaxTargets = 4 }
	constructSoulDamage.Triggers.OnProximity = {
		{ Payloads = { { Kind = "Damage", Amount = 5, DamageChannel = "Soul" } } },
	}
	assert(spec.validate(constructSoulDamage), "Soul-channel damage should be usable through a proximity Construct")
	local constructTimeDilation = spec.createDraft("Construct", "Time")
	constructTimeDilation.Proximity = { Radius = 8, Interval = 0.5, MaxTargets = 4 }
	constructTimeDilation.Triggers.OnProximity = {
		{ Payloads = { { Kind = "TimeDilation", Rate = 0.5, Duration = 5 } } },
	}
	assert(spec.validate(constructTimeDilation), "Time dilation should be usable through a proximity Construct")
	local enhancementSpaceDisplacement = spec.createDraft("SelfEnhancement", "Space")
	enhancementSpaceDisplacement.Proximity = { Radius = 8, Interval = 0.5, MaxTargets = 4 }
	enhancementSpaceDisplacement.Triggers.OnProximity = {
		{ Payloads = { { Kind = "Displacement", Mode = "AwayFromCaster", Distance = 8 } } },
	}
	assert(spec.validate(enhancementSpaceDisplacement), "Space displacement should work near a Self Enhancement")
	local enhancementSoulDamage = spec.createDraft("SelfEnhancement", "Soul")
	enhancementSoulDamage.Proximity = { Radius = 8, Interval = 0.5, MaxTargets = 4 }
	enhancementSoulDamage.Triggers.OnProximity = {
		{ Payloads = { { Kind = "Damage", Amount = 5, DamageChannel = "Soul" } } },
	}
	assert(spec.validate(enhancementSoulDamage), "Soul damage should work near a Self Enhancement")
	local enhancementTimeDilation = spec.createDraft("SelfEnhancement", "Time")
	enhancementTimeDilation.Proximity = { Radius = 8, Interval = 0.5, MaxTargets = 4 }
	enhancementTimeDilation.Triggers.OnProximity = {
		{ Payloads = { { Kind = "TimeDilation", Rate = 0.5, Duration = 5 } } },
	}
	assert(spec.validate(enhancementTimeDilation), "Time dilation should work near a Self Enhancement")
	local forceExpression = spec.createDraft("Projectile", "Energy")
	forceExpression.Source.Expression = "Force"
	forceExpression.Triggers.OnImpact = {
		{ Payloads = { { Kind = "Force", Magnitude = 12, Upward = 0 } } },
	}
	assert(spec.validate(forceExpression), "Energy/Force should validate through the generic Force payload")
	local wrongPrincipleDisplacement = spec.normalize(displacement)
	wrongPrincipleDisplacement.Source = { Principle = "Energy", Expression = "Fire" }
	local wrongPrincipleValid, wrongPrincipleReason = spec.validate(wrongPrincipleDisplacement)
	assert(not wrongPrincipleValid and string.find(wrongPrincipleReason, "Payload is not supported", 1, true))
	local excessiveDisplacement = spec.normalize(displacement)
	excessiveDisplacement.Triggers.OnCast[1].Payloads[1].Distance = limits.MaxDisplacementDistance + 1
	assert(not spec.validate(excessiveDisplacement), "Displacement distance must remain bounded")
	assert(schema.supportsPayload("TimeDilation", "Aura", "OnTick", "Time"))
	assert(not schema.supportsPayload("TimeDilation", "Aura", "OnTick", "Energy"))
	local timeSpell = spec.createDraft("Aura", "Time")
	timeSpell.Triggers.OnTick = {
		{ Payloads = { { Kind = "TimeDilation", Rate = 0.5, Duration = 5 } } },
	}
	assert(spec.validate(timeSpell), "A Time Aura should apply bounded dilation over time")
	local neutralRate = spec.normalize(timeSpell)
	neutralRate.Triggers.OnTick[1].Payloads[1].Rate = 1
	assert(not spec.validate(neutralRate), "A neutral rate must not create a no-op time effect")
	local restoration = spec.createDraft("Aura", "Energy")
	restoration.Triggers.OnTick = {
		{ Payloads = { { Kind = "Restoration", Amount = 4, Duration = 5, Interval = 1 } } },
	}
	assert(spec.validate(restoration), "Any supported Aura should accept periodic Restoration")
	-- 100 x floor(6 / 1) = 600 total healing, above the 500 aggregate cap.
	restoration.Triggers.OnTick[1].Payloads[1].Amount = 100
	restoration.Triggers.OnTick[1].Payloads[1].Duration = 6
	assert(not spec.validate(restoration), "Periodic Restoration must respect its aggregate safety budget")
	assert(schema.supportsPayload("Damage", "Field", "OnEnter"), "Fields should support OnEnter payloads")
	assert(schema.supportsPayload("Reveal", "Aura", "OnEnter"), "Auras should support Reveal on entry")
	local revealDraft = spec.createDraft("Projectile", "Energy")
	revealDraft.Triggers.OnImpact = { { Payloads = { { Kind = "Reveal", Duration = 8 } } } }
	assert(spec.validate(revealDraft), "Projectile Reveal should validate")
	revealDraft.Triggers.OnImpact[1].Payloads[1].Duration = limits.MaxRevealDuration + 0.1
	assert(not spec.validate(revealDraft), "Reveal duration should honor its configured cap")
	assert(table.find(schema.Forms.Field.GeometryOptions, "Cone"), "Fields should expose Cone geometry")
	assert(table.find(schema.Forms.Aura.GeometryOptions, "Cone"), "Auras should expose Cone geometry")
	assert(table.find(schema.Forms.Field.GeometryOptions, "Ring"), "Fields should expose Ring geometry")
	assert(table.find(schema.Forms.Aura.GeometryOptions, "Ring"), "Auras should expose Ring geometry")
	local coneField = spec.createDraft("Field", "Energy")
	coneField.Geometry = "Cone"
	coneField.Field = { Range = 12, Angle = 70, Height = 6, Interval = 0.6, DebugHeight = 0.2, Yaw = 20 }
	coneField.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 5 } } } }
	assert(spec.validate(coneField), "Field cone geometry should validate")
	coneField.Field.Angle = 121
	assert(not spec.validate(coneField), "Field cone angle should respect the configured maximum")
	local ringField = spec.createDraft("Field", "Energy")
	ringField.Geometry = "Ring"
	ringField.Field = { InnerRadius = 3, OuterRadius = 8, Height = 6, Interval = 0.6, DebugHeight = 0.2, Yaw = 0 }
	ringField.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 5 } } } }
	assert(spec.validate(ringField), "Field ring geometry should validate")
	ringField.Field.InnerRadius = ringField.Field.OuterRadius
	assert(not spec.validate(ringField), "Ring inner radius must be smaller than its outer radius")
	local lineField = spec.createDraft("Field", "Energy")
	lineField.Geometry = "Line"
	lineField.Field = { Width = 4, Height = 6, Range = 16, Interval = 0.6, DebugHeight = 0.2, Yaw = 25 }
	lineField.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 5 } } } }
	assert(spec.validate(lineField), "Forward Line Field should validate with its corridor dimensions")
	local ringAura = spec.createDraft("Aura", "Energy")
	ringAura.Geometry = "Ring"
	ringAura.Aura = { InnerRadius = 2, OuterRadius = 7, Height = 5, Interval = 0.5, Yaw = 0 }
	ringAura.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 4 } } } }
	assert(spec.validate(ringAura), "Aura ring geometry should validate")
	assert(schema.supportsPayload("Heal", "Aura", "OnExit"), "Auras should support OnExit payloads")
	for _, kind in ipairs({ "Heal", "Restoration", "Shield" }) do
		assert(schema.supportsPayload(kind, "Field", "OnEnter"), kind .. " should support Field entry effects")
		assert(schema.supportsPayload(kind, "Aura", "OnExit"), kind .. " should support Aura exit effects")
		assert(schema.supportsPayload(kind, "Construct", "OnProximity"), kind .. " should support Construct proximity")
		assert(
			schema.supportsPayload(kind, "SelfEnhancement", "OnProximity"),
			kind .. " should support Self Enhancement proximity"
		)
	end
	local supportFormEvents = {
		Projectile = "OnImpact",
		Beam = "OnCast",
		Wave = "OnCast",
		Field = "OnEnter",
		Aura = "OnEnter",
		Construct = "OnProximity",
		SelfEnhancement = "OnProximity",
	}
	for formName, eventName in pairs(supportFormEvents) do
		for _, kind in ipairs({ "Heal", "Restoration", "Shield" }) do
			assert(
				schema.supportsPayload(kind, formName, eventName),
				kind .. " should support the target-resolving " .. formName .. " event"
			)
			-- SelfEnhancement is not an Energy Form; Body is its baseline Principle.
			local principle = if schema.supportsPrincipleForm("Energy", formName) then "Energy" else "Body"
			local supportDraft = spec.createDraft(formName, principle)
			local value = spec.copy(schema.Payloads[kind].Defaults)
			value.Kind = kind
			supportDraft.Triggers[eventName] = { { Payloads = { value } } }
			assert(spec.validate(supportDraft), kind .. " should validate through " .. formName .. " / " .. eventName)
		end
	end
	assert(
		table.find(schema.payloadsFor("Construct", "OnProximity", "Support"), "Heal"),
		"Construct proximity healing should appear in the matching Magic Lab category"
	)
	assert(
		table.find(schema.payloadsFor("SelfEnhancement", "OnProximity", "Support"), "Shield"),
		"Self Enhancement proximity shields should appear in the matching Magic Lab category"
	)
	assert(
		table.find(schema.payloadsFor("Wave", "OnCast", "Movement"), "Displacement"),
		"Capability choices should include movement effects without a source filter"
	)
	assert(
		table.find(schema.payloadsFor("Aura", "OnCast", "Temporal"), "TimeDilation"),
		"Capability choices should include temporal effects without a source filter"
	)
	local openAirSupportConstruct = spec.createDraft("Construct", "Energy")
	openAirSupportConstruct.Proximity = { Radius = 8, Interval = 0.5, MaxTargets = 4 }
	openAirSupportConstruct.Triggers.OnProximity = {
		{
			Payloads = {
				{ Kind = "Heal", Amount = 10 },
				{ Kind = "Restoration", Amount = 2, Duration = 3, Interval = 1 },
			},
		},
		{ Payloads = { { Kind = "Shield", Amount = 10, Duration = 5 } } },
	}
	assert(
		spec.validate(openAirSupportConstruct),
		"An open-air Construct should validate proximity healing, restoration, and shield payloads without a surface target"
	)
	assert(schema.supportsPayload("Damage", "Beam", "OnTick"), "Channeled Beams should support repeated damage")
	assert(schema.supportsPayload("Heal", "Beam", "OnTick"), "Channeled Beams should support repeated healing")
	assert(schema.supportsPayload("Slow", "Beam", "OnTick"), "Channeled Beams should support repeated control")
	assert(schema.supportsPayload("Bind", "Aura", "OnEnter"), "Auras should support Bind on entry")
	assert(schema.supportsPayload("Bind", "Construct", "OnProximity"), "Constructs should support proximity Bind")
	assert(
		schema.supportsPayload("Bind", "SelfEnhancement", "OnProximity"),
		"Self Enhancements should support proximity Bind"
	)
	local bindDraft = spec.createDraft("Aura", "Energy")
	bindDraft.Triggers.OnEnter = { { Payloads = { { Kind = "Bind", Duration = 1.5 } } } }
	assert(spec.validate(bindDraft), "Aura Bind should validate")
	bindDraft.Triggers.OnEnter[1].Payloads[1].Duration = limits.MaxBindDuration + 0.1
	assert(not spec.validate(bindDraft), "Bind duration should honor its configured cap")
	local proximityBindConstruct = spec.createDraft("Construct", "Energy")
	proximityBindConstruct.Proximity = { Radius = 8, Interval = 0.25, MaxTargets = 4 }
	proximityBindConstruct.Triggers.OnProximity = { { Payloads = { { Kind = "Bind", Duration = 1.5 } } } }
	assert(spec.validate(proximityBindConstruct), "Construct proximity Bind should validate")
	local proximityBindEnhancement = spec.createDraft("SelfEnhancement", "Body")
	proximityBindEnhancement.Proximity = { Radius = 8, Interval = 0.25, MaxTargets = 4 }
	proximityBindEnhancement.Triggers.OnProximity = { { Payloads = { { Kind = "Bind", Duration = 1.5 } } } }
	assert(spec.validate(proximityBindEnhancement), "Self Enhancement proximity Bind should validate")
	local proximityExplodingConstruct = spec.createDraft("Construct", "Energy")
	proximityExplodingConstruct.Proximity = { Radius = 8, Interval = 0.25, MaxTargets = 4 }
	proximityExplodingConstruct.Triggers.OnProximity = {
		{ Behavior = "Explode", Radius = 6, Payloads = { { Kind = "Damage", Amount = 5 } } },
	}
	assert(spec.validate(proximityExplodingConstruct), "Construct proximity Explode should validate")
	assert(
		schema.supportsPayload("Control", "Projectile", "OnImpact"),
		"Projectile impacts should support maintained Control"
	)
	assert(schema.supportsPayload("Control", "Field", "OnEnter"), "Fields should support maintained Control on entry")
	assert(schema.supportsPayload("Control", "Aura", "OnTick"), "Auras should support repeated maintained Control")
	assert(schema.supportsPayload("Damage", "Projectile", "OnTick"), "Linger should support repeated projectile damage")
	assert(
		schema.supportsPayload("Damage", "Projectile", "OnInterval"),
		"The interval authoring alias should use the bounded tick runtime"
	)
	assert(
		table.find(schema.eventsForEffects("Field"), "OnInterval"),
		"The Lab should expose OnInterval for pulsed Fields"
	)
	assert(
		schema.supportsPayload("Damage", "Projectile", "OnThreshold"),
		"Projectile damage should support threshold reactions"
	)
	assert(
		schema.supportsPayload("Damage", "Projectile", "OnProximity"),
		"Projectile damage should support proximity reactions"
	)
	assert(table.find(schema.eventsForEffects("Projectile"), "OnProximity"), "The Lab should expose OnProximity")
	assert(table.find(schema.eventsForEffects("Projectile"), "OnSpawn"), "The Lab should expose projectile OnSpawn")
	assert(table.find(schema.eventsForEffects("Projectile"), "OnCast"), "The Lab should expose projectile OnCast")
	assert(table.find(schema.eventsForEffects("Projectile"), "OnExpire"), "The Lab should expose projectile OnExpire")
	local objectProjectileEvents = schema.eventsForEffects("Projectile", "Instant", "ObjectTarget")
	assert(
		table.find(objectProjectileEvents, "OnImpact"),
		"Object-targeted projectiles should expose their exact impact event"
	)
	assert(
		table.find(objectProjectileEvents, "OnSpawn"),
		"Object-targeted projectiles should expose target-independent summon spawn effects"
	)
	assert(
		table.find(objectProjectileEvents, "OnCast"),
		"Object-targeted projectiles should expose target-independent caster summons on cast"
	)
	assert(
		schema.supportsPayload("Summon", "Projectile", "OnCast"),
		"A Projectile Summon can be triggered at cast independently of its target"
	)
	assert(
		not schema.supportsPayload("Damage", "Projectile", "OnCast"),
		"Showing target-independent cast events must not enable target-dependent damage"
	)
	local objectProjectileSummon = spec.createDraft("Projectile", "Energy")
	objectProjectileSummon.Targeting = "ObjectTarget"
	objectProjectileSummon.Triggers.OnCast = {
		{ Payloads = { { Kind = "Summon", Archetype = "Wisp", SpawnAt = "Caster", Count = 1, Duration = 10 } } },
	}
	local objectSummonValid, objectSummonReason = spec.validate(objectProjectileSummon)
	assert(
		objectSummonValid,
		"Target-independent OnCast summon should validate for object projectiles: " .. tostring(objectSummonReason)
	)
	local objectBeamInstantEvents = schema.eventsForEffects("Beam", "Instant", "ObjectTarget")
	assert(table.find(objectBeamInstantEvents, "OnCast"), "Instant object-targeted beams resolve their cast event")
	assert(not table.find(objectBeamInstantEvents, "OnTick"), "Instant object-targeted beams do not tick")
	local objectBeamChannelEvents = schema.eventsForEffects("Beam", "Channeled", "ObjectTarget")
	assert(table.find(objectBeamChannelEvents, "OnTick"), "Channeled object-targeted beams resolve validated ticks")
	assert(
		not table.find(objectBeamChannelEvents, "OnExpire"),
		"Object-targeted beams cannot resolve an object at expiry"
	)
	local objectChannelBeam = spec.createDraft("Beam", "Energy")
	objectChannelBeam.Targeting = "ObjectTarget"
	objectChannelBeam.Casting.Mode = "Channeled"
	objectChannelBeam.Casting.ManaUpkeepPerSecond = 5
	objectChannelBeam.Lifetime = { Mode = "FixedDuration", Duration = 3 }
	objectChannelBeam.Triggers.OnTick = {
		{ Payloads = { { Kind = "Force", Magnitude = 12, Upward = 0 } } },
	}
	assert(
		spec.validate(objectChannelBeam),
		"The editor's object-targeted Beam tick event should validate on the server"
	)
	local objectIntervalBeam = spec.copy(objectChannelBeam)
	objectIntervalBeam.Triggers.OnInterval = objectIntervalBeam.Triggers.OnTick
	objectIntervalBeam.Triggers.OnTick = nil
	assert(spec.validate(objectIntervalBeam), "Object-targeted Beam OnInterval should alias the validated OnTick path")
	local mixedBeamIntervals = spec.copy(objectChannelBeam)
	mixedBeamIntervals.Triggers.OnInterval = {
		{
			Payloads = {
				{ Kind = "Control", Mode = "Pull", Acceleration = 24, Duration = 2, MaxSpeed = 32, MaxMass = 500 },
			},
		},
	}
	local normalizedBeamIntervals = spec.normalize(mixedBeamIntervals)
	assert(
		#normalizedBeamIntervals.Triggers.OnTick == 2,
		"Normalizing both channel timing names must preserve both steps"
	)
	assert(spec.validate(normalizedBeamIntervals), "Merged object-target channel timing aliases should remain valid")
	assert(
		normalizedBeamIntervals.Triggers.OnTick[1].Payloads[1].Kind == "Force"
			and normalizedBeamIntervals.Triggers.OnTick[2].Payloads[1].Kind == "Control",
		"Canonical OnTick steps should precede their OnInterval aliases deterministically"
	)
	local invalidObjectChannelBeam = spec.copy(objectChannelBeam)
	invalidObjectChannelBeam.Triggers = {
		OnExpire = { { Payloads = { { Kind = "Force", Magnitude = 12, Upward = 0 } } } },
	}
	assert(
		not spec.validate(invalidObjectChannelBeam),
		"Object-targeted Beam expiry cannot resolve the selected object"
	)
	local objectWaveReleaseEvents = schema.eventsForEffects("Wave", "HoldAndRelease", "ObjectTarget")
	assert(table.find(objectWaveReleaseEvents, "OnCast"), "Object-targeted waves resolve their initial cast")
	assert(not table.find(objectWaveReleaseEvents, "OnTick"), "Released object-targeted waves do not tick")
	local objectChannelWaveEvents = schema.eventsForEffects("Wave", "Channeled", "ObjectTarget")
	assert(table.find(objectChannelWaveEvents, "OnTick"), "Channeled object-targeted waves resolve validated ticks")
	local objectChannelWave = spec.createDraft("Wave", "Energy")
	objectChannelWave.Targeting = "ObjectTarget"
	objectChannelWave.Casting.Mode = "Channeled"
	objectChannelWave.Casting.ManaUpkeepPerSecond = 5
	objectChannelWave.Lifetime = { Mode = "FixedDuration", Duration = 3 }
	objectChannelWave.Triggers.OnTick = {
		{ Payloads = { { Kind = "Force", Magnitude = 12, Upward = 0 } } },
	}
	assert(
		spec.validate(objectChannelWave),
		"The editor's object-targeted Wave tick event should validate on the server"
	)
	local objectIntervalWave = spec.copy(objectChannelWave)
	objectIntervalWave.Triggers.OnInterval = objectIntervalWave.Triggers.OnTick
	objectIntervalWave.Triggers.OnTick = nil
	assert(spec.validate(objectIntervalWave), "Object-targeted Wave OnInterval should alias the validated OnTick path")
	local objectManipulationEvents = schema.eventsForEffects("Manipulation", "Instant", "ObjectTarget")
	assert(
		#objectManipulationEvents == 1 and objectManipulationEvents[1] == "OnCast",
		"Object Manipulation resolves only OnCast"
	)
	assert(schema.supportsBehavior("Explode", "Projectile", "OnCast"), "Cast bursts should use generic Explode")
	assert(schema.supportsBehavior("Explode", "Projectile", "OnSpawn"), "Spawn bursts should use generic Explode")
	assert(schema.supportsBehavior("Explode", "Projectile", "OnExpire"), "Expiry bursts should use generic Explode")
	for _, event in ipairs({ "OnCast", "OnSpawn", "OnExpire" }) do
		assert(
			not schema.supportsPayload("Heal", "Projectile", event),
			"Projectile " .. event .. " should not expose direct Heal without a validated target set"
		)
	end
	assert(
		not schema.supportsPayload("Damage", "Projectile", "OnSpawn"),
		"Projectile spawn damage should remain limited to a bounded behavior instead of a direct empty-target payload"
	)
	local projectileSpawnBurst = spec.createDraft("Projectile", "Energy")
	projectileSpawnBurst.Triggers.OnSpawn = {
		{ Behavior = "Explode", Radius = 5, Payloads = { { Kind = "Damage", Amount = 5 } } },
	}
	assert(spec.validate(projectileSpawnBurst), "Projectile OnSpawn Explode should validate through generic dispatch")
	local projectileCastBurst = spec.createDraft("Projectile", "Energy")
	projectileCastBurst.Triggers.OnCast = {
		{ Behavior = "Explode", Radius = 5, Payloads = { { Kind = "Damage", Amount = 5 } } },
	}
	assert(spec.validate(projectileCastBurst), "Projectile OnCast Explode should validate through generic dispatch")
	assert(
		not table.find(schema.eventsForEffects("Beam", "Instant"), "OnExpire"),
		"Instant Beams should not expose expiry triggers without an active lifetime"
	)
	assert(
		table.find(schema.eventsForEffects("Beam", "Channeled"), "OnExpire"),
		"Channeled Beams should expose OnExpire"
	)
	for _, form in ipairs({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement" }) do
		local castingMode = if form == "Beam" or form == "Wave" then "Channeled" else "Instant"
		assert(
			schema.supportsBehavior("Explode", form, "OnExpire"),
			form .. " expiry should support the generic Explode behavior"
		)
		assert(
			table.find(schema.eventsForEffects(form, castingMode), "OnExpire"),
			form .. " expiry should be authorable in the Magic Lab"
		)
	end
	assert(
		not table.find(schema.eventsForEffects("Wave", "HoldAndRelease"), "OnExpire"),
		"Released Waves should not expose expiry triggers without an active lifetime"
	)
	assert(schema.supportsPayload("Shield", "Field", "OnBreak"), "Fields should support shield break effects")
	assert(schema.supportsPayload("Damage", "Field", "OnBreak"), "Field shield breaks should support damage effects")
	assert(schema.supportsPayload("ModifyAttribute", "Aura", "OnTick"), "Auras should support timed attribute effects")
	assert(schema.supportsPayload("Transformation", "Aura", "OnTick"), "Auras should support timed transformations")
	assert(schema.supportsPayload("Transformation", "Projectile", "OnImpact"), "Impacts should support transformations")
	local transformDraft = spec.createDraft("Aura", "Energy")
	transformDraft.Triggers.OnTick = {
		{ Payloads = { { Kind = "Transformation", Mode = "Scale", Multiplier = 1.2, Duration = 5 } } },
	}
	assert(spec.validate(transformDraft), "A valid scale transformation should validate")
	local excessiveTransform = spec.normalize(transformDraft)
	excessiveTransform.Triggers.OnTick[1].Payloads[1].Multiplier = limits.MaxTransformScale + 0.1
	assert(not spec.validate(excessiveTransform), "Scale transformations should obey their configured bounds")
	local unsupportedTransform = spec.normalize(transformDraft)
	unsupportedTransform.Triggers.OnTick[1].Payloads[1].Mode = "Morph"
	assert(not spec.validate(unsupportedTransform), "Unimplemented transformation modes should be rejected")
	local duplicateTransform = spec.normalize(transformDraft)
	duplicateTransform.Triggers.OnEnter = {
		{ Payloads = { { Kind = "Transformation", Mode = "Scale", Multiplier = 0.9, Duration = 5 } } },
	}
	assert(not spec.validate(duplicateTransform), "A spell should have one deterministic transformation payload")
	-- Construct does not offer MaterialTarget; MagicMaterialSpec omits it.
	for _, formName in ipairs({ "Beam", "Wave", "Field", "Aura" }) do
		assert(
			materialSpec.supports("Matter", "Earth", formName, "MaterialTarget", "Metal"),
			"Metal sources should be usable by Earth-affinity Matter " .. formName
		)
		assert(
			materialSpec.supports("Matter", "Water", formName, "MaterialTarget", "Water"),
			"Water sources should be usable by Matter " .. formName
		)
	end
	local earthBeam = spec.createDraft("Beam", "Matter")
	earthBeam.Targeting = "MaterialTarget"
	earthBeam.Material = { Material = "Metal", Amount = 1, SearchRadius = 12 }
	earthBeam.Triggers.OnCast = { { Payloads = { { Kind = "Damage", Amount = 10 } } } }
	assert(spec.validate(earthBeam), "Earth-affinity Matter Beams should validate a consumed Metal source requirement")
	earthBeam.Material.Material = "Wood"
	assert(spec.validate(earthBeam), "Earth-affinity Matter Beams should validate a consumed Wood source requirement")
	earthBeam.Material.Material = "Earth"
	local waterField = spec.createDraft("Field", "Matter")
	waterField.Source.Expression = "Water"
	waterField.Targeting = "MaterialTarget"
	waterField.Material = { Material = "Water", Amount = 1, SearchRadius = 12 }
	waterField.Triggers.OnEnter = { { Payloads = { { Kind = "Damage", Amount = 2 } } } }
	assert(spec.validate(waterField), "Matter Fields should validate a consumed Water source requirement")
	local missingMaterialAmount = spec.normalize(earthBeam)
	missingMaterialAmount.Material.Amount = nil
	assert(not spec.validate(missingMaterialAmount), "Every consumed material requirement needs a bounded amount")
	local armorModifier = spec.createDraft("Aura", "Energy")
	armorModifier.Triggers.OnTick =
		{ { Payloads = {
			{ Kind = "ModifyAttribute", Attribute = "MagicArmor", Amount = 20, Duration = 5 },
		} } }
	assert(spec.validate(armorModifier), "A timed armor attribute modifier should validate")
	local lightArmorEstimate = spec.estimate(armorModifier).ManaDemand
	armorModifier.Triggers.OnTick[1].Payloads[1].Amount = 80
	assert(
		spec.estimate(armorModifier).ManaDemand > lightArmorEstimate,
		"stronger temporary attribute modifiers should increase the development estimate"
	)
	armorModifier.Triggers.OnTick[1].Payloads[1].Amount = 20
	armorModifier.Triggers.OnTick[1].Payloads[1].Attribute = "WalkSpeed"
	assert(not spec.validate(armorModifier), "unregistered engine attributes must be rejected")
	armorModifier.Triggers.OnTick[1].Payloads[1].Attribute = "MagicArmor"
	armorModifier.Triggers.OnTick[1].Payloads[1].Amount = 101
	assert(not spec.validate(armorModifier), "attribute values must obey the shared safety cap")
	local duplicateArmorModifier = spec.createDraft("Aura", "Energy")
	duplicateArmorModifier.Triggers.OnEnter =
		{ { Payloads = {
			{ Kind = "ModifyAttribute", Attribute = "MagicArmor", Amount = 10, Duration = 5 },
		} } }
	duplicateArmorModifier.Triggers.OnExit =
		{ { Payloads = {
			{ Kind = "ModifyAttribute", Attribute = "MagicArmor", Amount = 20, Duration = 5 },
		} } }
	assert(not spec.validate(duplicateArmorModifier), "a spell must have one deterministic modifier per attribute")
	-- Phase 2 attributes: each validates inside its own range; Element only for Resistance.
	local function attributeDraft(payload)
		local draft = spec.createDraft("Aura", "Energy")
		payload.Kind = "ModifyAttribute"
		payload.Duration = payload.Duration or 5
		draft.Triggers.OnTick = { { Payloads = { payload } } }
		return draft
	end
	for _, attribute in attributeSpec.Order do
		local definition = attributeSpec.Definitions[attribute]
		local element = if attributeSpec.requiresElement(attribute) then "Fire" else nil
		assert(table.find(schema.Payloads.ModifyAttribute.Fields[1].Options, attribute), attribute .. " is selectable")
		assert(
			spec.validate(attributeDraft({ Attribute = attribute, Element = element, Amount = definition.Maximum })),
			attribute .. " validates at its maximum"
		)
		assert(
			spec.validate(attributeDraft({ Attribute = attribute, Element = element, Amount = definition.Minimum })),
			attribute .. " validates at its minimum"
		)
		assert(
			not spec.validate(
				attributeDraft({ Attribute = attribute, Element = element, Amount = definition.Maximum + 0.5 })
			),
			attribute .. " rejects values above its own maximum"
		)
		assert(
			conditionSpec.Properties.Status[attributeSpec.attributeName(attribute, element)],
			attribute .. " bonus is available to Status conditions"
		)
	end
	local ok, reason = spec.validate(attributeDraft({ Attribute = "Resistance", Amount = 0.3 }))
	assert(not ok and string.find(reason, "Resistance element", 1, true), "Resistance requires an Element")
	assert(not spec.validate(attributeDraft({ Attribute = "Resistance", Element = "Neutral", Amount = 0.3 })))
	assert(not spec.validate(attributeDraft({ Attribute = "Resistance", Element = "Plasma", Amount = 0.3 })))
	ok, reason = spec.validate(attributeDraft({ Attribute = "DamageTaken", Element = "Fire", Amount = 10 }))
	assert(not ok and string.find(reason, "Only Resistance", 1, true), "Element is rejected for other attributes")
	assert(spec.validate(attributeDraft({ Attribute = "Resistance", Element = "Ice", Amount = -0.5 })))
	assert(not spec.validate(attributeDraft({ Attribute = "DamageTaken", Amount = 60 })), "DamageTaken caps at 50")
	assert(not spec.validate(attributeDraft({ Attribute = "HealingReceived", Amount = -80 })), "-75 floor")
	for _, element in attributeSpec.Elements do
		assert(conditionSpec.Properties.Status["MagicResistance" .. element .. "Bonus"], element)
	end
	-- Editor helpers: Element shows only for Resistance; Amount uses the attribute's range.
	local elementField, amountField
	for _, field in schema.Payloads.ModifyAttribute.Fields do
		if field.Key == "Element" then
			elementField = field
		elseif field.Key == "Amount" then
			amountField = field
		end
	end
	assert(elementField and not elementField.Required, "Element is optional at the schema level")
	assert(schema.fieldVisible({ Kind = "ModifyAttribute", Attribute = "Resistance" }, elementField))
	assert(not schema.fieldVisible({ Kind = "ModifyAttribute", Attribute = "CastSpeed" }, elementField))
	local resolved = schema.resolveField({ Kind = "ModifyAttribute", Attribute = "Resistance" }, amountField)
	assert(resolved.Min == -1 and resolved.Max == 1 and amountField.Min == -100, "per-attribute bounds")
	local switching = { Kind = "ModifyAttribute", Attribute = "Resistance", Amount = 15, Duration = 5 }
	schema.normalizePayload(switching)
	assert(switching.Element == "Fire" and switching.Amount == 0.2, "switching to Resistance picks an element")
	switching.Attribute = "CastSpeed"
	schema.normalizePayload(switching)
	assert(switching.Element == nil and switching.Amount == 0.2, "leaving Resistance drops the element")
	assert(spec.validate(attributeDraft(switching)), "a normalized payload validates")
	-- Cost weighs attributes on the armor scale, so a full Resistance is not free.
	local fullArmor = spec.estimate(attributeDraft({ Attribute = "MagicArmor", Amount = 100 })).ManaDemand
	local fullResist =
		spec.estimate(attributeDraft({ Attribute = "Resistance", Element = "Fire", Amount = 1 })).ManaDemand
	assert(math.abs(fullArmor - fullResist) < 1e-6, "full Resistance costs like full armor")
	-- AerialMovement is an Enchantment OnCast payload.
	assert(schema.supportsPayload("AerialMovement", "SelfEnhancement", "OnCast"), "AerialMovement on Enchantment")
	-- Phase 6: Stun, Silence and Cleanse validate within their limits.
	local function ccDraft(payload)
		local draft = spec.createDraft("Projectile", "Energy")
		draft.Triggers.OnImpact = { { Payloads = { payload } } }
		return draft
	end
	assert(spec.validate(ccDraft({ Kind = "Stun", Duration = 1.5 })), "Stun up to 1.5 s against creatures")
	assert(not spec.validate(ccDraft({ Kind = "Stun", Duration = 1.6 })), "Stun above 1.5 s is rejected")
	assert(spec.validate(ccDraft({ Kind = "Silence", Duration = 2 })), "Silence validates")
	assert(not spec.validate(ccDraft({ Kind = "Silence", Duration = 99 })), "Silence has a maximum")
	assert(spec.validate(ccDraft({ Kind = "Cleanse", Remove = "Banes", Count = 2 })), "Cleanse Banes validates")
	assert(spec.validate(ccDraft({ Kind = "Cleanse", Remove = "Boons", Count = 1, Element = "Fire" })))
	assert(not spec.validate(ccDraft({ Kind = "Cleanse", Remove = "Everything", Count = 1 })), "Banes or Boons only")
	assert(not spec.validate(ccDraft({ Kind = "Cleanse", Remove = "Banes", Count = 1.5 })), "whole numbers only")
	assert(not spec.validate(ccDraft({ Kind = "Cleanse", Remove = "Banes", Count = 0 })), "at least one")
	assert(schema.Payloads.Stun.Polarity == "Bane" and schema.Payloads.Silence.Polarity == "Bane")
	assert(schema.Payloads.Cleanse.Polarity == "Neutral")
	-- Phase 8: Taunt and Fear (creatures only) validate within their limits.
	assert(spec.validate(ccDraft({ Kind = "Taunt", Duration = 6 })), "Taunt up to 6 s")
	assert(not spec.validate(ccDraft({ Kind = "Taunt", Duration = 6.5 })), "Taunt has a maximum")
	assert(spec.validate(ccDraft({ Kind = "Fear", Duration = 4 })), "Fear up to 4 s")
	assert(not spec.validate(ccDraft({ Kind = "Fear", Duration = 5 })), "Fear has a maximum")
	assert(schema.Payloads.Taunt.Polarity == "Bane" and schema.Payloads.Fear.Polarity == "Bane")
	assert(spec.validate(ccDraft({ Kind = "Stealth", Duration = 8 })), "Stealth up to 8 s")
	assert(not spec.validate(ccDraft({ Kind = "Stealth", Duration = 9 })), "Stealth has a maximum")
	assert(schema.Payloads.Stealth.Polarity == "Boon", "Stealth is a Boon")
	-- DrainResource / RestoreResource: Mana or a configured special resource.
	assert(spec.validate(ccDraft({ Kind = "DrainResource", Resource = "Mana", Amount = 50 })), "drain mana")
	assert(spec.validate(ccDraft({ Kind = "RestoreResource", Resource = "Focus", Amount = 10 })), "restore Focus")
	assert(not spec.validate(ccDraft({ Kind = "DrainResource", Resource = "Gold", Amount = 10 })), "unknown resource")
	assert(not spec.validate(ccDraft({ Kind = "RestoreResource", Resource = "Mana", Amount = 51 })), "transfer limit")
	assert(schema.Payloads.DrainResource.Polarity == "Bane" and schema.Payloads.RestoreResource.Polarity == "Boon")
	-- Charge scales the whole estimate, including control: a charged volley of Slows.
	local volley = spec.createDraft("Projectile", "Energy")
	volley.Casting.Mode = "Charged"
	volley.Casting.MinimumCharge = 0.2
	volley.Casting.MaximumCharge = 2
	volley.Triggers.OnImpact = { { Payloads = { { Kind = "Slow", Multiplier = 0.5, Duration = 3 } } } }
	local slowBase = spec.estimate(volley).ManaDemand
	volley.Casting.ChargeScaling = { MinPotency = 1, MaxPotency = 1, MaxExtraProjectiles = 3 }
	assert(spec.validate(volley), "charged Slow volley validates")
	assert(spec.estimate(volley).ManaDemand > slowBase, "extra projectiles of Slow cost more")
	local volleyCost = spec.estimate(volley).ManaDemand
	volley.Casting.ChargeScaling.MaxPotency = 3
	assert(spec.estimate(volley).ManaDemand > volleyCost, "charge potency also prices non-damage payloads")
	local areaDraft = spec.createDraft("Field", "Matter")
	assert(areaDraft, "Field draft should be available to Matter")
	areaDraft.Triggers.OnEnter = { { Payloads = { { Kind = "Damage", Amount = 1 } } } }
	areaDraft.Triggers.OnExit = { { Payloads = { { Kind = "Heal", Amount = 1 } } } }
	assert(spec.validate(areaDraft), "Area enter/exit payloads should validate")
	local proximityEnhancement = spec.createDraft("SelfEnhancement", "Body")
	proximityEnhancement.Triggers.OnProximity = { { Payloads = { { Kind = "Damage", Amount = 1 } } } }
	assert(spec.validate(proximityEnhancement), "Self Enhancements should support bounded approach triggers")
	local proximityConstruct = spec.createDraft("Construct", "Matter")
	proximityConstruct.Targeting = "ObjectTarget"
	proximityConstruct.Material = nil
	proximityConstruct.Construct = { Width = 6, Height = 6, Depth = 1, Distance = 12 }
	proximityConstruct.Triggers.OnProximity = { { Payloads = { { Kind = "Damage", Amount = 1 } } } }
	assert(spec.validate(proximityConstruct), "Constructs should support bounded approach triggers")
	local growingConstruct = spec.createDraft("Construct", "Matter")
	growingConstruct.Construct = {
		Width = 4,
		Height = 6,
		Depth = 2,
		Distance = 12,
		GrowthStartScale = 0.25,
		GrowthEndScale = 1.5,
		GrowthDuration = 3,
	}
	assert(spec.validate(growingConstruct), "Constructs should allow bounded geometry expansion")
	local oversizedConstructGrowth = spec.copy(growingConstruct)
	oversizedConstructGrowth.Construct.Width = 12
	oversizedConstructGrowth.Construct.GrowthEndScale = 2
	assert(not spec.validate(oversizedConstructGrowth), "Construct expansion must respect maximum dimensions")
	local incompleteConstructGrowth = spec.copy(growingConstruct)
	incompleteConstructGrowth.Construct.GrowthDuration = nil
	assert(
		not spec.validate(incompleteConstructGrowth),
		"Construct expansion must configure start, end, and duration together"
	)
	local breakDraft = spec.createDraft("Field", "Matter")
	breakDraft.Triggers.OnCast = { { Payloads = { { Kind = "Shield", Amount = 20, Duration = 5 } } } }
	breakDraft.Triggers.OnBreak = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	assert(spec.validate(breakDraft), "A shield-backed OnBreak trigger should validate")
	local missingBreakSource = spec.copy(breakDraft)
	missingBreakSource.Triggers.OnCast = nil
	assert(not spec.validate(missingBreakSource), "OnBreak without a separate Shield payload should fail")
	local selfSourcedBreak = spec.copy(breakDraft)
	selfSourcedBreak.Triggers.OnCast = nil
	selfSourcedBreak.Triggers.OnBreak[1].Payloads[1] = { Kind = "Shield", Amount = 20, Duration = 5 }
	assert(not spec.validate(selfSourcedBreak), "OnBreak cannot qualify itself as its Shield source")
	local toggledField = spec.createDraft("Field", "Matter")
	toggledField.Lifetime = { Mode = "UntilToggledOff" }
	toggledField.Triggers.OnCast = { { Payloads = { { Kind = "Damage", Amount = 2 } } } }
	assert(spec.validate(toggledField), "Fields should support toggle lifetimes")
	toggledField.Lifetime.EndWhen = {
		Family = "Caster",
		Property = "HealthPercent",
		Operator = "<=",
		Value = 0.25,
	}
	assert(spec.validate(toggledField), "Active Fields should accept caster health end conditions")
	local instantBeam = spec.createDraft("Beam", "Energy")
	instantBeam.Lifetime = {
		Mode = "Instantaneous",
		EndWhen = { Family = "Caster", Property = "IsAlive", Operator = "==", Value = false },
	}
	assert(not spec.validate(instantBeam), "Instantaneous spells should reject lifetime end conditions")
	local timedProjectile = spec.normalize(spells.Fireball)
	timedProjectile.Lifetime = { Mode = "UntilToggledOff" }
	assert(not spec.validate(timedProjectile), "Projectiles should not support toggle lifetimes")
	local objectManipulation = spec.createDraft("Manipulation", "Matter")
	assert(objectManipulation, "Manipulation draft should be available to Matter")
	objectManipulation.Targeting = "ObjectTarget"
	objectManipulation.Material = { Material = "Earth", SearchRadius = 12 }
	local manipulationPayload = spec.copy(schema.Payloads.Manipulation.Defaults)
	manipulationPayload.Kind = "Manipulation"
	objectManipulation.Triggers.OnCast = { { Payloads = { manipulationPayload } } }
	local manipulationValid, manipulationReason = spec.validate(objectManipulation)
	assert(manipulationValid, "Tagged object manipulation should validate: " .. tostring(manipulationReason))
	objectManipulation.Material.Amount = 1
	assert(not spec.validate(objectManipulation), "Manipulation object target must not consume source material")
	local count = 0
	for id, source in pairs(spells) do
		local d = spec.normalize(source)
		-- Default Lab range caps do not change trusted source mechanics.
		local ok, reason = spec.validate(d)
		assert(ok, id .. ": " .. tostring(reason))
		count = count + 1
		assert(source.Version ~= 3, "Source mutated")
	end
	local base = spec.normalize(spells.Fireball)
	base.Projectile.MaxDistance = 100
	base.TargetRules.Relationship = "Hostile"
	assert(spec.validate(base), "Hostile target relationship should validate")
	local invalidRelationship = spec.copy(base)
	invalidRelationship.TargetRules.Relationship = "EveryoneExceptMe"
	assert(not spec.validate(invalidRelationship), "Unknown target relationship should fail validation")
	local function reject(edit)
		local d = spec.copy(base)
		edit(d)
		local ok, result = pcall(spec.validate, d)
		assert(ok, "Validator threw: " .. tostring(result))
		assert(not result, "Malformed spell accepted")
	end
	reject(function(d)
		d.Projectile.Speed = 0 / 0
	end)
	reject(function(d)
		d.Projectile.Radius = math.huge
	end)
	reject(function(d)
		d.Projectile.Radius = 21
	end)
	reject(function(d)
		d.Visual.ProjectileScale = 4.1
	end)
	reject(function(d)
		d.Form = "Aura"
	end)
	reject(function(d)
		d.Source.Principle = "Time"
		d.Source.Expression = ""
	end)
	reject(function(d)
		d.Development = true
	end)
	reject(function(d)
		d.Triggers.OnImpact[1].Payloads[1].WalkSpeedBonus = 10
	end)
	reject(function(d)
		d.Triggers.OnImpact[1].Behavior = "Homing"
	end)
	reject(function(d)
		d.Conditions = { "EnemyOnly" }
	end)
	local conditioned = spec.copy(base)
	conditioned.Conditions = {
		Operator = "ALL",
		Conditions = {
			{ Family = "Caster", Property = "IsAlive", Operator = "Is", Value = true },
			{
				Operator = "ANY",
				Conditions = {
					{ Family = "Relationship", Property = "IsHostile", Operator = "==", Value = true },
					{ Family = "Target", Property = "HealthPercent", Operator = "<", Value = 0.5 },
				},
			},
		},
	}
	assert(spec.validate(conditioned), "Valid nested ALL/ANY condition tree rejected")
	local badCondition = spec.copy(conditioned)
	badCondition.Conditions.Conditions[1].Property = "Parent.Parent.Script"
	assert(not spec.validate(badCondition), "Arbitrary condition property path was accepted")
	badCondition = spec.copy(conditioned)
	badCondition.Conditions.Conditions[1].Operator = "RunCode"
	assert(not spec.validate(badCondition), "Unknown condition operator was accepted")
	badCondition = spec.copy(conditioned)
	badCondition.Conditions = { Operator = "NOT", Conditions = {} }
	assert(not spec.validate(badCondition), "Empty NOT group was accepted")
	badCondition = spec.copy(conditioned)
	badCondition.Conditions.Conditions[1].Value = 2
	assert(not spec.validate(badCondition), "Out-of-range condition value was accepted")
	local eventDraft = spec.createDraft("Projectile", "Energy")
	eventDraft.Triggers.OnDamageDealt = {
		{ Payloads = { { Kind = "Damage", Amount = 3 } } },
	}
	assert(spec.validate(eventDraft), "Damage reaction trigger was rejected")
	assert(table.find(schema.eventsForEffects("Projectile"), "OnDamageDealt"), "Lab hides OnDamageDealt")
	-- Ratio heals: lifesteal on the caster; PercentDamageDealt only on OnDamageDealt.
	eventDraft.Triggers.OnDamageDealt = {
		{ TargetFrom = "Caster", Payloads = { { Kind = "Heal", Amount = 50, Mode = "PercentDamageDealt" } } },
	}
	assert(spec.validate(eventDraft), "Lifesteal heal was rejected")
	eventDraft.Triggers.OnDamageDealt[1].TargetFrom = "Attacker"
	assert(not spec.validate(eventDraft), "Attacker is not an OnDamageDealt target")
	eventDraft.Triggers.OnDamageDealt = nil
	eventDraft.Triggers.OnImpact = {
		{ Payloads = { { Kind = "Heal", Amount = 50, Mode = "PercentDamageDealt" } } },
	}
	assert(not spec.validate(eventDraft), "PercentDamageDealt accepted outside OnDamageDealt")
	eventDraft.Triggers.OnImpact[1].Payloads = {
		{ Kind = "Heal", Amount = 20, Mode = "PercentMaxHealth", Overflow = "Shield" },
		{ Kind = "Shield", Amount = 10, Duration = 3, Mode = "PercentMaxHealth" },
	}
	assert(spec.validate(eventDraft), "PercentMaxHealth heal/shield with overflow was rejected")
	eventDraft.Triggers.OnImpact[1].Payloads = { { Kind = "Heal", Amount = 20, Mode = "Half" } }
	assert(not spec.validate(eventDraft), "Unknown heal mode was accepted")
	eventDraft.Triggers.OnImpact[1].Payloads = { { Kind = "Heal", Amount = 20, Overflow = "Mana" } }
	assert(not spec.validate(eventDraft), "Unknown heal overflow was accepted")
	eventDraft.Triggers.OnImpact[1].Payloads = { { Kind = "Shield", Amount = 10, Duration = 3, Overflow = "Shield" } }
	assert(not spec.validate(eventDraft), "Overflow accepted on Shield")
	eventDraft = spec.createDraft("Projectile", "Energy")
	eventDraft = spec.createDraft("Aura", "Energy")
	eventDraft.Triggers.OnDamageTaken = {
		{ Payloads = { { Kind = "Shield", Amount = 10, Duration = 3 } } },
	}
	assert(spec.validate(eventDraft), "Active self-protection trigger was rejected")
	eventDraft.Triggers = {
		OnCasterDeath = {
			{ Behavior = "Explode", Radius = 5, Payloads = { { Kind = "Damage", Amount = 8 } } },
		},
	}
	assert(spec.validate(eventDraft), "Active caster-death behavior was rejected")
	assert(table.find(schema.eventsForEffects("Aura"), "OnDamageTaken"), "Lab hides OnDamageTaken")
	eventDraft = spec.createDraft("Construct", "Matter")
	eventDraft.Triggers.OnDamageDealt = {
		{ Payloads = { { Kind = "Damage", Amount = 3 } } },
	}
	assert(not spec.validate(eventDraft), "Unsupported lifecycle trigger was accepted")
	do
		-- Rush Form: Dash sweeps (OnImpact), Blink does not; Instant casts on the aim only.
		local rush = spec.createDraft("Rush", "Body")
		assert(rush and rush.Rush.Mode == "Dash" and rush.Targeting == "AimDirection", "Rush draft defaults")
		rush.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 10 } } } }
		rush.Triggers.OnExpire = { { Payloads = { { Kind = "Damage", Amount = 5 } } } }
		local rushOk, rushReason = spec.validate(rush)
		assert(rushOk, "Dash with impact and arrival effects was rejected: " .. tostring(rushReason))
		local function rushVariant(mutate)
			local copy = spec.copy(rush)
			mutate(copy)
			return spec.validate(copy)
		end
		assert(not rushVariant(function(d)
			d.Rush.Mode = "Blink"
		end), "Blink accepted OnImpact effects")
		assert(
			rushVariant(function(d)
				d.Rush.Mode = "Blink"
				d.Triggers.OnImpact = nil
			end),
			"Blink with arrival effects was rejected"
		)
		assert(not rushVariant(function(d)
			d.Rush.Mode = "Teleport"
		end), "Unknown Rush mode accepted")
		assert(not rushVariant(function(d)
			d.Rush.Distance = limits.MaxRushDistance + 1
		end), "Rush distance limit")
		assert(not rushVariant(function(d)
			d.Rush.Speed = limits.MaxRushSpeed + 1
		end), "Rush speed limit")
		assert(not rushVariant(function(d)
			d.Rush.Radius = limits.MaxRushRadius + 1
		end), "Rush radius limit")
		assert(not rushVariant(function(d)
			d.Rush.StopOnHit = "yes"
		end), "StopOnHit must be a boolean")
		assert(
			rushVariant(function(d)
				d.Rush.StopOnHit = true
			end),
			"StopOnHit was rejected"
		)
		assert(not rushVariant(function(d)
			d.Casting.Mode = "Channeled"
		end), "Rush accepted a non-Instant cast")
		assert(not rushVariant(function(d)
			d.Targeting = "EntityTarget"
		end), "Rush accepted EntityTarget")
		assert(not rushVariant(function(d)
			d.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 1 } } } }
		end), "Rush accepted OnTick")
		-- Recast (OnRecast + Casting.MaxRecasts) on Forms that leave an active effect.
		local recast = spec.createDraft("Field", "Energy")
		recast.Casting.MaxRecasts = 2
		recast.Triggers.OnRecast = { { Payloads = { { Kind = "Damage", Amount = 5 } } } }
		local recastOk, recastReason = spec.validate(recast)
		assert(recastOk, "Field recast was rejected: " .. tostring(recastReason))
		assert(table.find(schema.eventsForEffects("Field"), "OnRecast"), "Lab hides OnRecast")
		assert(not table.find(schema.eventsForEffects("Wave"), "OnRecast"), "Wave leaves nothing to recast")
		for _, formName in schema.RecastForms do
			assert(schema.Forms[formName].Events.OnRecast, formName .. " lacks OnRecast")
		end
		local badRecast = spec.copy(recast)
		badRecast.Casting.MaxRecasts = 1.5
		assert(not spec.validate(badRecast), "fractional MaxRecasts accepted")
		badRecast = spec.copy(recast)
		badRecast.Casting.MaxRecasts = 0
		assert(not spec.validate(badRecast), "MaxRecasts 0 accepted")
		badRecast = spec.copy(recast)
		badRecast.Lifetime = { Mode = "UntilToggledOff" }
		badRecast.Casting.Mode = "Toggle"
		assert(not spec.validate(badRecast), "toggled spell accepted OnRecast")
		assert(
			rushVariant(function(d)
				d.Triggers.OnRecast = { { Payloads = { { Kind = "Shield", Amount = 10, Duration = 2 } } } }
			end),
			"Rush recast was rejected"
		)
		do
			-- Tether Form: links, length, line of sight, pulses on either end.
			local tether = spec.createDraft("Tether", "Soul")
			assert(tether and tether.Tether.Anchors == "CasterToTarget" and tether.Targeting == "EntityTarget")
			tether.Triggers.OnTick = {
				{ Anchor = "B", Payloads = { { Kind = "Damage", Amount = 4 } } },
				{ Anchor = "A", Payloads = { { Kind = "Heal", Amount = 4 } } },
			}
			local tetherOk, tetherReason = spec.validate(tether)
			assert(tetherOk, "drain tether was rejected: " .. tostring(tetherReason))
			local function tetherVariant(mutate)
				local copy = spec.copy(tether)
				mutate(copy)
				return spec.validate(copy)
			end
			assert(
				tetherVariant(function(d)
					d.Tether.Anchors = "TargetToTarget"
					d.Triggers.OnBreak = { { Payloads = { { Kind = "Stun", Duration = 1 } } } }
				end),
				"chain with a snap stun was rejected"
			)
			assert(
				tetherVariant(function(d)
					d.Tether.ShareDamage = 50
				end),
				"soul link was rejected"
			)
			assert(not tetherVariant(function(d)
				d.Tether.ShareDamage = 95
			end), "shared damage is at most 90%")
			assert(not tetherVariant(function(d)
				d.Tether.MaxLength = limits.MaxTetherLength + 1
			end), "length limit")
			assert(not tetherVariant(function(d)
				d.Tether.MaxLength = limits.MinTetherLength - 1
			end), "minimum length")
			assert(not tetherVariant(function(d)
				d.Tether.Anchors = "CasterToCaster"
			end), "unknown links")
			assert(not tetherVariant(function(d)
				d.Triggers.OnTick[1].Anchor = "C"
			end), "unknown end")
			assert(not tetherVariant(function(d)
				d.Targeting = "AimDirection"
			end), "a Tether is aimed at a character")
			assert(not tetherVariant(function(d)
				d.Lifetime = { Mode = "UntilToggledOff" }
			end), "a Tether lasts a set duration")
			assert(not tetherVariant(function(d)
				d.Casting.Mode = "Channeled"
			end), "a Tether is cast instantly")
			assert(table.find(schema.eventsForEffects("Tether"), "OnBreak"), "Lab hides the snap")
			assert(
				schema.supportsPayload("Stun", "Tether", "OnBreak")
					and schema.supportsPayload("Damage", "Tether", "OnTick")
			)
			assert(not schema.supportsPrincipleForm("Matter", "Tether"), "Matter has no Tether")
			local plain = spec.createDraft("Projectile", "Energy")
			plain.Triggers.OnImpact = { { Anchor = "A", Payloads = { { Kind = "Damage", Amount = 3 } } } }
			assert(not spec.validate(plain), "Anchor only on Tether steps")
		end
		assert(not schema.supportsPrincipleForm("Matter", "Rush"), "Matter has no Rush")
		do
			-- Interception (OnBeforeDamageTaken).
			local function hitRule(property, operator, value)
				return {
					Operator = "ALL",
					Conditions = { { Family = "Hit", Property = property, Operator = operator, Value = value } },
				}
			end
			local parry = spec.createDraft("SelfEnhancement", "Body")
			parry.Element = "Fire"
			parry.Interception = { Charges = 1, EndWhenSpent = true }
			parry.Triggers.OnBeforeDamageTaken = {
				{ Intercept = { Action = "Negate" }, Payloads = {} },
				{
					TargetFrom = "Attacker",
					Payloads = { { Kind = "ElementalMark", Stacks = 1, Duration = 5 } },
				},
			}
			local parryOk, parryReason = spec.validate(parry)
			assert(parryOk, "parry was rejected: " .. tostring(parryReason))
			assert(
				table.find(schema.eventsForEffects("SelfEnhancement"), "OnBeforeDamageTaken"),
				"Lab hides Before damage taken"
			)
			assert(table.find(schema.eventsForEffects("Aura"), "OnBeforeDamageTaken"))
			assert(
				not table.find(schema.eventsForEffects("Projectile"), "OnBeforeDamageTaken"),
				"projectiles hold nothing"
			)
			local function parryVariant(mutate)
				local copy = spec.copy(parry)
				mutate(copy)
				return spec.validate(copy)
			end
			assert(not parryVariant(function(d)
				d.Interception = nil
			end), "charges are required")
			assert(not parryVariant(function(d)
				d.Interception.Charges = limits.MaxInterceptionCharges + 1
			end), "charge limit")
			assert(not parryVariant(function(d)
				d.Triggers.OnBeforeDamageTaken[1].Intercept = { Action = "Reduce", Percent = 95 }
			end), "reduce is at most 90%")
			assert(
				parryVariant(function(d)
					d.Triggers.OnBeforeDamageTaken[1].Intercept = { Action = "Reduce", Percent = 50 }
				end),
				"reduce 50% was rejected"
			)
			assert(
				parryVariant(function(d)
					d.Triggers.OnBeforeDamageTaken[1].Intercept = { Action = "Redirect", Percent = 50, To = "Owner" }
				end),
				"guardian redirect was rejected"
			)
			assert(not parryVariant(function(d)
				d.Triggers.OnBeforeDamageTaken[1].Intercept = { Action = "Redirect", Percent = 5, To = "Owner" }
			end), "redirect is at least 10%")
			assert(not parryVariant(function(d)
				d.Triggers.OnBeforeDamageTaken[1].Intercept = { Action = "Redirect", Percent = 50, To = "Bystander" }
			end), "redirect target")
			assert(
				parryVariant(function(d)
					d.Triggers.OnBeforeDamageTaken[1].Condition = hitRule("Damage", ">=", 20)
				end),
				"Hit conditions on Before damage taken"
			)
			assert(not parryVariant(function(d)
				d.Triggers.OnBeforeDamageTaken = nil
				d.Interception = nil
				d.Triggers.OnDamageTaken = {
					{
						Condition = hitRule("Damage", ">=", 20),
						Payloads = { { Kind = "Shield", Amount = 5, Duration = 2 } },
					},
				}
			end), "Hit conditions only on Before damage taken")
			assert(not parryVariant(function(d)
				d.Triggers.OnBeforeDamageTaken = nil
				d.Triggers.OnDamageTaken = { { Intercept = { Action = "Negate" }, Payloads = {} } }
			end), "Intercept only on Before damage taken")
			-- Cost: Negate is priced highest.
			local function priced(intercept)
				local copy = spec.copy(parry)
				copy.Triggers.OnBeforeDamageTaken = { { Intercept = intercept, Payloads = {} } }
				return spec.estimate(copy).ManaDemand
			end
			local negateCost = priced({ Action = "Negate" })
			local redirectCost = priced({ Action = "Redirect", Percent = 100, To = "Owner" })
			local reduceCost = priced({ Action = "Reduce", Percent = 90 })
			-- Normalization keeps charges in step with the event.
			local bare = spec.copy(parry)
			bare.Interception = nil
			assert(spec.normalize(bare).Interception.Charges == 1, "charges default to 1")
			bare.Triggers.OnBeforeDamageTaken = nil
			bare.Interception = { Charges = 3 }
			assert(spec.normalize(bare).Interception == nil, "charges go with the event")
			assert(
				negateCost > redirectCost and redirectCost > reduceCost,
				"Negate costs the most: " .. negateCost .. " " .. redirectCost .. " " .. reduceCost
			)
		end
		-- Construct pulses (Construct.Interval + OnTick).
		local totem = spec.createDraft("Construct", "Body")
		totem.Construct.Interval = 2
		totem.Triggers.OnTick = { { Payloads = { { Kind = "Heal", Amount = 5 } } } }
		local totemOk, totemReason = spec.validate(totem)
		assert(totemOk, "Construct pulse was rejected: " .. tostring(totemReason))
		assert(table.find(schema.eventsForEffects("Construct"), "OnTick"), "Lab hides Construct OnTick")
		local badTotem = spec.copy(totem)
		badTotem.Construct.Interval = nil
		assert(not spec.validate(badTotem), "Construct OnTick without an interval")
		badTotem = spec.copy(totem)
		badTotem.Construct.Interval = limits.MaxConstructInterval + 1
		assert(not spec.validate(badTotem), "Construct interval limit")
		assert(schema.supportsPayload("Damage", "Construct", "OnTick"), "Damage on Construct pulses")
		-- Construct health and OnDestroyed.
		local wall = spec.createDraft("Construct", "Matter")
		wall.Construct.Health = 200
		wall.Triggers.OnDestroyed = { { Payloads = { { Kind = "Damage", Amount = 10 } } } }
		local wallOk, wallReason = spec.validate(wall)
		assert(wallOk, "breakable wall was rejected: " .. tostring(wallReason))
		local badWall = spec.copy(wall)
		badWall.Construct.Health = limits.MaxConstructHealth + 1
		assert(not spec.validate(badWall), "Construct health limit")
		badWall = spec.copy(wall)
		badWall.Construct.Health = nil
		assert(not spec.validate(badWall), "OnDestroyed without health")
		assert(table.find(schema.eventsForEffects("Construct"), "OnDestroyed"), "Lab hides OnDestroyed")
		-- Field traps.
		local trap = spec.createDraft("Field", "Energy")
		assert(trap.Field.ArmDelay == 0 and trap.Field.Hidden == false and trap.Field.ConsumeOnTrigger == false)
		trap.Field.ArmDelay = 2
		trap.Field.Hidden = true
		trap.Field.ConsumeOnTrigger = true
		trap.Triggers.OnEnter = { { Payloads = { { Kind = "Damage", Amount = 30 } } } }
		local trapOk, trapReason = spec.validate(trap)
		assert(trapOk, "hidden trap was rejected: " .. tostring(trapReason))
		local function trapVariant(mutate)
			local copy = spec.copy(trap)
			mutate(copy)
			return spec.validate(copy)
		end
		assert(not trapVariant(function(d)
			d.Field.ArmDelay = limits.MaxTrapArmDelay + 1
		end), "arm delay limit")
		assert(not trapVariant(function(d)
			d.Field.Hidden = "yes"
		end), "Hidden must be a boolean")
		assert(not trapVariant(function(d)
			d.Field.GrowthStartScale, d.Field.GrowthEndScale, d.Field.GrowthDuration = 0.5, 1, 2
			d.Casting.Mode = "Channeled"
		end), "a hidden Field cannot grow")
		assert(not trapVariant(function(d)
			d.Lifetime = { Mode = "UntilDestroyed" }
		end), "a hidden Field needs a duration")
		assert(schema.supportsPrincipleForm("Space", "Rush") and schema.supportsPrincipleForm("Energy", "Rush"))
		assert(
			schema.supportsPayload("Damage", "Rush", "OnImpact") and schema.supportsPayload("Stun", "Rush", "OnExpire")
		)
	end
	reject(function(d)
		d.Source = nil
	end)
	reject(function(d)
		d.Casting = {}
	end)
	reject(function(d)
		d.Triggers = d
	end)
	local body = spec.normalize(spells.BodyReinforcement)
	body.Lifetime.Mode = "Instantaneous"
	assert(not spec.validate(body))
	body = spec.normalize(spells.BodyReinforcement)
	table.insert(body.Triggers.OnCast[1].Payloads, spec.copy(body.Triggers.OnCast[1].Payloads[1]))
	assert(not spec.validate(body))
	local stronger = spec.copy(base)
	stronger.Projectile.Radius = 8
	stronger.Triggers.OnImpact[1].Payloads[1].Amount = 50
	assert(spec.validate(stronger))
	assert(spec.estimate(stronger).ManaDemand > spec.estimate(base).ManaDemand)
	local largerAppearance = spec.copy(base)
	largerAppearance.Visual.ProjectileScale = 3.5
	assert(spec.validate(largerAppearance))
	assert(
		spec.estimate(largerAppearance).ManaDemand == spec.estimate(base).ManaDemand,
		"visual-only projectile scale must not increase spell cost"
	)
	table.insert(stronger.Triggers.OnImpact[1].Payloads, { Kind = "Force", Magnitude = 30, Upward = 3 })
	assert(spec.validate(stronger))
	for _, bad in ipairs({ false, 1, "bad", {}, { Source = false } }) do
		local ok, result = pcall(spec.validate, bad)
		assert(ok and not result)
	end
	print(
		"Magic Lab: "
			.. count
			.. " registered definitions, normalization, unsupported combinations, safety bounds, multi-payloads and estimates passed"
	)
end

-- Blank drafts have no preset content; effects are independent author choices.
do
	local blank = spec.createDraft("Projectile", "Energy")
	assert(blank and blank.Name == "Untitled Spell" and next(blank.Triggers) == nil)
	local blankOk, blankReason = spec.validate(blank)
	assert(not blankOk and blankReason == "Specify 1–8 payloads across triggers")
	local aura = spec.createDraft("Aura", "Energy")
	aura.Triggers.OnTick =
		{ { Payloads = { { Kind = "Damage", Amount = 20 }, { Kind = "Force", Magnitude = 10, Upward = 0 } } } }
	assert(spec.validate(aura))
	aura.Aura.Interval = 0
	assert(not spec.validate(aura))
	local wall = spec.createDraft("Construct", "Matter")
	assert(wall.Material == nil and wall.Targeting == "AimDirection")
	wall.Lifetime = { Mode = "UntilToggledOff" }
	assert(spec.validate(wall), "Construct geometry should support toggle lifetimes")
	wall.Lifetime = { Mode = "UntilDestroyed" }
	assert(spec.validate(wall), "Construct geometry should support destruction-bound lifetimes")
	wall.Targeting = "ObjectTarget"
	wall.Lifetime = { Mode = "UntilTargetLost" }
	assert(spec.validate(wall), "Object-attached Constructs should support target-bound lifetimes")
	wall.Targeting = "AimDirection"
	assert(not spec.validate(wall), "A free-standing Construct cannot use UntilTargetLost")
	wall.Construct.Width = 21
	assert(not spec.validate(wall))
	wall = spec.createDraft("Construct", "Matter")
	wall.Construct.Distance = 100
	assert(not spec.validate(wall))
	wall = spec.createDraft("Construct", "Matter")
	wall.Material = { Material = "Earth", Amount = 1, SearchRadius = 12 }
	assert(not spec.validate(wall))
	wall = spec.createDraft("Construct", "Matter")
	wall.Triggers.OnCast = { { Payloads = { { Kind = "Damage", Amount = 10 } } } }
	assert(not spec.validate(wall))
	wall = spec.createDraft("Construct", "Matter")
	wall.Targeting = "EntityTarget"
	wall.TargetPolicy = "AimOrLockOn"
	assert(spec.validate(wall), "Constructs should support attaching to a validated character")
	wall.TargetPolicy = "MaintainTarget"
	assert(not spec.validate(wall), "Constructs cannot maintain projectile homing targets")
	wall = spec.createDraft("Construct", "Matter")
	wall.Targeting = "ObjectTarget"
	assert(spec.validate(wall), "Constructs should support server-validated world-surface targets")
	wall.Material = { Material = "Earth", SearchRadius = 12 }
	assert(not spec.validate(wall), "Construct object targeting must not require a material source")
	local surfaceField = spec.createDraft("Field", "Energy")
	surfaceField.Targeting = "ObjectTarget"
	surfaceField.Triggers.OnTick = { { Payloads = { { Kind = "Heal", Amount = 6 } } } }
	assert(spec.validate(surfaceField), "Fields should support anchoring to a server-validated world surface")
	surfaceField.Material = { Material = "Earth", Amount = 1, SearchRadius = 12 }
	assert(not spec.validate(surfaceField), "Field surface targeting must not require a material source")
	local surfaceAura = spec.createDraft("Aura", "Matter")
	surfaceAura.Targeting = "ObjectTarget"
	surfaceAura.Triggers.OnTick = { { Payloads = { { Kind = "Shield", Amount = 5, Duration = 2 } } } }
	assert(spec.validate(surfaceAura), "Auras should support following a server-validated movable surface")
	local supportDraft = spec.createDraft("SelfEnhancement", "Body")
	supportDraft.Triggers.OnCast = {
		{ Payloads = { { Kind = "Heal", Amount = 20 }, { Kind = "Shield", Amount = 25, Duration = 8 } } },
	}
	assert(spec.validate(supportDraft))
	local targetedProjectile = spec.createDraft("Projectile", "Energy")
	targetedProjectile.Targeting = "EntityTarget"
	targetedProjectile.TargetPolicy = "LockOn"
	targetedProjectile.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 12 } } } }
	assert(spec.validate(targetedProjectile), "Projectile lock-on policy should validate")
	targetedProjectile.TargetPolicy = "MaintainTarget"
	assert(not spec.validate(targetedProjectile), "Maintained target must require Homing")

	local objectPhysicsEvents = { Projectile = "OnImpact", Beam = "OnCast", Wave = "OnCast" }
	for formName, eventName in objectPhysicsEvents do
		local objectPhysics = spec.createDraft(formName, "Energy")
		objectPhysics.Targeting = "ObjectTarget"
		objectPhysics.Triggers[eventName] = {
			{ Payloads = { { Kind = "Force", Magnitude = 12, Upward = 0 } } },
		}
		assert(spec.validate(objectPhysics), formName .. " should support Force on a validated movable object")
		local objectControl = spec.copy(objectPhysics)
		objectControl.Triggers[eventName] = {
			{
				Payloads = {
					{ Kind = "Control", Mode = "Pull", Acceleration = 24, Duration = 2, MaxSpeed = 32, MaxMass = 500 },
				},
			},
		}
		assert(
			spec.validate(objectControl),
			formName .. " should support Physical control on a validated movable object"
		)
		objectControl.Triggers[eventName][1].Payloads[1].Kind = "Heal"
		objectControl.Triggers[eventName][1].Payloads[1].Amount = 10
		assert(not spec.validate(objectControl), formName .. " object targeting must reject unrelated payloads")
		local misplacedForce = spec.copy(objectPhysics)
		misplacedForce.Triggers = {
			OnExpire = { { Payloads = { { Kind = "Force", Magnitude = 12, Upward = 0 } } } },
		}
		assert(
			not spec.validate(misplacedForce),
			formName .. " object targeting needs a Form event that actually resolves its object"
		)
	end

	local objectManipulationEvents = { Projectile = "OnImpact", Beam = "OnCast", Wave = "OnCast" }
	for formName, eventName in objectManipulationEvents do
		local objectManipulation = spec.createDraft(formName, "Matter")
		objectManipulation.Targeting = "ObjectTarget"
		objectManipulation.Material = { Material = "Earth", SearchRadius = 12 }
		objectManipulation.Triggers[eventName] = {
			{ Payloads = { { Kind = "Manipulation", Operation = "Raise", Distance = 3 } } },
		}
		assert(
			spec.validate(objectManipulation),
			formName .. " should support authorized material Manipulation on its resolving event"
		)
		local missingMaterial = spec.copy(objectManipulation)
		missingMaterial.Material = nil
		assert(
			not spec.validate(missingMaterial),
			formName .. " material Manipulation requires a matching material profile"
		)
		local wrongExpression = spec.copy(objectManipulation)
		wrongExpression.Source.Expression = "Water"
		assert(
			not spec.validate(wrongExpression),
			formName .. " should reject material Manipulation with an incompatible expression"
		)
	end

	targetedProjectile.Projectile.Behaviors = { { Kind = "Homing", SearchRadius = 24, TurnRate = 180 } }
	assert(spec.validate(targetedProjectile), "Maintained target with Homing should validate")
	local targetedBeam = spec.createDraft("Beam", "Energy")
	targetedBeam.Targeting = "EntityTarget"
	targetedBeam.TargetPolicy = "AimOrLockOn"
	targetedBeam.Triggers.OnCast = { { Payloads = { { Kind = "Damage", Amount = 12 } } } }
	assert(spec.validate(targetedBeam), "Beam aim-or-lock-on policy should validate")
	local targetedField = spec.createDraft("Field", "Energy")
	targetedField.Targeting = "EntityTarget"
	targetedField.TargetPolicy = "Aim"
	targetedField.TargetRules.Relationship = "Ally"
	targetedField.Triggers.OnTick = { { Payloads = { { Kind = "Heal", Amount = 4 } } } }
	assert(spec.validate(targetedField), "A Field should support a server-validated entity-centered healing area")
	targetedField.TargetRules.Relationship = "Hostile"
	targetedField.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 4 } } } }
	assert(spec.validate(targetedField), "An entity-centered Field should also support hostile effects")
	targetedField.Targeting = "WorldPoint"
	targetedField.TargetPolicy = nil
	assert(spec.validate(targetedField), "Existing world-point Fields should remain valid")
	targetedField.Targeting = "Area"
	assert(spec.validate(targetedField), "Fields should support selecting an area center without an entity target")
	local targetedAura = spec.createDraft("Aura", "Energy")
	targetedAura.Targeting = "EntityTarget"
	targetedAura.TargetPolicy = "AimOrLockOn"
	targetedAura.TargetRules.Relationship = "Ally"
	targetedAura.Lifetime = { Mode = "UntilTargetLost" }
	targetedAura.Triggers.OnTick = { { Payloads = { { Kind = "Heal", Amount = 4 } } } }
	assert(spec.validate(targetedAura), "Auras should support an ally-centered follow target")
	targetedAura.Targeting = "Self"
	targetedAura.TargetPolicy = nil
	targetedAura.TargetRules.Relationship = "Any"
	assert(not spec.validate(targetedAura), "A self-following Aura cannot use UntilTargetLost")
	targetedAura.Lifetime = { Mode = "FixedDuration", Duration = 8 }
	assert(spec.validate(targetedAura), "Existing self-following Auras should remain valid")
	local targetedWave = spec.createDraft("Wave", "Energy")
	targetedWave.Targeting = "EntityTarget"
	targetedWave.TargetPolicy = "LockOn"
	targetedWave.Triggers.OnCast = { { Payloads = { { Kind = "Damage", Amount = 6 } } } }
	assert(spec.validate(targetedWave), "Waves should support server-acquired entity targeting")
	targetedWave.Targeting = "Self"
	targetedWave.TargetPolicy = nil
	assert(spec.validate(targetedWave), "Existing self-directed Waves should remain valid")
	local channelBeam = spec.createDraft("Beam", "Energy")
	channelBeam.Casting.Mode = "Channeled"
	channelBeam.Casting.ManaUpkeepPerSecond = 45
	channelBeam.Lifetime = { Mode = "FixedDuration", Duration = 5 }
	channelBeam.Beam.Range = 40
	channelBeam.Beam.GrowthStartScale = 0.5
	channelBeam.Beam.GrowthEndScale = 1.5
	channelBeam.Beam.GrowthDuration = 1
	channelBeam.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 4 } } } }
	assert(spec.validate(channelBeam), "Channeled Beam should allow server-pulsed effects with bounded growth")
	local incompleteBeamGrowth = spec.normalize(channelBeam)
	incompleteBeamGrowth.Beam.GrowthEndScale = nil
	assert(not spec.validate(incompleteBeamGrowth), "Beam expansion requires all start/end/time values")
	local wideBeamGrowth = spec.normalize(channelBeam)
	wideBeamGrowth.Beam.Width = 8
	assert(not spec.validate(wideBeamGrowth), "Expanded Beam width must stay within the configured cap")
	local instantBeamGrowth = spec.createDraft("Beam", "Energy")
	instantBeamGrowth.Beam.GrowthStartScale = 0.5
	instantBeamGrowth.Beam.GrowthEndScale = 1.5
	instantBeamGrowth.Beam.GrowthDuration = 1
	assert(not spec.validate(instantBeamGrowth), "Instant Beams cannot author temporal geometry growth")
	local channelProjectile = spec.createDraft("Projectile", "Energy")
	channelProjectile.Casting.Mode = "Channeled"
	channelProjectile.Casting.ManaUpkeepPerSecond = 8
	channelProjectile.Lifetime = { Mode = "FixedDuration", Duration = 4 }
	channelProjectile.Projectile.ChannelInterval = 0.35
	channelProjectile.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 4 } } } }
	assert(spec.validate(channelProjectile), "Channeled Projectile should validate bounded repeat fire")
	channelProjectile.Projectile.ChannelInterval = 0.01
	assert(not spec.validate(channelProjectile), "Channeled Projectile should enforce minimum shot interval")
	local phasedProjectile = spec.createDraft("Projectile", "Energy")
	phasedProjectile.Lifetime.Duration = 3
	phasedProjectile.Projectile.MotionPhases = {
		{ Duration = 0.5, SpeedMultiplier = 1, Acceleration = 0, Gravity = 0 },
		{ Duration = 1.5, SpeedMultiplier = 1.8, Acceleration = 12, Gravity = 0 },
	}
	phasedProjectile.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 4 } } } }
	assert(spec.validate(phasedProjectile), "Timed projectile motion phases should validate")
	phasedProjectile.Projectile.MotionPhases[2].Duration = 3
	assert(not spec.validate(phasedProjectile), "Motion phases cannot outlast the projectile lifetime")
	local attachedProjectile = spec.createDraft("Projectile", "Energy")
	attachedProjectile.Projectile.MotionPhases = { { Mode = "Attached", Duration = 1 } }
	attachedProjectile.Projectile.Behaviors = {
		{ Kind = "Linger", Duration = 2, Radius = 3, Interval = 0.5 },
	}
	attachedProjectile.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 4 } } } }
	assert(spec.validate(attachedProjectile), "Attached motion should anchor a Linger effect after impact")
	attachedProjectile.Projectile.Behaviors = {}
	assert(not spec.validate(attachedProjectile), "Attached motion needs Linger to provide an active lifecycle")
	local channelWave = spec.createDraft("Wave", "Energy")
	assert(channelWave.Geometry == "Cone", "Existing Wave drafts should remain cone-shaped by default")
	local sphereWave = spec.copy(channelWave)
	sphereWave.Geometry = "Sphere"
	sphereWave.Triggers.OnCast = { { Payloads = { { Kind = "Damage", Amount = 4 } } } }
	assert(spec.validate(sphereWave), "Wave should support an omnidirectional spherical hit shape")
	sphereWave.Geometry = "Ring"
	assert(not spec.validate(sphereWave), "Wave should reject geometries outside its authored shape choices")
	channelWave.Casting.Mode = "Channeled"
	assert(
		table.find(schema.eventsForEffects("Wave", "Channeled"), "OnDamageTaken"),
		"Channeled Waves should expose active caster damage events"
	)
	assert(
		table.find(schema.eventsForEffects("Wave", "Channeled"), "OnCasterDeath"),
		"Channeled Waves should expose caster death events"
	)
	assert(
		not table.find(schema.eventsForEffects("Wave", "Instant"), "OnCasterDeath"),
		"Instant Waves should not expose an active caster death event"
	)
	assert(
		table.find(schema.eventsForEffects("Beam", "Channeled"), "OnDamageTaken"),
		"Channeled Beams should expose active caster damage events"
	)
	assert(
		table.find(schema.eventsForEffects("Construct", "Instant"), "OnCasterDeath"),
		"Constructs should expose caster death while their geometry is active"
	)
	channelWave.Casting.ManaUpkeepPerSecond = 5
	channelWave.Lifetime = { Mode = "FixedDuration", Duration = 3 }
	channelWave.Wave.GrowthStartScale = 0.5
	channelWave.Wave.GrowthEndScale = 1.5
	channelWave.Wave.GrowthDuration = 1.2
	channelWave.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 3 } } } }
	assert(spec.validate(channelWave), "Channeled Wave should allow repeated server cone checks with bounded expansion")
	local incompleteWaveGrowth = spec.normalize(channelWave)
	incompleteWaveGrowth.Wave.GrowthDuration = nil
	assert(not spec.validate(incompleteWaveGrowth), "Wave expansion requires all start/end/time values")
	local waveBeyondRules = spec.normalize(channelWave)
	waveBeyondRules.TargetRules.Range = waveBeyondRules.Wave.Range
	assert(not spec.validate(waveBeyondRules), "Expanded Wave reach cannot exceed its target-rule reach")
	channelWave.Lifetime = { Mode = "Instantaneous" }
	assert(not spec.validate(channelWave), "Channeled Wave expansion needs a fixed maximum duration")
	for _, form in ipairs({ "Field", "Aura" }) do
		local channelArea = spec.createDraft(form, "Energy")
		channelArea.Casting.Mode = "Channeled"
		channelArea.Casting.ManaUpkeepPerSecond = 3
		channelArea.Lifetime = { Mode = "FixedDuration", Duration = 4 }
		channelArea.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 2 } } } }
		assert(spec.validate(channelArea), "Channeled " .. form .. " should validate")
		channelArea.Lifetime = { Mode = "UntilToggledOff" }
		assert(not spec.validate(channelArea), "Channeled " .. form .. " needs a fixed maximum duration")
	end
	for _, form in ipairs({ "Field", "Aura" }) do
		local draft = spec.createDraft(form, "Energy")
		draft.Geometry = "Cylinder"
		draft[form] = { Radius = 7, Height = 5, Interval = 0.5, Yaw = 0 }
		if form == "Field" then
			draft[form].DebugHeight = 0.2
		end
		draft.Triggers.OnTick = { { Payloads = { { Kind = "Heal", Amount = 3 } } } }
		assert(spec.validate(draft), form .. " should accept cylindrical area geometry")
		draft.Geometry = "Box"
		draft[form] = { Width = 10, Height = 5, Depth = 8, Interval = 0.5, Yaw = 0 }
		if form == "Field" then
			draft[form].DebugHeight = 0.2
		end
		assert(spec.validate(draft), form .. " should accept box area geometry")
		draft[form].Radius = 3
		assert(not spec.validate(draft), form .. " should reject dimensions unrelated to its selected shape")
		draft[form].Radius = nil
		draft[form].Yaw = 180.1
		assert(not spec.validate(draft), form .. " yaw must stay within the authored angle limit")
		draft.Geometry = "Plane"
		draft[form] = { Width = 12, Height = 8, Thickness = 1, Interval = 0.5, Yaw = -45 }
		if form == "Field" then
			draft[form].DebugHeight = 0.2
		end
		assert(spec.validate(draft), form .. " should accept a thin vertical Plane/Wall hit volume")
		draft[form].Thickness = 4.1
		assert(not spec.validate(draft), form .. " should bound Plane/Wall thickness")
		draft.Geometry = "Cone"
		assert(not spec.validate(draft), form .. " should reject unsupported area shapes")
	end
	local channelEnhancement = spec.createDraft("SelfEnhancement", "Body", "BodyEnhancement")
	channelEnhancement.Casting.Mode = "Channeled"
	channelEnhancement.Casting.ManaUpkeepPerSecond = 3
	channelEnhancement.Lifetime = { Mode = "FixedDuration", Duration = 4 }
	channelEnhancement.Triggers.OnCast = {
		{ Payloads = { { Kind = "Enhancement", SpeedMultiplier = 1.5 } } },
	}
	assert(spec.validate(channelEnhancement), "Channeled Body Self Enhancement should validate")
	channelEnhancement.Lifetime = { Mode = "UntilToggledOff" }
	assert(not spec.validate(channelEnhancement), "Channeled Self Enhancement needs a fixed maximum duration")
	local invalidInterrupt = spec.createDraft("Projectile", "Energy")
	invalidInterrupt.Casting.InterruptOnDamage = "yes"
	assert(not spec.validate(invalidInterrupt), "Damage interruption must be a boolean")
	local excessiveInterrupt = spec.createDraft("Projectile", "Energy")
	excessiveInterrupt.Casting.InterruptMoveDistance = 20.1
	assert(not spec.validate(excessiveInterrupt), "Movement interruption must obey its safety bound")
	local freeHandSpell = spec.createDraft("Projectile", "Energy")
	freeHandSpell.Casting.RequiresFreeHand = true
	freeHandSpell.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 4 } } } }
	assert(spec.validate(freeHandSpell), "A valid spell may explicitly require a free hand")
	freeHandSpell.Casting.RequiresFreeHand = "yes"
	assert(not spec.validate(freeHandSpell), "Free-hand rules must use a validated boolean")
	local lingeringProjectile = spec.createDraft("Projectile", "Energy")
	lingeringProjectile.Projectile.Behaviors = {
		{ Kind = "Linger", Duration = 4, Radius = 6, Interval = 0.5 },
	}
	lingeringProjectile.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	lingeringProjectile.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 2 } } } }
	assert(spec.validate(lingeringProjectile), "Linger projectiles should validate repeated OnTick effects")
	local pulsingProjectile = spec.createDraft("Projectile", "Energy")
	pulsingProjectile.Projectile.Behaviors = {
		{ Kind = "Pulse", Radius = 5, Interval = 0.6 },
	}
	pulsingProjectile.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	pulsingProjectile.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 2 } } } }
	assert(spec.validate(pulsingProjectile), "Traveling Pulse should validate repeated OnTick effects")
	local invalidPulse = spec.copy(pulsingProjectile)
	invalidPulse.Projectile.Behaviors[1].Radius = 21
	assert(not spec.validate(invalidPulse), "Traveling Pulse radius must remain bounded")
	local thresholdProjectile = spec.createDraft("Projectile", "Energy")
	thresholdProjectile.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	thresholdProjectile.Triggers.OnThreshold = {
		{ HealthPercent = 50, Payloads = { { Kind = "Damage", Amount = 3 } } },
	}
	assert(spec.validate(thresholdProjectile), "A configured target-health threshold should validate")
	local duplicateThreshold = spec.copy(thresholdProjectile)
	table.insert(duplicateThreshold.Triggers.OnThreshold, {
		HealthPercent = 50,
		Payloads = { { Kind = "Damage", Amount = 2 } },
	})
	assert(not spec.validate(duplicateThreshold), "Duplicate threshold percentages should be rejected")
	local invalidThreshold = spec.copy(thresholdProjectile)
	invalidThreshold.Triggers.OnThreshold[1].HealthPercent = 50.5
	assert(not spec.validate(invalidThreshold), "Threshold percent must be a bounded whole number")
	local proximityProjectile = spec.createDraft("Projectile", "Energy")
	proximityProjectile.Projectile.Behaviors = {
		{ Kind = "Proximity", Radius = 6, Interval = 0.2, MaxTargets = 4 },
	}
	proximityProjectile.Triggers.OnProximity = { { Payloads = { { Kind = "Damage", Amount = 3 } } } }
	assert(spec.validate(proximityProjectile), "Projectile proximity triggers should validate with the behavior")
	local proximityWithoutBehavior = spec.copy(proximityProjectile)
	proximityWithoutBehavior.Projectile.Behaviors = {}
	assert(not spec.validate(proximityWithoutBehavior), "Projectile OnProximity must require the Proximity behavior")
	local invalidProximity = spec.copy(proximityProjectile)
	invalidProximity.Projectile.Behaviors[1].MaxTargets = 17
	assert(not spec.validate(invalidProximity), "Proximity target count must remain bounded")

	local returningProjectile = spec.createDraft("Projectile", "Energy")
	returningProjectile.Projectile.MaxDistance = 120
	returningProjectile.Projectile.Behaviors = {
		{ Kind = "Return", ReturnAtDistance = 90, CatchRadius = 2, TurnRate = 240 },
	}
	returningProjectile.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 4 } } } }
	assert(spec.validate(returningProjectile), "A bounded returning Projectile should validate")
	local invalidReturn = spec.copy(returningProjectile)
	invalidReturn.Projectile.Behaviors[1].ReturnAtDistance = 121
	assert(not spec.validate(invalidReturn), "Return distance cannot exceed maximum projectile distance")
	invalidReturn = spec.copy(returningProjectile)
	table.insert(invalidReturn.Projectile.Behaviors, { Kind = "Homing", SearchRadius = 24, TurnRate = 180 })
	assert(not spec.validate(invalidReturn), "Return cannot conflict with Homing's independent steering")
	invalidReturn = spec.copy(returningProjectile)
	table.insert(invalidReturn.Projectile.Behaviors, { Kind = "Linger", Duration = 4, Radius = 6, Interval = 0.5 })
	assert(not spec.validate(invalidReturn), "Return cannot be composed with post-impact Linger")
	local projectileTickWithoutLinger = spec.copy(lingeringProjectile)
	projectileTickWithoutLinger.Projectile.Behaviors = {}
	assert(not spec.validate(projectileTickWithoutLinger), "Projectile OnTick must require Pulse or Linger")
	local absorbBehavior = projectileBehaviorSpec.copyDefaults("Absorb")
	assert(
		absorbBehavior and projectileBehaviorSpec.validate(absorbBehavior),
		"Absorb should provide valid bounded defaults"
	)
	absorbBehavior.MaxAbsorbed = 9
	assert(not projectileBehaviorSpec.validate(absorbBehavior), "Absorb count must remain bounded")
	local reflectBehavior = projectileBehaviorSpec.copyDefaults("Reflect")
	assert(
		reflectBehavior and projectileBehaviorSpec.validate(reflectBehavior),
		"Reflect should provide valid bounded defaults"
	)
	reflectBehavior.MaxHopsPerProjectile = 4
	assert(not projectileBehaviorSpec.validate(reflectBehavior), "Reflection loops must remain bounded")
	local propagateBehavior = projectileBehaviorSpec.copyDefaults("Propagate")
	assert(
		propagateBehavior and projectileBehaviorSpec.validate(propagateBehavior),
		"Propagate defaults should validate"
	)
	assert(table.find(projectileBehaviorSpec.Order, "Propagate"), "Propagate should be selectable in the Lab")
	propagateBehavior.MaxTargets = limits.MaxPropagationTargets + 1
	assert(not projectileBehaviorSpec.validate(propagateBehavior), "Propagate targets must remain bounded")
	local propagationCostDraft = spec.createDraft("Projectile", "Energy")
	propagationCostDraft.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	local noPropagationCost = spec.estimate(propagationCostDraft)
	local boundedPropagation = projectileBehaviorSpec.copyDefaults("Propagate")
	boundedPropagation.MaxTargets = 1
	propagationCostDraft.Projectile.Behaviors = { boundedPropagation }
	local lowPropagationCost = spec.estimate(propagationCostDraft)
	boundedPropagation.MaxTargets = limits.MaxPropagationTargets
	local highPropagationCost = spec.estimate(propagationCostDraft)
	assert(lowPropagationCost.ManaDemand > noPropagationCost.ManaDemand, "Propagate should affect spell cost estimates")
	assert(
		highPropagationCost.ManaDemand > lowPropagationCost.ManaDemand
			and highPropagationCost.Complexity > lowPropagationCost.Complexity,
		"Propagate fan-out should increase estimated cost and complexity"
	)
	local humanoidFormCount = 0
	for _, formName in schema.FormOrder do
		local form = schema.Forms[formName]
		if form.TargetTypes and form.TargetTypes.Humanoid then
			-- Constructs start without a default effect timing; their support
			-- effects resolve on approach.
			local effectEvent = form.DefaultEvent or "OnProximity"
			assert(schema.supportsPayload("Heal", formName, effectEvent), formName .. " is missing Healing")
			assert(schema.supportsPayload("Shield", formName, effectEvent), formName .. " is missing Shield")
			local principle = schema.supportsPrincipleForm("Body", formName) and "Body" or "Energy"
			local formDraft = spec.createDraft(formName, principle)
			formDraft.Triggers[effectEvent] = {
				{ Payloads = { { Kind = "Heal", Amount = 20 }, { Kind = "Shield", Amount = 25, Duration = 8 } } },
			}
			if form.CanIncludeCaster then
				formDraft.TargetRules.IncludeCaster = true
			end
			local supportOk, supportReason = spec.validate(formDraft)
			assert(supportOk, formName .. " support payloads failed validation: " .. tostring(supportReason))
			humanoidFormCount = humanoidFormCount + 1
		end
	end
	print(
		"Blank drafts, "
			.. humanoidFormCount
			.. " humanoid-target Forms with Healing+Shield, intervals, dimensions and no material dependency passed"
	)
end

do
	local toggleFormOrder = { "Field", "Aura", "SelfEnhancement", "Construct" }
	for _, formName in ipairs(toggleFormOrder) do
		local principle = formName == "SelfEnhancement" and "Body" or "Energy"
		local toggleDraft = spec.createDraft(formName, principle)
		toggleDraft.Casting.Mode = "Toggle"
		toggleDraft.Lifetime = { Mode = "UntilToggledOff" }
		if formName == "SelfEnhancement" then
			toggleDraft.Triggers.OnCast = { { Payloads = { { Kind = "Enhancement", SpeedMultiplier = 1.1 } } } }
		elseif formName == "Construct" then
			-- Constructs have no pulse timing; their active effects resolve on approach.
			toggleDraft.Triggers.OnProximity = { { Payloads = { { Kind = "Heal", Amount = 1 } } } }
		else
			toggleDraft.Triggers.OnTick = { { Payloads = { { Kind = "Heal", Amount = 1 } } } }
		end
		assert(spec.validate(toggleDraft), formName .. " explicit toggle casting should validate")
		local invalidToggle = spec.copy(toggleDraft)
		invalidToggle.Lifetime = { Mode = "FixedDuration", Duration = 5 }
		assert(not spec.validate(invalidToggle), formName .. " toggle casting must require toggle-off lifetime")
	end
	local projectileToggle = spec.createDraft("Projectile", "Energy")
	projectileToggle.Casting.Mode = "Toggle"
	projectileToggle.Lifetime = { Mode = "UntilToggledOff" }
	assert(not spec.validate(projectileToggle), "Projectile must reject toggle casting")

	for _, chargeMode in ipairs({ "Charged", "HoldAndRelease" }) do
		local chargedSpell = spec.createDraft("Projectile", "Energy")
		chargedSpell.Casting.Mode = chargeMode
		chargedSpell.Casting.MinimumCharge = 0.2
		chargedSpell.Casting.MaximumCharge = 1.2
		chargedSpell.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 10 } } } }
		assert(spec.validate(chargedSpell), chargeMode .. " should validate bounded charge timing")
		local invalidCharge = spec.copy(chargedSpell)
		invalidCharge.Casting.MaximumCharge = 0.1
		assert(not spec.validate(invalidCharge), chargeMode .. " maximum charge must not precede its minimum")
	end

	for _, commandForm in ipairs({ "Projectile", "Beam", "Wave", "Field", "Aura" }) do
		local commandDraft = spec.createDraft(commandForm, "Energy")
		commandDraft.Casting.Mode = "CommandCast"
		local eventName = commandDraft.Form == "Projectile" and "OnImpact"
			or (commandDraft.Form == "Field" or commandDraft.Form == "Aura") and "OnTick"
			or "OnCast"
		commandDraft.Triggers[eventName] = { { Payloads = { { Kind = "Damage", Amount = 10 } } } }
		if commandDraft.Form == "Field" or commandDraft.Form == "Aura" then
			commandDraft.TargetRules.Relationship = "Hostile"
		end
		assert(spec.validate(commandDraft), commandForm .. " should validate CommandCast mode")
	end
	local unsupportedCommandDraft = spec.createDraft("Manipulation", "Matter")
	unsupportedCommandDraft.Casting.Mode = "CommandCast"
	unsupportedCommandDraft.Triggers.OnCast =
		{ { Payloads = { { Kind = "Manipulation", Operation = "Raise", Distance = 3 } } } }
	assert(not spec.validate(unsupportedCommandDraft), "Manipulation should not allow CommandCast mode")

	local sustainedConstruct = spec.createDraft("Construct", "Matter")
	sustainedConstruct.Casting.Mode = "Sustained"
	sustainedConstruct.Casting.ManaUpkeepPerSecond = 20
	sustainedConstruct.Lifetime = { Mode = "FixedDuration", Duration = 5 }
	sustainedConstruct.Triggers.OnProximity = { { Payloads = { { Kind = "Damage", Amount = 2 } } } }
	assert(spec.validate(sustainedConstruct), "A held Construct should validate positive upkeep and fixed lifetime")
	local unsupportedSustained = spec.createDraft("Field", "Energy")
	unsupportedSustained.Casting.Mode = "Sustained"
	unsupportedSustained.Casting.ManaUpkeepPerSecond = 20
	unsupportedSustained.Triggers.OnTick = { { Payloads = { { Kind = "Damage", Amount = 2 } } } }
	assert(not spec.validate(unsupportedSustained), "Field should not use Sustained casting")
	local unboundedSustained = spec.copy(sustainedConstruct)
	unboundedSustained.Lifetime = { Mode = "UntilDestroyed" }
	assert(not spec.validate(unboundedSustained), "Sustained Constructs must keep a fixed maximum duration")

	local dot = spec.normalize(spells.Fireball)
	table.insert(dot.Triggers.OnImpact[1].Payloads, { Kind = "DamageOverTime", Amount = 5, Duration = 4, Interval = 1 })
	assert(spec.validate(dot))
	local before = spec.estimate(dot).ManaDemand
	dot.Triggers.OnImpact[1].Payloads[2].Duration = 8
	assert(spec.validate(dot))
	assert(spec.estimate(dot).ManaDemand > before)
	dot.Triggers.OnImpact[1].Payloads[2].Interval = 0
	assert(not spec.validate(dot))
	dot = spec.normalize(spells.Fireball)
	dot.Element = "Unknown"
	assert(not spec.validate(dot))
	for _, element in ipairs(spec.Elements) do
		dot.Element = element
		assert(spec.validate(dot))
	end
	local clock = assert(loadfile("src/shared/Modules/MagicTickClock.luau"))()
	local nextTick = 1
	for _, now in ipairs({ 1.01, 2.03, 3.02, 4.01 }) do
		local due, nextValue = clock.advance(nextTick, 1, 4, now)
		assert(due)
		nextTick = nextValue
	end
	assert(nextTick == nil)
	local due, nextValue = clock.advance(1, 1, 4, 3.5)
	assert(due and nextValue == 4)
	local late, last = clock.advance(1, 1, 4, 10)
	assert(not late and last == nil)
	print("PASS: elements, DoT schema/cost, stable ticks, skipped catch-up and expiration")

	local styled = spec.normalize(spells.LightningLance)
	local originalCost = spec.estimate(styled).ManaDemand
	for _, profile in ipairs(spec.PresentationProfiles) do
		styled.Visual.Profile = profile
		assert(spec.validate(styled))
		assert(spec.estimate(styled).ManaDemand == originalCost, "Cosmetic profile changed cost")
	end
	styled.Visual.Profile = "ArbitraryClientAnimation"
	assert(not spec.validate(styled))
	print("PASS: presentation profile allowlist and cosmetic-only cost invariance")

	local summonDraft = spec.createDraft("Field", "Energy")
	summonDraft.Triggers.OnCast = {
		{ Payloads = { { Kind = "Summon", Archetype = "Wisp", Count = 3, Duration = 30 } } },
	}
	assert(spec.validate(summonDraft), "Field should support an owner-bound summon payload")
	-- The editor copies Summon Defaults, so new summons start unassigned; a
	-- payload without SpellSlot is also unassigned at runtime (SummonService).
	assert(
		schema.Payloads.Summon.Defaults.SpellSlot == "None"
			and summonDraft.Triggers.OnCast[1].Payloads[1].SpellSlot == nil,
		"new summons should explicitly start without an arbitrary companion spell assignment"
	)
	local assignedSummonSpell = spec.copy(summonDraft)
	assignedSummonSpell.Triggers.OnCast[1].Payloads[1].SpellSlot = "3"
	assert(spec.validate(assignedSummonSpell), "summons should accept a separately equipped companion spell slot")
	local beamSummon = spec.createDraft("Beam", "Energy")
	beamSummon.Triggers.OnImpact = {
		{
			Payloads = {
				{
					Kind = "Summon",
					Archetype = "Wisp",
					Role = "Hunter",
					SpawnAt = "Event",
					Count = 1,
					Duration = 30,
					SpellSlot = "2",
				},
			},
		},
	}
	assert(spec.validate(beamSummon), "Beam impact should summon a spell-assigned group at its endpoint")
	beamSummon.Beam.Pattern = "Cascade"
	assert(
		spec.validate(beamSummon),
		"Beam Cascade should compose with Event-placed Hunter summons assigned to an equipped spell slot"
	)
	local fieryCompanionSpell = spec.createDraft("Beam", "Energy")
	fieryCompanionSpell.Element = "Fire"
	fieryCompanionSpell.Beam.Pattern = "Cascade"
	fieryCompanionSpell.Triggers.OnCast = { { Payloads = { { Kind = "Damage", Amount = 8 } } } }
	local fieryCompanionProfile, fieryCompanionReason = companionPolicy.classify(fieryCompanionSpell)
	assert(
		fieryCompanionProfile and fieryCompanionProfile.Mode == "Hostile",
		"A summon-assigned Fire Beam Cascade should use the ordinary hostile companion spell path: "
			.. tostring(fieryCompanionReason)
	)
	assert(schema.supportsPayload("Damage", "Beam", "OnImpact"), "Beam impacts should support ordinary payloads")
	assert(schema.supportsPayload("Summon", "Beam", "OnImpact"), "Beam impacts should support Summon")
	assert(table.find(schema.eventsForEffects("Beam", "Instant"), "OnImpact"), "Beam impact must be editable")
	local invalidSpawnAt = spec.copy(beamSummon)
	invalidSpawnAt.Triggers.OnImpact[1].Payloads[1].SpawnAt = "Anywhere"
	assert(not spec.validate(invalidSpawnAt), "Summon placement must use a registered option")
	local invalidSummonSpellSlot = spec.copy(summonDraft)
	invalidSummonSpellSlot.Triggers.OnCast[1].Payloads[1].SpellSlot = "None-ish"
	assert(not spec.validate(invalidSummonSpellSlot), "companion spell slot choices must stay explicit and bounded")
	local commandedLifetime = spec.copy(summonDraft)
	commandedLifetime.Triggers.OnCast[1].Payloads[1].LifetimeMode = "UntilCommanded"
	commandedLifetime.Triggers.OnCast[1].Payloads[1].Duration = nil
	assert(spec.validate(commandedLifetime), "Summons should support an explicit until-commanded lifetime")
	commandedLifetime.Triggers.OnCast[1].Payloads[1].RespawnPolicy = "PersistUntilDismissed"
	assert(spec.validate(commandedLifetime), "Until-commanded summon parties may opt into respawn persistence")
	commandedLifetime.Triggers.OnCast[1].Payloads[1].Duration = 30
	assert(not spec.validate(commandedLifetime), "Until-commanded summons must not retain a hidden duration")
	commandedLifetime.Triggers.OnCast[1].Payloads[1].Duration = nil
	commandedLifetime.Triggers.OnCast[1].Payloads[1].LifetimeMode = "FixedDuration"
	assert(not spec.validate(commandedLifetime), "Respawn persistence requires an until-commanded lifetime")
	local missingSummonDuration = spec.copy(summonDraft)
	missingSummonDuration.Triggers.OnCast[1].Payloads[1].Duration = nil
	assert(not spec.validate(missingSummonDuration), "Fixed-duration summons still require a duration")
	local commandedSummon = spec.copy(summonDraft)
	commandedSummon.Triggers.OnCommand = {
		{ Command = "Attack", Payloads = { { Kind = "Heal", Amount = 8 } } },
	}
	assert(spec.validate(commandedSummon), "OnCommand should support command-filtered payload steps")
	assert(schema.supportsPayload("Heal", "Field", "OnCommand"), "Payloads should compose with summon commands")
	assert(table.find(schema.eventsForEffects("Field"), "OnCommand"), "The Lab should expose OnCommand")
	local invalidCommand = spec.copy(commandedSummon)
	invalidCommand.Triggers.OnCommand[1].Command = "Dance"
	assert(not spec.validate(invalidCommand), "OnCommand must reject commands outside the server command list")
	invalidCommand = spec.copy(commandedSummon)
	invalidCommand.Triggers.OnCast = nil
	assert(not spec.validate(invalidCommand), "OnCommand requires a summon group created by another trigger")
	local dismissCommand = spec.copy(commandedSummon)
	dismissCommand.Triggers.OnCommand[1].Command = "Dismiss"
	assert(spec.validate(dismissCommand), "OnCommand should support the validated Dismiss order")
	local constructSummon = spec.createDraft("Construct", "Matter")
	constructSummon.Triggers.OnCast = {
		{ Payloads = { { Kind = "Summon", Archetype = "Wisp", Count = 1, Duration = 15 } } },
	}
	assert(spec.validate(constructSummon), "Construct should dispatch generic OnCast payloads")
	local constructGeometry = spec.createDraft("Construct", "Matter")
	for _, shape in ipairs(schema.Forms.Construct.GeometryOptions) do
		constructGeometry.Geometry = shape
		if shape == "Custom" then
			constructGeometry.Construct.Components = { spec.copy(constructGeometrySpec.DefaultCustomComponent) }
		end
		assert(spec.validate(constructGeometry), "Construct geometry should validate: " .. shape)
	end
	constructGeometry.Geometry = "Mesh"
	assert(not spec.validate(constructGeometry), "Unregistered Construct geometry must be rejected")
	constructGeometry.Geometry = "Custom"
	constructGeometry.Construct.Components[1].SizeX = 2
	assert(
		not spec.validate(constructGeometry),
		"Custom Construct components must stay within the normalized size bound"
	)
	local deathFilter = spec.createDraft("Projectile", "Energy")
	deathFilter.Triggers.OnImpact = { { Payloads = { { Kind = "Damage", Amount = 10 } } } }
	deathFilter.Triggers.OnTargetDeath = {
		{ Payloads = { { Kind = "Damage", Amount = 4 } }, DeathMode = "KilledByThisSpell" },
	}
	assert(spec.validate(deathFilter), "OnTargetDeath should validate a cause filter")
	deathFilter.Triggers.OnTargetDeath[1].DeathMode = "DiedWhileAffected"
	assert(spec.validate(deathFilter), "OnTargetDeath should support DiedWhileAffected")
	deathFilter.Triggers.OnTargetDeath[1].DeathMode = "UnrelatedCause"
	assert(not spec.validate(deathFilter), "Unsupported death cause filters must be rejected")
	local invalidSummon = spec.copy(summonDraft)
	invalidSummon.Triggers.OnCast[1].Payloads[1].Count = 1.5
	assert(not spec.validate(invalidSummon), "fractional summon counts must be rejected")
	invalidSummon = spec.copy(summonDraft)
	invalidSummon.Triggers.OnCast[1].Payloads[1].Duration = summonLimits.MaxDuration + 1
	assert(not spec.validate(invalidSummon), "summon lifetime must respect configured limits")
	invalidSummon = spec.copy(summonDraft)
	invalidSummon.Triggers.OnCast[1].Payloads[1].Archetype = "Unknown"
	assert(not spec.validate(invalidSummon), "unregistered summon archetypes must be rejected")
	invalidSummon = spec.copy(summonDraft)
	invalidSummon.Triggers.OnCast[1].Payloads[1].SpellSlot = "10"
	assert(not spec.validate(invalidSummon), "companion spell slots must be selected from the equipped slots")
	print("PASS: generic Summon payload validation, Construct dispatch and caps")

	local controlDraft = spec.createDraft("Projectile", "Energy")
	controlDraft.Triggers.OnImpact = {
		{
			Payloads = {
				{ Kind = "Control", Mode = "Pull", Acceleration = 24, Duration = 2, MaxSpeed = 32, MaxMass = 500 },
			},
		},
	}
	assert(spec.validate(controlDraft), "maintained Control should validate as an impact payload")
	local invalidControl = spec.copy(controlDraft)
	invalidControl.Triggers.OnImpact[1].Payloads[1].Mode = "Stun"
	assert(not spec.validate(invalidControl), "Control must reject modes that imply unimplemented mechanics")
	invalidControl = spec.copy(controlDraft)
	invalidControl.Triggers.OnImpact[1].Payloads[1].Acceleration = limits.MaxAcceleration + 1
	assert(not spec.validate(invalidControl), "Control acceleration must remain bounded")
	invalidControl = spec.copy(controlDraft)
	invalidControl.Triggers.OnImpact[1].Payloads[1].MaxMass = limits.MaxControlledMass + 1
	assert(not spec.validate(invalidControl), "Control mass limit must remain bounded")
	print("PASS: maintained physical Control payload validation and safety caps")

	local companionHeal = spec.createDraft("Beam", "Energy")
	companionHeal.TargetRules.Relationship = "Ally"
	companionHeal.Triggers.OnCast = { { Payloads = { { Kind = "Heal", Amount = 18 } } } }
	assert(spec.validate(companionHeal), "server-validated companion support spell should validate")
	local companionProfile = companionPolicy.classify(companionHeal)
	assert(companionProfile and companionProfile.Mode == "Ally" and companionProfile.CanHeal)
	print("PASS: ally-targeted companion healing spell validation")
end
