# Declarative scenes and memory regions

Status : implemented and validated (July 2026). French design records :
[`modele-regions-2026-07.md`](../fr/modele-regions-2026-07.md) (doctrine),
[`scenes-declaratives-2026-07.md`](../fr/scenes-declaratives-2026-07.md)
(implementation plan). Runtime model : [`groups.md`](groups.md).

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
            <!-- data direntries, declared as usual -->

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

A scene is a regular direntry (raw, uncompressed, one id block) whose source
is generated ; it goes through the standard direntry pipeline and its name
becomes a file id equate, so game code loads it exactly as before :
`ldx #scenes.level1` / `jsr loader.scene.load`.

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

## Element reference

| Element | Attributes |
|---|---|
| `<layout>` | `gensymbols` (optional) : generated file of `<region>.page` / `<region>.address` equates for the game code to include |
| `<region>` | `name`, `page`, `address` (required) ; `size` : byte budget, checked ; `bulk` : the region takes an ordered list per scene, laid out one after the other — the list is the unit of replacement, members are not individually replaceable |
| `<scene>` | `name` (required), `section`, `gensource` (defaults to `gen/scenes/<name>.asm`) |
| `<load>` | `name` (required) ; either `region`, or `page`+`address` (raw escape hatch), or nothing (link data only — the file must be export-only) |

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
silently falls back to `%10`. Declaring the direntries of a lot consecutively
and listing them in the same order is what makes `%11` kick in.

## Validation

The whole example corpus (17 scene tables across 8 configurations) is
declarative. The migration was proven **byte for byte** against the
handwritten tables, and the `%11` encoding step was validated by execution :
`examples/loader-ut` replayed 16/16 under the toje emulator (multi-disk swaps
included), `examples/sound` title music verified in RAM and hot-swapped to
level1.
