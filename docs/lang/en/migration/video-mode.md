# The video mode is not set for you

A game mode that draws **must** set its mode. The machine boots in 320×200 with
two colours per group of eight horizontal pixels, and will happily read BM16
data as if it were that.

## Symptom

The screen is shredded into columns, or the colours are wrong in a way that
does not match any palette you can find. Everything else looks healthy —
including in-memory witnesses, which is what makes this one waste time: the
data is right, only its interpretation is wrong.

Two v2 benches (`sprites`, `hscroll`) ran this way. Their `$9C00` witnesses
were correct throughout, so every check that read memory passed; only judgement
*made on the screen* was invalid.

## The v1 idiom

v1 game modes wrote the register directly, inline:

```asm
        sta   $E7DC
```

r-type's level 1 does it twice, for its own mode changes. There was no helper,
so a port that drops the raw pokes silently drops the mode setting with them.

## The v2 model

Same register, behind a macro:

```asm
        ; 160x200 in 16 colours : without this the machine stays in its boot
        ; mode and reads the tiles as 320x200 two-colour data
        _gfxmode.setBM16
```

Nothing sets it on your behalf. The loader does not, and the engine does not —
the mode is a property of the game, not of the machinery.

## The fix

Call `_gfxmode.setBM16` (or the mode your game wants) in the stage's or game
mode's initialisation, before anything draws.

## Proof

Look at the screen. This is one of the few cases where memory inspection
actively misleads, so the screenshot is the primary evidence, not the
confirmation.

Check it **first** whenever a render looks shredded in columns — it is cheap to
rule out and it invalidates every other visual judgement while it is
outstanding.

## Met in

`examples/sprites` and `examples/hscroll`, 2026-08-01, both corrected.
`games/r-type` carries the call in `stage-main.asm` with the comment above.
