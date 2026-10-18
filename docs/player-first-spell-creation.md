# Player-first spell creation

## Audit

The current editor, schema, validator, persistence service, runtime dispatcher, VFX preview, and emergent-magic audit were inspected before this slice. They represent three different capability boundaries:

- **Runtime:** one Form with event-driven trigger steps, up to four parallel steps per event, up to four payloads per step, per-step conditions, projectile travel behaviors, and an `Explode` area behavior. It cannot spawn an independently defined child Form or create nested projectile → field → wave graphs.
- **Schema:** can represent all runtime features above and strictly rejects unknown keys, incompatible Forms/events, unsafe values, excessive cost, and unsupported nesting. Saved library records and equipped slots use this normalized `SpellSpec`.
- **Previous editor:** exposed most individual schema controls and an intent-first Quick Create flow, but treated ordinary payload selection as one primary step. Existing secondary steps could be preserved and conditioned, yet players could not clearly select, add, reorder, or remove independent payload steps.

The largest beginner obstacles were the amount of configuration visible in the Workshop, technical event names, weak distinction between a Form and its outcomes, and no concise visual explanation of simultaneous steps. Advanced creators were blocked by the editor gap above before they reached the runtime's actual limits.

## Priorities

1. Preserve every existing `SpellSpec` field and make actual execution order legible.
2. Let a beginner make a damaging projectile through intention → Form → effect, with no knowledge of payload tables.
3. Expose independent steps and conditions without implying unsupported nested Forms.
4. Keep testing, validation, cost, saving, and equipping visibly separate.
5. Keep essential actions tappable; drag-and-drop is never required.

## Interface alternatives

| Model | Discoverability | Complex composition | Mobile | Extensibility | Decision |
|---|---:|---:|---:|---:|---|
| Linear wizard | High initially | Poor; branches and revisiting choices become awkward | Good | Poor | Rejected as the sole editor |
| Free node graph | Low for beginners | Excellent in theory | Poor without precision pan/drag | Good | Deferred until the runtime supports nested child definitions |
| Intent-first cards + structured action list | High | Good for the runtime's flat event/step model | Good | Good; schema metadata drives choices | Selected |

The selected hybrid uses Quick Create for the first meaningful decisions and the existing Workshop for precision. Both edit one `SpellSpec`. The action map is a structured list rather than a fake graph: `WHEN` identifies an event, `ALSO` identifies a parallel step at that event, and `IF` identifies a real per-step condition. It does not suggest that one step creates another Form when the runtime cannot do that.

## Working vertical slice

`MagicActionFlow` is a pure presentation adapter driven by `MagicSchema` labels. It turns real trigger steps into reusable action-block metadata without mutating the spell. The composer now allows a player to:

- inspect every event step, including behavior-only and conditional steps;
- select the exact ordinary payload step being edited;
- add an independent `ALSO` step by copying the current safe configuration;
- tune the copy independently with existing schema-driven controls;
- move it earlier or remove it;
- add a real per-step condition;
- validate, preview, save, equip, and test through the existing server-authoritative workflow.

The four-step server limit is shown with a useful explanation. Unsupported operations remain absent. Existing complex records remain intact when switching Guided/Workshop modes.

## First spell walkthrough

A new player chooses **Attack**, **Projectile**, and **Damage**, then opens **Configure Effects**. The action map reads `WHEN · ON IMPACT › DAMAGE`. They can adjust damage, review the estimate, save, equip, spawn an enemy training dummy, and test cast. Engine concepts such as `Payloads` are never required.

An experienced player can select the impact action, add an `ALSO` step, change the new step to another compatible outcome, and add an `IF` condition. They can also add the real `Explode` behavior and projectile Split/Spread behaviors. The map preserves and exposes each independent step. Projectile → independently configured field → wave remains correctly identified as unsupported by the runtime rather than simulated by the UI.

## Usability scenarios

- **A — beginner damaging projectile:** supported. Three creation decisions lead to a valid draft; configuration, saving, equipping, and testing are explicit next actions.
- **B — explosion plus three secondary projectiles:** partially supported. Impact explosion and Split ×3 are real and editable. Split children inherit the parent definition, so each cannot be configured independently; the UI does not claim otherwise.
- **C — orbiting constructs that acquire targets and launch:** unsupported as a nested composition. Orbiting projectile motion and homing exist, but constructs cannot own and launch independent child spell definitions.
- **D — experiment and restore:** preview/test, session drafts, and safe close/reopen are supported. A dedicated multi-level undo/redo history remains unresolved; players should save a draft before broad experimentation.
- **E — incompatible operations:** schema filtering and server validation preserve the draft and explain incompatibility. The action map never rewrites the definition.

## Verification and limitations

The pure action-flow test verifies preservation of multiple steps, parallel labels, conditions, behaviors, and step-limit feedback. Formatting, Rojo serialization, reference checks, and the existing magic suites should remain the regression gate. Roblox Studio is still required for pointer, touch, controller-focus, device-emulation, live preview, persistence, and actual combat acceptance testing.

Remaining product work, in priority order: multi-level undo/redo; a clearer step-specific effect picker rather than copy-then-edit; optional execution replay from real runtime telemetry; controller focus QA; and, only after the runtime supports embedded child definitions, a nested action-card model for true sequential effect creation.
