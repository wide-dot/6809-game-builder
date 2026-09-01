# Memory : pages, windows and places

A game says where its bytes go. On a 6809 machine that question has three
parts, and the builder keeps them apart on purpose.

| what you are saying | how you say it | example |
|---|---|---|
| which RAM it lives in, absolutely | `page` | `$17` |
| what address it runs at, so addresses can be baked | `address` | `$6100` |
| which space the loader copies it into | *nothing — it follows from the address* | |

The third one is not written because it cannot differ : the machine's windows
occupy disjoint CPU ranges, so an address names one of them and one only.

## The absolute referential

A byte of RAM has one identity : **its physical address**.

```
position in the page = address modulo the page size
physical address     = page × page size + position
```

You never write the position. The builder computes it, and every check it
runs — overlaps, reserved ranges, budgets — happens there. That is what lets
it answer a question the declared addresses cannot : *are these two places the
same silicon ?*

They often are. On a TO8, page 1 seen through the resident window and page 1
mounted in the cartridge window are the same bytes at different addresses.

## Windows

A window is what the processor sees, and how the page it shows is chosen. The
machine declares them, in `engine/config/machine.xml` :

```xml
<machine name="to8">
    <ram pages="32" pagesize="$4000"/>

    <window name="cart" address="$0000" size="$4000" page="register:$E7E6"
            mask="%00011111" or="map.RAM_OVER_CART"
            include="engine/system/to8/map.const.asm"/>
    <window name="video" address="$4000" size="$2000" page="0"
            select="register:$E7C3" bit="0">
        <slice index="0" value="1"/>
        <slice index="1" value="0"/>
    </window>
    <window name="resident" address="$6000" size="$4000" page="1"/>
    <window name="data"     address="$A000" size="$4000" page="register:$E7E5"/>
</machine>
```

Three of them are pure arithmetic. The fourth needs two lines because it shows
**8 KB of a 16 KB page** : an address of `$4000` does not say which half, and
the register numbers the halves backwards — its bit set to 1 shows the FIRST
half. A place in that window says which half it means, in the page's own
order :

```xml
<region name="pscroll.vid" page="$00" slice="0" address="$4000" size="$2000"/>
```

and the builder writes `1` in the register for it. Nobody else has to know.

### Why $6000 is in the middle of a page

The low bits of the CPU address are the position in the page. The video window
is only 8 KB, so it pushes everything after it off the 16 KB grid :

| window | CPU | position in the page it shows |
|---|---|---|
| cartridge | `$0000-$3FFF` | `$0000-$3FFF` |
| resident | `$6000-$9FFF` | `$2000-$3FFF` then `$0000-$1FFF` |
| data | `$A000-$DFFF` | `$2000-$3FFF` then `$0000-$1FFF` |

Nothing is folded or wired oddly : `$6000 mod $4000` is `$2000`, and `$8000 mod
$4000` is `$0000`. What emulator documentation calls a non-linear segment order
is this, and nothing more.

**A place may run past the end of its page and continue at its start.** A file
loaded at `$7C00` and longer than `$0400` does exactly that : the processor
reads one continuous run, the page holds two pieces. It is legal, the checks
compare both pieces, and the occupancy report draws them and says why.

What is *not* legal is running past the end of the **window** : a 8 KB
cartridge file placed at `$3000` would spill into the video window and write on
screen. That is refused, with the arithmetic in the message.

## Places

```xml
<region   name="collision" page="$17" address="$0000" size="$4000"/>
<region   name="engine"                address="$6100"/>
<reserved name="loader"    page="$04" address="$C000" size="$2000"/>
<arena name="objects">
    <zone page="$04" address="$2000" size="$2000"/>
</arena>
```

`page` is omitted where the window fixes it — the resident window is a window
on page 1, the video window on page 0. Everything else is the address the code
itself uses, which is why no declaration has to be converted from one
coordinate system to another.

## The loader's spaces

At run time the loader copies and decompresses into a space. Those spaces are
not declared anywhere : they are **the machine's windows minus the one the
loader runs from**. Mounting a page in the window it executes from would unmap
it mid-copy, so a load that targets it is refused.

On a Thomson the loader lives in the data window, which is why it serves the
cartridge, video and resident spaces. On a machine whose loader lived
elsewhere the list would differ, with nothing to change.

The loader is a place like any other, and its declaration covers its heap as
well as its code — the pool it allocates from runs to the end of its window.
Declaring it is what stops anything being placed on top of it.

## What the builder checks

1. the place stays inside its window ;
2. the window can show that page — `window video` cannot show page 1 ;
3. no two places overlap **in physical bytes**, whatever windows they are
   reached through, and whether or not they wrap the end of a page ;
4. nothing lands on a reserved range, or on the loader ;
5. a place declared twice — a reservation and the assembler symbols the game
   defines for it — agrees with itself.

## Reading the report

`occupancy-<target>.html` draws one row per physical page, from its first
byte. An element is drawn where it *is* and labelled with the address it is
*reached at*, plus the window. A place in two pieces is drawn twice, and the
tooltip says so.
