"""Is `wCurMapScript` a real, editable value in a save -- or is it overwritten by the map's
OWN stored script byte the instant the map script runs?

WHY THIS EXISTS (project leadership, 2026-08-19). The Map screen shows two controls that look
like the same number in two places: the World / persistent-storage panel's per-map **stored**
script byte (`w<Map>CurScript`, save 0x289C + slot) and Map Details' **live** byte
(`wCurMapScript`, save 0x2CE5). Leadership's read of it:

    "I feel it needs to be synced somehow -- I feel somehow it may be duplicated values between
     persistent storage and non and they should be synced ... but maybe im misunderstanding."

    "If you are 100% sure and confident that the use_cur_map_script is the only way to use
     curMapScript and your 100% sure otherwise that even if the user sets that value it would be
     overwritten on load if useCurMapScript is still not set. That changes things and i'd verify
     it to make sure. ... Make sure this is correct before doing it."

The disassembly says exactly that (`home/trainers.asm`):

    ExecuteCurMapScriptInTable::            ; a = the map's STORED script byte on entry
        ...
        ld hl, wStatusFlags7
        bit BIT_USE_CUR_MAP_SCRIPT, [hl]
        res BIT_USE_CUR_MAP_SCRIPT, [hl]    ; one-shot: consumed the moment it is read
        jr z, .useProvidedIndex             ; bit CLEAR -> keep a (the STORED byte)
        ld a, [wCurMapScript]               ; bit SET   -> the LIVE byte wins instead
    .useProvidedIndex
        pop hl
        ld [wCurMapScript], a               ; ...and the live byte is (re)written either way
        call CallFunctionInTable
        ld a, [wCurMapScript]               ; the result goes back to w<Map>CurScript
        ret

and every scripted map's wrapper is `ld a, [w<Map>CurScript]` / `call` / `ld [w<Map>CurScript], a`.
`BIT_USE_CUR_MAP_SCRIPT` is set in exactly ONE place in the whole game: `TalkToTrainer`'s
`.trainerNotYetFought`, right before it bumps the live index and starts a trainer battle.

But a careful read of the assembly has been WRONG before -- the sprite-persistence pass
(notes/reference/sprites.md Part 5) and this very bit (probe_area_map_state.py predicted it was
cleared on load; on a quiet map it SURVIVES). So the console is asked.

THE CONSOLE'S VERDICT (Route 12, a scripted map, ordinary Continue) is printed by this probe:

  * bit CLEAR -> the live byte we wrote is REPLACED by the map's stored byte. Editing
    `wCurMapScript` alone changes nothing you can keep: it is a copy, refreshed from the stored
    byte on the first script tick.
  * bit SET   -> the live byte WINS, and propagates INTO the stored byte. The one-shot override
    is real, it survives a save, and it is the only thing that makes the live byte meaningful.

So the two really are one value with a game-provided switch between them, and the UI should say
so: World holds the persistent stored byte; the live byte + its override belong together in Map
Details, behind the Tinkerer gate, because a save resting on a desync is a state the game erases.

⚠️ Route 12 is used because it is SCRIPTED (its wrapper routes through the table). A quiet map
like Pallet never calls `ExecuteCurMapScriptInTable` at all, so nothing there would overwrite
anything -- which is exactly the false negative that would make a lazy probe agree with the
wrong answer.

Local-only; needs the gitignored ROM. Run: python scripts/emu/probe_cur_map_script.py
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROM = REPO / "assets" / "references" / "backup.gb"
BASE_SAV = REPO / "assets" / "saves" / "forged-maps" / "Route12.sav"
OUT = REPO / "tmp" / "emu-curmapscript"

# sMainData starts at 0x25A3 -> wMainDataStart $D2F7, so  wram = sav + 0xAD54
DELTA = 0xAD54

CUR_MAP_SCRIPT = 0x2CE5      # wCurMapScript          -- the LIVE byte (Map Details)

# wRoute12CurScript -- the STORED byte (World panel).
#
# ⚠️ **+52, NOT +39.** The script list's `ind` is a POSITION IN THE LIST, not a byte offset:
# `wGameProgressFlags` has `ds` padding holes in it (`ds 1` after Pallet Town, `ds 7` after
# Cerulean City, and five more), and both pret's wram map and our own `scripts.json` carry them.
# `WorldScripts::load()` walks the list honouring each entry's `skip`, which is why the app has
# always been right; this probe did the naive `0x289C + ind` and landed on
# `wSSAnneBowCurScript` — a byte Route 12 never reads. The first run therefore "proved" that
# Route 12's script never executes, which is nonsense, and it took the case-C control (whose
# side-effect witness also failed) to expose it. Counted from wram.asm and cross-checked by
# walking scripts.json's own skips: both say 52.
ROUTE12_SCRIPT = 0x289C + 52
SF7 = 0x29DF                 # wStatusFlags7, bit 4 = BIT_USE_CUR_MAP_SCRIPT
USE_CUR_BIT = 4

# EVENT_BEAT_ROUTE12_SNORLAX -- the SIDE EFFECT that makes case C decisive. @see case C below.
BEAT_SNORLAX_BYTE = 10884    # save offset
BEAT_SNORLAX_BIT = 7

# The marker we write into the live byte. Distinct from the stored byte so "which one won?"
# has a one-glance answer, and a legal Route 12 step so nothing runs off the dispatch table.
LIVE_MARKER = 0x02
STORED_VALUE = 0x00

# ⚠️ WHY THE OBVIOUS TEST OF THE OVERRIDE IS NOT DECISIVE, and what is.
#
# Cases A/B write a marker into the LIVE byte and ask which value survives. That settles the
# CLEAR case completely -- Route 12's step 0 handler writes nothing at all once the Snorlax is
# beaten, so a live byte that changes from our marker to the stored value can only have been
# overwritten by `ld [wCurMapScript], a`. It does NOT settle the SET case, because the marker
# names the step that then RUNS: step 2 is `EndTrainerBattle`, which resets the byte to 0. So
# "the override worked" and "the override did nothing" both end at 0, and reading 0 proves
# nothing either way. (Most non-default steps are transient by design -- 147 resting vs 234
# transient across the game; notes/reference/map-states.md -- so there is rarely a quiet
# non-zero step to use as a witness.)
#
# Case C settles it by SIDE EFFECT instead of by value. Stored = 3
# (`Route12SnorlaxPostBattleScript`), live = 0 (the quiet default), and the two runs differ only
# in the override bit:
#
#   bit CLEAR -> a = STORED = 3 -> step 3 runs -> it SETS EVENT_BEAT_ROUTE12_SNORLAX
#   bit SET   -> a = LIVE   = 0 -> step 0 runs -> quiet; the event stays as it was
#
# The flag is the witness, and it cannot be reached by the other branch. Both runs end with both
# bytes at 0 (the wrapper always writes the result back), which is exactly why the value alone
# could never have answered this.
CASE_C_STORED = 0x03
CASE_C_LIVE = 0x00

SAV_CHECKSUM = 0x3523
SAV_CHECKSUM_START = 0x2598
SAV_CHECKSUM_LEN = 0xF8B


def checksum(sav: bytearray) -> int:
    c = 0xFF
    for i in range(SAV_CHECKSUM_START, SAV_CHECKSUM_START + SAV_CHECKSUM_LEN):
        c = (c - sav[i]) & 0xFF
    return c


def sealed(sav: bytearray) -> bytes:
    sav[SAV_CHECKSUM] = checksum(sav)
    return bytes(sav)


def forge(base: bytes, *, override: bool, stored: int, live: int,
          clear_snorlax: bool = False) -> bytes:
    sav = bytearray(base)
    sav[ROUTE12_SCRIPT] = stored
    sav[CUR_MAP_SCRIPT] = live
    if override:
        sav[SF7] |= (1 << USE_CUR_BIT)
    else:
        sav[SF7] &= ~(1 << USE_CUR_BIT) & 0xFF
    if clear_snorlax:
        # Case C's witness has to START off, or "it is on afterwards" says nothing.
        sav[BEAT_SNORLAX_BYTE] &= ~(1 << BEAT_SNORLAX_BIT) & 0xFF
    return sealed(sav)


# ── boot to overworld (shared shape with the other probes) ───────────────────────────
W_CUR_MAP_WIDTH = 0xD369
W_CUR_MAP_HEIGHT = 0xD368
W_OVERWORLD_MAP = 0xC6E8
W_TILEMAP = 0xC3A0
SCREEN_TILES = 20 * 18


def boot(pyboy, budget: int = 9000) -> bool:
    def on_overworld() -> bool:
        mem = pyboy.memory
        w, h = mem[W_CUR_MAP_WIDTH], mem[W_CUR_MAP_HEIGHT]
        if not (0 < w <= 64 and 0 < h <= 96):
            return False
        blocks = bytes(mem[W_OVERWORLD_MAP:W_OVERWORLD_MAP + (w + 6) * (h + 6)])
        screen = bytes(mem[W_TILEMAP:W_TILEMAP + SCREEN_TILES])
        return len(set(blocks)) > 1 and len(set(screen)) > 1

    frames = 0
    while frames < budget and not on_overworld():
        pyboy.button("start" if (frames // 24) % 2 == 0 else "a", delay=8)
        for _ in range(24):
            pyboy.tick()
        frames += 24
    if not on_overworld():
        return False
    # Let the overworld loop tick the map script a good few times. ONE tick is enough for the
    # copy; several make sure we are reading a settled state and not a half-executed frame.
    for _ in range(300):
        pyboy.tick()
    return True


def run(rom: Path, sav: bytes, label: str) -> dict | None:
    from pyboy import PyBoy
    (OUT / "rom.gb.ram").write_bytes(sav)
    pyboy = PyBoy(str(rom), window="null", sound_emulated=False)
    if not boot(pyboy):
        pyboy.stop(save=False)
        print(f"  {label}: never reached the overworld")
        return None
    mem = pyboy.memory
    got = {
        "live": mem[CUR_MAP_SCRIPT + DELTA],
        "stored": mem[ROUTE12_SCRIPT + DELTA],
        "bit": (mem[SF7 + DELTA] >> USE_CUR_BIT) & 1,
        "snorlax": (mem[BEAT_SNORLAX_BYTE + DELTA] >> BEAT_SNORLAX_BIT) & 1,
    }
    pyboy.screen.image.save(OUT / f"{label}.png")
    pyboy.stop(save=False)
    return got


def main() -> int:
    if not ROM.exists():
        print("SKIP: no ROM (local-only verification)")
        return 2
    if not BASE_SAV.exists():
        print(f"SKIP: no fixture at {BASE_SAV}")
        return 2
    OUT.mkdir(parents=True, exist_ok=True)
    rom = OUT / "rom.gb"
    shutil.copyfile(ROM, rom)
    base = bytes(BASE_SAV.read_bytes())

    print("\n===== wCurMapScript vs the map's stored script byte (Route 12, Continue) =====")

    # ── A/B: does an edited LIVE byte survive when the override is off? ──────────────
    print(f"\n  A/B -- wrote stored=0x{STORED_VALUE:02X}  live=0x{LIVE_MARKER:02X}")
    ab = {}
    for label, override in (("A-override-clear", False), ("B-override-set", True)):
        got = run(rom, forge(base, override=override, stored=STORED_VALUE,
                             live=LIVE_MARKER), label)
        if not got:
            return 1
        ab[label] = got
        print(f"    BIT_USE_CUR_MAP_SCRIPT {'SET  ' if override else 'CLEAR'}"
              f" -> live=0x{got['live']:02X}  stored=0x{got['stored']:02X}"
              f"  bit now {got['bit']}")

    # ── C: the override, decided by SIDE EFFECT (see the note on CASE_C_STORED) ──────
    print(f"\n  C   -- wrote stored=0x{CASE_C_STORED:02X}  live=0x{CASE_C_LIVE:02X},"
          " Snorlax-beaten cleared; the witness is that event flag")
    c = {}
    for label, override in (("C-override-clear", False), ("C-override-set", True)):
        got = run(rom, forge(base, override=override, stored=CASE_C_STORED,
                             live=CASE_C_LIVE, clear_snorlax=True), label)
        if not got:
            return 1
        c[label] = got
        print(f"    BIT_USE_CUR_MAP_SCRIPT {'SET  ' if override else 'CLEAR'}"
              f" -> live=0x{got['live']:02X}  stored=0x{got['stored']:02X}"
              f"  beatSnorlax={got['snorlax']}")

    # ⚠️ THE EVENT-FLAG WITNESS DOES NOT FIRE, AND THAT IS FINE -- case C turned out to be
    # decisive BY VALUE, which is stronger. `Route12SnorlaxPostBattleScript` reaches
    # `DisplayTextID` and PARKS on a text box waiting for a button press, so it never gets as far
    # as `SetEvent` and never returns to write its result back. (A settle-only harness reading a
    # parked text box as "healthy" is a trap already on the books --
    # notes/reference/forged-saves.md.) The two byte readings mirror each other exactly and each
    # one can only be produced by its own branch, so they settle it on their own:
    #
    #   CLEAR: we wrote live=0, stored=3 -> read live=3. Only `ld [wCurMapScript], a` with
    #          a = the STORED byte can put a 3 there. The stored byte overwrote the live one.
    #   SET:   we wrote live=0, stored=3 -> read stored=0. Only the override branch
    #          (`ld a, [wCurMapScript]`) can make the LIVE 0 the value that is written back.
    clear_c, set_c = c["C-override-clear"], c["C-override-set"]
    took_stored = clear_c["live"] == CASE_C_STORED
    took_live = set_c["stored"] == CASE_C_LIVE

    print("\n  Verdict:")
    if ab["A-override-clear"]["live"] == STORED_VALUE and took_stored:
        print("    * bit CLEAR: the STORED byte overwrites the live one (live 0x00 -> 0x03)."
              "\n                 Editing the live byte alone keeps NOTHING.")
    else:
        print("    * bit CLEAR: NOT the expected copy -- the source read was wrong somewhere."
              f" A-live=0x{ab['A-override-clear']['live']:02X},"
              f" C-live=0x{clear_c['live']:02X} (want 0x{CASE_C_STORED:02X}).")

    if took_live:
        print("    * bit SET:   the LIVE byte wins and propagates INTO the stored byte"
              " (stored 0x03 -> 0x00)."
              "\n                 The override is real, and it survives a save.")
    else:
        print(f"    * bit SET:   inconclusive -- stored=0x{set_c['stored']:02X}"
              f" (want 0x{CASE_C_LIVE:02X}). Do NOT conclude from this run.")

    print(f"\n  (The EVENT_BEAT_ROUTE12_SNORLAX witness read"
          f" {clear_c['snorlax']}/{set_c['snorlax']}; see the note above -- step 3 parks on a"
          " text box before it reaches SetEvent, so the flag is silent by design here.)")
    return 0 if (took_stored and took_live) else 1


if __name__ == "__main__":
    sys.exit(main())
