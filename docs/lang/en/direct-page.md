# The direct page

The 6809 reaches an address in two bytes instead of three when its high byte
matches the DP register. The engine leans on that for its globals, so **which
page DP holds is part of the contract**, not an implementation detail. Two
pages are in play, and code that runs in both has to say which one it means.

| page | who | what lives there |
|---|---|---|
| `$60` | the monitor, and the loader while it talks to it | disk registers (`DK.OPC` `$6048`, `DK.BUF` `$604F`…), `STATUS` `$6019`, IRQ vectors `$6023`/`$6027`, keyboard buffer `$6079`, **the monitor's system stack `$608B-$60CC`**, `PTCLAV` `$60CD`, mouse coordinates `$60D6-$60D9` |
| `$9F` | the engine and the game | `glb_*` globals, `dp_extreg` (28 B), `dp_engine` (30 B), and the user space below them |

## The handover

The loader boots on the monitor's page, because that is where the disk
registers are. It switches to the engine's page in the last three instructions
before it jumps to the game mode:

```asm
        lds   #glb_system_stack
        lda   #dp/256
        tfr   a,dp
        jmp   loader.DEFAULT_SCENE_EXEC_ADDR
```

Both halves matter. Without the `tfr`, a game mode reads and writes its
globals *inside the monitor page* — every `<glb_...` in the runtime is a
forced-direct access, so it follows DP wherever DP happens to point. It works
right up until something else in that page moves: a scene load writes `$60DC`,
which is `glb_camera_x_offset`'s offset.

## The other direction

Once DP is the engine's page, the loader can no longer assume it owns DP:
`loader.dir.load`, `loader.file.load` and the "insert disk" prompt are called
*from a running game mode*. Each entry point that reaches the monitor saves
DP, sets `map.REG.DP`, and puts the caller's back:

```asm
loader.dir.load
        pshs  dp,a
        lda   #map.REG.DP
        tfr   a,dp
        puls  a
        jsr   loader.dir.load.do
        puls  dp
        rts
```

`loader.file.loadByPtr` always did this. The others got away without it only
because the handover above was missing, so DP was `$60` everywhere. The two
defects hid each other: fixing the handover alone hangs the loader on its
first prompt.

## Code that runs on both pages

`zx0_decompress` is assembled twice — once into the bootloader, once into a
game mode that draws compressed images — and the bootloader's copy runs on
`$60` at boot but on `$9F` when a game mode asks for a scene. So it does not
inherit a page at all: the includer names a **full address** in `ZX0_DP`, and
the routine sets DP from it and restores the caller's on exit.

```asm
ZX0_DP  equ $6031                 ; bootloader : the monitor's music note registers
ZX0_DP  equ dp_engine             ; game mode  : four bytes of the engine scratch
```

Ten cycles per call buys the removal of an entire class of question.

## Choosing bytes in the monitor page

`$6031..$6034` is taken from the seven bytes the monitor's **music note
routine** uses (`$6031-$6037`). The engine never plays a note through the
monitor, so these bytes have an owner that is provably never invoked. That is
a stronger claim than "nothing appears to use this address", and it is the
claim to look for.

Two properties back it up:

- **The stack.** The monitor sets `LDS #$60CC` at `$FDD5` and the stack grows
  down, so `$608B-$60CC` is stack and cannot be claimed. `$6031` is well clear.
  This is the part measurement cannot establish: a stack is never named by an
  instruction, so an operand scan of the ROM is blind to it, and a byte that
  survives one boot only shows the stack did not get that deep *that time*. A
  boot-long diff of the page shows writes from `$60A8` to `$60CB` — that is not
  a buffer, that is how far the stack went.
- **No persistence.** The decoder's four bytes hold nothing between calls:
  every read is preceded by a write on the same path. So only a write *during*
  a call could hurt — and the loader masks interrupts around it, and the
  decoder calls nothing. Bytes written between two decompressions are
  harmless.

Documented owners deliberately avoided: `$6048-$6050` (disk), `$6019`
(`STATUS`), `$6023`/`$6027` (FIRQ/timer vectors), `$6079` (`BUFCLV`), `$6099`
(SDdrive magic backup), `$60CD` (`PTCLAV`), `$60D6-$60D9` (mouse coordinates,
written under interrupt when the pointer IRQ is on), `$60FE` (cold reset).

## Choosing bytes in the engine page

**These bytes are scratch, not property.** Every routine that needs
temporaries carves its own aliases from `dp_engine+0` and they all overlap on
purpose. Nothing is reserved, and asking "who owns this byte" is the wrong
question — the right one is "how long does a value in it have to live".

Checked across the whole v1 engine: every alias of `dp_engine` and `dp_extreg`
is written before it is read, inside the routine that uses it. The one
exception is `moveByScript.callback`, which the *caller* sets before calling —
a parameter, not storage. And `moveByScript.register`, which really does keep
state between two entry points, keeps it in **self modified operands**
(`anim.page.1`, `anim.addr`), not here. So no value in either area outlives
the call that put it there.

That makes the only hazard a nesting one: running a scratch user *inside*
another one's lifetime, or under an interrupt that has its own. It is not a
question of which routine was there first.

`zx0` takes `dp_engine+0..+3` on that basis: it is called from inside
`DrawSprites`, which passes nothing in the direct page and holds nothing
there. No user of the area keeps it across a compiled-sprite call — `CheckSpritesRefresh`'s three variables die
before `DrawSprites`, and `BuildSprites` rewrites `+0..+5` for every sprite,
keeping only `+6`, `+7` and `+24` across its `jsr [_draw_routine]`.

One pattern to watch: r-type's `hud.asm` and `text.asm` hold a digit counter at
`dp_engine+0`/`+1` **across** their glyph draw call, as does Sonic-2's
`digit-counter`. A game doing that must not draw a compressed image from that
loop. It is not a live problem — a `zx0` image is a full-width background, not
a glyph — but it is the shape of the one that would be.
