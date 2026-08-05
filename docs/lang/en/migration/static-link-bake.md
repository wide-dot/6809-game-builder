# A v1 game has no link data; a v2 unit pays for every pointer it holds

v1 burned final addresses into its tables. v2 relocates, so the same table
arrives as a list of things the loader must patch — and that list lives in the
loader's memory pool. A faithful port has no reason to write the one thing that
avoids it, and no way to guess that it should.

## Symptom

The game boots, the loader runs, sectors keep coming — and then it stops. The
screen holds whatever was last drawn, often still the monitor's menu with a
palette the loader has already changed. Nothing is reported: no error, no
message, no reset.

The trace ring shows a two-byte self-loop at an address that appears in no
listing of the game:

```
PC=A2D9  cycles=3   PC=A2D9  cycles=3   PC=A2D9  cycles=3 …
```

`20 FE` is `bra *`. Look it up in the **loader's** map, not the game's:

```
$ grep -i a2d9 gen/bootloader/build/loader.lwmap
Symbol: tlsf.err.loop … = A2D9
```

That is the allocator's error trap. The code beside it is the giveaway that
sends people the wrong way: the bytes below it are `$FF`, which is the power-on
RAM pattern, so it reads like a bank that never loaded — a disk fault, an
emulator fault, anything but a link problem. Two sessions went to the disk image
and the emulator's `.fd` path before anyone read the error byte.

Read it. The addresses come from the loader map, and the codes from
`engine/memory/malloc/tlsf.asm`:

| symbol | in this build | value | meaning |
|---|---|---|---|
| `tlsf.err` | `$A138` | `3` | `tlsf.err.malloc.OUT_OF_MEMORY` |
| `tlsf.memoryPool` | `$A13D` | `$AF81` | pool start |
| `tlsf.memoryPool.end` | `$A13F` | `$CF81` | pool end |
| `tlsf.memoryPool.size` | `$A141` | `$2000` | **8 KB** |
| `tlsf.rsize` | `$A403` | `$0628` | the request that failed, 1576 bytes |

An 8 KB pool that cannot serve 1576 bytes is not fragmented, it is full. The
question is what filled it, and the answer is almost always link data.

## The v1 idiom

A v1 game mode is one absolute image. Its pointer tables were produced by the
build *after* placement, so they held finished addresses:

```asm
Ani_Asd_Index
        fdb   Ani_Asd_pata     ; a real address, known at assembly time
        fdb   Ani_Asd_rship
```

There is no loader-side work in that, and therefore no cost. The v1 engine has
no memory pool for link data because it has no link data.

## The v2 model

A unit is relocatable and linked on the machine at load time. Every reference
lwasm could not finish becomes an entry in the unit's link block: four bytes for
an intern, six for an extern. The loader reads that block when it indexes the
file and **keeps it in the pool for as long as the file stays indexed** — not
for the duration of the load, for the duration of the file's life.

The arithmetic is unforgiving on the shapes that migrate worst. R-type's
animation scripts are ~2900 pointers into themselves: 8 KB of link data, which
is the whole pool. The reference manual has the mechanism and the measurements
in [`symbols.md`](../symbols.md); what matters here is that the cost is
invisible in the source. The table looks exactly like its v1 counterpart.

## The fix

Bracket the table in a section whose name ends with `.static`. The source does
not otherwise change — same `EXTERNAL`, same `fdb`:

```asm
Ani_Asd_common EXPORT

 SECTION anim.static

Ani_Asd_common
        INCLUDE "src/common/fx/animation/index.asm"
        INCLUDE "src/common/fx/animation/script.asm"

 ENDSECTION
```

The builder resolves those references itself and emits no link data for them.
It refuses, with an error naming the section, offset and symbol, if a reference
does not have a single fixed destination — a `.static` section is a promise,
not a hint.

Then finish the job: when **every** reference of a unit is baked, drop
`loadtimelink` from its direntry. Half a unit baked shrinks the block but keeps
the allocation alive, so the pool cost only reaches zero at the end.

