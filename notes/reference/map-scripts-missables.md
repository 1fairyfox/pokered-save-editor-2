# Per-map script progress (the 97) & missables (the 228) — the Map Storage panel's big pages

Briefed by project leadership 2026-07-16: the map scripts and the missables join the persistent Map Storage
panel — the script as a **dropdown at the top of each map's page** (title + progression description
per step, custom values via "Something else…"), the missables **sorted into their own group** under
the owning map, with unused/glitch/known-issue flags and the missable↔event-flag conflict hooks.

## The save layout (both verified)

| Block | File | WRAM | Size | Model |
|---|---|---|---|---|
| Per-map script progress | **`0x289C`–`0x2915`** | `0xD5F0`+ (`wOaksLabCurScript`…) | **97 values** in `0x7A` bytes (1 byte each + pret's padding skips) | `WorldScripts` (`world.scripts`) |
| Missable visibility | **`0x2852`–`0x2871`** | `0xD5A6` (`wToggleableObjectFlags`) | 256 bits, **228 used** | `WorldMissables` (`world.missables`) |

- **Project leadership's counts were exactly right:** 97 `w<Map>CurScript` variables in `ram/wram.asm`, 228
  `TOGGLE_*` constants in `constants/toggle_constants.asm`.
- The script block's layout (sizes + skips) is `scripts.json`'s — v1's import, kept verbatim.
  **Byte-exactness pinned** by `tst_world::scripts_writeExactlyTheirByte` (offsets hardcoded
  independently: ind 0 → `0x289C`, ind 1 → `0x289D`, ind 3 → `0x28A0`, ind 96 → `0x2915`) and
  `missables_writeExactlyTheirBit` (bit 0 → `0x2852` b0, bit 227 → `0x286E` b3).
- ⚠️ **Polarity:** a missable bit **SET = HIDDEN** (pret: *"bit set = toggled off"*). The panel's
  switch shows the intuitive direction — checked = on the map.
- **Corrects an old note:** the sprites research (2026-07-13) placed `wToggleableObjectFlags` at
  `0x28A0` — that byte is actually **Viridian City's script-progress byte**. The flags are at
  `0x2852` (v1 concurs; pinned by the bit-exact test).

## Scripts: how the dropdown gets its meaning

- Each of the 97 entries owns one map (94) or a small map group (3 gates share a byte:
  Route 16 Gate 1F/2F, Power Plant + Route 7 Gate, Route 18 Gate 1F/2F).
- The steps come from `maps.json` `scriptEntries` (116 maps / 458 steps, imported 2026-07-15 from
  the game's own `SCRIPT_*` constants). **Each step now carries a `desc`** —
  `scripts/import_storage_meta.py` writes a **curated description for the story maps** (Pallet's
  intro, the whole 19-step Oak's Lab opening, Route 22's two ambushes, Cerulean's bridge rival,
  Vermilion's dock, the Championship rooms…) and an honest derived one elsewhere (gym
  START/END/POST pattern, EXIT/cutscene/battle patterns) — every option reads like a stage of the
  map's story, which is the *sense of progress* project leadership asked for.
- `AreaMap::curMapScript` (`0x2CE5`, the **live working step** of the map you're on) shows the
  **same descriptions** under the Details panel's "Current script step" combo — one meaning, two
  places. Relationship: on map entry the game copies the map's `w<Map>CurScript` into the dispatch
  path; editing the per-map byte sets where the story *will* resume, the `0x2CE5` byte is where it
  *is* right now.
- ⚠️ **The out-of-range hazard:** script steps dispatch through a per-map pointer table ending in
  `jp hl`, with **no bounds check** — a value past the map's own table reads garbage as a pointer
  and jumps to it (the same mechanism as the event-flag crash research). The panel's custom path
  accepts the full byte range (never refused) and **warns in words** beyond the named steps.

## Missables: the enrichment

`missables.json` (228 entries, v1's import) now carries, per entry
(`scripts/import_storage_meta.py`, additive + `--check`-idempotent):

- **`toggleConst`** — the pret `TOGGLE_*` name (position-matched; both lists are index-ordered).
- **`scriptToggled`** — **121 of 228 are pret's X-marks**: no map script ever calls
  ShowObject/HideObject on them (item balls and static encounters that deactivate through
  `wToggleableObjectList` detection instead). The bit still controls visibility either way; the
  description says so.
- **`oddity`** — pret's own four oddballs (`TOGGLE_SILPH_CO_2F_1`/`_10F_3` "never (de)activated?",
  `TOGGLE_SILPH_CO_7F_8`/`TOGGLE_UNUSED_MAP_F4_1` "sprite doesn't exist") — flagged **amber** in
  the panel: the bit exists and stores, toggling shows nothing.
- **`desc`** — kind-aware plain English (item ball / trainer / static encounter / character, with
  what hidden means for each).
- **`linkedEvents`** — the **14 verified flag↔object links** from the 2026-07-15 script
  cross-reference (`CheckEvent`-before-toggle), each with the flag name + canonical bit index.
  Placeholder "map-specific got-item" pseudo-flags are deliberately filtered out.

**The conflict hooks (v1 of the missable conflict system):** the panel prints each linked flag WITH
ITS LIVE STATE beside the switch — *"Tied to EVENT_FOLLOWED_OAK_INTO_LAB (ON)…"* — so a flag and a
visibility bit that disagree are visible at a glance. This is the *suspected* tier of the
conflicting-flags doctrine (event-flags plan, Phase 11): directional predicates (which combination
actually breaks) need per-object research and console probes, which is Phase 11's machinery; the
links themselves are baked and ready for it.

## Wiring

- `MissablesDB::deepLink()` **was never called at boot** (found + fixed 2026-07-16 — every
  missable's `toMap` link was silently null). Now runs after `MapsDB::deepLink()`.
- `world.h` fully includes `worldscripts.h`/`worldmissables.h`/`worldevents.h` so QML traverses
  `world.scripts` / `world.missables` / `world.events` (the WorldLocal de-opaque precedent).
- The panel's data comes from `MapModel::storagePages()` (one page per script entry + missable-only
  maps, the legacy trio merged in — Safari stays COMBINED), `storageScriptSteps()`,
  `storageMissables()`.
- ⚠️ **Qt Quick trap encoded in the panel:** a `ComboBox` writes `currentIndex` itself whenever its
  model changes, severing a plain binding — page switches then show the wrong step. The panel uses
  a `Binding` element, which re-asserts after internal writes. (Caught by the screenshot review:
  Oak's Lab stored step 18 while the combo displayed "Default".)

## ⚠️ Showing a missable is TWO writes, not one (found 2026-08-18)

The single most expensive thing on this page, because it looked like it worked.

Project leadership, 2026-08-18: *"some toggles still dont work like the receptionist is not there
despite toggled on, the map wasnt reconstructed well"* … *"Daisy sitting doesnt show when toggled on
Blues house map."*

**Hiding an object on a real Game Boy touches two places**, and `engine/overworld/missable_objects.asm`
does both:

| | what it writes | were we? |
|---|---|---|
| the flag | set/clear the `wMissableObjects` bit | ✅ yes |
| the slot | `HideObject` stores **0** into that sprite slot's **picture id** | ❌ no |

And **picture id 0 means "this slot is unused"** (`ram/wram.asm`) — which is precisely what
`MapModel::npcList()` skips on:

```cpp
// Picture id 0 means the slot is unused (ram/wram.asm). Draw nothing.
if (s->pictureID == 0)
  continue;
```

So clearing the bit on its own left behind a slot that still declared itself unused. The renderer
skipped it, and the object stayed invisible no matter how many times you toggled it. **The switch was
writing a true byte into a save the renderer had already been told to ignore** — which is why it
presented as "the map wasn't reconstructed well" rather than as a dead switch.

**The fix is `MapModel::setMissableShown(missableInd, shown)`**, and every user-facing filter-flag
control now routes through it (the World panel's switches, the Details panel's `FlagChip`). Calling
`WorldMissables::missablesSet()` directly from the UI is now a bug.

**The restore is deliberately minimal — do NOT rebuild the slot from the ROM.** The console only ever
zeroed the picture, so the rest of that slot (coordinates, facing, movement, text id, trainer fields)
is still the console's own data and is exactly right. Putting the picture back is the entire inverse
operation. Rebuilding would also be the *"sprite is reset for no reason"* that leadership ruled out in
the same brief. The picture comes from the slot's own second copy (`pictureIDCopy`,
spritestatedata2 field d — which `HideObject` does not touch), falling back to the map's ROM object
list (`MapDBEntry::getSprites()` → the entry whose `getMissable()` matches).

**The finder is the save's own link, not a positional guess:** `wMissableObjectList` at `0x287A` maps
sprite slot → missable index and survives hiding, so the slot is found by asking
`SpriteData::getMissableIndex()`.

⚠️ **Still open:** a missable on a map you are *not* standing on has **no loaded slot at all**, so its
bit is the whole of its stored state until you go there. That is correct — but the *constructed*-map
path (`changeMapConstructed` / `Area::setTo`) builds slots from the ROM and must honour the missable
bits when it does, or the same class of "toggled on but not drawn" returns by another road. Not yet
verified.

## Honesty ledger

- Script values and missable bits are **durable** save data (inside `sMainData`).
- The 121 never-script-toggled missables and the 4 oddities are **flagged, never hidden**.
- Custom script steps beyond the table are **stored as asked** with the crash-risk warning.
- Deeper per-map semantics (which step arms which trigger, exact conflict predicates) belong to the
  scripts-import + Phase 11 work — the descriptions say what is *known*, not guesses dressed up.
