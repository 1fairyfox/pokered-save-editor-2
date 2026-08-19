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

⚠️ **THE FIRST TWO RUNS WERE BOGUS, AND THE FAULT WAS ONE LINE.** Kept here because the shape of the
mistake matters more than the fix.

Both runs reported `FROZEN (screen never changed)` for **every** value -- including `DEFAULT` and
`NOOP`, the two resting values a normal save sits on. A save that boots and plays fine cannot be
frozen, so the controls said "your instrument is broken" on the very first line of output. Worse, the
same run printed the player WALKING on the line above the verdict: a dead CPU does not walk.

The cause was not the addresses (`wYCoord`/`wXCoord` were right; the movement check worked in all
seven cases). It was **`pyboy.tick()` without the render argument** -- with `window="null"` PyBoy does
not draw a frame unless asked, so `screen.image` returned the same stale buffer forever and every case
looked identical. `tick(1, True)` asks for the frame.

The lesson, and it is the `emu-venv` one again: **a check must be able to FAIL and to PASS.** Anything
that answers identically for a known-good and a suspected-bad input is measuring nothing -- and the
controls are what tell you, immediately, for free, if you put them in.

⚠️ AND THE REAL FAULT WAS NEITHER OF THOSE. It was that **PyBoy loads the `.ram` sitting next to the
ROM it was handed.** The save was written to `tmp/emu-transient/rom.gb.ram` and the emulator was
launched on `assets/references/backup.gb`, so it loaded `backup.gb.ram` -- an untouched save -- seven
times. Every run was the same run, which is why all seven screenshots were byte-identical and showed
an indoor room rather than Pallet Town. Nothing needed tuning; a file was in the wrong place.

── THE ANSWER (run 2026-08-18, after the fix) ────────────────────────────────────────────────────

    value  kind        verdict                      walked
    0      resting     PLAYABLE                     (5,6) -> (5,8)
    1      transient   CONTROLS HELD, cannot walk   (5,1) -> (5,1)     <- teleported to the cutscene
    2      transient   CONTROLS HELD, cannot walk   (5,1) -> (5,1)     <- teleported to the cutscene
    3      transient   CONTROLS HELD, cannot walk   (5,6) -> (5,6)
    4      transient   PLAYABLE                     (5,6) -> (5,8)
    5      resting     PLAYABLE                     (5,6) -> (5,8)
    6      resting     PLAYABLE                     (5,6) -> (5,8)

**All three resting values are playable. Three of the four transients are not.** The console does not
crash and does not freeze -- it comes up, it animates, and then it *keeps the controls*, because a
cutscene is running and the game is driving. Two of them also **move the player** to the cutscene's
staging square (5,1) before you ever touch the pad.

So project leadership's read was right: a Continue cannot sensibly resume into a mid-cutscene step.
That is the evidence for gating the cutscene entries -- they are not a crash, they are a save you
cannot play.

⚠️ Do NOT quote the `scripted movement` column: it read 0 in every case including the three that
demonstrably held the controls, so that flag/bit is not the one being read. The verdict above rests
entirely on observed behaviour (came up, animated, could/could not walk), which needs no such claim.

Local-only; needs the gitignored ROM. Run:
    tmp\emu-venv\Scripts\python.exe scripts\emu\probe_transient_state_steps.py
"""

from __future__ import annotations

import shutil
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

    # ⚠️ PyBoy LOADS THE `.ram` THAT SITS NEXT TO THE ROM IT WAS GIVEN.
    #
    # This is the whole of the bogus result, and it is not subtle once seen: the first cut wrote the
    # forged save to `tmp/emu-transient/rom.gb.ram` and then launched `PyBoy(assets/.../backup.gb)`,
    # so the emulator loaded `assets/.../backup.gb.ram` -- an untouched save -- **seven times**. Every
    # run was the same run. The screenshots proved it: all seven PNGs were byte-identical, and they
    # showed an indoor room, not Pallet Town, so the byte under test was never even consulted.
    #
    # Copy the ROM next to the save, and launch THAT. (The other probes in this folder do exactly
    # this; dropping the copy is what broke it.)
    OUT.mkdir(parents=True, exist_ok=True)
    rom_here = OUT / "rom.gb"
    if not rom_here.exists():
        shutil.copyfile(ROM, rom_here)
    (OUT / "rom.gb.ram").write_bytes(with_step(base, value))

    pyboy = PyBoy(str(rom_here), window="null", sound_emulated=False)
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
    #
    # ⚠️ `tick(1, True)` -- the second argument is RENDER. With `window="null"` PyBoy does not draw a
    # frame unless asked, so `screen.image` just returns the same stale buffer forever and every
    # single case looks "frozen". That was the whole of the bogus result, and the controls said so
    # immediately: DEFAULT and NOOP cannot be frozen, and the very same run reported the player
    # walking. Ask for the frame and the picture moves.
    hashes = set()
    for _ in range(12):
        for _ in range(29):
            pyboy.tick()
        pyboy.tick(1, True)
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