Apply it to every unit whose destination is fixed, not only to what is shared
between stages — the policy, and why the shared/not-shared distinction is the
wrong one, is stated in [`symbols.md`](../symbols.md#the-policy).

Two traps on the way, both met on r-type :

**Do not bake a unit that reads a swappable one.** The engine's references into
the stage are the stage exchange itself; freezing them would break the swap
rather than shrink it. The policy section states the direction.

**A whole-unit bake renames the entry point's section.** These units are one
`SECTION code` holding code and tables together, so baking them means
`SECTION code.static` — which the builder now leads with, as it did `code`. Any
generated `SECTION code` in the same unit (`png2pal`'s palette tables) has to
move out with `section="palette.static"`, or two sections would claim the first
byte and the object's order would decide the entry point.

## Proof

The build's link report is the direct answer. Before, on r-type:

```
link data: 30 direntries, 8578 bytes (pool cost while indexed), 4077 references baked
  bytes  intern  x8  x16  page  expA  expR   baked  direntry
   2438     473   0   13     0     0   114       0  common.engine
   1576      70   0  210     0     0     6       0  stage1
   1424      44   0  202     0     0     6       0  stage2
```

8578 bytes of link data for an 8192 byte pool: over budget before a single
allocation. And `stage1` is **1576 bytes** — the very `tlsf.rsize` the machine
reported. The request that failed was that file's link block.

After baking the two stages, 526 references resolved at build time:

```
link data: 30 direntries, 5278 bytes (pool cost while indexed), 4603 references baked
   2138     473   0   13     0     0    39       0  common.engine
     36       0   0    0     0     0     6     280  stage1
```

`stage1` 1576 → 36, `stage2` 1424 → 36. `common.engine` drops 300 bytes it was
never asked about: with the stages no longer importing through the loader, 75 of
its exports became dead and were pruned. The two mechanisms compound.

On the machine: `tlsf.err` at `$A138` reads `0`, and the load runs past the
title into stage 1 — ship, starfield, scrolling terrain and HUD.

## The same wall, met from the other side

Baking buys headroom ; it does not remove the ceiling. Two days later, wiring
one more common object (the bit device, 344 bytes of link data) took r-type
from 8760 to 9104 bytes against a pool capped at `$2800` = 10240 — and the
machine hung at the monitor menu again, PC parked inside the loader, with a
build that was entirely green.

Two things make this worth its own paragraph.

**The failure is indistinguishable from "the disk did not boot".** There is no
`tlsf.err` to read this time and no crash : the loader simply never hands over,
so what you see is the machine's own menu, exactly as if the keypress had been
missed. The tell is the PC — inside the data window (`$A000-$DFFF`), which is
where the loader lives, rather than in the monitor.

**The real ceiling is not the configured value.** `loader.memoryPool` is
`equ *` — it starts where the loader's code ends. Read both from the loader's
map file :

```
Symbol: loader.ADDRESS      = A000
Symbol: loader.memoryPool   = AF81
```

The data window ends at `$E000`, so the pool can be at most `$E000 - $AF81`
= `$307F` = 12415 bytes.

**And the link-data figure alone will not predict the failure.** The build
prints

```
link data: 30 direntries, 9104 bytes (pool cost while indexed), 4537 references baked
```

but the pool also carries the **directory**, the **scene file**, and a **slot
table the loader reallocs** — three more `tlsf.malloc` sites in
`loader.asm`. Doing the arithmetic on link data alone says 9032 bytes for the
29 boot entries, plus 4 bytes of header per block, plus TLSF's second-level
rounding, is 9304 — comfortably inside a 10240-byte pool. It is not: the pool
ran out anyway.

So treat that line as an **indicator**, and measure the answer :

| pool | `tlsf.err` at `$A138` after boot | result |
|---|---|---|
| `$2800` = 10240 | `3` (`OUT_OF_MEMORY`) | loader never hands over |
| `$3000` = 12288 | `0` | boots |

Reading that one byte is the whole diagnosis, and it costs nothing. Do it
before theorising about which allocation failed.

## Met in

`games/r-type`, 2026-08-03, and again 2026-08-05. The v1 build of the same game boots under the same
emulator, which is what finally ruled out the disk and the emulator: v1 has no
link data to lose.
