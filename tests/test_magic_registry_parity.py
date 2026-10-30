from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


def block(source: str, start: str, end: str) -> str:
	start_index = source.index(start) + len(start)
	return source[start_index : source.index(end, start_index)]


def top_level_table_keys(source: str) -> set[str]:
	return set(re.findall(r"^\t([A-Za-z][A-Za-z0-9]*) = \{", source, re.MULTILINE))


def payload_entries(schema: str) -> dict[str, str]:
	payloads = block(schema, "Schema.Payloads = {", "\nfor kind, payload in Schema.Payloads")
	return dict(re.findall(r"^\t([A-Za-z][A-Za-z0-9]*) = \{\n(.*?)^\t\},?$", payloads, re.MULTILINE | re.DOTALL))


def names_kind(source: str, kind: str) -> bool:
	# A consumer "registers" a kind when it names it as a string or a table key.
	return f'"{kind}"' in source or re.search(rf'(?<![A-Za-z0-9_."]){kind}\s*=(?!=)', source) is not None


BOON = {"Heal", "Restoration", "Shield", "Enhancement", "AerialMovement", "Stealth", "RestoreResource"}
BANE = {
	"Damage",
	"DamageOverTime",
	"Slow",
	"Bind",
	"ElementalMark",
	"Stun",
	"Silence",
	"Taunt",
	"Fear",
	"DrainResource",
	"Dispel",  # Bane against Hostile spells, Neutral otherwise (Schema.DispelPolarity)
}

# Every Schema.Payloads kind must be named by each of these consumers, so a new
# payload kind fails here until every file handles it.
PAYLOAD_CONSUMERS = [
	"src/server/Services/MagicPayloadExecutors.luau",
	"src/server/Services/MagicStatusEffectService.luau",
	"src/shared/Modules/SpellStatCaps.luau",
	"src/shared/Modules/CombatPolicy.luau",
	"src/shared/Modules/MagicCompanionSpellPolicy.luau",
	"src/client/UI/SpellForgeComponents.luau",
	"src/client/UI/GrimoireSpellVisual.luau",
	"src/shared/SpellVFXSystem/Core/SpellVFXAnalyzer.luau",
	"src/shared/SpellVFXSystem/Visual/SpellVisualFeatureExtractor.luau",
	"src/shared/Modules/MagicAuthoringGuide.luau",
	"tests/test_magic_lab.lua",
]

# Kinds each consumer does not name today, kept as an explicit baseline. The
# test fails when a kind outside this list is missing, and when a listed gap
# gets fixed (remove the entry so it cannot regress).
KNOWN_PAYLOAD_GAPS = {
	"src/shared/Modules/CombatPolicy.luau": {
		"Damage",
		"Heal",
		"Restoration",
		"Shield",
		"Enhancement",
		"AerialMovement",
		"Manipulation",
		"Summon",
		"Stealth",
		"RestoreResource",
	},
	"src/client/UI/GrimoireSpellVisual.luau": {"Force", "ModifyAttribute", "Transformation", "Control"},
	"src/shared/SpellVFXSystem/Core/SpellVFXAnalyzer.luau": {"ConsumeElementalMark", "ModifyAttribute", "Transformation"},
	"src/shared/SpellVFXSystem/Visual/SpellVisualFeatureExtractor.luau": {
		"ConsumeElementalMark",
		"Transformation",
		"Manipulation",
	},
	"src/shared/Modules/MagicAuthoringGuide.luau": {"ElementalMark", "ConsumeElementalMark"},
}


