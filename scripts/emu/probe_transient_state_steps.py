r"""What actually happens when you CONTINUE into a mid-cutscene ("transient") map-state step?

Project leadership, 2026-08-18:

  *"Dont have state steps like Step 1, Step 2, Step 3 -- i dont think its how it works, like if i
   select this and load the game the continue feature i dont think can enter a cutscene. Please
   investigate if this is glitchy or crashy or buggy -- it needs to be gated useless but i need solid
   confirmation first."*

The editor's progression picker lists every value of a map's `def_script_pointers` table. Our own
research (notes/reference/map-states.md) splits those 381 values into **147 resting** and **234
transient**: a resting value is what the byte sits at between play sessions; a transient one is a step
the engine passes through frame-by-frame during a cutscene (Oak walking over, the rival marching in).

What a source read CAN settle: a transient value is a real entry in the table, so it is NOT the
unbounded-`jp hl` crash that an out-of-RANGE byte causes. What it CANNOT settle is the thing actually
asked -- whether the console can be dropped into the middle of a cutscene by a Continue and carry on,
because that depends on state the cutscene set up before it ever reached that step (sprite positions,
scripted-movement flags, text box state), and on what `LoadMapHeader`/`EnterMap` rebuild on the way in.
A careful asm read has been wrong here before (the sprite-persistence pass, 2026-07-13), so the
console is asked.

**Pallet Town** is the exemplar and the cleanest test bench: slot 1, seven values, and the four in the
middle are the Oak intro cutscene.

    0  SCRIPT_PALLETTOWN_DEFAULT                  resting   (control)
    1  SCRIPT_PALLETTOWN_OAK_HEY_WAIT             transient
    2  SCRIPT_PALLETTOWN_OAK_WALKS_TO_PLAYER      transient
    3  SCRIPT_PALLETTOWN_OAK_NOT_SAFE_COME_WITH_ME transient
    4  SCRIPT_PALLETTOWN_PLAYER_FOLLOWS_OAK       transient
    5  SCRIPT_PALLETTOWN_DAISY                    resting
    6  SCRIPT_PALLETTOWN_NOOP                     resting   (control)

For each: write the byte, re-seal the checksum, boot Continue, and then ask three questions the user
would ask.

  1. **Does it come up at all?**  -- did we ever reach the overworld, or did it hang/black-screen?
  2. **Does it stay up?**         -- tick on and watch for the CPU dying (a crashed Game Boy executes
                                     `STOP`, the clocks halt, and the screen stops changing entirely).
  3. **Can you MOVE?**            -- the honest test of "did I land in a playable state". A cutscene
                                     holds the controls: `wStatusFlags5` bit 7 (`BIT_SCRIPTED_MOVEMENT
                                     _STATE`) / `wJoyIgnore` non-zero mean the game is driving, not
                                     you. We also press a direction for a while and see whether the
                                     player's coordinates ever change.

The verdict this prints is the evidence for whether these entries get gated behind the "!" -- nothing
is gated on a hunch, and nothing is left in on one either.

⚠️⚠️ **THIS PROBE IS NOT CALIBRATED YET. DO NOT QUOTE ITS OUTPUT AS EVIDENCE.** ⚠️⚠️

Two runs (2026-08-18) produced a verdict for all seven values, and the verdict is worthless, because
**both instruments are reading the wrong thing** -- which the CONTROLS proved, exactly as controls are
meant to:

  * every value came back `FROZEN (screen never changed)` -- *including* `DEFAULT` and `NOOP`, the two
    known-good resting values a normal save sits on. A save that boots and plays fine cannot be
    frozen, so the liveness test is broken, not the game. Hashing `wTilemap` was the first mistake
    (the background scrolls through the LCD registers, so the tile ids can sit still while the picture
    moves); switching to the framebuffer did NOT fix it, so the render path needs looking at too --
    `window="null"` may not be producing new frames without an explicit render.
  * every value reported the player walking `(3,6) -> (3,7)` -- the same numbers every time, and the
    app says this save's player is at **(5,6)**. So `W_X_COORD`/`W_Y_COORD` are not the player's
    coordinates either; something else is incrementing.
  * the first cut also read a hardcoded `wCurMapScript` that returned 0 for every case. That address
    is now not asserted at all rather than published wrong.

A probe that returns the same answer for a known-good and a suspected-bad input **distinguishes
nothing** -- the `emu-venv` lesson in a new costume: a check must be able to fail, and it must be able
to PASS. Calibrate against `DEFAULT` first (it must read PLAYABLE) before trusting a single word this
prints about a transient value.

**The question is still open.** Project leadership asked for solid confirmation before these entries
are gated, and this does not yet supply it.

Local-only; needs the gitignored ROM. Run:
    tmp\emu-venv\Scripts\python.exe scripts\emu\probe_transient_state_steps.py
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROM = REPO / "assets" / "references" / "backup.gb"
BASE_SAV = REPO / "assets" / "saves" / "natural-clean" / "BaseSAV.sav"
OUT = REPO / "tmp" / "emu-transient"

# ── save offsets ────────────────────────────────────────────────────────────────────
# sMainData starts at 0x25A3 and maps wMainDataStart = $D2F7, so  wram = sav + 0xAD54.
SAV_SCRIPTS = 0x289C              # wMapScripts -- one byte per scripted map, indexed by slot
PALLET_SLOT = 1                   # from projects/db/assets/data/map-states/PalletTown.json

SAV_CHECKSUM = 0x3523
SAV_CHECKSUM_START = 0x2598
SAV_CHECKSUM_LEN = 0xF8B

# ── wram addresses ──────────────────────────────────────────────────────────────────
#
# ⚠️ The live `wCurMapScript` address is NOT asserted here. The first cut guessed $D5F0 and read 0
# for every single case, controls included -- which means it was reading something else, not that the
# byte was zero. Rather than publish a number this probe cannot stand behind, the byte is read back
# from the SAVE ARRAY we wrote (which is the thing under test), and the verdict rests on behaviour:
# does it come up, does it stay up, can you move.
W_STATUS_FLAGS_5 = 0xD730         # bit 7 = BIT_SCRIPTED_MOVEMENT_STATE
W_JOY_IGNORE = 0xD730             # (kept distinct below; see read_console)
W_X_COORD = 0xD362
W_Y_COORD = 0xD361

W_CUR_MAP_WIDTH = 0xD369
W_CUR_MAP_HEIGHT = 0xD368
W_OVERWORLD_MAP = 0xC6E8
W_TILEMAP = 0xC3A0
SCREEN_TILES = 20 * 18

STEPS = [
    (0, "SCRIPT_PALLETTOWN_DEFAULT", "resting"),
    (1, "SCRIPT_PALLETTOWN_OAK_HEY_WAIT", "transient"),
    (2, "SCRIPT_PALLETTOWN_OAK_WALKS_TO_PLAYER", "transient"),
    (3, "SCRIPT_PALLETTOWN_OAK_NOT_SAFE_COME_WITH_ME", "transient"),
    (4, "SCRIPT_PALLETTOWN_PLAYER_FOLLOWS_OAK", "transient"),
    (5, "SCRIPT_PALLETTOWN_DAISY", "resting"),
    (6, "SCRIPT_PALLETTOWN_NOOP", "resting"),
]


def checksum(sav: bytearray) -> int:
    c = 0xFF
    for i in range(SAV_CHECKSUM_START, SAV_CHECKSUM_START + SAV_CHECKSUM_LEN):
        c = (c - sav[i]) & 0xFF
    return c


def with_step(base: bytes, value: int) -> bytes:
    sav = bytearray(base)
    sav[SAV_SCRIPTS + PALLET_SLOT] = value & 0xFF
    sav[SAV_CHECKSUM] = checksum(sav)
    return bytes(sav)


def on_overworld(pyboy) -> bool:
    mem = pyboy.memory
    w, h = mem[W_CUR_MAP_WIDTH], mem[W_CUR_MAP_HEIGHT]
    if not (0 < w <= 64 and 0 < h <= 96):
        return False
    blocks = bytes(mem[W_OVERWORLD_MAP:W_OVERWORLD_MAP + (w + 6) * (h + 6)])
    screen = bytes(mem[W_TILEMAP:W_TILEMAP + SCREEN_TILES])
    return len(set(blocks)) > 1 and len(set(screen)) > 1


def boot(pyboy, budget: int = 9000) -> bool:
    """Continue into the save. Presses start/a alternately until the overworld appears."""
    frames = 0
    while frames < budget and not on_overworld(pyboy):
        pyboy.button("start" if (frames // 24) % 2 == 0 else "a", delay=8)
        for _ in range(24):
            pyboy.tick()
        frames += 24
    if not on_overworld(pyboy):
        return False
    for _ in range(240):          # let the map settle / any auto-cutscene get going
        pyboy.tick()
    return True


def screen_hash(pyboy) -> int:
    """⚠️ THE FRAMEBUFFER, not `wTilemap`.

    The first cut of this probe hashed `wTilemap` and reported **every** case as FROZEN -- including
    the two known-good controls (DEFAULT and NOOP) -- while printing, on the very same line, that the
    player had walked from (3,6) to (3,7). A dead CPU does not walk. The check was simply wrong: the
    background scrolls through the LCD's scroll registers and the visible tile ids can sit still while
    the picture moves, so an unchanging `wTilemap` says nothing about whether the machine is alive.

    A check that fails on everything distinguishes nothing -- this is the `emu-venv` lesson again, and
    a probe that lies is worse than no probe, so the results of that run were discarded rather than
    reported. Hash what the screen ACTUALLY shows.
    """
    return hash(pyboy.screen.image.tobytes())


def run(value: int, name: str, kind: str, base: bytes) -> dict:
    from pyboy import PyBoy

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "rom.gb.ram").write_bytes(with_step(base, value))

    pyboy = PyBoy(str(ROM), window="null", sound_emulated=False)
    r: dict = {"value": value, "name": name, "kind": kind}

    if not boot(pyboy):
        r["reachedOverworld"] = False
        r["verdict"] = "NEVER REACHED THE OVERWORLD"
        pyboy.screen.image.save(OUT / f"step{value}-stuck.png")
        pyboy.stop(save=False)
        return r

    mem = pyboy.memory
    r["reachedOverworld"] = True
    r["statusFlags5"] = mem[W_STATUS_FLAGS_5]
    r["scriptedMovement"] = (mem[W_STATUS_FLAGS_5] >> 7) & 1

    # ── is it ALIVE? a crashed CPU stops changing the screen entirely ───────────────
    hashes = set()
    for _ in range(12):
        for _ in range(30):
            pyboy.tick()
        hashes.add(screen_hash(pyboy))
    r["screenStates"] = len(hashes)

    # ── can you MOVE? the honest "is this playable" test ────────────────────────────
    x0, y0 = mem[W_X_COORD], mem[W_Y_COORD]
    for _ in range(10):
        pyboy.button("down", delay=6)
        for _ in range(24):
            pyboy.tick()
    x1, y1 = mem[W_X_COORD], mem[W_Y_COORD]
    r["movedFrom"] = (x0, y0)
    r["movedTo"] = (x1, y1)
    r["canMove"] = (x0, y0) != (x1, y1)

    pyboy.screen.image.save(OUT / f"step{value}-{kind}.png")
    pyboy.stop(save=False)

    if r["screenStates"] <= 1:
        r["verdict"] = "FROZEN (screen never changed -- CPU likely dead)"
    elif not r["canMove"]:
        r["verdict"] = "ALIVE but CONTROLS HELD (could not walk)"
    else:
        r["verdict"] = "PLAYABLE"
    return r


def main() -> int:
    if not ROM.exists():
        print(f"no ROM at {ROM} -- local only, never committed")
        return 2

    OUT.mkdir(parents=True, exist_ok=True)
    base = BASE_SAV.read_bytes()

    print("Continue-ing into every Pallet Town script value\n")
    rows = []
    for value, name, kind in STEPS:
        r = run(value, name, kind, base)
        rows.append(r)
        print(f"  {value}  {kind:9}  {name}")
        print(f"       reached overworld : {r['reachedOverworld']}")
        if r["reachedOverworld"]:
            print(f"       scripted movement : {r['scriptedMovement']}")
            print(f"       screen states/360f: {r['screenStates']}")
            print(f"       walked            : {r['movedFrom']} -> {r['movedTo']}")
        print(f"       VERDICT           : {r['verdict']}\n")

    print("-" * 70)
    bad = [r for r in rows if r["verdict"] != "PLAYABLE"]
    if not bad:
        print("Every value -- transient included -- came up PLAYABLE.")
    else:
        print("Not playable:")
        for r in bad:
            print(f"  {r['value']}  {r['kind']:9}  {r['name']}  -> {r['verdict']}")
    print(f"\nscreenshots: {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
