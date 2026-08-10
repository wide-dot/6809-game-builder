# Declarative scenes and memory regions

> **The vocabulary, one line each.** A `<region>` is a named destination. The
> layout declares **constraints, not decisions** : write the page when the
> region has to travel with its neighbours, the address when it has to be at a
> given place, the size when it is a budget to enforce — and leave out
> whatever the builder can work out. A `<window>` says where the machine sees
> a page, which is how the builder knows where one begins and ends. A `<file>` is one loadable file, placed in a region. A `<unit>` is one
> indivisible object — entry symbol plus content, code and images alike ; its
> container decides its dressing. A `<pageset>` packs many contents into a page
> budget : divisible content spreads, units fill the tails. A `<scene>` says
> what is in memory at a time, `<load>` by `<load>`. `stacked` on a region
> lays a scene's loads end to end at run time. `linkdata="LINK"` sends a
> file's link block to the LINK section ; `bake` decides what never needs one.
> A `<file>` may declare its **attributed place** (`arena=`, `region=`, or
> `page=`+`address=`) — then every `<load>` of it reduces to the name.

> **Next model, decided 2026-08-06, not yet implemented** : regions gain
> `<zone>` children (a continuous range in one page), `<arena>` arrives for
> automatic placement, and `<window>` / `size="auto"` / `address="auto"` /
> `pages="auto"` / `stacked` all go away. See
> [`modele-zones-2026-08.md`](../fr/modele-zones-2026-08.md) — decision and
> implementation plan.

Status : implemented and validated (July 2026). French design records :
[`modele-regions-2026-07.md`](../fr/modele-regions-2026-07.md) (doctrine),
[`scenes-declaratives-2026-07.md`](../fr/scenes-declaratives-2026-07.md)
(implementation plan). Runtime model : [`groups.md`](groups.md).

## Declare the constraints, not the decisions

A layout used to spell out every number : page, address, size, page count. Most
of them were guesses — a size is a number the author has to invent before the
content exists, and re-invent every time it changes. Guessing high is the safe
move, so every region ended up carrying a tail nobody could use (105 060 bytes
measured on r-type).

So the rule is reversed. **What you write is a constraint ; what you leave out,
the builder works out.**

| you write | you are saying |
|---|---|
| `page="$13"` | this region travels with whatever else is on page $13 |
| `address="$6100"` | it has to be exactly there |
| `size="$1EC0"` | this is a budget — refuse the build if the content outgrows it |
| nothing | up to you |

```xml
<region name="common" page="$01" address="$6100" size="$1EC0"/>  <!-- everything pinned -->
<region name="weapon" page="$13"/>                               <!-- page pinned, rest measured -->
<region name="beamcharge" page="$13"/>                           <!-- same page, right behind -->
<region name="checkpoint"/>                                      <!-- the builder finds it a home -->
```

A region with no page is placed in the first hole big enough, scanning the
pages the author pinned before opening one from the layout's `sparepages`
range — so the unused tail of a page gets filled before fresh RAM is spent.
First fit in declaration order, never sorted by size : adding a region must
not move the ones already placed, or every object would change page, and its
page id with it.

**What this costs you.** The builder decides who sits next to whom. On a paged
machine that is a real decision — two objects in one page is one bank switch
saved when they run together. Keep `page="…"` for anything whose neighbours
matter, and for everything the machine reaches by a fixed address : the
resident window, the loader, the interface regions scenes swap. A region is a
good candidate for automatic placement when it is reached through a page id,
which is exactly what the game's objects are.


## What this is

Scene tables — the placement scripts `loader.scene.load` consumes — are
**generated** from declarations in the configuration file instead of being
handwritten in assembly. Destinations come from named **regions**, so a wrong
page or address is a build error with a `file:line` position instead of a
runtime memory corruption.

```xml
<target name="fd">

    <layout gensymbols="gen/layout.asm">
        <region name="gamemode" page="$01" address="$6100" size="$1F00"/>
        <region name="music"    page="$06" address="$0400" size="$3C00"/>
        <region name="sfx"      page="$05" address="$0000" size="$2000" bulk="true"/>
    </layout>

    <floppydisk model="fd640">
        <directory id="0" ...>
            <!-- data files, declared as usual -->

            <scene name="scenes.level1" section="SCENE">
                <load name="group.gm.level1"   region="gamemode"/>
                <load name="group.level1.music" region="music"/>
                <!-- bulk region : an ordered list, laid out one after the other -->
                <load name="sfx.shot" region="sfx"/>
                <load name="sfx.boom" region="sfx"/>
                <!-- link data only : no destination -->
                <load name="engine.system.to8.sound.ym.const"/>
            </scene>
        </directory>
    </floppydisk>
</target>
```

