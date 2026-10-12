from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


def block(source: str, start: str, end: str) -> str:
	start_index = source.index(start) + len(start)
	return source[start_index : source.index(end, start_index)]


def top_level_table_keys(source: str) -> set[str]:
	return set(re.findall(r"^\t([A-Za-z][A-Za-z0-9]*) = \{", source, re.MULTILINE))


class MagicRegistryParity(unittest.TestCase):
	@classmethod
	def setUpClass(cls) -> None:
		cls.schema = (ROOT / "src/shared/Configuration/MagicSchema.luau").read_text()
		cls.lab_test = (ROOT / "tests/test_magic_lab.lua").read_text()

	def test_each_form_has_a_server_executor(self):
		form_definitions = block(self.schema, "Schema.Forms = {", "\nfor _, form in Schema.Forms")
		executor_source = (ROOT / "src/server/Services/MagicFormExecutors.luau").read_text()
		executor_table = block(executor_source, "Forms.Executors = {", "\n}\n\nfunction Forms.execute")
		forms = top_level_table_keys(form_definitions)
		executors = set(re.findall(r"^\t([A-Za-z][A-Za-z0-9]*) = function", executor_table, re.MULTILINE))
		self.assertEqual(forms, executors, "Every authored Form must have exactly one generic server executor")

	def test_wave_geometry_is_selected_for_every_server_pulse_and_preview(self):
		self.assertIn('GeometryOptions = { "Cone", "Sphere" }', self.schema)
		spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text()
		self.assertIn('d.Geometry = d.Geometry or (Schema.Forms[d.Form] and Schema.Forms[d.Form].Geometry)', spec)
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		self.assertGreaterEqual(service.count('Geometry == "Sphere" then HitDetection.findSphere'), 2)
		self.assertGreaterEqual(service.count("Vector3.one * waveRange * 2"), 2)
		lab = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text()
		self.assertIn('sphere("WaveSphere", root.Position, previewRange', lab)
		self.assertIn('"Wave shape"', lab)

	def test_active_forms_expose_supported_caster_lifecycle_events(self):
		beam = block(self.schema, "Beam = {", "\n\tWave = {")
		wave = block(self.schema, "Wave = {", "\n\tField = {")
		construct = block(self.schema, "Construct = {", "\n\tManipulation = {")
		for form in (beam, wave, construct):
			self.assertIn('"OnDamageTaken"', form)
			self.assertIn('"OnCasterDeath"', form)
		supports_event = block(self.schema, "function Schema.supportsEvent(", "\nfunction Schema.eventsForEffects(")
		self.assertIn('event == "OnDamageTaken"', supports_event)
		self.assertIn('event == "OnCasterDeath"', supports_event)
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		self.assertIn('if spell.Caster == targetModel and hasEvent(spell.Definition, "OnDamageTaken")', service)
		self.assertIn('if humanoid and humanoid.Health <= 0 and hasEvent(d, "OnCasterDeath")', service)

	def test_each_payload_has_a_server_executor(self):
		payload_definitions = block(
			self.schema,
			"Schema.Payloads = {",
			"\nfor kind, payload in Schema.Payloads",
		)
		executor_source = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text()
		executor_table = block(
			executor_source,
			"Payloads.Executors = {",
			"\n}\n\nfunction Payloads.execute",
		)
		payloads = top_level_table_keys(payload_definitions)
		executors = set(re.findall(r"^\t([A-Za-z][A-Za-z0-9]*) = function", executor_table, re.MULTILINE))
		self.assertEqual(payloads, executors, "Every selectable Payload must have a server executor")

	def test_elemental_marks_use_the_selected_element_and_shared_status_path(self):
		payloads = block(self.schema, "Schema.Payloads = {", "\nfor kind, payload in Schema.Payloads")
		self.assertIn("ElementalMark = {", payloads)
		self.assertIn("ConsumeElementalMark = {", payloads)
		self.assertIn("MaxElementalMarkStacks = 5", (ROOT / "src/shared/Configuration/MagicLab.luau").read_text())
		limits = (ROOT / "src/shared/Configuration/MagicLab.luau").read_text()
		for element in ("Fire", "Water", "Ice", "Lightning", "Earth", "Wind", "Poison"):
			self.assertIn(element + " = {", limits, "Every authored element should have a starter interaction")
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text()
		self.assertIn("context.DamageContext.Element", executors)
		self.assertIn("Status.elementalMark(", executors)
		self.assertIn("Status.consumeElementalMark(", executors)
		self.assertIn("ElementalInteractions.effectsFor(element", executors)
		status = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text()
		self.assertIn("ElementalMarkSpec.apply(", status)
		self.assertIn('"MagicElementalMarks"', status)
		conditions = (ROOT / "src/server/Services/MagicConditions.luau").read_text()
		self.assertIn('GetAttribute("MagicElementalMarks")', conditions)
		spell_spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text()
		self.assertIn("Elemental marks require a non-neutral selected Element", spell_spec)

	def test_humanoid_target_tracking_is_payload_metadata_not_a_kind_branch(self):
		executor_source = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text()
		metadata = block(executor_source, "Payloads.Metadata = {", "\n}\n\nPayloads.Executors")
		tracking = top_level_table_keys(metadata)
		executor_table = block(
			executor_source,
			"Payloads.Executors = {",
			"\n}\n\nfunction Payloads.execute",
		)
		executors = set(re.findall(r"^\t([A-Za-z][A-Za-z0-9]*) = function", executor_table, re.MULTILINE))
		self.assertTrue(tracking <= executors, "Tracking metadata must only reference executable payloads")
		self.assertIn("Displacement", tracking, "Displacement must count its successfully targeted Humanoids")
		self.assertIn("Enhancement", tracking, "Self Enhancement must count its caster target")
		dispatch = block(executor_source, "function Payloads.execute(", "\nreturn Payloads")
		self.assertIn("metadata.TracksHumanoidTargets", dispatch)
		self.assertIn("context.TrackAffected(target)", dispatch)
		self.assertNotIn("payload.Kind ==", dispatch, "Cross-cutting target tracking should stay data-driven")

	def test_each_projectile_behavior_has_a_runtime_handler(self):
		behavior_spec = (ROOT / "src/shared/Modules/ProjectileBehaviorSpec.luau").read_text()
		behavior_definitions = block(behavior_spec, "local Definitions: { [string]: any } = {", "\n}\n\nlocal Spec")
		executor_source = (ROOT / "src/server/Services/MagicProjectileBehaviorExecutors.luau").read_text()
		definitions = top_level_table_keys(behavior_definitions)
		handlers = set(re.findall(r"^executors\.([A-Za-z][A-Za-z0-9]*) = \{", executor_source, re.MULTILINE))
		self.assertEqual(definitions, handlers, "Every selectable Projectile behavior must have a server handler")

	def test_each_generic_behavior_has_a_runtime_handler(self):
		behavior_definitions = block(self.schema, "Schema.Behaviors = {", "\nfor formName, events in Schema.Behaviors")
		executor_source = (ROOT / "src/server/Services/MagicBehaviorExecutors.luau").read_text()
		executor_table = block(
			executor_source,
			"local executors: { [string]: (Context, any) -> () } = {",
			"\n}\n\nfunction Behaviors.execute",
		)
		definitions = top_level_table_keys(behavior_definitions)
		handlers = set(re.findall(r"^\t([A-Za-z][A-Za-z0-9]*) = function", executor_table, re.MULTILINE))
		self.assertEqual(definitions, handlers, "Every selectable generic Behavior must have a server handler")

	def test_environmental_area_visuals_share_the_validated_visual_registry(self):
		visual_spec = (ROOT / "src/shared/Modules/MagicVisualSpec.luau").read_text()
		schema = (ROOT / "src/shared/Configuration/MagicSchema.luau").read_text()
		lab = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text()
		presentation = (ROOT / "src/server/Services/MagicPresentation.luau").read_text()
		magic_service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		presentation_controller = (ROOT / "src/client/Controllers/MagicPresentationController.luau").read_text()
		presentation_config = (ROOT / "src/shared/Configuration/MagicPresentation.luau").read_text()
		self.assertIn('Spec.EnvironmentalVisuals = { "None", "Motes", "GroundMist" }', visual_spec)
		self.assertIn("EnvironmentalVisuals = VisualSpec.EnvironmentalVisuals", schema)
		self.assertIn('select(\n\t\t\t\t\t"Environmental layer"', lab)
		self.assertIn('local style = settings.EnvironmentalVisual or "None"', presentation)
		self.assertIn("environmentalLayer(marker, definition)", presentation)
		self.assertIn('marker:SetAttribute("MagicVisualDistortion", distortion)', presentation)
		self.assertIn('CollectionService:AddTag(marker, "MagicDistortionArea")', presentation)
		self.assertIn('CollectionService:GetTagged("MagicDistortionArea")', presentation_controller)
		self.assertIn('Instance.new("BlurEffect")', presentation_controller)
		self.assertIn('Instance.new("ColorCorrectionEffect")', presentation_controller)
		self.assertIn('slider(\n\t\t\t\t\t"Camera distortion"', lab)
		self.assertIn("LocalDistortion = {", presentation_config)
		self.assertIn("local distortionConfig = Config.LocalDistortion", presentation_controller)
		aura_creation = block(magic_service, "formContext.CreateAura = function(d)", "formContext.ExecuteBeam = function(d)")
		field_creation = block(magic_service, "formContext.CreateField = function(d)", "formContext.RegisterChannel = function(spell)")
		self.assertIn('"MagicAuraDebug"', aura_creation)
		self.assertIn('"MagicFieldDebug"', field_creation)
		self.assertIn("\n\t\t\td\n", aura_creation)
		self.assertIn("\n\t\t\td\n", field_creation)

	def test_explosion_payloads_use_the_shared_server_target_filters(self):
		runtime = (ROOT / "src/server/Services/MagicService.luau").read_text()
		explosion_context = block(runtime, "ctx.ApplySpherePayloads = function(radius, payloads)", "\n\treturn ctx")
		self.assertIn("HitDetection.findSphere", explosion_context)
		self.assertIn("RequireLineOfSight = definition.TargetRules.RequiresLineOfSight", explosion_context)
		self.assertIn("IncludeAttacker = definition.TargetRules.IncludeCaster", explosion_context)
		self.assertIn("Conditions.targets(definition, caster, position, candidates", explosion_context)
		self.assertIn("Player = player", explosion_context)
		self.assertIn("Resources = resourceSnapshot(stats)", explosion_context)
		self.assertLess(
			explosion_context.index("Conditions.targets("),
			explosion_context.index("Payloads.execute("),
			"Explosions must filter candidates before applying any payload",
		)

	def test_active_construct_and_self_enhancement_expiry_events_are_executable(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		construct = block(self.schema, "Construct = {", "\n\tManipulation = {")
		self.assertIn('"OnExpire"', construct)
		self.assertIn('"OnProximity"', construct)
		self.assertIn('Events = set({ "OnCast", "OnExpire", "OnDamageTaken", "OnCasterDeath", "OnProximity" })', self.schema)
		expiry_helper = block(service, "local function expireSelfEnhancement(player: Player, effect: any)", "\nlocal function stopToggledEffect")
		self.assertIn("LifetimeSpec.claimExpiry(effect)", expiry_helper)
		self.assertIn("dispatchClaimedExpiry(effect, position, { humanoid }, nil, character, player)", expiry_helper)
		lifecycle = block(service, "local function dispatchClaimedExpiry(", "\nlifecycleState = function")
		self.assertIn('hasEvent(effect.Definition, "OnExpire")', lifecycle)
		self.assertIn('lifecycleState(effect, "OnExpire"', lifecycle)
		self.assertIn("LifetimeSpec.claimExpiry(effect)", block(service, "local function emitExpiry(", "\nlifecycleState = function"))
		start = block(service, "function Magic.start(", "\nfunction Magic.release")
		self.assertIn("expireSelfEnhancement(player, effect)", start, "Toggle-off must run expiry exactly once")
		channel_finish = block(service, "finishBeamChannel = function(channel)", "\nfunction Magic.release")
		self.assertIn("expireSelfEnhancement(channel.Player, effect)", channel_finish)
		reset = block(service, "function Magic.reset(player)", "\nfunction Magic.remove")
		self.assertIn("expireSelfEnhancement(player, effect)", reset, "Reset cleanup must run expiry")
		self.assertIn("expireSelfEnhancement(player, effect)", service, "Natural termination must run expiry")
		self.assertIn("expireConstruct(spell)", service, "Caster cleanup must dispatch Construct expiry")
		self.assertIn("expireConstruct(channel)", service, "Held Construct cleanup must dispatch expiry")

	def test_expiry_event_authoring_matches_beam_and_wave_lifetimes(self):
		schema = (ROOT / "src/shared/Configuration/MagicSchema.luau").read_text()
		spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text()
		controller = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text()
		availability = block(schema, "function Schema.supportsEvent(", "\nfunction Schema.eventsForEffects")
		self.assertIn('(form == "Beam" or form == "Wave")', availability)
		self.assertIn('event == "OnExpire" or event == "OnDamageTaken" or event == "OnCasterDeath"', availability)
		self.assertIn('return castingMode == "Channeled"', availability)
		self.assertIn("Schema.supportsEvent(d.Form, event, d.Casting.Mode)", spec)
		self.assertIn("Schema.eventsForEffects(draft.Form, draft.Casting.Mode, draft.Targeting)", controller)
		self.assertIn("local function supportedEffectEventsForDraft()", controller)
		self.assertIn("local function effectEventsForDraft()", controller)
		self.assertIn('"Unavailable: " .. label', controller)
		self.assertIn("Remove its effects here or restore a compatible targeting mode", controller)
		self.assertIn('not table.find(schema.eventsForEffects("Beam", "Instant"), "OnExpire")', self.lab_test)
		self.assertIn('table.find(schema.eventsForEffects("Beam", "Channeled"), "OnExpire")', self.lab_test)

	def test_beam_impact_dispatches_at_server_endpoint_and_can_place_summons(self):
		beam = block(self.schema, "Beam = {", "\n\tWave = {")
		self.assertIn('"OnImpact"', beam)
		self.assertIn("payload.Events.Beam.OnImpact = true", self.schema)
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		self.assertGreaterEqual(len(re.findall(r'"OnImpact",\s+state.Character,\s+endpoint', service)), 2)
		self.assertRegex(service, r'"OnImpact",\s+spell.Caster,\s+endpoint')
		self.assertGreaterEqual(len(re.findall(r'if hit then\s+emit\(\s*d,\s*"OnImpact"', service)), 2)
		single_beam = block(service, 'if d.Beam.Pattern == "Cascade" then', "\n\tformContext.ExecuteWave = function(d)")
		self.assertRegex(single_beam, r'emit\(\s*d,\s*"OnImpact",\s*state.Character,\s*endpoint')
		self.assertNotRegex(single_beam, r'if hit then\s+emit\(\s*d,\s*"OnImpact"')
		self.assertIn("maximum-range endpoint if unobstructed", self.schema)
		self.assertIn("resolvedPotency,\n\t\t\t\tposition", service)
		summons = (ROOT / "src/server/Services/SummonService.luau").read_text()
		self.assertIn('if spawnAt == "Event"', summons)
		self.assertIn("#group.Slots + countPerTrigger", summons)
		self.assertIn('group.SpawnAt == "Event" and command == "Protect"', summons)
		self.assertIn('Options = { "Caster", "Event" }', self.schema)
		self.assertIn('Kind = "Summon",\n\t\t\t\t\tArchetype = "Wisp"', self.lab_test)

	def test_combat_sandbox_keeps_avatar_appearance_instead_of_city_clothing(self):
		opening = (ROOT / "src/server/Services/OpeningService.luau").read_text()
		self.assertIn("if not Arena.enabled() and player.Character == character then", opening)

	def test_beam_cascade_is_bounded_server_dispatched_and_testbed_unlocked(self):
		beam = block(self.schema, "Beam = {", "\n\tWave = {")
		self.assertIn('Pattern = "Single"', beam)
		self.assertIn('Options = { "Single", "Cascade" }', beam)
		spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text()
		self.assertIn('d.Beam.Pattern == "Cascade"', spec)
		self.assertIn('strikeCount % 1 ~= 0', spec)
		self.assertIn('beamExtraStrikes * 2.5', spec)
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		self.assertIn('Kind = "BeamCascade"', service)
		self.assertIn("resolveBeamCascadeStrike(spell, spell.StrikeIndex)", service)
		self.assertIn('local hit = sweep(start, delta, spell.Caster, nil, beam.Width / 2)', service)
		self.assertIn('"OnImpact"', service)
		lab_config = (ROOT / "src/shared/Configuration/MagicLab.luau").read_text()
		locus_config = (ROOT / "src/shared/Configuration/MagicLocus.luau").read_text()
		self.assertIn("ProgressionEnabled = false", lab_config)
		self.assertIn("Enabled = false", locus_config)
		self.assertIn("if Limits.ProgressionEnabled then", service)
		lab = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text()
		self.assertNotIn("Config.ProgressionEnabled", lab, "The authoring UI must not expose deferred Locus progression controls")
		self.assertNotIn("LocusRequirementSpec", lab)
		summons = (ROOT / "src/server/Services/SummonService.luau").read_text()
		self.assertIn("group.Color = color", summons)
		self.assertIn("SpellSlot = spellSlot", summons)
		self.assertIn("castCompanionSpell(record.Owner, model, record.SpellSlot", summons)
		self.assertIn('fieryCompanionSpell.Element = "Fire"', self.lab_test)

	def test_projectile_spawn_trigger_has_a_generic_executable_behavior(self):
		projectile = block(self.schema, 'Projectile = {', '\n\tBeam = {')
		explosion = block(self.schema, "Explode = {", "\n}\n\nfor formName, events")
		self.assertIn('Events = set({', projectile)
		payload_events = block(projectile, "EffectEvents = set({", "\n\t\t}),")
		self.assertNotIn('"OnCast"', payload_events)
		self.assertNotIn('"OnSpawn"', payload_events)
		self.assertNotIn('"OnExpire"', payload_events)
		self.assertIn('Projectile = set({', explosion)
		self.assertIn('"OnSpawn",', explosion)
		self.assertIn('"OnCast",', explosion)
		self.assertIn("and definition.Forms[d.Form] == true", (ROOT / "src/shared/Modules/SpellSpec.luau").read_text())
		self.assertIn('schema.supportsBehavior("Explode", "Projectile", "OnSpawn")', self.lab_test)
		self.assertIn('emit(definition, "OnSpawn"', (ROOT / "src/server/Services/MagicService.luau").read_text())
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		channel_spawn = block(service, "local function spawnChannelProjectile(channel)", "\nlocal function constructPlacement")
		self.assertNotIn('emit(definition, "OnCast"', channel_spawn)
		self.assertIn('emit(definition, "OnSpawn"', channel_spawn)
		self.assertIn('emit(d, "OnCast", state.Character, start', service)

	def test_object_target_channel_validation_normalizes_interval_alias(self):
		spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text()
		self.assertIn('local runtimeEvent = if event == "OnInterval" then "OnTick" else event', spec)
		object_filter = block(spec, "local function hasOnlyObjectInteractionPayloads(d)", "\nfunction Spec.validate")
		self.assertIn('and runtimeEvent == "OnTick"', object_filter)
		self.assertIn('Object-targeted Beam OnInterval should alias', self.lab_test)
		self.assertIn('Object-targeted Wave OnInterval should alias', self.lab_test)
		trigger_spec_path = ROOT / "src/shared/Modules/MagicTriggerSpec.luau"
		trigger_spec = trigger_spec_path.read_text()
		self.assertIn("TriggerSpec.normalize(d.Triggers)", spec)
		self.assertIn('event ~= "OnInterval"', trigger_spec)
		self.assertIn("table.insert(result.OnTick, action)", trigger_spec)
		self.assertIn("Normalizing both channel timing names must preserve both steps", self.lab_test)

	def test_channeled_beam_and_wave_expiry_resolve_final_validated_targets(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		expiry = block(service, "local function finalChannelTargets(", "\nfinishBeamChannel = function")
		self.assertIn('channel.Kind == "BeamChannel"', expiry)
		self.assertIn('channel.Kind == "WaveChannel"', expiry)
		self.assertIn("sweep(origin, channel.Direction * range", expiry)
		self.assertIn("HitDetection.findCone", expiry)
		self.assertIn("objectTargetHit(", expiry)
		self.assertIn("ObjectTarget = runtime.ObjectTarget or source.ObjectTarget", service)
		self.assertIn("finalChannelTargets(channel)", block(service, "finishBeamChannel = function", "\nfunction Magic.release"))

	def test_expiry_explosion_is_compatible_with_every_active_form(self):
		explosion = block(self.schema, "Explode = {", "\n}\n\nfor formName, events")
		for form in ("Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement"):
			definition = block(explosion, f"{form} = set(", ")," if form != "SelfEnhancement" else "),")
			self.assertIn('"OnExpire"', definition, f"{form} should support expiry explosion")
		self.assertIn('"OnExpire",', block(self.schema, 'Projectile = {', '\n\tBeam = {'))
		self.assertIn('form .. " expiry should support the generic Explode behavior"', self.lab_test)

	def test_reset_runs_construct_expiry_and_finishes_its_visual(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		cleanup = block(service, "local function clearActive(player)", "\nlocal function locusProfileKey")
		construct_expiry = block(cleanup, 'elseif active[i].Kind == "Construct" then', "\n\t\t\telseif active[i].Visual")
		expire_helper = block(service, "local function expireConstruct(", "\nfinishBeamChannel = function")
		self.assertIn("emitExpiry(spell,", expire_helper)
		self.assertIn("expireConstruct(spell)", construct_expiry)
		self.assertIn("Presentation.finish(spell.Visual)", construct_expiry)
		self.assertLess(
			construct_expiry.index("expireConstruct(spell)"),
			construct_expiry.index("Presentation.finish(spell.Visual)"),
			"Reset/removal should run construct expiry payloads before finishing their visuals",
		)

	def test_reset_expires_traveling_projectiles_and_linger_hazards(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		cleanup = block(service, "local function clearActive(player)", "\nlocal function locusProfileKey")
		for kind in ("ProjectileLinger", "Projectile"):
			branch = block(
				cleanup,
				f'elseif active[i].Kind == "{kind}" then',
				"\n\t\t\telseif active[i].Kind ==",
			)
			self.assertIn("expireProjectile(spell)", branch)
			self.assertIn("Presentation.finish(spell.Visual)", branch)

	def test_caster_death_expires_projectiles_and_linger_hazards(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		expire = block(service, "local function expireProjectile(spell)", "\nlocal function formAreaCandidates")
		self.assertIn("emitExpiry(spell,", expire)
		dispatch = block(service, "local function dispatchClaimedExpiry(", "\nlifecycleState = function")
		self.assertIn('hasEvent(effect.Definition, "OnExpire")', dispatch)
		self.assertIn('spell.Kind == "ProjectileLinger"', expire)
		self.assertIn("areaTargets(spell, spell.Position, spell.LingerRadius)", expire)
		heartbeat_source = service[service.index("RunService.Heartbeat:Connect(function(delta)") :]
		heartbeat = block(heartbeat_source, "for i = #active, 1, -1 do", '\n\t\tlocal step = if spell.Kind == "BeamCascade"')
		self.assertIn('spell.Kind == "Projectile" or spell.Kind == "ProjectileLinger"', heartbeat)
		self.assertLess(heartbeat.index('"OnCasterDeath"'), heartbeat.index("expireProjectile(spell)"))

	def test_reset_clears_summons_after_active_expiry_triggers(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		reset = block(service, "function Magic.reset(player)", "\nfunction Magic.remove")
		self.assertLess(
			reset.index("clearActive(player)"),
			reset.index("Summons.clearOwner(player)"),
			"Active spell OnExpire payloads must not recreate a group after reset cleanup",
		)
		self.assertLess(
			reset.index("expireSelfEnhancement(player, effect)"),
			reset.index("Summons.clearOwner(player)"),
			"Self Enhancement OnExpire payloads must not recreate a group after reset cleanup",
		)

	def test_construct_casts_without_a_target_and_attaches_only_when_the_ray_hits(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		validation = block(service, "local function validate(", "\nlocal function updateEnhancement")
		placement = block(service, "local function constructPlacement(", "\nlocal function execute(")
		self.assertIn(
			'local targeting = if definition.Form == "Construct" then "AimDirection" else definition.Targeting',
			validation,
			"Construct casts must not require a selected entity/object/surface",
		)
		self.assertIn("local hit = sweep(origin, direction * placementDistance", placement)
		self.assertIn("if hit then", placement, "A ray hit may optionally attach a Construct")
		self.assertNotIn('d.Targeting == "ObjectTarget" and (not hit', placement)
		self.assertNotIn("GetPartBoundsInBox", placement, "Nearby geometry must not veto open-air Construct placement")
		self.assertNotIn("return nil, nil", placement, "Construct placement should not fail for lack of free volume")

	def test_damage_payloads_apply_server_resolved_body_region_scaling(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		context = block(service, "local function context(", "emit = function(")
		impact = block(service, "spell.CurrentPhase = \"Impact\"", "local continue = ProjectileBehaviors.impact")
		self.assertIn("HitPart = runtimeState and runtimeState.HitPart", context)
		self.assertLess(impact.index("spell.HitPart = hit.Instance"), impact.index("emit("))
		self.assertIn("spell.HitPart = nil", impact)
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text()
		self.assertIn("BodyRegion.multiplier(payload, hitPart and hitPart.Name)", executors)
		self.assertIn("damageContext.RegionMultiplier = multiplier", executors)
		damage = (ROOT / "src/server/Services/DamageService.luau").read_text()
		self.assertLess(damage.index("incoming *= math.clamp(regionMultiplier, 0, 4)"), damage.index("DamageRules.applyChannel"))
		spec = (ROOT / "src/shared/Configuration/MagicSchema.luau").read_text()
		for region in ("Head", "Torso", "Arm", "Leg", "Other"):
			self.assertIn(f"{region}Multiplier = 1", spec)

	def test_spell_identity_tags_are_editable_and_server_bounded(self):
		identity = (ROOT / "src/shared/Modules/MagicSpellIdentitySpec.luau").read_text()
		self.assertIn("MaxTags = 16", identity)
		self.assertIn("MaxTagLength = 48", identity)
		self.assertIn("function Spec.validateTags(tags)", identity)
		spell_spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text()
		self.assertIn("SpellIdentitySpec.validateTags(d.Tags)", spell_spec)
		ui = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text()
		self.assertIn('"Spell tags"', ui)
		self.assertIn("SpellIdentitySpec.parse(box.Text)", ui)
		conditions = (ROOT / "src/server/Services/MagicConditions.luau").read_text()
		self.assertIn("Tags = SpellIdentitySpec.encode(castState.SpellTags or {})", conditions)
		self.assertIn("context.SpellState.SpellTags = definition.Tags or {}", conditions)
		condition_spec = (ROOT / "src/shared/Modules/MagicConditionSpec.luau").read_text()
		self.assertIn('Tags = { Kind = "String", MaxLength = 48, Operators = { "Has", "DoesNotHave" } }', condition_spec)
		self.assertIn('Tags = EnvironmentZoneSpec.encodeTags(target and target:GetAttribute("MagicConditionTags") or "")', conditions)
		self.assertIn('Tags = { Kind = "String", MaxLength = 24, Operators = { "Has", "DoesNotHave" } }', condition_spec)

	def test_auto_material_is_shared_by_server_presentation_and_editor_preview(self):
		visual_spec = (ROOT / "src/shared/Modules/MagicVisualSpec.luau").read_text()
		self.assertIn("function Spec.autoMaterial(principle, expression, form)", visual_spec)
		presentation = (ROOT / "src/server/Services/MagicPresentation.luau").read_text()
		self.assertIn("VisualSpec.autoMaterial(", presentation)
		ui = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text()
		self.assertIn("VisualSpec.autoMaterial(definition.Source.Principle, definition.Source.Expression, definition.Form)", ui)

	def test_discovery_is_preserved_but_does_not_gate_the_testing_lab(self):
		discovery = (ROOT / "src/server/Services/MagicDiscoveryService.luau").read_text()
		self.assertIn("Spec.recordCast(profiles[player], principle, form, expression)", discovery)
		self.assertIn("Spec.recordCast(sessionProgress[player], principle, form, expression)", discovery)
		self.assertIn("previousSource.Expression == expression", discovery)
		lab = (ROOT / "src/server/Services/MagicLabService.luau").read_text()
		apply = block(lab, 'if action == "Apply" then', '\n\t\telseif action == "Cast" then')
		self.assertNotIn("Discovery.validateExpression", apply)
		self.assertNotIn("Discovery.validateVisual", apply)
		self.assertLess(apply.index("Spec.validate(data)"), apply.index("definitions[player][slot] = definition"))
		self.assertIn("scheduleSave(player)", apply)
		ui = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text()
		for kind in ("Expression", "Palette", "Shape"):
			self.assertNotIn('GetAttribute("MagicUnlock' + kind, ui)
		setup = block(ui, 'if activeSection == "Setup" then', 'elseif activeSection == "Targeting" then')
		self.assertLess(setup.index('select("Spell Form"'), setup.index('row("Spell name")'))
		self.assertIn('forms.Name = "SpellFormChoices"', setup)
		self.assertIn('for i, formName in Schema.FormOrder do', setup)

	def test_magic_focus_profiles_are_unlocked_saved_and_resolved_server_side(self):
		profiles = (ROOT / "src/shared/Configuration/MagicProfiles.luau").read_text()
		spells = (ROOT / "src/shared/Configuration/Spells.luau").read_text()
		registered = set(re.findall(r'^\t([A-Za-z0-9_]+) = \{\n\t\tSpellId = "([A-Za-z0-9_]+)"', spells, re.MULTILINE))
		registered_ids = {spell_id for _, spell_id in registered}
		profile_ids = re.findall(r'(?:PrimarySpellId|AreaSpellId) = "([A-Za-z0-9_]+)"', profiles)
		self.assertTrue(profile_ids)
		self.assertTrue(set(profile_ids) <= registered_ids, "focus profiles must only route to registered spells")
		self.assertIn('MagicAwakeningSelect = "MagicAwakeningSelect"', (ROOT / "src/shared/Networking/Protocol.luau").read_text())
		router = (ROOT / "src/server/Networking/ActionRouter.luau").read_text()
		self.assertIn("Discovery.selectAwakeningProfile(player, payload.AwakeningProfileId)", router)
		equipment = (ROOT / "src/server/Services/EquipmentService.luau").read_text()
		self.assertIn("MagicDiscoveryService).awakeningProfileId(player)", equipment)
		self.assertNotIn("payload.AwakeningProfileId", equipment, "equipment cast resolution must not trust the client selection")
		discovery = (ROOT / "src/server/Services/MagicDiscoveryService.luau").read_text()
		self.assertIn(
			"Spec.selectAwakeningProfile(profiles[player], profileId, MagicProfiles, Config.ProgressionEnabled == true)",
			discovery,
		)
		discovery_spec = (ROOT / "src/shared/Modules/MagicDiscoverySpec.luau").read_text()
		self.assertIn("Spec.awakeningProfileUnlocked", discovery_spec)
		self.assertIn("Spec.selectAwakeningProfile", discovery_spec)
		self.assertIn('AwakeningProfileId = "RecruitGeneric"', discovery_spec)
		self.assertIn("Version = 3", (ROOT / "src/shared/Modules/MagicDiscoverySpec.luau").read_text())

	def test_unrestricted_testbed_has_no_active_cast_count_gates(self):
		lab_config = (ROOT / "src/shared/Configuration/MagicLab.luau").read_text()
		locus_config = (ROOT / "src/shared/Configuration/MagicLocus.luau").read_text()
		profiles = (ROOT / "src/shared/Configuration/MagicProfiles.luau").read_text()
		discovery = (ROOT / "src/server/Services/MagicDiscoveryService.luau").read_text()
		self.assertIn("ProgressionEnabled = false", lab_config)
		self.assertIn("Enabled = false", block(locus_config, "Progression = {", "\n\t},"))
		self.assertNotIn("Unlock =", profiles, "Active Focus profiles should contain no progression requirements")
		self.assertIn("if Config.ProgressionEnabled ~= true then\n\t\treturn\n\tend", discovery)
		self.assertIn("Config.ProgressionEnabled ~= true or player:GetAttribute", discovery)

	def test_status_expiry_is_shared_and_time_dilation_is_removed_before_rate_calculation(self):
		service = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text()
		self.assertIn("MagicStatusEffectSpec", service)
		heartbeat = service[service.rindex("RunService.Heartbeat:Connect(function()") :]
		pre_rate_cleanup = block(
			heartbeat,
			"for i = #active, 1, -1 do",
			"local timeRate = TemporalRate.combine(state.Effects, now)",
		)
		self.assertIn('effect.Kind == "TimeDilation"', pre_rate_cleanup)
		self.assertIn("casterHumanoid.Health > 0", pre_rate_cleanup)
		self.assertIn("EffectSpec.isExpired(", pre_rate_cleanup)
		cleanup = block(heartbeat, "local timeRate = TemporalRate.combine(state.Effects, now)", "if #state.Effects == 0 then")
		self.assertIn("EffectSpec.isExpired(", cleanup)
		self.assertIn("effect.Remaining", cleanup)

	def test_periodic_payloads_keep_target_death_lifecycle_after_source_form_ends(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		payloads = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text()
		target_death = (ROOT / "src/shared/Modules/MagicTargetDeathSpec.luau").read_text()
		self.assertIn("ctx.TargetDeathCallback = function(targetHumanoid)", service)
		self.assertIn('ctx.DamageContext.EmitEvent("OnTargetDeath", targetHumanoid, { DeathCause = "DiedWhileAffected" })', service)
		self.assertIn("TargetDeathSpec.claim(runtime, targetHumanoid)", service)
		self.assertIn("TargetDeathSpec.claim(spell.RuntimeOrigin or spell, target)", service)
		self.assertIn("effect.Target.Died:Connect", payloads)
		self.assertIn("task.defer(callback)", payloads)
		self.assertIn("effect.DeathConnection:Disconnect()", payloads)
		self.assertIn("context.TargetDeathCallback and context.TargetDeathCallback(target)", payloads)
		status = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text()
		self.assertIn("OnTargetDeath: ((Humanoid) -> ())?", status)
		self.assertIn("effect.OnTargetDeath = onTargetDeath", status)
		self.assertIn("task.defer(callback, humanoid)", status)
		control = (ROOT / "src/server/Services/MagicControlService.luau").read_text()
		self.assertIn("dispatchTargetDeath(state)", control)
		self.assertIn("effect.OnTargetDeath = onTargetDeath", control)
		for payload, next_payload in (
			("Shield", "ModifyAttribute"),
			("ModifyAttribute", "Transformation"),
			("Transformation", "Slow"),
			("Slow", "Bind"),
			("Bind", "Reveal"),
			("Reveal", "Control"),
			("Control", "Force"),
			("TimeDilation", "Enhancement"),
		):
			with self.subTest(payload=payload):
				executor = block(payloads, f"\t{payload} = function", f"\n\t{next_payload} = function")
				self.assertIn("context.TargetDeathCallback", executor)
		self.assertIn("MaxPeriodicEffectsGlobal = 256", (ROOT / "src/shared/Configuration/MagicLab.luau").read_text())
		self.assertIn("MaxPeriodicEffectsPerCaster = 32", (ROOT / "src/shared/Configuration/MagicLab.luau").read_text())
		self.assertIn("function Spec.claim(runtime, target)", target_death)

	def test_beam_damage_uses_the_server_raycast_hit_part_for_region_scaling(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		payloads = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text()
		self.assertIn("HitPart = if not objectTarget and hit then hit.Instance else nil", service)
		self.assertIn("channel.HitPart = if not channel.ObjectTarget and hit then hit.Instance else nil", service)
		self.assertIn("spell.HitPart = if not spell.ObjectTarget and hit then hit.Instance else nil", service)
		final_targets = block(service, "local function finalChannelTargets(channel)", "\nend")
		self.assertIn("channel.HitPart = if not channel.ObjectTarget and hit then hit.Instance else nil", final_targets)
		self.assertIn("local hitPart = damageContext.HitPart", payloads)
		self.assertIn("damageContext.RegionMultiplier = multiplier", payloads)

	def test_condition_bound_channels_are_bounded_and_exposed_in_the_lab(self):
		spell_spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text()
		lifetime_validation = block(spell_spec, "local life = d.Lifetime", "local rules = d.TargetRules")
		self.assertIn('c.Mode == "Channeled" and life.Mode == "UntilConditionFails" and life.Duration ~= nil', lifetime_validation)
		self.assertIn('d.Form == "Beam"', lifetime_validation)
		self.assertIn('d.Form == "Wave"', lifetime_validation)
		self.assertIn('CastingSpec.isHeldMode(c.Mode) and life.Duration == nil', lifetime_validation)
		controller = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text()
		self.assertIn('local conditionBoundChannel = draft.Casting.Mode == "Channeled"', controller)
		self.assertIn('draft.Form == "Projectile" or conditionBoundChannel', controller)
		self.assertIn("Maximum channel duration (seconds)", controller)

	def test_replacing_a_spell_slot_cleans_old_lifetimes_after_expiry_callbacks(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		cleanup = block(service, "function Magic.clearTemporary(", "\nlocal function summonSpellProfile")
		self.assertIn("stats.Pending = nil", cleanup)
		self.assertIn("stats.Charge = nil", cleanup)
		self.assertIn("finishBeamChannel(spell)", cleanup)
		self.assertIn("finishInterruptedArea(spell)", cleanup)
		self.assertIn("expireConstruct(spell)", cleanup)
		self.assertIn("expireSelfEnhancement(player, effect)", cleanup)
		self.assertGreater(cleanup.index("Summons.clearSpell(player, spellId)"), cleanup.index("expireSelfEnhancement(player, effect)"))

	def test_object_target_physics_rules_use_the_shared_pure_eligibility_spec(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		validator = block(service, "local function isValidObjectInteractionTarget(", "\nlocal function isLiveHomingTarget")
		self.assertIn("MagicObjectTargetSpec", service)
		self.assertIn("ObjectTargetSpec.isValidInteractionTarget", validator)
		self.assertIn('Tagged = CollectionService:HasTag(target, "MagicManipulable")', validator)
		self.assertIn('RaiseAuthorized = target:GetAttribute("MagicRaise") == true', validator)
		self.assertIn("MaterialMatches = definition.Material ~= nil", validator)
		surface_validator = block(service, "local function isSolidWorldSurfaceTarget(", "\nlocal function isValidObjectInteractionTarget")
		self.assertIn("ObjectTargetSpec.isSolidWorldSurfaceTarget", surface_validator)
		self.assertIn("not isSolidWorldSurfaceTarget(targetInstance)", service)
		self.assertIn("ObjectTargetSpec.isValidManipulationTarget", service)
		self.assertIn("MaterialMatches = definition.Material ~= nil", service)

	def test_controlled_mass_condition_uses_the_control_service_aggregate(self):
		control = (ROOT / "src/server/Services/MagicControlService.luau").read_text()
		self.assertIn("setControlledMass(effect, targetRoot.AssemblyMass)", control)
		self.assertIn("function Control.controlledMass(caster: Model, spellId: string)", control)
		conditions = (ROOT / "src/server/Services/MagicConditions.luau").read_text()
		self.assertIn("ControlledMass = controlledMass", conditions)
		self.assertIn("Control.controlledMass(caster, spellId)", conditions)
		spec = (ROOT / "src/shared/Modules/MagicConditionSpec.luau").read_text()
		self.assertIn("ControlledMass = { Kind = \"Number\"", spec)

	def test_command_casts_are_limited_by_distinct_active_executions(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		command = (ROOT / "src/server/Services/MagicCommandSpec.luau").read_text()
		cast = block(service, "function Magic.castSummonSpell(", "\nlocal function clearActive")
		self.assertIn("SummonConfiguration.MaxActiveCommands", cast)
		self.assertIn("CommandSpec.canStartActiveCommand(active, player", cast)
		self.assertIn("CommandId = commandId", cast)
		self.assertIn("nextCommandCastId += 1", cast)
		self.assertIn("effect.CommandCastId", command)
		self.assertIn("projectile.CommandCastId", service, "Projectile continuations must retain their command slot")
		self.assertIn("effect.CommandCastId = commandCastId", service)

	def test_area_targeting_uses_server_validated_field_center_rules(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		area_validation = block(service, 'elseif targeting == "WorldPoint" or targeting == "Area" then', '\n\telseif targeting == "MaterialTarget" then')
		self.assertIn('Area = {', self.schema)
		self.assertIn('"WorldPoint", "Area", "EntityTarget"', self.schema)
		self.assertIn("definition.TargetRules.Range", area_validation)
		self.assertIn("MinimumWorldAimDot", area_validation)
		self.assertIn('targeting == "Area"', service, "Area centers must share server line-of-sight validation")

	def test_spell_state_conditions_resolve_only_server_owned_runtime_values(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		conditions = (ROOT / "src/server/Services/MagicConditions.luau").read_text()
		spec = (ROOT / "src/shared/Modules/MagicConditionSpec.luau").read_text()
		spell_state = block(conditions, "SpellState = {", "\n\t\tResource = {")
		for property_name in (
			"DistanceFromCaster",
			"RemainingDuration",
			"PierceCount",
			"BounceCount",
			"AbsorbedEnergy",
			"HasCurrentTarget",
		):
			self.assertIn(property_name, spec)
			self.assertIn(property_name, spell_state)
		self.assertIn("castState.Position", conditions)
		self.assertIn("castState.RemainingLifetime", conditions)
		lifecycle = block(
			service,
			"lifecycleState = function(source: any, event: string, depth: number)",
			"\nlocal function interruptWindupForDamage",
		)
		for runtime_property in ("Position", "RemainingLifetime", "PierceCount", "BounceCount", "AbsorbedEnergy"):
			self.assertIn(runtime_property, lifecycle, "Nested lifecycle events must retain runtime state")

	def test_held_cast_pose_is_sustained_until_server_cleanup(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		presentation = (ROOT / "src/server/Services/MagicPresentation.luau").read_text()
		controller = (ROOT / "src/client/Controllers/MagicPresentationController.luau").read_text()
		poses = (ROOT / "src/shared/Modules/MagicPoseSpec.luau").read_text()
		self.assertIn("Presentation.sustain(state.Character, definition)", service)
		self.assertIn('cue(character, Presentation.profile(definition), "Sustain", 0, 0)', presentation)
		self.assertIn('existing.Phase = "Sustain"', controller)
		self.assertIn('existing.Duration = math.huge', controller)
		self.assertIn('elseif phase == "Sustain" then', poses)
		self.assertIn("pose = selected.Sustain", poses)
		self.assertIn("Presentation.cancel(channel.Caster, definition)", service)

	def test_construct_expiry_triggers_on_caster_cleanup(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text()
		expiry = block(service, "local function expireConstruct(", "\nfinishBeamChannel = function")
		self.assertIn("emitExpiry(spell,", expiry)
		self.assertIn("spell.AttachedHumanoid", expiry)
		dispatch = block(service, "local function dispatchClaimedExpiry(", "\nlocal function emitExpiry")
		self.assertIn('hasEvent(effect.Definition, "OnExpire")', dispatch)
		channel_cleanup = block(service, "finishBeamChannel = function", "\nfunction Magic.release")
		self.assertIn('elseif channel.Kind == "Construct" then', channel_cleanup)
		self.assertIn("expireConstruct(channel)", channel_cleanup)
		caster_cleanup = block(service, "local humanoid = spell.Caster:FindFirstChildOfClass", "\n\t\tlocal step =")
		self.assertIn('elseif spell.Kind == "Construct" then', caster_cleanup)
		self.assertIn("expireConstruct(spell)", caster_cleanup)


if __name__ == "__main__":
	unittest.main()
