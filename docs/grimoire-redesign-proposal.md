# Grimoire and magic creation redesign

## Design proposal

### Book layout and navigation

Keep the outer book, header, chapter navigation, live spell summary, validation status, and footer actions in fixed regions. At desktop sizes, use a contents page for chapters and a separate editor page; on narrow screens, use a horizontally scrollable chapter strip. Only the editor page scrolls. Selectors expand inline in reserved space inside the page, so choices stay beside their controls. Use a deep evergreen binding, nearly white paper, ink-dark typography, restrained gold markers, book serif headings, and readable sans-serif control text. Light cards and white inputs separate controls from the page without relying on brown-on-brown contrast.

The chapters are **Form**, **Targeting**, **Conditions**, **Choose Effects**, **Configure Effects**, **Casting**, **Costs**, **Appearance**, and **Review & Test**. Specialist groups such as triggers, nested conditions, projectile motion phases, and environment limits remain searchable in Spell Workshop and collapse behind named headings.

### Creation flows

**Quick Create** asks what the spell should do, recommends compatible Forms while keeping compatible alternatives selectable, then presents grouped effect choices. It creates a validated draft with runtime-safe defaults and opens Configure Effects with only selected outcomes. Review keeps the live estimate and validation next to separate Save Draft, Save Spell, Equip, and Test actions.

**Spell Workshop** opens directly into the same SpellSpec data and validation path. It uses the same Choose Effects then Configure Effects sequence, with the full existing targeting, casting, cost, condition, appearance, and specialist controls. Switching modes keeps the current draft and its validation state.

Runtime-required internal defaults remain in the definition for compatibility. They never appear as creator controls, labels, or spell-summary content. Effect availability in the authoring flow comes from Form, event, target, and registry capabilities; a selected combination that cannot be represented by the existing runtime is retained and explained so the creator can resolve it without silent changes.

### Reference lessons

- [Magicka](https://www.paradoxinteractive.com/games/magicka/about): effects can compose into expressive outcomes. The interface should make compatible combinations easy to explore and show the result in plain language.
- [Path of Exile](https://www.pathofexile.com/game): distinguish the base skill from compatible modifiers. Here that means separating the delivery Form from the effects that happen when it resolves.
- [Blender 4.0 node editor](https://developer.blender.org/docs/release_notes/4.0/node_editor/): group and collapse specialist controls to keep the main workspace readable while preserving access to detailed options.
- [Roblox ScreenGui insets](https://create.roblox.com/docs/reference/engine/classes/ScreenGui#ScreenInsets): keep the book inside the platform safe area. [GuiButton.Activated](https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated) provides one activation path for mouse, touch, and gamepad.

### Effect selection and configuration

Choose Effects groups registry-backed outcomes into Damage, Healing, Defense, Control, Movement, Summoning, and Utility. Each choice explains its gameplay result and the Form/event/target constraints that apply. Configure Effects shows editors only for outcomes already present in the selected timing. Common spell settings stay in their own chapters. Existing incompatible selections are preserved and surfaced with a repair message; changing a Form or target mode never silently deletes effects.

### Library and profile model

The saved spell library remains separate from the nine-slot combat loadout. Library records support search, sorting, collections, favorites, tags, previews, duplication, rename, archive/restore, and confirmed deletion. Editing a saved record uses a working copy; equipping is a separate action, and linked slots refresh only when the saved record is updated. Slot behavior remains unchanged.

Keep the existing version 2 library profile and version 1 slot-profile reader. Preserve the datastore namespace. The existing guarded migration validates old slot definitions before adding them to the catalog, and refuses to overwrite malformed or unknown-version data. Server-side SpellSpec validation remains authoritative for saves and equips; no client-authored data bypasses it.

## Acceptance criteria

1. New creators can make a valid simple spell from intent through save without seeing internal source, Principle, or Expression choices.
2. Both creation styles separate effect choice from configuration, and configuration shows only selected effects.
3. The book frame, navigation, summary/status, and footer stay stable while only page content scrolls; inline menus stay inside the book.
4. The live summary shows effect details, range, duration, estimates, and validation in plain language.
5. Creators can find advanced controls, search them, understand dependencies, and repair incompatible choices without losing work.
6. Saved library records remain distinct from equipped slots, and profile migration preserves validated legacy spells without overwriting unsafe data.
7. The flow works at representative phone, tablet, short-landscape, and desktop sizes with mouse, touch, and gamepad activation.

## Implementation and verification record

This redesign is implemented in the existing Magic Lab and Grimoire path. The data model, server authority, execution system, and safe versioned persistence remain the existing ones. Verification results and any Studio checks not available in this environment are recorded in the delivery summary.
