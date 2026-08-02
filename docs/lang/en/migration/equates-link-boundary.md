# Absolute equates never cross the link boundary

An engine interface list (`_api` and friends) may carry **routines**. It must
never carry an **equate that denotes an absolute address** — a direct-page
slot, a hardware register, a fixed RAM location. Those are shared by
assembling the same header on both sides.

## Symptom

Nothing at build time. The unit assembles, links and runs.

Then a value written by a paged unit never arrives, and the engine reads zero
where the unit swears it stored something. In the case that produced this file,
the missing value was a callback address, so the engine called `$0000` instead
— which happened to be the caller's own entry point, so the object re-entered
itself, recursed without bound, and the stack walked down out of its 124-byte
budget through the object pool. The visible failure was *memory corruption
seven hundred bytes away from anything related*.

Read the emitted bytes rather than the source when you suspect this:

```
004F FD0000    std   moveByScript.callback     ← relocation placeholder
                                                  linked to $00A9
```

against what it should be:

```
004F FD9FA9    std   moveByScript.callback     ← the absolute address
```

`$9FA9` and `$00A9` differ by `$9F00`, which is `dp`. That constant offset
between "what I meant" and "what got linked" is the signature.

## The v1 idiom

There was no boundary. A v1 game mode is one assembly: the engine's
`moveByScript.asm` defined

```
moveByScript.callback   equ glb_a0     ; object routine called at each move step
```

and every object in the same image saw `$9FA9` directly. Sharing it cost
nothing and needed no declaration.

## The v2 model

A v2 unit is relocatable, and `EXPORT` / `EXTERNAL` are resolved by the loader
against **section-relative** values. That is exactly right for a routine: the
linker knows where the section landed and completes the address.

An equate has no section. Passing one through the boundary asks the linker to
rebase something that was already absolute, and it obliges — silently, because
a relocation that resolves is not an error.

So the two kinds of shared name need two different mechanisms:

| What is shared | Mechanism | Why |
|---|---|---|
| a routine, a table — anything with an address *inside a unit* | `EXPORT` / `EXTERNAL`, resolved at load time | its address is only known once the unit is placed |
| an absolute address — direct page, registers, fixed RAM | a header included by both sides, at assembly time | its address is a property of the machine, not of any unit |

The engine's own `engine/constants.asm` is already included by both sides. That
is the natural home, and it puts the equate next to the `glb_*` chain it
derives from.

## The fix

Take the names out of the interface list:

```asm
        ; Only the routines cross the boundary. callback, anim.end and
        ; anim.loops are direct-page equates, not labels: they are shared at
        ; assembly time by engine/constants.asm. Listing them here had the
        ; linker rebase them, $9FA9 -> $00A9.
        _api moveByScript.initialize
        _api moveByScript.runByB
        _api moveByScript.runByFrameDrop
        _api moveByScript.register
```

and move the definitions to `engine/constants.asm`, beside the registers they
alias:

```asm
moveByScript.callback       equ glb_a0
moveByScript.anim.speed     equ glb_d0
moveByScript.anim.end       equ glb_d0_b
moveByScript.anim.loops     equ glb_d0_b+1
```

Before deleting them from their old home, check that **every** file which
includes that home also includes `engine/constants.asm` — otherwise you have
traded a silent wrong value for a loud build break in some other project.

## Proof

The listing, not the source:

```
004F FD9FA9    std   moveByScript.callback
0071 B69F98    lda   moveByScript.anim.end
```

Then the behaviour that the wrong value was suppressing. Here the enemy
initialised, animated and moved instead of recursing, with the stack back
inside its budget (`S = $9EFE`, ceiling `$9F00`) and the witness area
untouched.

## A note on "an external resolved to zero is not an error"

That sentence is true for a routine: two units both loaded at offset zero
legitimately expose symbols at offset zero. It is **never** true for an
absolute address. Zero is not a plausible direct-page slot, and treating it as
benign is what let this bug live for two sessions.

## How it was found

Not by reading. The corruption was located with a memory watchpoint under
[toje][toje] — `set_watchpoint` on the witness range, then `run_to_breakpoint`,
which reported the writing instruction (`culprit_pc`) rather than the
instruction after it. That pointed at a `pshs` whose `S` had wandered, which
turned a memory-corruption hunt into a stack-overflow hunt, which led to the
recursion, which led here. A second watchpoint on the callback slot itself
proved it was written exactly once — by the direct-page clear at startup — and
never again.

[toje]: https://github.com/wide-dot/toje

## Met in

`games/r-type`, 2026-08-02. Cost two debugging sessions before it was found:
the first established that the object initialised correctly and that something
else corrupted `$9C00`, and stopped there.
