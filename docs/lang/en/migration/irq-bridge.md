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

The kept-v2 players are linked at load time against `irq.on` / `irq.off`. A
v1-dialect game mode exports neither. Bridge them with equates, which emit no
bytes:

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
