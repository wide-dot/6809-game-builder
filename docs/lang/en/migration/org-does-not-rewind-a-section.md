# `org` does not rewind a section : the bytes after it move away from their symbols

## Symptom

None at assembly : the unit assembles, links and loads. Then the game
behaves as if half of its code were someone else's — in Sonic 2's title the
first sign was the layout check, `region 'gm' [$6100-$9EC3] runs into the
reserved range 'stack'`, a game mode 820 bytes bigger than its v1 twin with
the same code.

The listing looks right. `lwobjdump` does not agree with it :

```
0008 39       after   rts          <- the listing
CODE 0012 bytes                    <- the object : the rts is at offset $0E
    0000 8601000000000000010203040506398E
```

## The v1 idiom

v1's SMPS driver (`engine/sound/Smps.asm`) declares its RAM as struct
instances, labels only, then goes back to the first one to give them their
initial values :

```asm
StructStart
Smps          SmpsVar          ; 22 bytes reserved
SongDAC       Track            ; 42 bytes reserved, x 19 tracks
...
StructEnd
        org   StructStart      ; back to the start...
        fill  0,sizeof{SmpsVar}
        fdb   $0006            ; ...to write VoiceControl, hardcoded
        fill  0,sizeof{Track}-2
        ...
```

In an absolute image `org` moves the location counter and the bytes land
over the reservation : the labels name the initial values.

## The v2 model

In lwasm's obj target a section's bytes are **appended in source order**.
`org` moves the location counter — every later symbol takes the rewound
value — but the emission does not go back. A struct instance in a code
section is a reservation, emitted as zeros. So the zeros come first, the
initial values are appended after them, and everything that follows the
`org` sits `StructEnd - StructStart` bytes further than its symbols say : 820
bytes for SMPS, whose code follows the block.

Any `org` that goes backwards inside a section has this effect, whatever
precedes it.

## The fix

Emit the bytes once, and turn the reservation into equates on them. The
member symbols a struct instance defines (`Smps.SFXToPlay`,
`SongFM7.NoteControl`) have to be spelled out, so two macros do it from the
offset equates the file already has :

```asm
_smps.track MACRO
\1              equ   StructStart+smps.var.size+(\2)*smps.track.size
\1.NoteControl  equ   \1+NoteControl
        ...
 ENDM
smps.var.size   equ   sizeof{SmpsVar}
smps.track.size equ   sizeof{Track}
StructStart
        _smps.var    Smps
        _smps.track  SongDAC,0
        ...
        ;org   StructStart     ; V2-DEVIATION
        fill  0,sizeof{SmpsVar}
        fdb   $0006
        ...
StructEnd
```

`set` would have been the natural running counter ; it does not take a
section-relative value in a macro (`Multiply defined symbol`), hence the
track index in the second argument.

## Proof

The game mode shrank by exactly 820 bytes, `lwobjdump` and the listing agree
again, and the SMPS state read under toje at the same frame is the v1 one
byte for byte (docs/migration.md §7 of wide-dot/sonic-2) : the music plays.

The same idiom was in `sound/SmpsObj.asm` (`org tracksStart`, the tracks of
the SMPS object) and `irq/IrqObjSmps.asm` (`org SmpsStructStart`, a lone
`SmpsVar`) ; both got the same treatment for Sonic 2's Emerald Hill, the
members spelled from the structs' own field offsets (`\1+Track.NoteControl`,
lwasm defines `Struct.field`). Note that `sizeof{}` is refused inside a macro
(`Bad operand`) : take it into an equate first.

## Met in

wide-dot/sonic-2, title game mode, 05/10/2026. `sound/Smps.asm` left the v2
engine on 06/10/2026 : Sonic 2's title runs the SMPS object too, one driver
for the game ; the idiom above stays v1's.
