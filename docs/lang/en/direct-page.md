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
ZX0_DP  equ $60DD                 ; bootloader : four bytes of the monitor page
ZX0_DP  equ dp_engine             ; game mode  : four bytes of the engine scratch
```

Ten cycles per call buys the removal of an entire class of question.

## Choosing bytes in the monitor page

**Start with the stack.** The monitor sets `LDS #$60CC` at `$FDD5` and the
stack grows down, so **`$608B-$60CC` is stack** and nothing below `$60CC` can
be claimed. This is the part that measurement cannot tell you: a stack is
never named by an instruction, so an operand scan is blind to it, and a byte
that survives one boot only proves the stack did not get that deep *that
time*. The boot-long diff below shows the page changing from `$60A8` to
`$60CB` — that is not a buffer, it is how far the stack went.

`$60DD..$60E0` was then picked where three sources agree:

- **Above the stack top**, so no call depth can reach it.
- **The monitor ROM**, disassembled (`toje/docs/rom-disasm`, monitor1 +
  monitor2): 147 of the 256 offsets appear as a direct or absolute operand.
  `$60DD..$60E4` appears nowhere.
- **A boot-long diff** — the page captured at the monitor menu and again at the
  game mode's first instruction, so boot, directory load and scene load are all
  covered — and **a pattern test**: `D0 D1 D2 D3 D4 D5 D6 D7` written there
  survives the whole boot, on floppy **and** on SDDrive. Together these catch
  writes made through a pointer, which the operand scan cannot see.

Documented owners nearby, deliberately avoided: `$6099` (SDdrive magic backup,
inside the stack anyway), `$60CD` (`PTCLAV`), `$60D6-$60D9` (mouse coordinates
— written under interrupt when the pointer IRQ is enabled), `$60FE` (cold
reset).

"Free" here means *above the monitor stack, never named by the monitor ROM, and
never written during a full boot and scene load on either medium*. It does not
cover monitor services the engine never calls — tape, printer, returning to
BASIC.

## Choosing bytes in the engine page

`dp_engine` is a union, not an allocation: every routine that needs temporaries
carves its own aliases from `dp_engine+0` and they all overlap. The rule is
that only one of them is live at a time.

`zx0` takes `dp_engine+0..+3`, which is safe because no user of that area keeps
it across a compiled-sprite call — `CheckSpritesRefresh`'s three variables die
before `DrawSprites`, and `BuildSprites` rewrites `+0..+5` for every sprite,
keeping only `+6`, `+7` and `+24` across its `jsr [_draw_routine]`.

One pattern to watch: r-type's `hud.asm` and `text.asm` hold a digit counter at
`dp_engine+0`/`+1` **across** their glyph draw call, as does Sonic-2's
`digit-counter`. A game doing that must not draw a compressed image from that
loop. It is not a live problem — a `zx0` image is a full-width background, not
a glyph — but it is the shape of the one that would be.