class MagicRegistryParity(unittest.TestCase):
	@classmethod
	def setUpClass(cls) -> None:
		cls.schema = (ROOT / "src/shared/Configuration/MagicSchema.luau").read_text(encoding="utf-8")
		cls.lab_test = (ROOT / "tests/test_magic_lab.lua").read_text(encoding="utf-8")

	def test_each_form_has_a_server_executor(self):
		form_definitions = block(self.schema, "Schema.Forms = {", "\nfor _, form in Schema.Forms")
		executor_source = (ROOT / "src/server/Services/MagicFormExecutors.luau").read_text(encoding="utf-8")
		executor_table = block(executor_source, "Forms.Executors = {", "\n}\n\nfunction Forms.execute")
		forms = top_level_table_keys(form_definitions)
		executors = set(re.findall(r"^\t([A-Za-z][A-Za-z0-9]*) = function", executor_table, re.MULTILINE))
		self.assertEqual(forms, executors, "Every authored Form must have exactly one generic server executor")

	def test_wave_geometry_is_selected_for_every_server_pulse_and_preview(self):
		self.assertIn('GeometryOptions = { "Cone", "Sphere" }', self.schema)
		spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text(encoding="utf-8")
		self.assertIn('d.Geometry = d.Geometry or (Schema.Forms[d.Form] and Schema.Forms[d.Form].Geometry)', spec)
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		# Both server pulses (initial cast and channeled tick) choose the sphere query.
		self.assertGreaterEqual(len(re.findall(r'Geometry == "Sphere" then HitDetection\.findSphere\(', service)), 2)
		presentation = (ROOT / "src/server/Services/MagicPresentation.luau").read_text(encoding="utf-8")
		wave_preview = block(presentation, "function Presentation.wave(", "\nend")
		self.assertIn('Geometry == "Sphere" then Vector3.one * range * 2', wave_preview)
		lab = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text(encoding="utf-8")
		geometry_preview = (ROOT / "src/client/Controllers/GrimoireGeometryPreview.luau").read_text(encoding="utf-8")
		self.assertIn('sphere("WaveSphere", root.Position, previewRange', geometry_preview)
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
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		self.assertIn('if spell.Caster == targetModel and hasEvent(spell.Definition, "OnDamageTaken")', service)
		self.assertIn('if humanoid and humanoid.Health <= 0 and hasEvent(d, "OnCasterDeath")', service)

	def test_each_payload_has_a_server_executor(self):
		payload_definitions = block(
			self.schema,
			"Schema.Payloads = {",
			"\nfor kind, payload in Schema.Payloads",
		)
		executor_source = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		executor_table = block(
			executor_source,
			"Payloads.Executors = {",
			"\n}\n\nfunction Payloads.execute",
		)
		payloads = top_level_table_keys(payload_definitions)
		executors = set(re.findall(r"^\t([A-Za-z][A-Za-z0-9]*) = function", executor_table, re.MULTILINE))
		self.assertEqual(payloads, executors, "Every selectable Payload must have a server executor")

	def test_each_payload_kind_is_registered_in_every_consumer(self):
		kinds = set(payload_entries(self.schema))
		self.assertTrue(kinds)
		for path in PAYLOAD_CONSUMERS:
			source = (ROOT / path).read_text(encoding="utf-8")
			missing = {kind for kind in kinds if not names_kind(source, kind)}
			known = KNOWN_PAYLOAD_GAPS.get(path, set())
			with self.subTest(consumer=path):
				self.assertLessEqual(known, kinds, "Known gaps must be real Schema.Payloads kinds")
				self.assertEqual(missing - known, set(), f"{path} does not handle these payload kinds")
				self.assertEqual(known - missing, set(), f"{path} now handles these; remove them from KNOWN_PAYLOAD_GAPS")

	def test_each_payload_declares_its_polarity(self):
		for kind, body in payload_entries(self.schema).items():
			with self.subTest(kind=kind):
				polarities = re.findall(r'^\t\tPolarity = "([A-Za-z]+)",$', body, re.MULTILINE)
				expected = "Boon" if kind in BOON else "Bane" if kind in BANE else "Neutral"
				self.assertEqual(polarities, [expected], f'{kind} must declare Polarity = "{expected}"')

	def test_status_and_periodic_effects_record_polarity_and_source_spell(self):
		status = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text(encoding="utf-8")
		self.assertIn("Polarity: string,", status)
		self.assertIn("local definition = Schema.Payloads[kind]", status)
		mark = block(status, "local candidate: Effect = {", "\n\t}")
		self.assertIn("SpellId = spellId,", mark)
		self.assertIn('Polarity = polarityOf("ElementalMark"),', mark)
		put_effect = block(status, "\ttable.insert(state.Effects, {", "\n\t})")
		self.assertIn("SpellId = spellId,", put_effect)
		self.assertIn("Polarity = polarityOf(kind),", put_effect)
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		for kind in ("DamageOverTime", "Restoration"):
			periodic = block(executors, f'\t\t\t\t\tKind = "{kind}",', "\n\t\t\t\t}")
			self.assertIn("SpellId = context.SpellId,", periodic)
			self.assertIn(f"Polarity = Schema.Payloads.{kind}.Polarity,", periodic)

	def test_melee_hits_and_damage_taken_reactions_are_wired_and_bounded(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		listener = block(service, "Damage.Applied:Connect(function(", "\nend)\n")
		# OnDamageTaken: attacker passed as event data; non-spell hits start a root at
		# depth 0, spell hits continue the chain so thorns cannot ping-pong forever.
		self.assertIn("local reactionDepth = if fromSpell then depth + 1 else 0", listener)
		self.assertIn("eventState.EventAttacker = attackerHumanoid", listener)
		self.assertIn("eventState.OperationBudget = damageContext.OperationBudget", listener)
		self.assertEqual(listener.count("damageTakenState(spell)") + listener.count("damageTakenState(effect)"), 2)
		# OnMeleeHit: only real melee hits (no spell context), new root at depth 0.
		self.assertIn("if melee == true and damageContext == nil then", listener)
		self.assertIn('lifecycleState(spell, "OnMeleeHit", 0)', listener)
		self.assertIn('lifecycleState(effect, "OnMeleeHit", 0)', listener)
		self.assertIn("spell.FollowTargetModel == attacker", listener)
		self.assertIn("EventAttackers = if runtimeState and runtimeState.EventAttacker", service)
		damage = (ROOT / "src/server/Services/DamageService.luau").read_text(encoding="utf-8")
		self.assertIn("applied:Fire(attacker, target, dealt, killed, eventContext, melee)", damage)
		self.assertIn("return apply(attacker, target, amount, nil, true)", damage)
		dispatch = (ROOT / "src/server/Services/MagicTriggerDispatch.luau").read_text(encoding="utf-8")
		self.assertIn('step.TargetFrom == "Attacker"', dispatch)
		self.assertIn("conditions.filter(step.Condition, stepContext)", dispatch)
		self.assertIn('"OnMeleeHit"', self.schema)

	def test_enchantments_split_owner_and_holder(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		start = block(service, "local function startSelfEnhancement(", "\nend\n")
		# Record: State is the holder, OwnerState/Caster/Player the owner.
		for field in ("State = holder,", "OwnerState = state,", "Owner = player,", "Caster = state.Character,", "IsSelf = isSelf,"):
			self.assertIn(field, start)
		self.assertIn("canHoldEnchantment(player, d, holder.Character)", start)
		self.assertIn("Identity = enchantmentIdentity(d),", start)
		self.assertIn("Presentation.follow(d, holder.Root", start)
		# Caps are checked before costs in validate, and again on start.
		validation = block(service, "local function validate(", "\nlocal function refreshHolder")
		self.assertIn("canHoldEnchantment(player, definition, selectedTarget)", validation)
		# Movement and the overhead summary are per holder, across all owners.
		refresh = block(service, "local function refreshHolder(", "\nend\n")
		self.assertIn('character:SetAttribute("MagicEnchantments"', refresh)
		self.assertIn('CollectionService:AddTag(character, "MagicEnchanted")', refresh)
		self.assertIn("if not Players:GetPlayerFromCharacter(character) then", refresh)
		self.assertIn("EnchantmentSpec.movement(effect.IsSelf ~= false, true)", refresh)
		# Lifecycle goes through EnchantmentSpec; holder-view events credit the owner.
		self.assertIn("EnchantmentSpec.endReason(effect, {", service)
		self.assertIn("EnchantmentSpec.endEvents(endReason, effect.IsSelf ~= false)", service)
		self.assertIn("TargetDeathSpec.claim(effect, humanoid)", service)
		listener = block(service, "Damage.Applied:Connect(function(", "\nend)\n")
		self.assertGreaterEqual(listener.count("effect.Caster or "), 4)
		self.assertIn('hasEvent(effect.Definition, "OnHolderDealtDamage")', listener)
		self.assertIn("damageContext.SourceRuntimeState ~= effect", listener)
		client = (ROOT / "src/client/Controllers/MagicEnchantmentController.luau").read_text(encoding="utf-8")
		self.assertIn('local TAG = "MagicEnchanted"', client)
		self.assertIn('startController("MagicEnchantmentController")', (ROOT / "src/client/init.client.luau").read_text(encoding="utf-8"))
		summons = (ROOT / "src/server/Services/SummonService.luau").read_text(encoding="utf-8")
		self.assertIn("profile.CanEnchant == true", summons)
		limits = (ROOT / "src/shared/Configuration/MagicLab.luau").read_text(encoding="utf-8")
		self.assertIn("MaxSameEnchantmentPerHolder = 3", limits)
		self.assertNotIn("MaxEnchantmentsPerHolder", limits)

	def test_scaling_clamps_once_in_order(self):
		# authored amount -> ScaleBy -> charge potency -> outgoing strength -> mitigation -> final caps
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		helper = block(executors, "local function scaledAmount(", "\nend\n")
		self.assertIn("ScaleSpec.amount(amount, payload.ScaleBy, units)", helper)
		self.assertIn("return amount * context.Potency", helper)
		for kind in ("Damage", "Heal", "Shield"):
			executor = block(executors, f"\n\t{kind} = function(", "\n\tend,")
			self.assertIn("scaledAmount(payload, context, humanoid)", executor, kind)
		self.assertEqual(executors.count("scaledAmount(payload, context, target)"), 2, "DamageOverTime apply and refresh")
		for kind in ("Damage", "Heal", "Shield"):
			self.assertNotIn("payload.Amount * context.Potency", block(executors, f"\n\t{kind} = function(", "\n\tend,"))
		self.assertIn("groupContext.CapProfile = CapProfiles[profile]", executors)
		caps = (ROOT / "src/shared/Modules/SpellStatCaps.luau").read_text(encoding="utf-8")
		payload_caps = block(caps, "function Caps.payload(", "\nend\n")
		for cap in ("MaxDotPerTick", "MaxHealPerHit", "MaxShield"):
			self.assertNotIn(cap, payload_caps, f"{cap} is applied once, on the final amount")
		damage = (ROOT / "src/server/Services/DamageService.luau").read_text(encoding="utf-8")
		order = [
			damage.index("DamageRules.applyOutgoingStrength(incoming"),
			damage.index("DamageRules.applyChannel(incoming"),
			damage.index("StatCaps.damage(incoming"),
			damage.index("incoming = math.min(incoming, eventContext.PerHitCap)"),
		]
		self.assertEqual(order, sorted(order), "strength -> mitigation -> PvP caps")
		status = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text(encoding="utf-8")
		self.assertIn("local limit = if cap then math.min(cap, Limits.MaxHeal) else Limits.MaxHeal", status)
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		self.assertIn("* (definition._ChargePotency or 1)", service)
		self.assertIn("definition._ChargePotency =", service)
		self.assertIn("Conditions.scaleValue(source, {", service)
		self.assertIn("StatusEffects.elementalMarkStacks(humanoid, element)", service)
		launch = block(service, "formContext.CreateProjectile = function(d)", "\n\tend\n")
		self.assertIn("ScaleSpec.extraProjectiles(d.Casting.ChargeScaling, d._ChargeFraction or 0)", launch)
		self.assertIn("ScaleSpec.extraOffsets(extras, spreadAngle, spreadPairs)", launch)
		self.assertIn("if not hasCapacity(player) then", launch)
		self.assertLess(launch.index("ScaleSpec.extraProjectiles("), launch.index("ProjectileBehaviors.spawn(projectile"))
		lab = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text(encoding="utf-8")
		self.assertIn('"Charge scales power"', lab)
		self.assertIn('"Extra projectiles at full charge"', lab)
		self.assertIn('"Scale by"', lab)

	def test_stun_silence_and_cleanse_are_wired(self):
		status = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text(encoding="utf-8")
		self.assertIn('setAttribute(state.Humanoid, parentModel, "MagicStunned", stunned)', status)
		self.assertIn('setAttribute(state.Humanoid, parentModel, "MagicSilenced", silenced)', status)
		self.assertIn("CrowdControl.applyStun(history, os.clock()", status)
		self.assertIn("function Status.removeWhere(", status)
		movement = (ROOT / "src/shared/Modules/MagicMovementEffects.luau").read_text(encoding="utf-8")
		self.assertIn('effect.Kind == "Bind" or effect.Kind == "Stun"', movement)
		router = (ROOT / "src/server/Networking/ActionRouter.luau").read_text(encoding="utf-8")
		gate = router.index("local blocked = CrowdControl.blocks(")
		self.assertLess(gate, router.index("Magic.start(player, state, payload, feedback)"), "gate before casts are routed")
		self.assertLess(gate, router.index("Combat.request(state, now"), "gate before melee")
		enemy = (ROOT / "src/server/Services/EnemyService.luau").read_text(encoding="utf-8")
		self.assertIn("if now < nextHit or not activeAttack or stunned() then", enemy)
		self.assertIn("if visible(other) and not stunned()", enemy)
		self.assertNotIn("MagicSilenced", enemy, "Silence never affects monster attacks")
		self.assertNotIn("Magic", (ROOT / "src/server/Services/NascentAttackSelector.luau").read_text(encoding="utf-8"))
		summons = (ROOT / "src/server/Services/SummonService.luau").read_text(encoding="utf-8")
		self.assertIn('if humanoid:GetAttribute("MagicStunned") == true then', summons)
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		self.assertIn('if stunned then "Stunned" elseif silenced then "Silenced" else "Polymorphed"', service)
		self.assertIn("ctx.EnchantmentCandidates = function(", service)
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		silence = block(executors, "\n\tSilence = function(", "\n\tend,")
		self.assertIn("Players:GetPlayerFromCharacter(humanoid.Parent)", silence, "Silence: players only")
		cleanse = block(executors, "\n\tCleanse = function(", "\n\tend,")
		for source in ("Status.cleanseCandidates(humanoid)", "periodicEffects", "context.EnchantmentCandidates"):
			self.assertIn(source, cleanse)
		self.assertIn("CrowdControl.select(candidates, payload.Remove, payload.Count or 1, payload.Element)", cleanse)
		policy = (ROOT / "src/shared/Modules/CombatPolicy.luau").read_text(encoding="utf-8")
		self.assertIn('return payload.Remove ~= "Banes"', policy)

	def test_taunt_and_fear_are_creature_only_and_gate_enemy_targeting(self):
		enemy = (ROOT / "src/server/Services/EnemyService.luau").read_text(encoding="utf-8")
		decide = enemy.index("local control = ControlState.decide(")
		self.assertLess(decide, enemy.index("for _, player in Players:GetPlayers() do"), "checked before the player scan")
		self.assertIn("if not feared then", enemy, "Fear reuses the disengage path and skips the scan")
		status = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text(encoding="utf-8")
		helper = block(status, "local function npcControl(", "\nend\n")
		self.assertIn("Players:GetPlayerFromCharacter(model)", helper, "players are never taunted or feared")
		self.assertIn('parentModel:SetAttribute("MagicForcedTargetUntil"', status)
		self.assertIn('parentModel:SetAttribute("MagicFearUntil"', status)
		self.assertNotIn("Taunt", (ROOT / "src/server/Services/NascentAttackSelector.luau").read_text(encoding="utf-8"))

	def test_rush_is_server_moved_and_the_client_stands_down(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		validate = block(service, "local function validate(", "\nend\n")
		self.assertIn('definition.Form == "Rush"', validate, "Rush is refused before any cost is paid")
		self.assertIn("Movement.canMagicRush(state", validate)
		execute = block(service, "formContext.ExecuteRush = function(d)", "\n\tformContext.ApplyManipulation")
		self.assertIn("Ownership.claim(state.Root, token)", execute, "the server owns the root while rushing")
		self.assertIn("Movement.magicRush(state, now + duration)", execute)
		finish = block(service, "local function finishRush(", "\nend\n")
		self.assertIn("Ownership.release(root, rush.OwnershipToken)", finish)
		self.assertIn('elseif spell.Kind == "Rush" then\n\t\t\tif stepRush(spell, step) then', service)
		self.assertIn('elseif spell.Kind == "Rush" then\n\t\t\t\tfinishRush(spell, true)', service, "caster loss ends the rush")
		movement = (ROOT / "src/server/Services/MovementService.luau").read_text(encoding="utf-8")
		update = block(movement, "function Movement.update(", "\nend\n")
		self.assertIn("if now < (state.MagicRushUntil or 0) then", update, "speed checks stand down")
		self.assertIn('state.Character:SetAttribute("MagicRushUntil", untilTime)', movement)
		self.assertIn("or now < (state.MagicRushUntil or 0)", block(movement, "function Movement.dash(", "\nend\n"))
		client = (ROOT / "src/client/Controllers/MovementController.luau").read_text(encoding="utf-8")
		self.assertIn('GetAttributeChangedSignal("MagicRushUntil")', client)
		self.assertIn("if now < readyAt or stopDash or now < rushingUntil then", client, "no predicted dash mid-rush")
		rush = (ROOT / "src/server/Services/MagicRush.luau").read_text(encoding="utf-8")
		self.assertIn("Vector3.new(0, 8, 0), Vector3.new(0, -24, 0)", rush, "same ground probe as displaceTarget")

	def test_recast_routes_the_press_to_the_active_effect_for_free(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		start = block(service, "function Magic.start(", "\nend\n")
		route = start.index("RecastSpec.pick(active, player, definition.SpellId")
		self.assertLess(route, start.index("isSpellCooling(stats, definition.SpellId, now)"), "before the cooldown gate")
		self.assertLess(route, start.index("queueCast("), "no new cast, so no cost")
		self.assertIn('feedback(remote, player, "RECAST", definition, nil)', start)
		recast = block(service, "local function recastActive(", "\nend\n")
		self.assertIn('lifecycleState(record, "OnRecast"', recast, "counted on the record: TriggerCount = stage")
		self.assertIn('Schema.RecastForms = { "Projectile", "Field", "Aura", "Construct", "Rush" }', self.schema)
		recast_spec = (ROOT / "src/shared/Modules/MagicRecastSpec.luau").read_text(encoding="utf-8")
		self.assertIn('Spec.Forms = { "Projectile", "Field", "Aura", "Construct", "Rush" }', recast_spec)
		hud = (ROOT / "src/client/UI/HUD/SpellState.luau").read_text(encoding="utf-8")
		self.assertIn('or message.Result == "RECAST"', hud, "a recast does not restart the cooldown sweep")

	def test_construct_health_routes_hits_and_destroys_without_expiry(self):
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		execute = block(executors, "function Payloads.execute(", "\nend\n")
		self.assertIn("metadata.DamagesStructures and hitPart and context.DamageStructure", execute, "once per payload")
		self.assertIn("Damage = { TracksHumanoidTargets = true, DamagesStructures = true }", executors)
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		self.assertIn("ConstructHealth.damage(part, amount, caster)", service)
		self.assertIn("ConstructHealth.register(construct, model, player.UserId, maxHealth, nil, {", service)
		destroy = block(service, "local function destroyConstruct(", "\nend\n")
		self.assertIn("LifetimeSpec.claimExpiry(spell)", destroy, "a destroyed Construct never also runs OnExpire")
		self.assertIn('"OnDestroyed"', destroy)
		self.assertIn("if spell.Destroyed then\n\t\t\t\t\tdestroyConstruct(spell)", service)
		combat = (ROOT / "src/server/Services/CombatService.luau").read_text(encoding="utf-8")
		self.assertIn("ConstructHealth.damage(part, attack.Damage * state.DamageScale, state.Character)", combat)
		health = (ROOT / "src/server/Services/MagicConstructHealth.luau").read_text(encoding="utf-8")
		self.assertIn("HealthSpec.canDamage(", health, "owner and PvP rules")
		self.assertIn("StatCaps.damage(amount, profile)", health, "PvP damage caps apply to structures")
		# Persistent Constructs: saved health, batched writes, limit kept in step with MagicLab.
		persistent_spec = (ROOT / "src/shared/Modules/MagicPersistentConstructSpec.luau").read_text(encoding="utf-8")
		lab = (ROOT / "src/shared/Configuration/MagicLab.luau").read_text(encoding="utf-8")
		saved_limit = re.search(r"MaxHealth = (\d+) }", persistent_spec).group(1)
		self.assertIn(f"MaxConstructHealth = {saved_limit},", lab)
		self.assertIn("PersistentConstructStore.flushHealth()", service)
		self.assertIn("game:BindToClose(function()", service)
		builder = (ROOT / "src/server/Services/MagicConstructBuilder.luau").read_text(encoding="utf-8")
		self.assertIn("trackPersistentHealth(model, record.Id, record.OwnerUserId, record.MaxHealth, record.Health)", builder)
		self.assertIn("PersistentConstructStore.updateHealth(id, entry.Health)", builder)

	def test_field_traps_arm_consume_and_never_replicate_hidden_markers(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		self.assertIn("local armed = TrapSpec.armed(spell.Age, spell.ArmDelay or 0)", service)
		self.assertIn("if spell.RemainingLifetime > 0 and armed and now >= spell.NextInterval then", service)
		membership = block(service, "local function updateAreaMembership(", "\nend\n")
		self.assertIn("TrapSpec.consumes(spell.Definition.Field.ConsumeOnTrigger, #entered)", membership)
		# Both Field creation paths (cast and SpawnEffect) hide the marker and set the arm delay.
		self.assertEqual(service.count("Presentation.hideMarker(marker, player)"), 2)
		self.assertEqual(service.count("TrapSpec.armDelay("), 2)
		presentation = (ROOT / "src/server/Services/MagicPresentation.luau").read_text(encoding="utf-8")
		hide = block(presentation, "function Presentation.hideMarker(", "\nend\n")
		self.assertIn("marker.Parent = hiddenStorage()", hide, "hidden markers live outside Workspace")
		self.assertIn('game:GetService("ServerStorage")', presentation)
		self.assertIn("TrapSpec.canSee(viewer.UserId", presentation, "only non-opponents are sent the marker")
		finish = block(presentation, "function Presentation.finish(", "\nend\n")
		self.assertIn("if releaseHiddenMarker(part) then", finish)
		server = (ROOT / "src/server/init.server.luau").read_text(encoding="utf-8")
		self.assertIn('"MagicHiddenMarkers",', server)
		client = (ROOT / "src/client/init.client.luau").read_text(encoding="utf-8")
		self.assertIn('startController("MagicHiddenMarkerController")', client)

	def test_interception_runs_before_mitigation_without_recursion(self):
		damage = (ROOT / "src/server/Services/DamageService.luau").read_text(encoding="utf-8")
		apply = block(damage, "local function apply(", "\nend\n")
		hook = apply.index("if interceptor and not (eventContext and eventContext.Redirected == true) then")
		self.assertLess(apply.index("applyOutgoingStrength"), hook, "after the attacker's strength")
		self.assertLess(hook, apply.index("DamageRules.applyChannel"), "before every mitigation")
		self.assertLess(hook, apply.index("Defense.resolve"))
		spec = (ROOT / "src/shared/Modules/MagicInterceptionSpec.luau").read_text(encoding="utf-8")
		self.assertIn("eventContext.Periodic == true or eventContext.Redirected == true", spec)
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		self.assertIn("damageContext.Periodic = true", executors, "DoT ticks are marked")
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		self.assertIn("Damage.setInterceptor(function(", service)
		self.assertIn("Redirected = true,", service, "redirected damage is flagged")
		candidates = block(service, "local function interceptionCandidates(", "\nend\n")
		self.assertIn("depth >= Limits.MaxMagicEventDepth", candidates, "nested interception stops at the depth limit")
		dispatch = (ROOT / "src/server/Services/MagicTriggerDispatch.luau").read_text(encoding="utf-8")
		self.assertIn("hooks.intercept(step.Intercept)", dispatch)
		interception = (ROOT / "src/server/Services/MagicInterception.luau").read_text(encoding="utf-8")
		self.assertIn("kept += redirect.Amount", interception, "an undeliverable share returns to the holder")
		self.assertIn("if not Spec.eligible(hit.Context)", interception, "DoT ticks reach the hook but are never intercepted")

	def test_tether_snaps_shares_and_never_loops(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		self.assertIn('elseif spell.Kind == "Tether" then\n\t\t\tif stepTether(spell, step) then', service)
		finish = block(service, "	Finish = function(spell, how)", "\n\tend,\n")
		self.assertIn("LifetimeSpec.claimExpiry(spell)", finish, "a snap never also runs OnExpire")
		self.assertIn("Presentation.endTether(", finish)
		self.assertIn('if eventName == "OnBreak" and definition.Form == "Tether" then', service, "shields never fire the snap")
		self.assertIn("TetherSpec.toEnd(mine, Limits.MaxTethersPerCaster)", service)
		self.assertIn("TetherSpec.anchorFull(tetherAnchorCount(", service)
		interceptor = block(service, "Damage.setInterceptor(function(", "\nend)\n")
		self.assertLess(interceptor.index("Interception.resolve("), interceptor.index("shareSoulLinks("), "share after interception")
		share = block(service, "local function shareSoulLinks(", "\nend\n")
		self.assertIn("Shared = true,", share)
		self.assertIn("Redirected = true,", share, "shared damage is never intercepted or shared again")
		tether = (ROOT / "src/server/Services/MagicTether.luau").read_text(encoding="utf-8")
		self.assertIn("not Spec.shareable(eventContext)", tether)
		dispatch = (ROOT / "src/server/Services/MagicTriggerDispatch.luau").read_text(encoding="utf-8")
		self.assertIn("context.AnchorTargets[step.Anchor]", dispatch)
		presentation = (ROOT / "src/server/Services/MagicPresentation.luau").read_text(encoding="utf-8")
		self.assertIn('Instance.new("Beam")', block(presentation, "function Presentation.tether(", "\nend\n"))

	def test_transformation_modes_gate_restore_and_share_crowd_control(self):
		status = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text(encoding="utf-8")
		diminish = block(status, "function Status.diminish(", "\nend\n")
		self.assertIn("stunHistory[humanoid]", diminish, "Polymorph shares Stun's diminishing returns")
		self.assertIn("stunHistory[humanoid]", block(status, "function Status.stun(", "\nend\n"))
		self.assertIn("* (speedFactors[state.Humanoid] or 1)", status, "the critter walks slower")
		transform = (ROOT / "src/server/Services/MagicTransformService.luau").read_text(encoding="utf-8")
		self.assertIn('Spec.isBoss(model:GetAttribute("MagicBoss"), model:GetAttribute("MissionRole"))', transform)
		self.assertIn("humanoid.Died:Connect", transform, "death restores")
		visual = (ROOT / "src/server/Services/MagicTransformVisual.luau").read_text(encoding="utf-8")
		self.assertIn("item:IsDescendantOf(handle.Model)", visual, "restore only touches the same model")
		router = (ROOT / "src/server/Networking/ActionRouter.luau").read_text(encoding="utf-8")
		self.assertIn('state.Humanoid:GetAttribute("MagicPolymorphed") == true', router)
		self.assertEqual(router.count("meleeLoadoutFor(player, state)"), 3, "light, heavy and block use the shapeshift")
		enemy = (ROOT / "src/server/Services/EnemyService.luau").read_text(encoding="utf-8")
		self.assertIn('humanoid:GetAttribute("MagicPolymorphed") == true', enemy, "critters do not attack")
		damage = (ROOT / "src/server/Services/DamageService.luau").read_text(encoding="utf-8")
		self.assertIn("Transform.onDamaged(target, attacker)", damage)
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		self.assertIn("for _, candidate in Transform.cleanseCandidates(humanoid) do", executors, "Cleanse removes them")
		self.assertIn("payload.BreakOnDamage ~= false or cap ~= nil", executors, "always breaks on damage against players")
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		start = block(service, "function Magic.start(", "\nend\n")
		self.assertLess(start.index("Transform.endShapeshift(state.Humanoid, definition.SpellId)"), start.index("isSpellCooling("), "recast ends it for free")
		self.assertIn('ctx.DamageContext.EmitEvent("OnTransformEnd", targetHumanoid)', service)
		policy = (ROOT / "src/shared/Modules/CombatPolicy.luau").read_text(encoding="utf-8")
		self.assertIn('return payload.Mode == "Polymorph"', policy)

	def test_environment_reactions_are_wired(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		applied = service[service.index("Damage.Applied:Connect(function(") :]
		self.assertIn("World.Reactions.chain(", applied[:400], "the chain runs where spell hits land")
		self.assertIn("profile.MaxWetChainPlayerJumps", service, "PvP chain caps")
		self.assertIn('if event == "OnImpact" and typeof(eventState.HitPart) == "Instance"', service, "impacts react")
		self.assertIn('CollectionService:HasTag(part, "Flammable")', service)
		self.assertIn('CollectionService:HasTag(part, "Water")', service)
		self.assertIn("hit.Material == Enum.Material.Water", service, "Terrain water")
		self.assertIn("Limits.IcePlatformHealth", service, "the platform has Construct health")
		self.assertIn("IgnoreEnvironment = definition.IgnoreEnvironment == true or nil", service)
		self.assertIn("return field\n", service, "spawnEffect returns the Field for the per-caster limit")
		self.assertIn("return construct\n", service)
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		self.assertIn("damageContext.WetBefore[target] = context.IsWet(target)", executors, "Wet before reactions")
		runtime = (ROOT / "src/server/Services/MagicEnvironmentReactions.luau").read_text(encoding="utf-8")
		self.assertIn("Redirected = true,", runtime, "hops are marked like redirected damage")
		self.assertIn("Depth = context.Depth + 1,", runtime)
		self.assertIn("IgnoreEnvironment = true,", runtime, "spawned fires and platforms never react")
		config = (ROOT / "src/shared/Configuration/MagicLab.luau").read_text(encoding="utf-8")
		self.assertIn("FlammableMaterials = {},", config, "no flammable materials by default")
		for path in ("src/client/UI/GuidedSpellForge.luau", "src/client/Controllers/MagicLabController.luau"):
			editor = (ROOT / path).read_text(encoding="utf-8")
			self.assertIn('"Ignore the world"', editor, path)
			self.assertIn("draft.IgnoreEnvironment = if", editor, path)
		preview = (ROOT / "src/client/UI/ForgePreviewPanel.luau").read_text(encoding="utf-8")
		self.assertIn("EnvironmentSpec.previewLine(draft.Element, draft.IgnoreEnvironment)", preview)

	def test_companion_command_cast_slot_uses_the_cast_definition(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		start = service.index("local function execute(")
		end = service.index("\nend\n", start)
		self.assertIn("CompanionSpellPolicy.requiresCommandSlot(definition)", service[start:end])
		self.assertNotIn("requiresCommandSlot(d)", service[start:end], "`d` is not defined in execute")

	def test_blood_magic_is_paid_as_health_not_damage(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		blood = (ROOT / "src/server/Services/MagicBloodMagic.luau").read_text(encoding="utf-8")
		self.assertNotIn("Damage", blood.split("local Blood = {}")[1].replace("damage", ""), "paying health never deals damage")
		self.assertIn("humanoid.Health = value", service, "health is set directly")
		self.assertIn("return \"IMPOSSIBLE\", BloodMagic.FloorReason", service, "the cast check refuses at the floor")
		self.assertIn("BloodMagic.pay(state.Humanoid, healthDue, setCasterHealth)", service)
		pay = service.index("BloodMagic.pay(state.Humanoid, healthDue, setCasterHealth)")
		self.assertLess(service.index("paidSpecialResources = true"), pay, "paid after every other cost")
		self.assertLess(pay, service.index("feedback(remote, player, result, definition, {"), "and before any effect runs")
		self.assertIn("BloodMagic.PlayersOnlyReason", service, "companion and command casts are refused")
		self.assertIn("definition._HealthPaid = healthDue", service)
		self.assertIn('elseif source == "HealthPaid" then', service)
		self.assertEqual(service.count("BloodMagic.upkeep("), 2, "health upkeep in both upkeep loops")
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		self.assertIn("profile.MaxHealthPaidBonus", executors, "PvP cap on the HealthPaid bonus")
		for path in ("src/shared/Modules/MagicLabCost.luau", "src/shared/Modules/SpellProgressionRules.luau"):
			reprice = (ROOT / path).read_text(encoding="utf-8")
			self.assertIn("HealthForMana = previous.HealthForMana", reprice, f"{path} keeps blood costs")
		forge = (ROOT / "src/client/UI/GuidedSpellForge.luau").read_text(encoding="utf-8")
		lab = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text(encoding="utf-8")
		for path, editor in (("Forge", forge), ("Lab", lab)):
			self.assertIn('"PAY WITH HEALTH"', editor, path)
			self.assertIn("BloodCostSpec.costLabel(", editor, f"{path} shows mana + HP")
			self.assertIn("BloodCostSpec.paidScalePreset(", editor, f"{path} offers HealthPaid scaling")
		self.assertIn("ActionFlow.casterHealthBelow(50)", lab, "stronger-when-hurt branch")
		hud = (ROOT / "src/client/UI/HUD/SpellBar.luau").read_text(encoding="utf-8")
		self.assertIn("slot.HealthCost.Text = info.HealthCost", hud, "the spell slot shows the health cost")

	def test_spells_as_targets_dispel_force_and_lenses_are_wired(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		dispel = block(service, "spellRuntime.dispel = function(", "\nend\n")
		self.assertIn('tetherDeps.Emit(record, "OnBreak")', dispel, "a dispelled Tether snaps")
		self.assertIn('tetherDeps.Finish(record, "Snap")', dispel)
		self.assertIn("if record.Dispelled then", dispel, "OnDispelled runs once")
		self.assertIn('"OnDispelled"', dispel)
		self.assertIn("LifetimeSpec.claimExpiry(record)", dispel, "no OnExpire after a dispel")
		self.assertIn("depth < Limits.MaxMagicEventDepth", dispel)
		self.assertIn("record:Destroy()", dispel, "a saved Construct is removed (its store record follows)")
		force = block(service, "spellRuntime.force = function(", "\nend\n")
		self.assertIn("SpellTargetSpec.pushTravel(distance, hit and hit.Distance, 1, 0.5)", force, "stops at walls")
		self.assertIn("profile.MaxSpellForceDistance", force)
		self.assertIn("spellRuntime.lens(spell, Geometry.areaSize(d.Geometry, scaledArea))", service)
		self.assertIn("for _, element in spell.LensMarks do", service, "lens marks land on impact")
		finder = block(service, "FindIncomingProjectile = function(", "\n\t\tend,\n")
		self.assertIn("projectilesNear(", finder, "Absorb/Reflect share the lens scan")
		self.assertIn("budget.SpellTouched", service, "once per spell target per root cast")
		dispatch = (ROOT / "src/server/Services/MagicTriggerDispatch.luau").read_text(encoding="utf-8")
		self.assertIn('if matches and step.TargetKind == "Spell" then', dispatch)
		self.assertIn("stepContext.SpellTargets = spells", dispatch)
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		self.assertIn("context.DispelSpells(payload, context.SpellTargets)", executors)
		self.assertIn("context.ForceSpells(payload, context.SpellTargets)", executors)
		for path in ("src/client/UI/GuidedSpellForge.luau", "src/client/Controllers/MagicLabController.luau"):
			editor = (ROOT / path).read_text(encoding="utf-8")
			self.assertIn('"Target spells"', editor, path)
			self.assertIn('"Which spells"', editor, path)
			self.assertIn('"LENS"', editor, path)
			self.assertIn("SpellTargetSpec.syncStep(", editor, f"{path} keeps TargetKind in step with its payloads")

	def test_stealth_hides_from_monsters_and_player_path_is_behind_the_setting(self):
		enemy = (ROOT / "src/server/Services/EnemyService.luau").read_text(encoding="utf-8")
		self.assertEqual(enemy.count("StealthSpec.hiddenFromMonsters("), 2, "scan skip + lose a target that stealths")
		damage = (ROOT / "src/server/Services/DamageService.luau").read_text(encoding="utf-8")
		self.assertIn("Status.breakStealth(attackerHumanoid)", damage, "dealing damage ends Stealth")
		status = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text(encoding="utf-8")
		reveal = block(status, "function Status.reveal(", "\nend\n")
		self.assertIn("Status.breakStealth(humanoid)", reveal, "a Reveal ends Stealth")
		caps = (ROOT / "src/shared/Configuration/SpellStatCaps.luau").read_text(encoding="utf-8")
		self.assertEqual(caps.count("StealthHidesFromPlayers = false"), 2, "off in both PvP profiles")
		controller = (ROOT / "src/client/Controllers/MagicStealthController.luau").read_text(encoding="utf-8")
		self.assertIn("if not StealthSpec.hidesFromPlayers(CapProfiles) then", controller)
		self.assertIn('startController("MagicStealthController")', (ROOT / "src/client/init.client.luau").read_text(encoding="utf-8"))

	def test_hud_cooldown_follows_cooldown_rate(self):
		state = (ROOT / "src/client/UI/HUD/SpellState.luau").read_text(encoding="utf-8")
		self.assertIn('AttributeSpec.multiplier(player.Character, "CooldownRate")', state)
		self.assertIn("State.CooldownDurations[slot] = duration", state)
		self.assertIn("definition.Casting.RecoveryTime", state)
		bar = (ROOT / "src/client/UI/HUD/SpellBar.luau").read_text(encoding="utf-8")
		self.assertIn("SpellState.CooldownDurations[index]", bar)
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		self.assertIn("/ cooldownRate", service)
		# Charge and wind-up visuals are timed by the server, already scaled by CastSpeed.
		self.assertIn("definition.Casting.MaximumCharge / chargeRate", service)
		self.assertIn("definition.Casting.CastTime / castSpeed", service)

	def test_elemental_marks_use_the_selected_element_and_shared_status_path(self):
		payloads = block(self.schema, "Schema.Payloads = {", "\nfor kind, payload in Schema.Payloads")
		self.assertIn("ElementalMark = {", payloads)
		self.assertIn("ConsumeElementalMark = {", payloads)
		self.assertIn("MaxElementalMarkStacks = 5", (ROOT / "src/shared/Configuration/MagicLab.luau").read_text(encoding="utf-8"))
		limits = (ROOT / "src/shared/Configuration/MagicLab.luau").read_text(encoding="utf-8")
		# ElementalInteractions is one list: starter entries have Incoming and no Existing.
		interactions = block(limits, "\tElementalInteractions = {", "\n\t},\n")
		for element in ("Fire", "Water", "Ice", "Lightning", "Earth", "Wind", "Poison"):
			self.assertRegex(
				interactions,
				rf'\{{\n\t\t\tIncoming = "{element}",\n\t\t\tEffects = \{{',
				"Every authored element should have a starter interaction",
			)
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		self.assertIn("context.DamageContext.Element", executors)
		self.assertIn("Status.elementalMark(", executors)
		self.assertIn("Status.consumeElementalMark(", executors)
		self.assertIn("ElementalInteractions.effectsFor(element", executors)
		# Starter and reaction effects go through Payloads.execute (hostility filter + PvP caps).
		secondary = block(executors, "local function applySecondary(", "\nend\n")
		self.assertIn("Payloads.execute({ effect }, effectContext)", secondary)
		# Reaction effects: credited to the incoming caster, paid from the cascade
		# budget, and capped (Chain damage and plain effects via applySecondary).
		reaction = block(executors, "local function applyReaction(", "\nend\n")
		self.assertIn("OperationBudget.spend(budget, 1 + #reaction.Effects)", reaction)
		self.assertEqual(reaction.count("applySecondary("), 2, "Chain damage and plain effects")
		self.assertIn('if target:IsA("Humanoid") and not context.FromMark and not context.FromReaction then', executors)
		# Reactions are checked when the mark lands, before it stacks.
		status_source = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text(encoding="utf-8")
		mark = block(status_source, "function Status.elementalMark(", "\nfunction ")
		self.assertLess(mark.index("Status.checkReaction(humanoid, element)"), mark.index("ElementalMarkSpec.apply("))
		status = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text(encoding="utf-8")
		self.assertIn("ElementalMarkSpec.apply(", status)
		self.assertIn('"MagicElementalMarks"', status)
		conditions = (ROOT / "src/server/Services/MagicConditions.luau").read_text(encoding="utf-8")
		self.assertIn('GetAttribute("MagicElementalMarks")', conditions)
		spell_spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text(encoding="utf-8")
		self.assertIn("Elemental marks require a non-neutral selected Element", spell_spec)

	def test_humanoid_target_tracking_is_payload_metadata_not_a_kind_branch(self):
		executor_source = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
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
		behavior_spec = (ROOT / "src/shared/Modules/ProjectileBehaviorSpec.luau").read_text(encoding="utf-8")
		behavior_definitions = block(behavior_spec, "local Definitions: { [string]: any } = {", "\n}\n\nlocal Spec")
		executor_source = (ROOT / "src/server/Services/MagicProjectileBehaviorExecutors.luau").read_text(encoding="utf-8")
		definitions = top_level_table_keys(behavior_definitions)
		handlers = set(re.findall(r"^executors\.([A-Za-z][A-Za-z0-9]*) = \{", executor_source, re.MULTILINE))
		self.assertEqual(definitions, handlers, "Every selectable Projectile behavior must have a server handler")

	def test_each_generic_behavior_has_a_runtime_handler(self):
		behavior_definitions = block(self.schema, "Schema.Behaviors = {", "\nfor formName, events in Schema.Behaviors")
		executor_source = (ROOT / "src/server/Services/MagicBehaviorExecutors.luau").read_text(encoding="utf-8")
		executor_table = block(
			executor_source,
			"local executors: { [string]: (Context, any) -> () } = {",
			"\n}\n\nfunction Behaviors.execute",
		)
		# Behaviors are declared in the table literal or added afterwards as
		# Schema.Behaviors.<Name> = { (SpawnEffect builds on Explode's events).
		definitions = top_level_table_keys(behavior_definitions) | set(
			re.findall(r"^Schema\.Behaviors\.([A-Za-z][A-Za-z0-9]*) = \{", self.schema, re.MULTILINE)
		)
		handlers = set(re.findall(r"^\t([A-Za-z][A-Za-z0-9]*) = function", executor_table, re.MULTILINE))
		self.assertEqual(definitions, handlers, "Every selectable generic Behavior must have a server handler")

	def test_environmental_area_visuals_share_the_validated_visual_registry(self):
		visual_spec = (ROOT / "src/shared/Modules/MagicVisualSpec.luau").read_text(encoding="utf-8")
		schema = (ROOT / "src/shared/Configuration/MagicSchema.luau").read_text(encoding="utf-8")
		lab = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text(encoding="utf-8")
		presentation = (ROOT / "src/server/Services/MagicPresentation.luau").read_text(encoding="utf-8")
		magic_service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		presentation_controller = (ROOT / "src/client/Controllers/MagicPresentationController.luau").read_text(encoding="utf-8")
		presentation_config = (ROOT / "src/shared/Configuration/MagicPresentation.luau").read_text(encoding="utf-8")
		self.assertIn('Spec.EnvironmentalVisuals = { "None", "Motes", "GroundMist" }', visual_spec)
		self.assertIn("EnvironmentalVisuals = VisualSpec.EnvironmentalVisuals", schema)
		self.assertIn('select(\n\t\t\t\t\t"Environmental layer"', lab)
		# EnvironmentalVisual stays valid in saved data but no longer drives
		# composition (SpellVFXAnalyzer.LegacyFields).
		analyzer = (ROOT / "src/shared/SpellVFXSystem/Core/SpellVFXAnalyzer.luau").read_text(encoding="utf-8")
		self.assertIn('"EnvironmentalVisual",', block(analyzer, "Analyzer.LegacyFields = {", "\n}"))
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
		runtime = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
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
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		construct = block(self.schema, "Construct = {", "\n\tManipulation = {")
		self.assertIn('"OnExpire"', construct)
		self.assertIn('"OnProximity"', construct)
		enchantment = block(self.schema, "\n\tSelfEnhancement = {", "\n\tConstruct = {")
		enchantment_events = block(enchantment, "\t\tEvents = set({", "})")
		for event in ("OnCast", "OnExpire", "OnDamageTaken", "OnMeleeHit", "OnHolderDealtDamage", "OnTargetDeath", "OnCasterDeath", "OnProximity"):
			self.assertIn(f'"{event}"', enchantment_events)
		expiry_helper = block(service, "local function expireSelfEnhancement(player: Player, effect: any, reason: string?)", "\nlocal function endOwnedEnchantments")
		self.assertIn("LifetimeSpec.claimExpiry(effect)", expiry_helper)
		# Events run from the owner (caster) at the holder's position, targeting the holder.
		self.assertIn("dispatchClaimedExpiry(effect, position, { humanoid }, nil, owner, player)", expiry_helper)
		lifecycle = block(service, "local function dispatchClaimedExpiry(", "\nlifecycleState = function")
		self.assertIn('hasEvent(effect.Definition, "OnExpire")', lifecycle)
		self.assertIn('lifecycleState(effect, "OnExpire"', lifecycle)
		self.assertIn("LifetimeSpec.claimExpiry(effect)", block(service, "local function emitExpiry(", "\nlifecycleState = function"))
		start = block(service, "function Magic.start(", "\nfunction Magic.release")
		self.assertIn('endOwnedEnchantments(player, definition.SpellId, "Toggle")', start, "Toggle-off must run expiry exactly once")
		owned = block(service, "local function endOwnedEnchantments(", "\nend\n")
		self.assertIn("expireSelfEnhancement(player, effect, reason)", owned)
		channel_finish = block(service, "finishBeamChannel = function(channel)", "\nfunction Magic.release")
		self.assertIn("expireSelfEnhancement(channel.Player, effect)", channel_finish)
		reset = block(service, "function Magic.reset(player)", "\nfunction Magic.remove")
		self.assertIn('expireSelfEnhancement(player, effect, "OwnerDeath")', reset, "Reset cleanup must run expiry")
		self.assertIn("expireSelfEnhancement(player, effect, reason)", service, "Natural termination must run expiry")
		self.assertIn("expireConstruct(spell)", service, "Caster cleanup must dispatch Construct expiry")
		self.assertIn("expireConstruct(channel)", service, "Held Construct cleanup must dispatch expiry")

	def test_expiry_event_authoring_matches_beam_and_wave_lifetimes(self):
		schema = (ROOT / "src/shared/Configuration/MagicSchema.luau").read_text(encoding="utf-8")
		spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text(encoding="utf-8")
		controller = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text(encoding="utf-8")
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
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		self.assertGreaterEqual(len(re.findall(r'"OnImpact",\s+state.Character,\s+endpoint', service)), 2)
		self.assertRegex(service, r'"OnImpact",\s+spell.Caster,\s+endpoint')
		self.assertGreaterEqual(len(re.findall(r'if hit then\s+emit\(\s*d,\s*"OnImpact"', service)), 2)
		single_beam = block(service, 'if d.Beam.Pattern == "Cascade" then', "\n\tformContext.ExecuteWave = function(d)")
		self.assertRegex(single_beam, r'emit\(\s*d,\s*"OnImpact",\s*state.Character,\s*endpoint')
		self.assertNotRegex(single_beam, r'if hit then\s+emit\(\s*d,\s*"OnImpact"')
		self.assertIn("maximum-range endpoint if unobstructed", self.schema)
		self.assertIn("resolvedPotency,\n\t\t\t\tposition", service)
		summons = (ROOT / "src/server/Services/SummonService.luau").read_text(encoding="utf-8")
		self.assertIn('if spawnAt == "Event"', summons)
		self.assertIn("#group.Slots + countPerTrigger", summons)
		self.assertIn('group.SpawnAt == "Event" and command == "Protect"', summons)
		self.assertIn('Options = { "Caster", "Event" }', self.schema)
		self.assertIn('Kind = "Summon",\n\t\t\t\t\tArchetype = "Wisp"', self.lab_test)

	def test_beam_cascade_is_bounded_server_dispatched_and_testbed_unlocked(self):
		beam = block(self.schema, "Beam = {", "\n\tWave = {")
		self.assertIn('Pattern = "Single"', beam)
		self.assertIn('Options = { "Single", "Cascade" }', beam)
		spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text(encoding="utf-8")
		self.assertIn('d.Beam.Pattern == "Cascade"', spec)
		self.assertIn('strikeCount % 1 ~= 0', spec)
		self.assertIn('beamExtraStrikes * 2.5', spec)
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		self.assertIn('Kind = "BeamCascade"', service)
		self.assertIn("resolveBeamCascadeStrike(spell, spell.StrikeIndex)", service)
		self.assertIn('local hit = sweep(start, delta, spell.Caster, nil, beam.Width / 2)', service)
		self.assertIn('"OnImpact"', service)
		lab_config = (ROOT / "src/shared/Configuration/MagicLab.luau").read_text(encoding="utf-8")
		# Discovery and Locus stat progression were removed; nothing may gate on them.
		self.assertNotIn("ProgressionEnabled", lab_config)
		self.assertNotIn("ProgressionEnabled", service)
		lab = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text(encoding="utf-8")
		self.assertNotIn("LocusRequirementSpec", lab)
		summons = (ROOT / "src/server/Services/SummonService.luau").read_text(encoding="utf-8")
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
		self.assertIn("and definition.Forms[d.Form] == true", (ROOT / "src/shared/Modules/SpellSpec.luau").read_text(encoding="utf-8"))
		self.assertIn('schema.supportsBehavior("Explode", "Projectile", "OnSpawn")', self.lab_test)
		self.assertIn('emit(definition, "OnSpawn"', (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8"))
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		channel_spawn = block(service, "local function spawnChannelProjectile(channel)", "\nend\n")
		self.assertNotIn('emit(definition, "OnCast"', channel_spawn)
		self.assertIn('emit(definition, "OnSpawn"', channel_spawn)
		self.assertIn('emit(d, "OnCast", state.Character, start', service)

	def test_object_target_channel_validation_normalizes_interval_alias(self):
		spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text(encoding="utf-8")
		self.assertIn('local runtimeEvent = if event == "OnInterval" then "OnTick" else event', spec)
		object_filter = block(spec, "local function hasOnlyObjectInteractionPayloads(d)", "\nfunction Spec.validate")
		self.assertIn('and runtimeEvent == "OnTick"', object_filter)
		self.assertIn('Object-targeted Beam OnInterval should alias', self.lab_test)
		self.assertIn('Object-targeted Wave OnInterval should alias', self.lab_test)
		trigger_spec_path = ROOT / "src/shared/Modules/MagicTriggerSpec.luau"
		trigger_spec = trigger_spec_path.read_text(encoding="utf-8")
		self.assertIn("TriggerSpec.normalize(d.Triggers)", spec)
		self.assertIn('event ~= "OnInterval"', trigger_spec)
		self.assertIn("table.insert(result.OnTick, action)", trigger_spec)
		self.assertIn("Normalizing both channel timing names must preserve both steps", self.lab_test)

	def test_channeled_beam_and_wave_expiry_resolve_final_validated_targets(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		expiry = block((ROOT / "src/server/Services/MagicWorldQuery.luau").read_text(encoding="utf-8"), "local function finalChannelTargets(", "\nend\n")
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
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		cleanup = block(service, "local function clearActive(player)", "\n-- Mana, Strain and special resources")
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
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		cleanup = block(service, "local function clearActive(player)", "\n-- Mana, Strain and special resources")
		for kind in ("ProjectileLinger", "Projectile"):
			branch = block(
				cleanup,
				f'elseif active[i].Kind == "{kind}" then',
				"\n\t\t\telseif active[i].Kind ==",
			)
			self.assertIn("expireProjectile(spell)", branch)
			self.assertIn("Presentation.finish(spell.Visual)", branch)

	def test_caster_death_expires_projectiles_and_linger_hazards(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
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
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		reset = block(service, "function Magic.reset(player)", "\nfunction Magic.remove")
		self.assertLess(
			reset.index("clearActive(player)"),
			reset.index("Summons.clearOwner(player)"),
			"Active spell OnExpire payloads must not recreate a group after reset cleanup",
		)
		self.assertLess(
			reset.index('expireSelfEnhancement(player, effect, "OwnerDeath")'),
			reset.index("Summons.clearOwner(player)"),
			"Self Enhancement OnExpire payloads must not recreate a group after reset cleanup",
		)

	def test_construct_casts_without_a_target_and_attaches_only_when_the_ray_hits(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		validation = block(service, "local function validate(", "\nlocal function refreshHolder")
		placement = block((ROOT / "src/server/Services/MagicWorldQuery.luau").read_text(encoding="utf-8"), "local function constructPlacement(", "\nend\n")
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
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		context = block(service, "local function context(", "emit = function(")
		impact = block(service, "spell.CurrentPhase = \"Impact\"", "local continue = ProjectileBehaviors.impact")
		self.assertIn("HitPart = runtimeState and runtimeState.HitPart", context)
		self.assertLess(impact.index("spell.HitPart = hit.Instance"), impact.index("emit("))
		self.assertIn("spell.HitPart = nil", impact)
		executors = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		self.assertIn("BodyRegion.multiplier(payload, hitPart and hitPart.Name)", executors)
		self.assertIn("damageContext.RegionMultiplier = multiplier", executors)
		damage = (ROOT / "src/server/Services/DamageService.luau").read_text(encoding="utf-8")
		self.assertLess(damage.index("incoming *= math.clamp(regionMultiplier, 0, 4)"), damage.index("DamageRules.applyChannel"))
		spec = (ROOT / "src/shared/Configuration/MagicSchema.luau").read_text(encoding="utf-8")
		for region in ("Head", "Torso", "Arm", "Leg", "Other"):
			self.assertIn(f"{region}Multiplier = 1", spec)

	def test_spell_identity_tags_are_editable_and_server_bounded(self):
		identity = (ROOT / "src/shared/Modules/MagicSpellIdentitySpec.luau").read_text(encoding="utf-8")
		self.assertIn("MaxTags = 16", identity)
		self.assertIn("MaxTagLength = 48", identity)
		self.assertIn("function Spec.validateTags(tags)", identity)
		spell_spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text(encoding="utf-8")
		self.assertIn("SpellIdentitySpec.validateTags(d.Tags)", spell_spec)
		ui = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text(encoding="utf-8")
		self.assertIn('"Spell tags"', ui)
		self.assertIn("SpellIdentitySpec.parse(box.Text)", ui)
		conditions = (ROOT / "src/server/Services/MagicConditions.luau").read_text(encoding="utf-8")
		self.assertIn("Tags = SpellIdentitySpec.encode(castState.SpellTags or {})", conditions)
		self.assertIn("context.SpellState.SpellTags = definition.Tags or {}", conditions)
		condition_spec = (ROOT / "src/shared/Modules/MagicConditionSpec.luau").read_text(encoding="utf-8")
		self.assertIn('Tags = { Kind = "String", MaxLength = 48, Operators = { "Has", "DoesNotHave" } }', condition_spec)
		self.assertIn('Tags = EnvironmentZoneSpec.encodeTags(target and target:GetAttribute("MagicConditionTags") or "")', conditions)
		self.assertIn('Tags = { Kind = "String", MaxLength = 24, Operators = { "Has", "DoesNotHave" } }', condition_spec)

	def test_auto_material_is_shared_by_server_presentation_and_editor_preview(self):
		visual_spec = (ROOT / "src/shared/Modules/MagicVisualSpec.luau").read_text(encoding="utf-8")
		self.assertIn("function Spec.autoMaterial(principle, expression, form)", visual_spec)
		presentation = (ROOT / "src/server/Services/MagicPresentation.luau").read_text(encoding="utf-8")
		self.assertIn("VisualSpec.autoMaterial(", presentation)
		ui = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text(encoding="utf-8")
		self.assertIn("VisualSpec.autoMaterial(definition.Source.Principle, definition.Source.Expression, definition.Form)", ui)

	def test_discovery_and_locus_persistence_are_removed(self):
		for path in (
			"src/server/Services/MagicDiscoveryService.luau",
			"src/shared/Modules/MagicDiscoverySpec.luau",
			"src/shared/Modules/MagicLocusProfile.luau",
			"src/shared/Modules/MagicLocusProgressionSpec.luau",
		):
			self.assertFalse((ROOT / path).exists(), path + " was removed")
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		self.assertNotIn("DataStoreService", service, "Locus resources are no longer persisted")
		self.assertNotIn("Discovery", (ROOT / "src/server/Networking/ActionRouter.luau").read_text(encoding="utf-8"))
		locus_config = (ROOT / "src/shared/Configuration/MagicLocus.luau").read_text(encoding="utf-8")
		self.assertNotIn("Persistence", locus_config)
		self.assertNotIn("PracticeCastsPerRank", locus_config)
		lab = (ROOT / "src/server/Services/MagicLabService.luau").read_text(encoding="utf-8")
		apply = block(lab, 'if action == "Apply" then', '\n\t\telseif action == "Cast" then')
		self.assertLess(apply.index("Spec.validate(data)"), apply.index("definitions[player][slot] = definition"))
		self.assertIn("scheduleSave(player)", apply)
		ui = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text(encoding="utf-8")
		for kind in ("Expression", "Palette", "Shape"):
			self.assertNotIn('GetAttribute("MagicUnlock' + kind, ui)
		forge = (ROOT / "src/client/UI/GuidedSpellForge.luau").read_text(encoding="utf-8")
		self.assertIn("for _, formName in schema.FormOrder or {} do", forge)
		self.assertIn("schema.supportsPrincipleForm(principle(), formName)", forge)

	def test_magic_focus_casts_its_own_registered_spells_server_side(self):
		items = (ROOT / "src/shared/Configuration/Items.luau").read_text(encoding="utf-8")
		spells = (ROOT / "src/shared/Configuration/Spells.luau").read_text(encoding="utf-8")
		registered = set(re.findall(r'^\t([A-Za-z0-9_]+) = \{\n\t\tSpellId = "([A-Za-z0-9_]+)"', spells, re.MULTILINE))
		registered_ids = {spell_id for _, spell_id in registered}
		focus_ids = re.findall(r'(?:PrimarySpellId|AreaSpellId) = "([A-Za-z0-9_]+)"', items)
		self.assertTrue(focus_ids)
		self.assertTrue(set(focus_ids) <= registered_ids, "the Magic Focus must only route to registered spells")
		self.assertFalse((ROOT / "src/shared/Configuration/MagicProfiles.luau").exists(), "Focus profiles were removed")
		self.assertFalse((ROOT / "src/client/Controllers/AwakeningController.luau").exists(), "profile picker was removed")
		self.assertNotIn("MagicAwakeningSelect", (ROOT / "src/shared/Networking/Protocol.luau").read_text(encoding="utf-8"))
		equipment = (ROOT / "src/server/Services/EquipmentService.luau").read_text(encoding="utf-8")
		self.assertIn("item.PrimarySpellId", equipment)
		self.assertNotIn("payload.", block(equipment, "function Equipment.magicCast", "\nend"), "focus casts must not trust client data")

	def test_status_expiry_is_shared_and_time_dilation_is_removed_before_rate_calculation(self):
		service = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text(encoding="utf-8")
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
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		payloads = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		target_death = (ROOT / "src/shared/Modules/MagicTargetDeathSpec.luau").read_text(encoding="utf-8")
		self.assertIn("ctx.TargetDeathCallback = function(targetHumanoid)", service)
		self.assertIn('ctx.DamageContext.EmitEvent("OnTargetDeath", targetHumanoid, { DeathCause = "DiedWhileAffected" })', service)
		self.assertIn("TargetDeathSpec.claim(runtime, targetHumanoid)", service)
		self.assertIn("TargetDeathSpec.claim(spell.RuntimeOrigin or spell, target)", service)
		self.assertIn("effect.Target.Died:Connect", payloads)
		self.assertIn("task.defer(callback)", payloads)
		self.assertIn("effect.DeathConnection:Disconnect()", payloads)
		self.assertIn("context.TargetDeathCallback and context.TargetDeathCallback(target)", payloads)
		status = (ROOT / "src/server/Services/MagicStatusEffectService.luau").read_text(encoding="utf-8")
		self.assertIn("OnTargetDeath: ((Humanoid) -> ())?", status)
		self.assertIn("effect.OnTargetDeath = onTargetDeath", status)
		self.assertIn("task.defer(callback, humanoid)", status)
		control = (ROOT / "src/server/Services/MagicControlService.luau").read_text(encoding="utf-8")
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
		self.assertIn("MaxPeriodicEffectsGlobal = 256", (ROOT / "src/shared/Configuration/MagicLab.luau").read_text(encoding="utf-8"))
		self.assertIn("MaxPeriodicEffectsPerCaster = 32", (ROOT / "src/shared/Configuration/MagicLab.luau").read_text(encoding="utf-8"))
		self.assertIn("function Spec.claim(runtime, target)", target_death)

	def test_beam_damage_uses_the_server_raycast_hit_part_for_region_scaling(self):
		# MagicWorldQuery holds the channel end-target sweep extracted from MagicService.
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8") + (ROOT / "src/server/Services/MagicWorldQuery.luau").read_text(encoding="utf-8")
		payloads = (ROOT / "src/server/Services/MagicPayloadExecutors.luau").read_text(encoding="utf-8")
		self.assertIn("HitPart = if not objectTarget and hit then hit.Instance else nil", service)
		self.assertIn("channel.HitPart = if not channel.ObjectTarget and hit then hit.Instance else nil", service)
		self.assertIn("spell.HitPart = if not spell.ObjectTarget and hit then hit.Instance else nil", service)
		final_targets = block(service, "local function finalChannelTargets(channel)", "\nend")
		self.assertIn("channel.HitPart = if not channel.ObjectTarget and hit then hit.Instance else nil", final_targets)
		self.assertIn("local hitPart = damageContext.HitPart", payloads)
		self.assertIn("damageContext.RegionMultiplier = multiplier", payloads)

	def test_condition_bound_channels_are_bounded_and_exposed_in_the_lab(self):
		spell_spec = (ROOT / "src/shared/Modules/SpellSpec.luau").read_text(encoding="utf-8")
		lifetime_validation = block(spell_spec, "local life = d.Lifetime", "local rules = d.TargetRules")
		self.assertIn('c.Mode == "Channeled" and life.Mode == "UntilConditionFails" and life.Duration ~= nil', lifetime_validation)
		self.assertIn('d.Form == "Beam"', lifetime_validation)
		self.assertIn('d.Form == "Wave"', lifetime_validation)
		self.assertIn('CastingSpec.isHeldMode(c.Mode) and life.Duration == nil', lifetime_validation)
		controller = (ROOT / "src/client/Controllers/MagicLabController.luau").read_text(encoding="utf-8")
		self.assertIn('local conditionBoundChannel = draft.Casting.Mode == "Channeled"', controller)
		self.assertIn('draft.Form == "Projectile" or conditionBoundChannel', controller)
		self.assertIn("Maximum channel duration (seconds)", controller)

	def test_replacing_a_spell_slot_cleans_old_lifetimes_after_expiry_callbacks(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		cleanup = block(service, "function Magic.clearTemporary(", "\nlocal function summonSpellProfile")
		self.assertIn("stats.Pending = nil", cleanup)
		self.assertIn("stats.Charge = nil", cleanup)
		self.assertIn("finishBeamChannel(spell)", cleanup)
		self.assertIn("finishInterruptedArea(spell)", cleanup)
		self.assertIn("expireConstruct(spell)", cleanup)
		self.assertIn("endOwnedEnchantments(player, spellId)", cleanup)
		self.assertGreater(cleanup.index("Summons.clearSpell(player, spellId)"), cleanup.index("endOwnedEnchantments(player, spellId)"))

	def test_object_target_physics_rules_use_the_shared_pure_eligibility_spec(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		world = (ROOT / "src/server/Services/MagicWorldQuery.luau").read_text(encoding="utf-8")
		validator = block(world, "local function isValidObjectInteractionTarget(", "\nend\n")
		self.assertIn("MagicObjectTargetSpec", world)
		self.assertIn("ObjectTargetSpec.isValidInteractionTarget", validator)
		self.assertIn('Tagged = CollectionService:HasTag(target, "MagicManipulable")', validator)
		self.assertIn('RaiseAuthorized = target:GetAttribute("MagicRaise") == true', validator)
		self.assertIn("MaterialMatches = definition.Material ~= nil", validator)
		surface_validator = block(service, "local function isSolidWorldSurfaceTarget(", "\nend\n")
		self.assertIn("ObjectTargetSpec.isSolidWorldSurfaceTarget", surface_validator)
		self.assertIn("not isSolidWorldSurfaceTarget(targetInstance)", service)
		self.assertIn("ObjectTargetSpec.isValidManipulationTarget", service)
		self.assertIn("MaterialMatches = definition.Material ~= nil", service)

	def test_controlled_mass_condition_uses_the_control_service_aggregate(self):
		control = (ROOT / "src/server/Services/MagicControlService.luau").read_text(encoding="utf-8")
		self.assertIn("setControlledMass(effect, targetRoot.AssemblyMass)", control)
		self.assertIn("function Control.controlledMass(caster: Model, spellId: string)", control)
		conditions = (ROOT / "src/server/Services/MagicConditions.luau").read_text(encoding="utf-8")
		self.assertIn("ControlledMass = controlledMass", conditions)
		self.assertIn("Control.controlledMass(caster, spellId)", conditions)
		spec = (ROOT / "src/shared/Modules/MagicConditionSpec.luau").read_text(encoding="utf-8")
		self.assertIn("ControlledMass = { Kind = \"Number\"", spec)

	def test_command_casts_are_limited_by_distinct_active_executions(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		command = (ROOT / "src/server/Services/MagicCommandSpec.luau").read_text(encoding="utf-8")
		cast = block(service, "function Magic.castSummonSpell(", "\nlocal function clearActive")
		self.assertIn("SummonConfiguration.MaxActiveCommands", cast)
		self.assertIn("CommandSpec.canStartActiveCommand(active, player", cast)
		self.assertIn("CommandId = commandId", cast)
		self.assertIn("nextCommandCastId += 1", cast)
		self.assertIn("effect.CommandCastId", command)
		self.assertIn("projectile.CommandCastId", service, "Projectile continuations must retain their command slot")
		self.assertIn("effect.CommandCastId = commandCastId", service)

	def test_area_targeting_uses_server_validated_field_center_rules(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		area_validation = block(service, 'elseif targeting == "WorldPoint" or targeting == "Area" then', '\n\telseif targeting == "MaterialTarget" then')
		self.assertIn('Area = {', self.schema)
		self.assertIn('"WorldPoint", "Area", "EntityTarget"', self.schema)
		self.assertIn("definition.TargetRules.Range", area_validation)
		self.assertIn("MinimumWorldAimDot", area_validation)
		self.assertIn('targeting == "Area"', service, "Area centers must share server line-of-sight validation")

	def test_spell_state_conditions_resolve_only_server_owned_runtime_values(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		conditions = (ROOT / "src/server/Services/MagicConditions.luau").read_text(encoding="utf-8")
		spec = (ROOT / "src/shared/Modules/MagicConditionSpec.luau").read_text(encoding="utf-8")
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
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
		presentation = (ROOT / "src/server/Services/MagicPresentation.luau").read_text(encoding="utf-8")
		controller = (ROOT / "src/client/Controllers/MagicPresentationController.luau").read_text(encoding="utf-8")
		poses = (ROOT / "src/shared/Modules/MagicPoseSpec.luau").read_text(encoding="utf-8")
		self.assertIn("Presentation.sustain(state.Character, definition)", service)
		self.assertIn('cue(character, Presentation.profile(definition), "Sustain", 0, 0)', presentation)
		self.assertIn('existing.Phase = "Sustain"', controller)
		self.assertIn('existing.Duration = math.huge', controller)
		self.assertIn('elseif phase == "Sustain" then', poses)
		self.assertIn("pose = selected.Sustain", poses)
		self.assertIn("Presentation.cancel(channel.Caster, definition)", service)

	def test_construct_expiry_triggers_on_caster_cleanup(self):
		service = (ROOT / "src/server/Services/MagicService.luau").read_text(encoding="utf-8")
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
