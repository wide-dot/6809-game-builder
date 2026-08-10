# The `irq.on` / `irq.off` bridge

Kept-v2 players resolve `irq.on` and `irq.off` at load time. In a v1-dialect
game mode those names do not exist, and **an unresolved symbol is zero, not an
error** — so the player calls `$0000`.

## Symptom

Silence, or a crash inside a sound player, with nothing in the build log. The
`jsr` went to address zero.

This is the same silent-zero failure mode as
[equates-link-boundary](equates-link-boundary.md), from the opposite direction:
there a symbol was resolved when it should not have been, here it is missing
when it should be present. Both produce a plausible-looking address and no
diagnostic.

## The v1 idiom

The v1 engine names them `IrqOn` and `IrqOff`, and everything is in one image,
so the player called them directly.

## The v2 model

The kept-v2 players are linked at load time against `irq.on` / `irq.off`,
whose v2 contract is to **preserve registers** — `engine/system/to8/irq/
irq.asm` obtains it with `pshs a / … / puls a,pc`. The v1 `IrqOn`/`IrqOff`
read the STATUS byte through A instead. A v1-dialect game mode must
therefore bridge with a preserving wrapper, NOT a bare equate:

```asm
irq.on  EXPORT
irq.on  pshs  a
        jsr   IrqOn
        puls  a,pc

irq.off EXPORT
irq.off pshs  a
        jsr   IrqOff
        puls  a,pc
```

A bare `equ` keeps the promise of the name without the promise of the
contract. It cost twice : first found in the r-type common engine (its
bridge carries the full war story), then again in `examples/sound` —
whose title game mode kept the equate form this case used to recommend.
There, `ymm.obj.play`'s internal `jsr irq.off` destroyed the A that
carried the music data page an instruction before `sta ymm.data.page` ;
the stored page became the STATUS residue ($00), and every
`ymm.frame.play` then remounted the cartridge window on page 0 **while
executing from the window** — the ground vanished under the PC, the CPU
walked ROM bytes into VRAM and parked with IRQs masked. The failure is
timing-shaped : whether the machine dies or limps depends on where the
first music IRQ lands, so any change to any file's size moved the
verdict — which is what made it bisect to an innocent commit
(`f7d4474`) before the real cause surfaced.

The obsolete form, kept for recognition — do not use it :

```asm
irq.on   equ IrqOn
irq.off  equ IrqOff
```

and export those names so the loader can resolve the player's references.

## The fix

Add the two bridging exports to the game mode. Then respect the v1 ordering,
which is not obvious:

1. arm the IRQs early (`IrqSet50Hz`);
2. the `obj.play` calls switch them off internally;
3. **switch them back on after the last `obj.play`**.

Skipping step 3 leaves interrupts off with no visible error.

## Proof

Sound plays, and the IRQ is running after initialisation. If you suspect a
`jsr $0000`, a breakpoint at zero settles it immediately.

## Met in

Recorded from the `sound/to8` pilot, 2026-07-31.