A scene is a regular file (raw, uncompressed, one id block) whose source
is generated ; it goes through the standard file pipeline and its name
becomes a file id equate, so game code loads it exactly as before :
`ldx #scenes.level1` / `jsr loader.scene.load`.

## The attributed place

A file may declare its destination **on its own declaration** instead of on
every load that names it :

```xml
<file name="common.player" codec="zx0" linkdata="LINK" bake="auto" arena="objects">…</file>
<file name="common.engine" codec="zx0" linkdata="LINK" bake="auto" region="common">…</file>
…
<scene name="scenes.boot" section="SCENE">
    <load name="common.player"/>     <!-- loads into arena "objects" -->
    <load name="common.engine"/>     <!-- loads at region "common" -->
</scene>
```

One form of the three at most : `arena=` (the builder picks page and
address), `region=` (a named place of the layout), or a literal
`page=`+`address=`. A `<pageset>` already declares its `region=` — that IS
its attributed place, so a scene names the set bare.

What this buys is **structural uniqueness** : a file loaded by five scenes
has one declared destination, and there is nothing left for two scenes to
disagree about — where the per-load form could only verify their agreement
after the fact. One destination per file is also what lets `bake="auto"`
resolve references into it at build time.

The rules :

- a **bare load** of a file with an attributed place loads it there ; a bare
  load of a file without one stays what it always was, link data only ;
- a load that **repeats** the same destination is tolerated — the
  transitional form while a configuration migrates ;
- a load that **contradicts** the attributed place is a build error naming
  both declarations ;
- declaring a **different place** for the same file name twice is a build
  error.

The per-load destination keeps working for files that declare nothing — the
attributed place is additive, and the target model (where `<load>` is only
ever a name) is reached by migrating file by file.

## The model in one rule

The loader evicts a stale link data slot on an **exact destination match**
(page + address). Two resources can therefore only take turns at a shared
fixed address — which is precisely what a region is. Hence :

> **The region, not the file, is the unit of replacement.**

Declaring a layout is answering *"how many things do I need to replace
independently ?"*. Reloading into the same region costs nothing (implicit
unload does the bookkeeping) ; loading at a different address over live
content requires an explicit `loader.file.linkData.unload` first.

## What the builder checks — and what it does not

Compositions are made of reusable elements of inherently heterogeneous sizes ;
the game code sequences them in an order the builder cannot see. So :

- **the builder verifies one scene** (one composition), completely :
  - every `<load>` references an existing entry of the directory ;
  - unknown region, duplicated region, region combined with a raw
    destination : errors at generation time ;
  - once all entries are built and sizes are known : every file fits its
    region budget (`size`), no two writes of one scene land on each other
    (bulk layouts computed member by member), and a file carrying data cannot
    go without a destination — while an empty file at a destination stays
    legal (page-switch tricks) ;
- **sequencing belongs to the game code** : regions may overlap, two scenes
  may carve the same page differently. Nothing is checked across scenes —
  that would amount to demanding a single memory map for the whole game.

## The occupancy map

Destinations are placed by hand, against budgets worked out once. What nothing
said until now is what those budgets leave over — a region's `size` is a
promise, not a measurement, and the difference between the two is exactly the
room the next object can take.

Every build writes `dist/ram-map-<target>.txt` : one map per scene, since a
scene is the composition that gets optimised. Each map shows the **whole
declared layout**, page by page, in address order.

```
scene scenes.boot
------------------------------------------------------------------------------
page $01
  $6100-$82FF  region    common                   8704  common.engine    7687   88%
  $8300-$8FFF  region    stage                    3328  stage1           1501   45%
  $9000-$90AF  free                                176
  $90B0-$97FF  reserved  objects.pool             1872
  ...
  declared up to $A000
page $14
  $0000-$0FFF  region    explosion                4096  common.explosion  505   12%
  declared up to $1000
```

Three things it says, in the order you need them :

