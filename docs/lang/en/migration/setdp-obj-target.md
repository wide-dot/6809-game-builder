# `setdp` is refused by the obj target

Neutralise the directive. Extended addressing is always correct; explicit `<`
operands stay correct too.

## Symptom

lwasm refuses `setdp` when assembling to the relocatable object format.

## The v1 idiom

```asm
        setdp dp/256
```

so that implicit-direct operands assembled as direct-page instructions, saving
a byte and a cycle each.

## The v2 model

`setdp` is a statement about a *fixed* runtime `DP` in an absolute image. In the
obj target it is not available. Two consequences, and only the first is
obvious:

- operands that were implicitly direct now assemble **extended**. That is
  larger and slower, but always correct — the runtime `DP` is untouched;
- operands written with an explicit `<` still assemble direct, taking the low
  byte of the symbol. Those remain correct **only if the runtime `DP` is what
  the code assumes**. Generated draw code relies on this (see
  [generated-code-addresses](generated-code-addresses.md)).

## The fix

Comment the directive out, leave a `; V2-DEVIATION:` marker and record it in
`engine/v1-manifest.csv`:

```asm
        ;setdp dp/256 ; V2-DEVIATION: setdp neutralized (not permitted in
                      ; lwasm obj target ; runtime DP is untouched,
                      ; implicit-direct operands assemble extended)
```

Do not "fix" the resulting extended operands by hand — that is a renaming-phase
optimisation, not a migration step, and hand edits break the 1:1 diff against
v1.

## Proof

The build passes, and the listing shows extended operands where the source
looked direct. Where an explicit `<` survives, check the emitted byte against
the runtime `DP` — `DE F0` with `DP = $9F` is `$9FF0`, not `$00F0`.

## Met in

Recorded from the `sound/to8` pilot, 2026-07-31. Three files carry the
deviation: `engine/irq/Irq.asm`, `engine/palette/PalUpdateNow.asm`,
`engine/palette/PalUpdateNowLean.asm`.

Met again in wide-dot/sonic-2 (2026-10-05), where the extended operands
mattered : Emerald Hill's parity bench compares Sonic's trajectory with v1
loop for loop, and v1's physics, collision and HUD code leant on `setdp` for
some 1 200 operands. That game restores them with a tool rather than by hand
(`tools/force_direct.py` there) : it reads v1's listings, finds each
instruction v1 assembled direct without a `<` in its source, and adds the `<`
to the same line of the game's copy — game code only, the engine files keep
this case's rule.

