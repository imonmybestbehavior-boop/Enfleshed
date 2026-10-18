# Grimoire and combat sandbox: implementation and verification

## Open the current build

Open `Enfleshed-Combat-Sandbox.rbxlx` in Studio, press Play, then P or click **Open grimoire**. Studio now starts in the practice arena with the real player magic system, an ally and enemy training dummy, range markings, material sources and a movable object. The grimoire's gamepad shortcut is Select/Back; native button selection remains available.

The active Rojo build is `Enfleshed-Combat-Sandbox.rbxlx`. The earlier city and narrative content has been moved into `Shelved Project`.

## Implemented workflow

- Setup → Effects → Targeting → Presentation → Review & test, with direct chapter tabs and previous/next buttons. Existing authoring controls remain; optional requirements, conditions, trigger behaviors, motion phases and audio have expandable sections.
- First-use help is inside the book, skippable, saved when persistence is available, and reopenable. Practice bolt and Healing beam are constructed from the real schema and validated in tests.
- A live summary on large spreads and a full review on every screen show activation, cooldown/recovery, targeting, effects and their numbers, estimates, conditions and validation. The existing Lab mana/strain exemptions are explained rather than silently changed.
- P preserves the current page and draft. Number keys cannot cast through the open grimoire and remain usable in text fields. Form/family changes that discard unsaved settings require confirmation.
- Library: names, literal-text search (including effects/triggers), recent/name/cost sorting, status/collection/Form/Element filters, up to 32 collections, separate organization labels, bookmarks, previews, duplicate, rename, move, archive/restore and confirmed permanent deletion. Up to 200 records; nine existing combat slots are retained.
- Equip & edit explicitly selects a destination slot and confirms replacement of its session draft. Saved spells remain in the library after unequipping. A shared library spell can occupy multiple slots; saving it updates those equipped references. Duplicate creates an independent variation.
- Save states distinguish unsaved edits, saving, saved, failed save and session-only storage. Save library now retries persistence without implicitly saving an uncommitted editor draft.
- Sandbox controls reuse TrainingDummyService and MagicService: spawn/restore/clear targets, restore player health/resources, end owned active spells/reset cooldowns, respawn and return to start. Damage/health, invalid-cast and resource feedback use existing runtime events. No separate damage simulation or fake pause control was added.

## Compatibility and persistence

SpellSpec v3 and the existing slot IDs and combat calculation modules are unchanged. The DataStore namespace remains `EnfleshedMagicLabLibraryV1`, with the existing `u:<userId>` keys. A v2 wrapper stores the original Slots snapshot plus a separate Catalog. Old v1 slots migrate into Unfiled without changes to spell behavior. Unknown/malformed data is protected against overwrite. The original v1 slot codec remains unchanged.

A real-schema integration test found an existing Lab serialization defect: saving the complete estimator output inserted display-only upkeep keys into Cost, which SpellSpec rejects. `MagicLabCost` keeps the original allowed Cost fields, preserves configured special-resource costs, and removes only the two known legacy estimate fields during hydration. It does not change estimation math. Writes are serialized per player so an older in-flight save cannot overwrite a newer queued save.

Studio DataStore saving requires a published test experience with API access enabled. If unavailable, the UI explicitly reports SESSION ONLY; those changes do not survive server shutdown. No claim of offline file persistence is made.

The Studio fighter sandbox starts directly in the castle arena without a narrative opening.

## Checks executed

- 33 changed/client Luau scripts compile using the official Luau compiler.
- 38 existing Python magic regression checks and 5 new workflow wiring checks pass.
- 59 engine-independent Lua magic/spell/library/summary test files pass under Lua.
- The new real-schema Luau workflow suite passes: both walkthrough examples, real SpellSpec validation and estimates, summary, library capture/organization/reopen, duplicate/archive/restore, and malformed/incomplete guidance.
- The actual MagicLabService serializer passes RGB serialization/hydration, stable slot identity, legacy cost-field migration, special-resource preservation and rejection of unknown saved cost fields.
- Actual server action branches pass equip, rename, revision across shared slots, unequip, archive/restore and re-equip with real spell definitions. A simulated persistence failure preserves the session copy and reports a failed save.
- Pure library tests cover v1 migration, metadata isolation, capacity limits, literal search, filters, archive protection, recovery and invalid/unknown profile rejection.
- UI geometry checks pass at 360×640, 768×600, 864×480 and 1120×900 panel sizes. These verify rectangles, content space and action placement; they are not rendered screenshots or engine input tests.
- Rojo builds the preview successfully. StyLua and diff whitespace checks pass for the edited scope.

Reproducible commands:

```sh
python -m unittest discover -s tests -p 'test_magic*.py'
python -m unittest discover -s tests -p 'test_grimoire*.py'
lua tests/test_grimoire_library.lua
lua tests/test_grimoire_summary.lua
lua tests/test_magic_lab_access.lua
python scripts/run_luau_magic_tests.py /path/to/luau --workflow-only
python scripts/run_luau_ui_tests.py /path/to/luau
rojo build default.project.json -o Enfleshed-Combat-Sandbox.rbxlx
```

## Known existing regression-suite mismatch

The full `test_magic_lab.lua` requires Luau. Its stale dependency fixtures were repaired so it can execute with `scripts/run_luau_magic_tests.py`. It now reaches an existing assertion expecting Damage on Channeled Beam OnExpire, while the current schema rejects that pairing with `Payload is not supported for this Form and trigger`. The redesign changes descriptions and section order, not this compatibility table. That discrepancy remains unresolved rather than inventing a combat rule to make the assertion pass.

## Studio acceptance checks still required

This environment has no Roblox Studio runtime. The implementation is not declared fully verified until these engine checks pass:

1. Fresh session: arena appears without an intro; both dummies spawn; starter magic is usable. Open, skip and reopen help. Create each example, save, close with P, cast with its number key, and reopen the same page.
2. Enter numbers in fields, use keyboard/native gamepad focus, activate all navigation controls and test held-cast release. Confirm UI interaction never attacks or casts unintentionally. Inspect text wrapping, long descriptions, focus visibility, enlarged text and touch at supported screen sizes.
3. Save a spell with a special-resource cost, then edit targeting, lifetime, effects and conditions. Compare actual costs, damage, delays, cooldowns and targeting to the existing engine behavior.
4. Create a collection, search/filter/sort, label/bookmark, duplicate, rename, equip in another slot, unequip, archive, restore and delete a duplicate. Verify metadata operations do not change damage or estimates and dirty destination drafts require confirmation.
5. In a published private Studio test with API access, save, stop and restart. Verify spells, collections, labels, favorites, equipped references and help preference. Repeat with API access disabled and confirm session-only feedback and no overwrite of existing saved records.
6. Exercise malformed/unsupported saved profiles, server validation failure, rapid library commands and save retries. Confirm errors preserve draft context.
7. Reset targets/player, restore resources, end spells and return to start. Existing expiry effects may execute during cleanup. Dummies are anchored; verify displacement and motion on an appropriate movable target or second client.
8. Confirm test-only authoring and training remotes stay Studio-gated; live servers should not expose the development Grimoire transport.
