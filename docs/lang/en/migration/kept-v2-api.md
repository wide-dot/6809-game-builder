# A KEPT-V2 module imposes its API on imported objects

When an imported v1 object talks to a module the migration kept in its v2 form,
the object adapts to the v2 vocabulary — not the other way round. Do it as a
pure rename, marked as one deviation.

## Symptom

Build errors on symbols that obviously exist — just not under that name:

```
ERROR : Undefined symbol Fire_Press
ERROR : Undefined symbol c1_button_A_mask
```

The v1 object speaks the v1 dialect; the resident engine carries the KEPT-V2
module, which exports the same facilities under its own names.

## The v1 idiom

The r-type player reads the pad through the v1 joypad module:

```asm
        lda   Fire_Press
        anda  #c1_button_A_mask
```

## The v2 model

The joypad module was arbitrated **KEPT-V2** on 2026-07-31: its form is
v2-native (it carries the Megadrive 6-button support the v1 lacks), it is
already in the resident unit, and it is drift-checked against its v1 original.
Keeping both modules would mean two input readers in the resident engine and a
decision deferred to the renaming phase anyway.

Before adapting, **diff the two routines** — the decision is only this easy
because they turned out identical:

- same read (`ldd` the PIA, `coma/comb`), same edge detection (XOR-then-AND),
  same three variable pairs in the same order, same cycle counts;
- same mask values bit for bit;
- the only differences: names, and `map.MC6821.PRA1` instead of a hard-coded
  `$E7CC`.

Had the logic differed, this would be a behaviour decision, not a rename.

## The fix

A mechanical rename at the call sites, one deviation marker for the lot:

| v1 | v2 |
|---|---|
| `Fire_Press` / `Fire_Held` | `joypad.pressed.fire` / `joypad.held.fire` |
| `Dpad_Press` / `Dpad_Held` | `joypad.pressed.dpad` / `joypad.held.dpad` |
| `c1_button_A_mask` | `joypad.0.A` |
| `c1_button_up/down/left/right_mask` | `joypad.0.UP` / `.DOWN` / `.LEFT` / `.RIGHT` |
| `c1_dpad` | `joypad.0.DPAD` |

The module's *variables* cross the link boundary (they are labels in the
resident unit); its *masks* are shared at assembly time by
`joypad.const.asm` — the [equates-link-boundary](equates-link-boundary.md)
split, applied once more.

Two companion facts found while wiring the player:

- **v1 companions of a KEPT-V2 module still import 1:1.** `joypad.buffer.asm`
  (the direction history the force pod replays) has no v2 counterpart; it was
  imported unchanged, placed under `system/to8/controller/` beside the module
  it belongs to, and — being a v1 file with no `SECTION` — included inside the
  host's section ([v1-file-sections](v1-file-sections.md)).
- **Someone must call the reader.** In v1 the game mode's loop called
  `ReadJoypadsKbd` every frame; the v2 stage loop must call `joypad.read` (and
  `joypad.buffer.addDirection`) itself, or `held`/`pressed` stay zero and the
  player simply never moves — with no error anywhere.

## Proof

Behavioural, under toje: force the direction source, watch the object state.
Patching `addDirection`'s PIA read to a constant `UP` for 50 frames moved the
player's `y_pixel` from 121 to 88 with a negative `y_vel` and the banked-up
pose; restoring the read dropped `y_vel` to zero and froze the position.

## Met in

`games/r-type`, 2026-08-03, porting the player. Ten call sites, seven symbols.