- **the gaps** between declarations, with their size — that is where something
  new can go without moving anything ;
- **budget against content** for every region the scene loads, so an oversized
  budget shows up as a low percentage rather than as nothing at all ;
- **`declared up to`**, the highest address the layout claims on that page.
  What lies beyond is not free, it is *undeclared* : a layout declares regions
  and reserved ranges, never the bounds of a page, and those bounds differ with
  the window a page is seen through. So the map states where the declarations
  stop rather than inventing where the page does.

A region a scene does **not** load reads `(not loaded by this scene)`, never
"free". It holds what an earlier scene put there, and that is precisely what
the builder does not know — see the rule above. Regions spread over several
pages are counted **page by page** : a pageset member lands on one of them.

## The link data pool map

The occupancy map answers *where does this scene land*. The other budget a
scene is placed against is *what does linking it cost*, and it has its own
report : `dist/pool-map-<target>.txt`.

The loader keeps one link block per indexed file, in its memory pool, for as
long as that file stays indexed. So a scene's demand is the sum over the files
it loads — and the sum that matters is not the raw one. TLSF adds a four byte
header to every block and rounds each request up to its size class, so a 2266
byte link block occupies 2304. The report counts what the allocator reserves :

```
loader.DEFAULT_DYNAMIC_MEMORY_SIZE = $3000 (12288 bytes)

scene scenes.boot — 28 indexed file(s) carrying link data
     bytes   served  file
      2266     2304  common.engine
       918      928  common.player
       ...
  --------- --------
      9036     9296  total — 75% of the pool, 2992 bytes left
```

**The total is a floor, not the peak**, and the report says so at the top. The
same pool also holds the directory, the scene file and the loader's slot table,
and a scene swap allocates the incoming scene before releasing the outgoing
one. Those depend on constants that live in the assembler sources ; hard-coding
them here would produce a figure that silently goes wrong. What the report does
count is the term that grows every time a unit is wired, which is the one you
are arbitrating.

The definitive check costs one byte : read `tlsf.err` on the machine after the
boot. `0` is fine, `3` is `OUT_OF_MEMORY` — and an overflow shows nothing at
all on screen, the loader simply never hands over. See
[static-link-bake.md](migration/static-link-bake.md).

Read the two reports together. When something no longer fits, the RAM map says
whether there is a page for it and the pool map says whether the loader can
still link it — and the answers are independent.

## Element reference

| Element | Attributes |
|---|---|
| `<layout>` | `gensymbols` (optional) : generated file of `<region>.page` / `<region>.address` equates for the game code to include |
| `<region>` | `name`, `page`, `address` (required) ; `size` : byte budget, checked ; `bulk` : the region takes an ordered list per scene, laid out one after the other — the list is the unit of replacement, members are not individually replaceable |
| `<reserved>` | `name`, `page`, `address`, `size` (all required) : a range the game occupies without loading anything into it — object pool, globals, stack, direct page. Nothing may be loaded on top, and the check is on the *declarations*, so a region declared over the pool is an error even while its content stays small |
| `<scene>` | `name` (required), `section`, `gensource` (defaults to `gen/scenes/<name>.asm`) |
| `<load>` | `name` (required) ; either `region`, `arena`, or `page`+`address` (raw escape hatch), or nothing — which means the file's attributed place when it declares one, link data only otherwise (the file must then be export-only) |

## Block encoding is automatic

The loader's three scene block types exist for table compactness (the table
is malloc'ed from the TLSF pool at load time). They are never authored — the
generator selects them :

| shape | encoding | bytes |
|---|---|---|
| loads with their own destination | `%01` explicit triplets | 2 + 5n |
| bulk list / export-only lot | `%10` base + ids | 5 + 2n |
| same, when the ids chain (next id = id + blocks) | `%11` base + start id | **7 flat** |

The id chain is re-checked at every build ; reordering the configuration
silently falls back to `%10`. Declaring the files of a lot consecutively
and listing them in the same order is what makes `%11` kick in.

## Validation

The whole example corpus (17 scene tables across 8 configurations) is
declarative. The migration was proven **byte for byte** against the
handwritten tables, and the `%11` encoding step was validated by execution :
`examples/loader-ut` replayed 16/16 under the toje emulator (multi-disk swaps
included), `examples/sound` title music verified in RAM and hot-swapped to
level1.
