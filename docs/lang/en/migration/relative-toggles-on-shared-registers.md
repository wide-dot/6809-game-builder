# A v1 relative toggle assumes v1 owned the register ; in v2 it does not

## Symptom

The stage loads, the loader hands over, and the screen stays **black**. No
crash message, no reboot — the CPU has walked off into unmapped memory and is
executing `$FF` bytes (`STU $FFFF`, over and over).

Stepping shows the derailment happens *inside* the pre-scroll replay, several
routines after the real mistake. Everything up to there — the position search,
the six `*_Clear*` calls, the two `ClearDataMem` calls — completes normally and
returns. Nothing reports an error, because nothing detected one : two screen
buffers were faithfully cleared. They just were not the screen buffers.

The title (T1c) hit the same trap with a **smaller symptom** : its opening
cleared "both buffers" before anything had anchored the data window, so both
passes wiped the loader's page instead — a delayed time bomb for the next
`scene.load` — and the real buffers kept their boot residue. Almost all of it
happened to be black already ; what remained was a **single stray byte**, two
white pixels hanging over the logo, visible on one buffer parity only. A
one-byte ghost on screen is this case until proven otherwise : diff the two
buffer parities, the orphan byte gives you the address, and the address tells
you which clear never reached a real buffer.

## The v1 idiom

v1 alternates the two video buffers with a **relative toggle** on the data
window register :

```asm
_SwitchScreenBuffer MACRO
        ldb   $E7E5
        eorb  #1                       ; switch btw page 2 and 3
        orb   #$02
        stb   $E7E5
 ENDM
```

Read the comment literally: *switch between page 2 and 3*. The macro only does
that if the register **already holds 2 or 3**. Feed it 4 and it yields 7, then
6.

In v1 that precondition is free. `gfxlock.bufferSwap.do` writes `$E7E5` itself,
every single frame, so by the time any game-mode code runs the register is
always on a screen buffer. The macro never sees anything else, so its author
never had to say so.

## What changes in v2

Two things, and neither is visible from the call site.

**The frame swap no longer touches the data window.** v2's
`gfxlock.bufferSwap.do` writes only `map.CF74021.SYS2` (`$E7DD`) — the
*displayed* page. Mounting the *working* buffer in `$A000-$DFFF` moved to
`_gfxlock.on`, which does it **absolutely** :

```asm
        ldb   gfxlock.backBuffer.status
        andb  #%00000001                ; B = buffer parity
        orb   #%00000010                ; value should be 2 or 3
        stb   map.CF74021.DATA
```

**The data window belongs to someone else at stage entry.** Scene loading runs
through `game.stage.switch`, which mounts the loader's own page there and never
gives it back — the stage that follows inherits it :

```asm
        _ram.data.set #loader.PAGE
        jsr   loader.ADDRESS+loader.scene.load.IDX
        jmp   stage.address
```

So the first `_SwitchScreenBuffer` a freshly loaded stage executes reads the
loader's page, not a buffer. Every subsequent toggle is offset by the same
amount, forever.

## The v2 idiom

Anchor absolutely, then toggle. One line before the first use :

```asm
        _ram.data.set #2               ; anchor, do not inherit
        ldx   #$FFFF
        jsr   ClearDataMem
        _SwitchScreenBuffer            ; -> 3
        ldx   #$FFFF
        jsr   ClearDataMem
        _SwitchScreenBuffer            ; -> 2
```

The engine had already learned this, one register over. `_gfxlock.on` carries
the same fix for the MC6846 PRC half-page, and says why in as many words :

> pose en ABSOLU sur la parité buffer (comme DATA) au lieu d'un toggle relatif.
> Le toggle dérivait si le registre matériel était stale (…) -> backup corrompu
> / crash. L'absolu est robuste à tout état initial du registre.

## The rule

**A v1 read-modify-write on a hardware register carries an unwritten
precondition: that v1 put the value there.** In v2 the resident engine, the
loader and the mounted units all share those registers, and no single owner
re-establishes them every frame.

When importing any `ldb <reg> / eor / or / stb <reg>` sequence, find who used
to guarantee the input value. If the answer is "a v1 routine that runs every
frame and no longer does this", the import must post an absolute value first.
The failure is silent and lands far from the cause: you clear, draw into, and
flip pages that exist, so the machine keeps running until something reads
through a pointer it destroyed.

## See also

- [Reserved RAM is not zeroed](reserved-ram-is-not-zeroed.md) — the other
  "v1 got it for free" trap, on memory instead of registers.
- [The checkpoint is one routine](checkpoint-is-one-routine.md) — the import
  that surfaced this one.
