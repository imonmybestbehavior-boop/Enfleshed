# Single façade study — isolated visual prototype

Open `Enfleshed_FacadeStudy.rbxlx` from the repository root in Roblox Studio. This is a separate review place, not the main Enfleshed game. The building is present in Edit mode; no Play session or procedural script is required to generate it. Press Play to walk into its four empty ground-floor premises. Standard Roblox movement/camera apply.

## Authored architecture

One approximately **108 × 34 × 87-stud** masonry building: a tall commercial ground floor beneath **four upper storeys**, with 31 inset sash windows and one masonry-filled former opening. Four unequal commercial openings span 17, 33, 19 and 24 studs between structural piers. The wider building includes party walls and masonry divisions between businesses; these are actual enclosed rooms rather than disconnected openings.

Each bay has a masonry plinth, deep display-window sill/reveals, inset metal glazing frames, mullions, a transom, and a loadbearing lintel. The separate entrances recess 2.4, 3.6, 1.8 and 3 studs behind the façade. Visible timber jambs, heads, glazed transoms and open door leaves define the doorways. Flush thresholds lead to continuous floors; no stairs or raised entry platforms are used.

The upper floors have their own masonry wall areas, smaller residential windows, continuous floor bands and a restrained roof parapet. No signs, awnings, merchandise, counters, advertisements or scattered decorative props disguise the underlying architecture. Interior review lights are invisible and are grouped within each bay.

This is a static, hand-authored Roblox Part model (**547 Parts**), organized into the structural shell, four numbered shop bays, and upper storeys. It has no runtime generator, placement system, gameplay scripts or external asset dependencies. Repetition in the window construction does not introduce a modular storefront kit; that is deferred pending visual approval.

## Controlled variation revision

The approved overall dimensions, four shop rooms, entrance depths, structural shell and architectural language are preserved. The second shop now occupies nearly twice the narrow first shop's frontage. Its display has three panes and a slightly lower transom, while the other displays use two panes. Door positions remain offset to the sides, adjusted with the tenant boundaries. Dividing piers and interior party walls move together.

Of the original 32 upper-window positions, 25 retain the standard window, two have a wider opening/heavier lintel, four use a narrower, simpler replacement profile, and one has been filled with subtly different flush masonry. A pair of narrow windows is closer together on one upper section. These are deliberately placed changes, not randomized variation.

The band above the first upper storey is heavier; the next course is simpler; one higher band ends at the masonry division above the second shop. Floor slabs remain continuous behind the varied façade details. No signage, dressing or props were added.

Offline geometry previews were inspected after the change. They are not Roblox screenshots; review glass, material response and avatar scale in Studio before any wider use. Only this model, this document and the standalone compiled review place change in this revision.

## Files and isolation

- `Facade.rbxmx`: editable standalone building model. Insert this file into a disposable Studio place to inspect the building independently.
- `review.project.json`: isolated Rojo configuration with only this model, a review ground, spawn and review lighting.
- `README.md`: these review instructions.
- Root `Enfleshed_FacadeStudy.rbxlx`: compiled review place.

No existing city, topology, storefront generator, population, navigation, gameplay, main project configuration or earlier prototype asset is modified. The rejected storefront generator and prior kits are not used. The main `Enfleshed.rbxlx` is not rebuilt by this pass.

Rebuild this review place from the repository root:

```sh
rojo build prototypes/FacadeStudy/review.project.json -o Enfleshed_FacadeStudy.rbxlx
```

## Visual review

1. In Edit mode, select `Workspace.Facade`, then press **F** to frame it. Inspect the full height: upper floors should read as occupied architecture above the shops, not elongated storefronts.
2. At street level, compare the four bays from straight ahead and an oblique angle. Check the piers, wall thickness, display-frame shadows and entrance recesses without any commercial decoration.
3. Press Play and walk through all four open doors. Assess the scale beside an avatar, readable display glazing, and the ability of each empty room to house a real business.
4. Inspect the model under the intended darker city lighting in a disposable copy before approving city integration. The review place uses neutral lighting for architectural inspection and does not attempt to reconstruct the city or its enclosing megastructure.

Rojo 7.7.0 successfully builds the isolated project. XML/part validation checks four continuous three-stud-wide, nine-stud-high entrance-to-room paths. No Luau is introduced, so script formatting and gameplay regression tests are not applicable to this static asset. Roblox Studio rendering/physics have not been exercised here. Upper floors are visual architecture with floor slabs, not accessible furnished apartments. This is not a production-optimized mesh asset or approved city-wide system.
