"""Integration boundaries that don't require a running Roblox engine."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text()

class WorkflowWiring(unittest.TestCase):
    def test_digits_edit_fields_and_cannot_cast_through_ui(self):
        ui = read('src/client/Controllers/MagicLabController.luau')
        keys = ui[ui.index('local function slotAction(slot: number)'):]
        # Keyboard 1–9 and gamepad RB share the same guarded handler.
        self.assertIn('slotHandlers[slot],', keys)
        self.assertIn('return slotHandlers[slot](action, state, input)', keys)
        self.assertLess(keys.index('UIS:GetFocusedTextBox()'), keys.index('if panel.Visible then'))
        self.assertLess(keys.index('if panel.Visible then'), keys.index('cast(slot, true)'))

    def test_saving_closes_the_forge_and_new_spell_starts_fresh(self):
        ui = read('src/client/Controllers/MagicLabController.luau')
        handler = ui[ui.index('local saveMode = pendingLibrarySaveMode'):ui.index('persistenceState = catalog.SaveState')]
        self.assertIn('local closeAfterSave = ok and saveMode ~= nil and pageMode == "Editor"', handler)
        self.assertIn('pageMode = if savedFromSlot then "Slots" else "Library"', handler)
        self.assertIn('standaloneWorkingDraft = nil', handler)
        new_spell = ui[ui.index('local function startNewSpell()'):ui.index('local function hasWorkingDraft()')]
        self.assertIn('beginCreation(true, true)', new_spell)
        self.assertIn('if forLibrary and standaloneWorkingDraft and not fresh then', ui)

    def test_library_filters_cannot_mark_combat_drafts_dirty(self):
        ui = read('src/client/Controllers/MagicLabController.luau')
        self.assertIn('if not presentationOnly then', ui)
        self.assertIn('ctx.select(label, value, options, change, nil, nil, nil, nil, true)', read('src/client/UI/GrimoireLibraryView.luau'))

    def test_sandbox_arena_starts_and_raw_spell_casts_stay_studio_only(self):
        # The city/narrative services were shelved; the practice arena is always built.
        self.assertIn('function Arena.enabled()', read('src/server/Services/CombatSandboxService.luau'))
        startup = read('src/server/init.server.luau')
        self.assertIn('require(script.Services.CombatSandboxService).start()', startup)
        router = read('src/server/Networking/ActionRouter.luau')
        self.assertIn('Equipment.chooseStarter(player, "Magic", feedback)', router)
        # Client-supplied spell definitions may only be cast in the Studio sandbox.
        for action in ('MagicStart', 'MagicRelease', 'MagicAimUpdate'):
            self.assertIn('action == Protocol.' + action + ' and RunService:IsStudio() and StudioSandbox.Enabled', router)

    def test_storage_retains_original_namespace_and_guards(self):
        self.assertIn('LibraryDataStoreName = "EnfleshedMagicLabLibraryV1"', read('src/shared/Configuration/MagicLab.luau'))
        service = read('src/server/Services/MagicLabService.luau')
        self.assertIn('while saving[player] do', service)
        self.assertIn('snapshot.Version = Library.Version', service)
        self.assertIn('local _, safe = decode(existing)', service)
        self.assertIn('LabCost.refresh(definition, Spec.estimate, Spec.copy)', service)
        self.assertIn('if not allowed() then', service)
        self.assertIn('local ok, reason = Spec.validate(data)', service)

    def test_guided_creation_and_independent_library_save_are_wired(self):
        ui = read('src/client/Controllers/MagicLabController.luau')
        service = read('src/server/Services/MagicLabService.luau')
        guide = read('src/shared/Modules/MagicAuthoringGuide.luau')
        # New spells open straight into the Spell Forge with a valid starter.
        self.assertIn('draft.Triggers.OnImpact = { { Payloads = { starterDamage } } }', ui)
        new_spell = ui[ui.index('local function startNewSpell()'):ui.index('local function hasWorkingDraft()')]
        self.assertIn('beginCreation(true, true)', new_spell)
        self.assertIn('local saveMode = if editingLibraryRecord then "Update" else "SaveNew"', ui)
        self.assertIn('elseif data.Action == "SaveNew" then', service)
        self.assertIn('local valid, reason = Spec.validate(data.Definition)', service)
        self.assertIn('schema.supportsPayloadCapability(kind, formName, event)', guide)
        self.assertNotIn('schema.supportsPayload(kind, formName, event, principle)', guide)
        # Suggested starters are pre-validated so the guide never offers one the server rejects.
        self.assertIn('if not spec.validate(draft) then', guide)

    def test_empty_slots_choose_a_saved_spell_and_home_is_always_available(self):
        ui = read('src/client/Controllers/MagicLabController.luau')
        library_ui = read('src/client/UI/GrimoireLibraryView.luau')
        hub = read('src/client/UI/SpellHub.luau')
        # Home is a toolbar tab on every non-editor screen.
        self.assertIn('{ Id = "Home", Label = "HOME"', hub)
        self.assertIn('navigateTab = function(tab)', ui)
        self.assertIn('libraryView.chooseForSlot(slotId)', ui)
        self.assertNotIn('beginCreation(false)', ui)
        self.assertIn('Spell = draftsBySlot[slot] or equipped[slot]', ui)
        self.assertIn('function self.chooseForSlot(slot)', library_ui)
        self.assertIn('"EQUIP IN SLOT " .. self.ChoosingSlot', library_ui)
        self.assertIn('local completedSlotChoice = ok and changedSlot ~= nil and changedSlot == libraryView.ChoosingSlot', ui)

    def test_expert_search_and_library_copy_edit_do_not_equip_implicitly(self):
        ui = read('src/client/Controllers/MagicLabController.luau')
        library_ui = read('src/client/UI/GrimoireLibraryView.luau')
        service = read('src/server/Services/MagicLabService.luau')
        self.assertIn('authoringMode = "Guided"', ui)
        self.assertIn('expertSearch = search or ""', ui)
        self.assertIn('string.find(string.lower(label), string.lower(expertSearch), 1, true)', ui)
        self.assertIn('ctx.editRecord(self.Selected, record.Definition)', library_ui)
        self.assertIn('Action = saveMode', ui)
        update = service[service.index('elseif data.Action == "Update" then'):service.index('\n\t\t\telse', service.index('elseif data.Action == "Update" then'))]
        self.assertIn('Spec.validate(data.Definition)', update)
        self.assertIn('Library.update(catalog, data.Id, definition', update)
        self.assertIn('assigned.SpellId = Slots.id(assignedSlot)', update)

    def test_intent_recommends_but_does_not_fix_the_spell_form(self):
        ui = read('src/client/Controllers/MagicLabController.luau')
        guide = read('src/shared/Modules/MagicAuthoringGuide.luau')
        self.assertIn('RecommendedForms = { "Aura", "Field", "Beam", "Projectile" }', guide)
        self.assertIn('function Guide.isRecommended(intentId, formName)', guide)
        self.assertNotIn('intent.Forms', guide)
        self.assertIn('table.insert(results, formName)', guide)

    def test_advanced_show_toggle_preserves_editor_scroll(self):
        ui = read('src/client/Controllers/MagicLabController.luau')
        helper = ui[ui.index('local function rebuildPreservingScroll()'):ui.index('local libraryView')]
        heading = ui[ui.index('local function heading(text)'):ui.index('local function info(text, _height)')]
        self.assertIn('scroll.CanvasPosition = previousCanvasPosition', helper)
        self.assertIn('rebuildPreservingScroll()', heading)

    def test_event_summon_spawns_clear_of_impact_surface_and_reports_failure(self):
        summons = read('src/server/Services/SummonService.luau')
        service = read('src/server/Services/MagicService.luau')
        event_placement = summons[summons.index('if spawnAt == "Event" then'):summons.index('local now = os.clock()', summons.index('if spawnAt == "Event" then'))]
        summon_context = service[service.index('Summon = function(payload)'):service.index('\n\t\tend,', service.index('Summon = function(payload)'))]
        self.assertIn('Placement.behindImpact(', event_placement)
        self.assertIn('if message or not created then', summon_context)
        self.assertIn('No new summon was created', summon_context)

    def test_summon_callback_captures_resolved_context_without_self_reference(self):
        service = read('src/server/Services/MagicService.luau')
        context = service[service.index('local function context('):service.index('\n\treturn ctx\nend', service.index('local function context('))]
        summon_callback = context[context.index('Summon = function(payload)'):context.index('\n\t\tend,', context.index('Summon = function(payload)'))]
        self.assertIn('local resolvedPotency = potency or', context)
        self.assertIn('resolvedPotency,\n\t\t\t\tposition', summon_callback)
        self.assertNotIn('ctx.Potency', summon_callback)
        self.assertNotIn('ctx.Origin', summon_callback)

    def test_caster_summons_spawn_beside_owner_and_recast_refills_removed_slots(self):
        summons = read('src/server/Services/SummonService.luau')
        self.assertIn('if spawnAt == "Caster" then', summons)
        self.assertIn('math.cos(now * Config.OrbitRate + (index - 1) * math.pi) * archetype.FollowDistance', summons)
        self.assertIn('not record.Model\n\t\t\t\tand liveCount(owner) < Config.MaxActivePerPlayer', summons)
        self.assertIn('makeSummonModel(record, record.SpawnPosition + initialOffset, archetype)', summons)

    def test_projectile_summon_can_trigger_on_cast_without_impact(self):
        schema = read('src/shared/Configuration/MagicSchema.luau')
        ui = read('src/client/Controllers/MagicLabController.luau')
        tests = read('tests/test_magic_lab.lua')
        summon_definition = schema[schema.index('\tSummon = {'):schema.index('\n\t},\n}', schema.index('\tSummon = {'))]
        self.assertIn('if definition.Events.OnCast then', summon_definition)
        self.assertIn('summonEvents.OnCast = true', summon_definition)
        self.assertIn('Choose OnCast to summon as soon as you cast.', ui)
        self.assertIn('event = "OnCast"', ui[ui.index('local function setPayload(kind, on)'):ui.index('local function ', ui.index('local function setPayload(kind, on)') + 25)])
        self.assertIn('payload.TargetIndependent == true', schema)
        self.assertIn('objectProjectileSummon.Triggers.OnCast', tests)

    def test_training_uses_real_services_and_guarded_commands(self):
        dummies = read('src/server/Services/TrainingDummyService.luau')
        self.assertIn('not RunService:IsStudio()', dummies)
        self.assertIn('require(script.Parent.MagicService).reset(player)', dummies)
        self.assertIn('require(script.Parent.MagicService).restoreTestingResources(player)', dummies)
        self.assertIn('createModel(entry, player)', dummies)
        self.assertIn('countOwned(player) >= Config.MaxPerPlayer', dummies)

if __name__ == '__main__': unittest.main()
