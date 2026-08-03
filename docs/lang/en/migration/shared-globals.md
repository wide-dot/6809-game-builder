# A global read from several pages is an address, not a label

## Symptom

Nothing fails. Two units each hold a byte called `globals.backgroundSolid`,
each initialised to zero, each in its own page — and they are not the same
byte. One writes it, the other keeps reading zero, and the bug looks like a
logic error in whichever code you read second.

The variant that does fail is louder and comes from the same cause :

```
ERROR : Undefined symbol globals.difficulty
```

in a unit that has no business owning that variable.

## The v1 idiom

v1 has one flat memory map. `global/variables.asm` names the inter-main
variables as **absolute equates** in a reserved block :

```asm
GLOBAL_VARIABLES         equ $9E84
globals.score            equ GLOBAL_VARIABLES+1 ; 3 bytes
globals.backgroundSolid  equ GLOBAL_VARIABLES+5 ; 1 byte
globals.difficulty       equ GLOBAL_VARIABLES+6 ; 1 byte
```

Every game mode and every object includes that file, and the question "where
does this variable live" never comes up : it lives at `$9E89`, for everyone.

## The v2 model

A v2 unit is relocatable and lands in a region, so the reflex when porting is
to give a variable a home in whichever unit uses it :

```asm
globals.backgroundSolid  fcb  0        ; in the player's unit
```

That works exactly as long as one unit reads it. The moment a second unit in
another page needs it, there are two answers :

- **export it** — it becomes a link symbol, resolved at load time, and the two
  units agree. It costs link data, and it makes an ordinary variable part of
  the engine's interface ;
- **declare it in the layout** — a `<reserved>` range is precisely a piece of
  memory the game occupies without loading anything into it, and an equate
  into that range is an absolute address every unit computes for itself, with
  no link data and no interface entry.

The second is what v1 was doing all along, and what the reserved zone exists
for. The first is right for a routine or a table that belongs to one unit ; a
*global* is not that.

The tell is in the name : if it is called `globals.something`, it is being read
from more than one place, and the layout should know about it.

## The fix

Declare the range once in the layout, and include the equates wherever they
are read :

```xml
<reserved name="globals" page="$01" address="$9E84" size="$007C"/>
```

```asm
        INCLUDE "src/common/state/variables.asm"
```

Then delete the labels that were standing in for them, and take the name **out
of the interface** if it was in it — an absolute equate that crosses the link
gets rebased, which is the case next door
([equates-link-boundary.md](equates-link-boundary.md)).

One consequence to carry : a reserved range is RAM **nothing loads**, so its
content at power-on is whatever the machine left there. v1 initialises those
variables in its main ; the port has to do the same, at the same place. A dirty
`globals.difficulty` indexes the enemy fire preset table 64 bytes further along
per step, straight out of its own data.

## Proof

`ram-map-fd.txt` shows the range as reserved on page `$01`, with no region
overlapping it. In the game, an enemy in page `$05` and the player in page
`$11` now read the same `globals.backgroundSolid` that the stage in page `$01`
wrote — the enemy bullets stop on the background exactly where the player's
shots do.

## Met in

R-Type v2, 2026-08-03, porting the enemy fire chain. `globals.backgroundSolid`
and `globals.missileUnlocked` were labels in the player's unit ;
`globals.score` was a label in the engine's. All three moved to the reserved
zone, and `globals.score` left the engine interface.
